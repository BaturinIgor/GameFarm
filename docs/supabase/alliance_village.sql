-- Деревня альянса Harvest Hollow: домики участников, визиты к друзьям и общие постройки.
-- Запуск: Supabase -> SQL Editor -> вставить файл целиком -> Run (после alliances.sql и alliance_chronicle.sql). Повторный запуск безопасен.
--
-- Общие постройки (мельница, башня, колодец) растут от монет, которые вкладывают участники (монеты списывает игра),
-- до 10 уровня, и дают всему альянсу бонус. Вкладов в день - 5 на игрока.
-- Визит к другу: полить его грядки (раз в день на друга, 5 в день) и оставить подарок (раз в день на друга,
-- кристаллы списывает игра). Хозяин забирает поливы и подарки через al_village_take.
-- Украшения домика игрок выбирает в игре и присылает сюда, чтобы их видели другие (до 3).
-- Числа как в godot/scripts/data/village.gd.

alter table public.alliance_members add column if not exists deco text[] not null default '{}';

create table if not exists public.alliance_village (
  alliance_id bigint not null references public.alliances (id) on delete cascade,
  kind        text   not null,
  level       int    not null default 0,
  points      bigint not null default 0,
  primary key (alliance_id, kind)
);

create table if not exists public.alliance_village_acts (
  id       bigserial primary key,
  day_key  int  not null,
  visitor  uuid not null references auth.users (id) on delete cascade,
  host     uuid not null references auth.users (id) on delete cascade,
  act      text not null,
  taken    boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists alliance_village_acts_visitor on public.alliance_village_acts (visitor, day_key);
create index if not exists alliance_village_acts_host on public.alliance_village_acts (host) where not taken;

alter table public.alliance_village enable row level security;
alter table public.alliance_village_acts enable row level security;
revoke all on public.alliance_village, public.alliance_village_acts from anon, authenticated;

-- Королевская рамка статуи из набора «Праздник в деревне» (как в alliance_chronicle.sql).
create or replace function public._al_frames() returns text[] language sql immutable as $$
  select array['stone', 'bronze', 'gold', 'crystal', 'flame', 'royal', 'war']
$$;

create or replace function public._al_village_kinds() returns text[] language sql immutable as $$
  select array['mill', 'tower', 'well']
$$;

-- Сколько монет нужно на уровень L постройки.
create or replace function public._al_village_need(p_level int) returns bigint language sql immutable as $$
  select round(200000 * power(greatest(p_level, 1), 1.5))::bigint
$$;

-- Деревня моего альянса: постройки, домики участников, мои лимиты на сегодня и что ждёт меня.
create or replace function public.al_village()
returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m record; d int := _al_day();
begin
  if uid is null then raise exception 'not signed in'; end if;
  select * into m from alliance_members where user_id = uid;
  if not found then return null; end if;
  return jsonb_build_object(
    'buildings', (select jsonb_object_agg(k, jsonb_build_object('level', coalesce(v.level, 0), 'points', coalesce(v.points, 0),
                      'need', _al_village_need(coalesce(v.level, 0) + 1)))
                    from unnest(_al_village_kinds()) k
                    left join alliance_village v on v.alliance_id = m.alliance_id and v.kind = k),
    'houses', (select coalesce(jsonb_agg(jsonb_build_object('id', x.user_id, 'name', x.name, 'level', x.level,
                      'deco', to_jsonb(x.deco), 'me', x.user_id = uid,
                      'watered', exists (select 1 from alliance_village_acts a where a.day_key = d and a.visitor = uid
                                           and a.host = x.user_id and a.act = 'water'),
                      'gifted', exists (select 1 from alliance_village_acts a where a.day_key = d and a.visitor = uid
                                          and a.host = x.user_id and a.act = 'gift'))
                      order by x.level desc), '[]'::jsonb)
                 from alliance_members x where x.alliance_id = m.alliance_id),
    'donates', (select count(*) from alliance_village_acts where day_key = d and visitor = uid and act like 'build:%'),
    'waters', (select count(*) from alliance_village_acts where day_key = d and visitor = uid and act = 'water'),
    'inbox', jsonb_build_object(
      'water', (select count(*) from alliance_village_acts where host = uid and not taken and act = 'water'),
      'gift', (select count(*) from alliance_village_acts where host = uid and not taken and act = 'gift')));
end $$;

-- Вложить монеты в постройку. Возвращает её новый уровень.
create or replace function public.al_village_build(p_kind text, p_coins int, p_player text)
returns int
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m record; b alliance_village; n int;
begin
  if uid is null then raise exception 'not signed in'; end if;
  select * into m from alliance_members where user_id = uid;
  if not found then raise exception 'not in alliance'; end if;
  if not p_kind = any(_al_village_kinds()) or p_coins < 1 or p_coins > 100000 then raise exception 'bad lot'; end if;
  select count(*) into n from alliance_village_acts where day_key = _al_day() and visitor = uid and act like 'build:%';
  if n >= 5 then raise exception 'limit'; end if;
  insert into alliance_village (alliance_id, kind) values (m.alliance_id, p_kind) on conflict do nothing;
  select * into b from alliance_village where alliance_id = m.alliance_id and kind = p_kind for update;
  if b.level >= 10 then raise exception 'talent maxed'; end if;
  b.points := b.points + p_coins;
  while b.level < 10 and b.points >= _al_village_need(b.level + 1) loop
    b.points := b.points - _al_village_need(b.level + 1);
    b.level := b.level + 1;
    perform _al_system(m.alliance_id, 'village', _rating_clean_name(p_player), p_kind || ':' || b.level);
  end loop;
  if b.level >= 10 then b.points := 0; end if;
  update alliance_village set level = b.level, points = b.points where alliance_id = m.alliance_id and kind = p_kind;
  insert into alliance_village_acts (day_key, visitor, host, act, taken) values (_al_day(), uid, uid, 'build:' || p_kind, true);
  return b.level;
end $$;

-- Полить грядки друга или оставить ему подарок (p_act: water или gift).
create or replace function public.al_village_visit(p_host uuid, p_act text)
returns void
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m record; n int;
begin
  if uid is null then raise exception 'not signed in'; end if;
  if p_act not in ('water', 'gift') or p_host = uid then raise exception 'not allowed'; end if;
  select * into m from alliance_members where user_id = uid;
  if not found then raise exception 'not in alliance'; end if;
  if not exists (select 1 from alliance_members where user_id = p_host and alliance_id = m.alliance_id) then
    raise exception 'not allowed';
  end if;
  if exists (select 1 from alliance_village_acts where day_key = _al_day() and visitor = uid and host = p_host and act = p_act) then
    raise exception 'limit';
  end if;
  if p_act = 'water' then
    select count(*) into n from alliance_village_acts where day_key = _al_day() and visitor = uid and act = 'water';
    if n >= 5 then raise exception 'limit'; end if;
  end if;
  insert into alliance_village_acts (day_key, visitor, host, act) values (_al_day(), uid, p_host, p_act);
end $$;

-- Забрать поливы и подарки от друзей. Возвращает {water, gift, from: [имена]}.
create or replace function public.al_village_take()
returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); r jsonb;
begin
  if uid is null then raise exception 'not signed in'; end if;
  select jsonb_build_object(
           'water', count(*) filter (where a.act = 'water'),
           'gift', count(*) filter (where a.act = 'gift'),
           'from', coalesce(jsonb_agg(distinct coalesce(mm.name, 'Farmer')), '[]'::jsonb))
    into r
    from alliance_village_acts a left join alliance_members mm on mm.user_id = a.visitor
   where a.host = uid and not a.taken and a.act in ('water', 'gift');
  update alliance_village_acts set taken = true where host = uid and not taken;
  return r;
end $$;

-- Украшения моего домика, которые видят другие (до 3).
create or replace function public.al_village_deco(p_deco text[])
returns void
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not signed in'; end if;
  update alliance_members
     set deco = coalesce((select array_agg(x) from (select distinct left(x, 24) as x from unnest(p_deco) x
                                                     where x ~ '^[A-Za-z_]{1,24}$' limit 3) t), '{}')
   where user_id = uid;
end $$;

-- Чистка: действия старше 30 дней (забранные).
create or replace function public.al_village_cleanup() returns void
language sql security definer set search_path = public as $$
  delete from alliance_village_acts where day_key < _al_day() - 30 and taken
$$;

revoke all on function public.al_village() from public, anon;
revoke all on function public.al_village_build(text, int, text) from public, anon;
revoke all on function public.al_village_visit(uuid, text) from public, anon;
revoke all on function public.al_village_take() from public, anon;
revoke all on function public.al_village_deco(text[]) from public, anon;
revoke all on function public.al_village_cleanup() from public, anon, authenticated;
grant execute on function public.al_village() to authenticated;
grant execute on function public.al_village_build(text, int, text) to authenticated;
grant execute on function public.al_village_visit(uuid, text) to authenticated;
grant execute on function public.al_village_take() to authenticated;
grant execute on function public.al_village_deco(text[]) to authenticated;
