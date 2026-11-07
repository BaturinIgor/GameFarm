-- События альянса Harvest Hollow (шаг 2): страж альянса, задания недели, награды за место в неделе.
-- Запуск: Supabase -> SQL Editor -> вставить файл целиком -> Run. Повторный запуск безопасен.
-- Нужен уже выполненный alliances.sql.
--
-- Неделя та же, что у альянсов (_al_week: UTC, с понедельника).
-- Страж: у альянса на неделю свой страж, ступень 1, 2, 3...; убили - сразу следующий, сильнее.
--   У каждого участника 3 бесплатных удара в день и 5 за кристаллы. Сила удара считается здесь.
--   За каждую ступень, по которой участник ударил хотя бы раз, - награда.
-- Задания: 3 общих цели на неделю (из 8 видов), цель растёт с числом участников на начало недели.
--   Игра присылает счётчики пачками, вклад одного игрока в цель не больше 3 его долей.
--   Выполнили - награда тем, кто внёс хотя бы десятую часть своей доли.
-- Место: альянсы за неделю ранжируются по недельному опыту (вклады + события). В новой неделе
--   участники, которые что-то делали в прошлой, забирают награду по месту своего альянса.
-- Награды (монеты, кристаллы, ключи) выдаёт игра по ответу al_ev_claim: сервер следит только,
-- чтобы каждую забирали один раз. Числа должны совпадать с godot/scripts/data/alliance_events.gd.

-- ---------- таблицы ----------

alter table public.alliance_members add column if not exists last_week int not null default 0;
alter table public.alliance_members add column if not exists last_week_key int not null default 0;

-- Неделя альянса: участников на начало недели, страж, прогресс заданий {вид: число}, итоговый опыт недели.
create table if not exists public.alliance_weeks (
  alliance_id bigint      not null references public.alliances (id) on delete cascade,
  week_key    int         not null,
  members     int         not null default 1,
  boss_tier   int         not null default 1,
  boss_hp     bigint      not null default 0,
  tasks       jsonb       not null default '{}'::jsonb,
  score       bigint      not null default 0,
  primary key (alliance_id, week_key)
);
create index if not exists alliance_weeks_week on public.alliance_weeks (week_key, score desc);

-- Неделя участника: удары за день, урон, по каким ступеням бил и какие забрал, вклад в задания.
create table if not exists public.alliance_week_members (
  user_id      uuid    not null references auth.users (id) on delete cascade,
  week_key     int     not null,
  alliance_id  bigint  not null references public.alliances (id) on delete cascade,
  day_key      int     not null default 0,
  day_hits     int     not null default 0,
  day_extra    int     not null default 0,
  damage       bigint  not null default 0,
  boss_tiers   int[]   not null default '{}',
  boss_claimed int[]   not null default '{}',
  tasks        jsonb   not null default '{}'::jsonb,
  task_claimed text[]  not null default '{}',
  place_claimed boolean not null default false,
  primary key (user_id, week_key)
);

alter table public.alliance_weeks enable row level security;
alter table public.alliance_week_members enable row level security;
revoke all on public.alliance_weeks, public.alliance_week_members from anon, authenticated;

-- ---------- правила (как в alliance_events.gd) ----------

-- Виды заданий и доля одного участника за неделю.
create or replace function public._al_task_share(p_kind text) returns int language sql immutable as $$
  select case p_kind
    when 'kill' then 120 when 'produce' then 200 when 'order' then 20 when 'cook' then 25
    when 'dungeon' then 12 when 'mine' then 15 when 'treasure' then 15 when 'chest' then 10
    else null end
$$;
-- Задания недели: 3 вида из 8 по номеру недели.
create or replace function public._al_task_kinds(p_week int) returns text[] language sql immutable as $$
  select array[k[1 + (p_week % 8)], k[1 + ((p_week + 3) % 8)], k[1 + ((p_week + 5) % 8)]]
  from (select array['kill', 'produce', 'order', 'cook', 'dungeon', 'mine', 'treasure', 'chest'] as k) s
$$;
-- Цель задания: доля * участников (не меньше 5) / 2.
create or replace function public._al_task_target(p_kind text, p_members int) returns int language sql immutable as $$
  select (public._al_task_share(p_kind) * greatest(5, p_members) / 2)::int
$$;
-- Здоровье стража ступени t: 4000 * t^1.6 * участников / 10 (участников не меньше 5).
create or replace function public._al_boss_hp(p_tier int, p_members int) returns bigint language sql immutable as $$
  select round(4000 * power(p_tier, 1.6) * greatest(5, p_members) / 10.0)::bigint
$$;
-- Ранг таланта по очкам (как Alliances.rank_of): на ранг r нужно 60 * r(r+1)/2 * tier.
create or replace function public._al_rank(p_talent text, p_points int) returns int language sql immutable as $$
  select coalesce(max(r), 0) from generate_series(1, 10) r
   where p_points >= floor(60 * r * (r + 1) / 2 * case when public._al_talent_level(p_talent) >= 10 then 3
                         when public._al_talent_level(p_talent) >= 6 then 2
                         when public._al_talent_level(p_talent) >= 3 then 1.5 else 1 end)
$$;

-- Опыт альянсу (и в неделю) с сообщением в чат о новом уровне.
create or replace function public._al_add_xp(p_alliance bigint, p_xp int) returns void
language plpgsql security definer set search_path = public as $$
declare before bigint;
begin
  select xp into before from alliances where id = p_alliance for update;
  update alliances set xp = xp + p_xp, week_xp = week_xp + p_xp where id = p_alliance;
  if _al_level(before + p_xp) > _al_level(before) then
    perform _al_system(p_alliance, 'level', '', _al_level(before + p_xp)::text);
  end if;
end $$;

-- Неделя сменилась: запоминаем итог прошлой недели (опыт альянса и вклад участников) и обнуляем.
-- Заменяет _al_roll из alliances.sql.
create or replace function public._al_roll(p_alliance bigint) returns void
language plpgsql security definer set search_path = public as $$
declare wk int := _al_week(); a record;
begin
  select id, week_key, week_xp into a from alliances where id = p_alliance;
  if found and a.week_key <> wk and a.week_key > 0 then
    insert into alliance_weeks (alliance_id, week_key, score) values (a.id, a.week_key, a.week_xp)
      on conflict (alliance_id, week_key) do update set score = excluded.score;
  end if;
  update alliances set week_xp = 0, week_key = wk where id = p_alliance and week_key <> wk;
  update alliance_members set last_week = week, last_week_key = week_key, week = 0, week_key = wk
   where alliance_id = p_alliance and week_key <> wk;
end $$;

-- Строка недели альянса (создаёт на первом обращении: участники и первый страж).
create or replace function public._al_week_row(p_alliance bigint) returns public.alliance_weeks
language plpgsql security definer set search_path = public as $$
declare wk int := _al_week(); n int; w alliance_weeks;
begin
  select * into w from alliance_weeks where alliance_id = p_alliance and week_key = wk for update;
  if found then return w; end if;
  select count(*) into n from alliance_members where alliance_id = p_alliance;
  insert into alliance_weeks (alliance_id, week_key, members, boss_tier, boss_hp)
    values (p_alliance, wk, n, 1, _al_boss_hp(1, n))
    on conflict (alliance_id, week_key) do nothing;
  select * into w from alliance_weeks where alliance_id = p_alliance and week_key = wk for update;
  return w;
end $$;

-- Строка недели участника (в своём альянсе; перешёл в другой - начинает заново).
create or replace function public._al_me_week(p_user uuid, p_alliance bigint) returns public.alliance_week_members
language plpgsql security definer set search_path = public as $$
declare wk int := _al_week(); r alliance_week_members;
begin
  insert into alliance_week_members (user_id, week_key, alliance_id) values (p_user, wk, p_alliance)
    on conflict (user_id, week_key) do nothing;
  update alliance_week_members set alliance_id = p_alliance, day_key = 0, day_hits = 0, day_extra = 0, damage = 0,
         boss_tiers = '{}', boss_claimed = '{}', tasks = '{}'::jsonb, task_claimed = '{}'
   where user_id = p_user and week_key = wk and alliance_id <> p_alliance;
  update alliance_week_members set day_key = _al_day(), day_hits = 0, day_extra = 0
   where user_id = p_user and week_key = wk and day_key <> _al_day();
  select * into r from alliance_week_members where user_id = p_user and week_key = wk for update;
  return r;
end $$;

-- Место альянса в неделе p_week (по итоговому опыту недели) и сколько альянсов было.
create or replace function public._al_week_place(p_alliance bigint, p_week int) returns int
language sql stable security definer set search_path = public as $$
  with s as (
    select a.id, coalesce(w.score, case when a.week_key = p_week then a.week_xp else 0 end) as score, a.xp
      from alliances a left join alliance_weeks w on w.alliance_id = a.id and w.week_key = p_week
  )
  select place::int from (select id, row_number() over (order by score desc, xp desc) as place from s where score > 0) r
   where id = p_alliance
$$;

-- ---------- для игры ----------

-- Всё о событиях моего альянса на эту неделю. Пусто - не в альянсе.
create or replace function public.al_events()
returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m record; w alliance_weeks; me alliance_week_members; wk int := _al_week();
        kinds text[]; tasks jsonb := '[]'::jsonb; k text; prev alliance_week_members; place int; i int;
begin
  if uid is null then raise exception 'not signed in'; end if;
  select * into m from alliance_members where user_id = uid;
  if not found then return null; end if;
  perform _al_roll(m.alliance_id);
  select * into m from alliance_members where user_id = uid;
  w := _al_week_row(m.alliance_id);
  me := _al_me_week(uid, m.alliance_id);
  kinds := _al_task_kinds(wk);
  for i in 1..3 loop
    k := kinds[i];
    tasks := tasks || jsonb_build_object('kind', k, 'target', _al_task_target(k, w.members),
      'progress', coalesce((w.tasks ->> k)::int, 0), 'mine', coalesce((me.tasks ->> k)::int, 0),
      'share', _al_task_share(k), 'claimed', k = any(me.task_claimed));
  end loop;
  -- Награда за прошлую неделю: был в этом альянсе и что-то делал
  select * into prev from alliance_week_members where user_id = uid and week_key = wk - 1 and alliance_id = m.alliance_id;
  place := null;
  if (m.last_week_key = wk - 1 and m.last_week > 0) or (prev.user_id is not null and (prev.damage > 0 or prev.tasks <> '{}'::jsonb)) then
    place := _al_week_place(m.alliance_id, wk - 1);
  end if;
  return jsonb_build_object(
    'week', wk, 'ends', ((wk + 1) * 7 - 3) * 86400,
    'members', w.members, 'tier', w.boss_tier, 'hp', w.boss_hp, 'max_hp', _al_boss_hp(w.boss_tier, w.members),
    'hits', me.day_hits, 'extra', me.day_extra, 'damage', me.damage,
    'unclaimed', (select coalesce(jsonb_agg(t order by t), '[]'::jsonb) from unnest(me.boss_tiers) t
                   where t < w.boss_tier and not t = any(me.boss_claimed)),
    'tasks', tasks,
    'place', _al_week_place(m.alliance_id, wk),
    'last_place', place,
    'last_claimed', coalesce(prev.place_claimed, false));
end $$;

-- Удар по стражу: p_extra = за кристаллы (их списывает игра после успеха). Возвращает урон и что стало со стражем.
create or replace function public.al_ev_attack(p_level int, p_extra boolean)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m record; a record; w alliance_weeks; me alliance_week_members; dmg bigint;
        killed boolean := false; tier int;
begin
  if uid is null then raise exception 'not signed in'; end if;
  select * into m from alliance_members where user_id = uid;
  if not found then raise exception 'not in alliance'; end if;
  perform _al_roll(m.alliance_id);
  w := _al_week_row(m.alliance_id);
  me := _al_me_week(uid, m.alliance_id);
  if p_extra then
    if me.day_extra >= 5 then raise exception 'limit'; end if;
  elsif me.day_hits >= 3 then
    raise exception 'limit';
  end if;
  select * into a from alliances where id = m.alliance_id;
  dmg := round((60 + 8 * greatest(1, least(p_level, 200)))
         * (1 + 0.02 * _al_rank('strength', coalesce((a.talents ->> 'strength')::int, 0)))
         * (0.85 + random() * 0.3));
  tier := w.boss_tier;
  update alliance_week_members set
         day_hits = day_hits + case when p_extra then 0 else 1 end,
         day_extra = day_extra + case when p_extra then 1 else 0 end,
         damage = damage + dmg,
         boss_tiers = case when tier = any(boss_tiers) then boss_tiers else boss_tiers || tier end
   where user_id = uid and week_key = me.week_key;
  if w.boss_hp - dmg <= 0 then
    killed := true;
    update alliance_weeks set boss_tier = tier + 1, boss_hp = _al_boss_hp(tier + 1, w.members)
     where alliance_id = w.alliance_id and week_key = w.week_key;
    perform _al_system(m.alliance_id, 'boss', '', tier::text);
    perform _al_add_xp(m.alliance_id, 10 * tier);
  else
    update alliance_weeks set boss_hp = boss_hp - dmg where alliance_id = w.alliance_id and week_key = w.week_key;
  end if;
  update alliance_members set level = greatest(1, least(p_level, 200)), seen_at = now() where user_id = uid;
  return jsonb_build_object('damage', dmg, 'killed', killed, 'tier', tier);
end $$;

-- Счётчики для заданий недели: {вид: сколько} с прошлой отправки. Лишние виды пропускаются.
create or replace function public.al_ev_progress(p_counts jsonb)
returns void
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m record; w alliance_weeks; me alliance_week_members; k text; n int; mine int;
        cap int; target int; before int;
begin
  if uid is null then raise exception 'not signed in'; end if;
  if jsonb_typeof(p_counts) <> 'object' then return; end if;
  select * into m from alliance_members where user_id = uid;
  if not found then return; end if;
  perform _al_roll(m.alliance_id);
  w := _al_week_row(m.alliance_id);
  me := _al_me_week(uid, m.alliance_id);
  foreach k in array _al_task_kinds(w.week_key) loop
    n := least(greatest(coalesce((p_counts ->> k)::int, 0), 0), 100000);
    if n = 0 then continue; end if;
    mine := coalesce((me.tasks ->> k)::int, 0);
    cap := 3 * _al_task_share(k);
    n := least(n, cap - mine);
    if n <= 0 then continue; end if;
    before := coalesce((w.tasks ->> k)::int, 0);
    target := _al_task_target(k, w.members);
    update alliance_week_members set tasks = jsonb_set(tasks, array[k], to_jsonb(mine + n))
     where user_id = uid and week_key = me.week_key;
    me.tasks := jsonb_set(me.tasks, array[k], to_jsonb(mine + n));
    update alliance_weeks set tasks = jsonb_set(tasks, array[k], to_jsonb(before + n))
     where alliance_id = w.alliance_id and week_key = w.week_key;
    w.tasks := jsonb_set(w.tasks, array[k], to_jsonb(before + n));
    if before < target and before + n >= target then
      perform _al_system(m.alliance_id, 'task', '', k);
      perform _al_add_xp(m.alliance_id, 50);
    end if;
  end loop;
end $$;

-- Забрать награду: p_what = boss (p_ref - ступень), task (p_ref - номер задания 0..2), place (за прошлую неделю).
-- Возвращает, что выдать: {what, tier} / {what, kind} / {what, place}. Уже забрано или нельзя - ошибка.
create or replace function public.al_ev_claim(p_what text, p_ref int)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m record; w alliance_weeks; me alliance_week_members; wk int := _al_week(); k text;
        prev alliance_week_members; place int;
begin
  if uid is null then raise exception 'not signed in'; end if;
  select * into m from alliance_members where user_id = uid;
  if not found then raise exception 'not in alliance'; end if;
  perform _al_roll(m.alliance_id);
  select * into m from alliance_members where user_id = uid;
  w := _al_week_row(m.alliance_id);
  me := _al_me_week(uid, m.alliance_id);
  if p_what = 'boss' then
    if not p_ref = any(me.boss_tiers) or p_ref >= w.boss_tier or p_ref = any(me.boss_claimed) then
      raise exception 'not allowed';
    end if;
    update alliance_week_members set boss_claimed = boss_claimed || p_ref where user_id = uid and week_key = wk;
    return jsonb_build_object('what', 'boss', 'tier', p_ref);
  elsif p_what = 'task' then
    if p_ref < 0 or p_ref > 2 then raise exception 'not allowed'; end if;
    k := (_al_task_kinds(wk))[p_ref + 1];
    if k = any(me.task_claimed) or coalesce((w.tasks ->> k)::int, 0) < _al_task_target(k, w.members)
       or coalesce((me.tasks ->> k)::int, 0) * 10 < _al_task_share(k) then
      raise exception 'not allowed';
    end if;
    update alliance_week_members set task_claimed = task_claimed || k where user_id = uid and week_key = wk;
    return jsonb_build_object('what', 'task', 'kind', k);
  elsif p_what = 'place' then
    select * into prev from alliance_week_members where user_id = uid and week_key = wk - 1 for update;
    if found and (prev.place_claimed or prev.alliance_id <> m.alliance_id) then raise exception 'not allowed'; end if;
    if not ((m.last_week_key = wk - 1 and m.last_week > 0) or (prev.user_id is not null and (prev.damage > 0 or prev.tasks <> '{}'::jsonb))) then
      raise exception 'not allowed';
    end if;
    place := _al_week_place(m.alliance_id, wk - 1);
    if place is null then raise exception 'not allowed'; end if;
    insert into alliance_week_members (user_id, week_key, alliance_id, place_claimed) values (uid, wk - 1, m.alliance_id, true)
      on conflict (user_id, week_key) do update set place_claimed = true;
    return jsonb_build_object('what', 'place', 'place', place);
  end if;
  raise exception 'not allowed';
end $$;

-- Чистка: недели старше 8 недель.
create or replace function public.al_ev_cleanup() returns void
language sql security definer set search_path = public as $$
  delete from alliance_weeks where week_key < public._al_week() - 8;
  delete from alliance_week_members where week_key < public._al_week() - 8;
$$;

-- Общая чистка из cleanup.sql дополнительно чистит недели событий.
create or replace function public.hh_cleanup() returns void
language plpgsql security definer set search_path = public as $$
begin
  delete from rating_scores where updated_at < now() - interval '30 days';
  delete from alliance_chat where created_at < now() - interval '30 days';
  if to_regproc('public.al_ev_cleanup') is not null then
    perform al_ev_cleanup();
  end if;
end $$;

do $$
declare f text;
begin
  foreach f in array array['al_events()', 'al_ev_attack(int, boolean)', 'al_ev_progress(jsonb)', 'al_ev_claim(text, int)'] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  foreach f in array array['_al_roll(bigint)', '_al_add_xp(bigint, int)', '_al_week_row(bigint)', '_al_me_week(uuid, bigint)',
                           '_al_week_place(bigint, int)', 'al_ev_cleanup()', 'hh_cleanup()'] loop
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;
