-- Летопись и статуи альянса Harvest Hollow.
-- Запуск: Supabase -> SQL Editor -> вставить файл целиком -> Run (после alliance_events.sql). Повторный запуск безопасен.
--
-- Летопись: когда у альянса сменяется неделя (_al_roll), итог прошлой недели записывается страницей:
--   опыт недели, уровень, сколько ступеней стража пало, сколько заданий выполнено, лучший удар недели
--   (кто нанёс больше всего урона стражу) и опора недели (кто больше всех вложил в таланты).
--   Место альянса в неделе считается при чтении (_al_week_place), к тому времени неделя закрыта у всех.
-- Статуи: лучший удар и опора недели получают по статуе. В зале славы стоят статуи нынешних участников:
--   ушёл из альянса - статуя остаётся в летописи, но не в зале.
-- Рамка статуи - украшение за кристаллы (их списывает игра), сервер только хранит выбранную рамку.

alter table public.alliance_members add column if not exists statue_frame text not null default 'stone';

create table if not exists public.alliance_chronicle (
  alliance_id  bigint  not null references public.alliances (id) on delete cascade,
  week_key     int     not null,
  xp           bigint  not null default 0,
  level        int     not null default 1,
  members      int     not null default 0,
  boss_down    int     not null default 0,
  tasks_done   int     not null default 0,
  hit_user     uuid,
  hit_name     text,
  hit_value    bigint  not null default 0,
  give_user    uuid,
  give_name    text,
  give_value   bigint  not null default 0,
  primary key (alliance_id, week_key)
);
create index if not exists alliance_chronicle_hit on public.alliance_chronicle (hit_user);
create index if not exists alliance_chronicle_give on public.alliance_chronicle (give_user);
alter table public.alliance_chronicle enable row level security;
revoke all on public.alliance_chronicle from anon, authenticated;

-- Рамки статуй (как Chronicle.FRAMES в игре).
create or replace function public._al_frames() returns text[] language sql immutable as $$
  select array['stone', 'bronze', 'gold', 'crystal', 'flame']
$$;

-- Страница летописи за неделю p_week. Пустую неделю (никто ничего не делал) не пишем.
create or replace function public._al_chronicle_write(p_alliance bigint, p_week int, p_xp bigint) returns void
language plpgsql security definer set search_path = public as $$
declare w alliance_weeks; hit record; give record; done int := 0; k text; n int;
begin
  if p_xp <= 0 then return; end if;
  select * into w from alliance_weeks where alliance_id = p_alliance and week_key = p_week;
  if found then
    n := w.members;
    foreach k in array _al_task_kinds(p_week) loop
      if coalesce((w.tasks ->> k)::int, 0) >= _al_task_target(k, n) then done := done + 1; end if;
    end loop;
  else
    select count(*) into n from alliance_members where alliance_id = p_alliance;
  end if;
  select wm.user_id, am.name, wm.damage into hit
    from alliance_week_members wm join alliance_members am on am.user_id = wm.user_id
   where wm.alliance_id = p_alliance and wm.week_key = p_week and wm.damage > 0
   order by wm.damage desc limit 1;
  -- Вклад недели ещё не сброшен: _al_roll зовёт эту функцию до обнуления
  select user_id, name, week into give from alliance_members
   where alliance_id = p_alliance and week_key = p_week and week > 0
   order by week desc limit 1;
  insert into alliance_chronicle (alliance_id, week_key, xp, level, members, boss_down, tasks_done,
                                  hit_user, hit_name, hit_value, give_user, give_name, give_value)
  values (p_alliance, p_week, p_xp, (select _al_level(xp) from alliances where id = p_alliance), n,
          greatest(0, coalesce(w.boss_tier, 1) - 1), done,
          hit.user_id, hit.name, coalesce(hit.damage, 0), give.user_id, give.name, coalesce(give.week, 0))
  on conflict (alliance_id, week_key) do nothing;
end $$;

-- Смена недели: как в alliance_events.sql, плюс страница летописи.
create or replace function public._al_roll(p_alliance bigint) returns void
language plpgsql security definer set search_path = public as $$
declare wk int := _al_week(); a record;
begin
  select id, week_key, week_xp into a from alliances where id = p_alliance for update;
  if found and a.week_key <> wk and a.week_key > 0 then
    insert into alliance_weeks (alliance_id, week_key, score) values (a.id, a.week_key, a.week_xp)
      on conflict (alliance_id, week_key) do update set score = excluded.score;
    perform _al_chronicle_write(a.id, a.week_key, a.week_xp);
  end if;
  update alliances set week_xp = 0, week_key = wk where id = p_alliance and week_key <> wk;
  update alliance_members set last_week = week, last_week_key = week_key, week = 0, week_key = wk
   where alliance_id = p_alliance and week_key <> wk;
end $$;

-- Летопись моего альянса: страницы (последние 30 недель), зал славы и дата основания. Пусто - не в альянсе.
create or replace function public.al_chronicle()
returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m record; a record;
begin
  if uid is null then raise exception 'not signed in'; end if;
  select * into m from alliance_members where user_id = uid;
  if not found then return null; end if;
  perform _al_roll(m.alliance_id);
  select id, created_at into a from alliances where id = m.alliance_id;
  return jsonb_build_object(
    'founded', extract(epoch from a.created_at)::bigint,
    'founded_week', floor((floor(extract(epoch from a.created_at) / 86400) + 3) / 7.0)::int,
    'frame', m.statue_frame,
    'weeks', (select coalesce(jsonb_agg(jsonb_build_object('week', c.week_key, 'xp', c.xp, 'level', c.level,
                'members', c.members, 'boss', c.boss_down, 'tasks', c.tasks_done,
                'place', _al_week_place(c.alliance_id, c.week_key),
                'hit', c.hit_name, 'hit_value', c.hit_value, 'give', c.give_name, 'give_value', c.give_value)
                order by c.week_key desc), '[]'::jsonb)
              from (select * from alliance_chronicle where alliance_id = m.alliance_id
                     order by week_key desc limit 30) c),
    'statues', (select coalesce(jsonb_agg(jsonb_build_object('name', s.name, 'frame', s.statue_frame,
                  'hits', s.hits, 'gives', s.gives, 'me', s.user_id = uid) order by s.hits + s.gives desc, s.name), '[]'::jsonb)
                from (select am.user_id, am.name, am.statue_frame,
                             (select count(*) from alliance_chronicle c where c.alliance_id = am.alliance_id and c.hit_user = am.user_id) as hits,
                             (select count(*) from alliance_chronicle c where c.alliance_id = am.alliance_id and c.give_user = am.user_id) as gives
                        from alliance_members am where am.alliance_id = m.alliance_id) s
               where s.hits + s.gives > 0));
end $$;

-- Выбрать рамку своей статуи.
create or replace function public.al_statue_frame(p_frame text)
returns void
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not signed in'; end if;
  if not p_frame = any(_al_frames()) then raise exception 'bad frame'; end if;
  update alliance_members set statue_frame = p_frame where user_id = uid;
  if not found then raise exception 'not in alliance'; end if;
end $$;

revoke all on function public.al_chronicle() from public, anon;
revoke all on function public.al_statue_frame(text) from public, anon;
revoke all on function public._al_chronicle_write(bigint, int, bigint) from public, anon, authenticated;
grant execute on function public.al_chronicle() to authenticated;
grant execute on function public.al_statue_frame(text) to authenticated;
