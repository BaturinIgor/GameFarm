-- Турнир зверей Harvest Hollow: отряд из трёх зверей сражается с отрядами других игроков.
-- Запуск: Supabase -> SQL Editor -> вставить файл целиком -> Run (после ratings.sql и alliances.sql). Повторный запуск безопасен.
--
-- Отряд (до 3 зверей с их мощью) присылает игра. Бой - три поединка по порядку, победа в поединке с шансом
-- p^1.3 / (p^1.3 + q^1.3), бой выигран при 2 победах из 3. Рейтинг меняется как в Эло (K = 32), защитник
-- получает половину изменения. Пока других отрядов меньше 3, соперник - бот с мощью около моей.
-- Боёв в день: 5 бесплатных и ещё по 5 за кристаллы (их списывает игра), 2 раза в день.
-- Очки недели: 3 за победу, 1 за поражение. По ним - дорожка наград (выдаёт игра) и места недели:
-- награду за место прошлой недели забирают через tn_claim. Числа как в godot/scripts/data/tourney.gd.

create table if not exists public.tourney_squads (
  user_id    uuid        primary key references auth.users (id) on delete cascade,
  name       text        not null,
  level      int         not null default 1,
  squad      jsonb       not null default '[]',
  power      int         not null default 0,
  rating     int         not null default 1000,
  day_key    int         not null default 0,
  fights     int         not null default 0,
  bought     int         not null default 0,
  last_opp   uuid,
  updated_at timestamptz not null default now()
);
create index if not exists tourney_squads_rating on public.tourney_squads (rating);

create table if not exists public.tourney_points (
  week_key int  not null,
  user_id  uuid not null references auth.users (id) on delete cascade,
  name     text not null,
  level    int  not null default 1,
  points   int  not null default 0,
  wins     int  not null default 0,
  primary key (week_key, user_id)
);
create index if not exists tourney_points_top on public.tourney_points (week_key, points desc, wins desc);

create table if not exists public.tourney_log (
  id         bigserial   primary key,
  defender   uuid        not null references auth.users (id) on delete cascade,
  attacker   text        not null,
  held       boolean     not null,
  delta      int         not null,
  created_at timestamptz not null default now()
);
create index if not exists tourney_log_defender on public.tourney_log (defender, created_at desc);

create table if not exists public.tourney_claims (
  week_key int  not null,
  user_id  uuid not null references auth.users (id) on delete cascade,
  primary key (week_key, user_id)
);

alter table public.tourney_squads enable row level security;
alter table public.tourney_points enable row level security;
alter table public.tourney_log enable row level security;
alter table public.tourney_claims enable row level security;
revoke all on public.tourney_squads, public.tourney_points, public.tourney_log, public.tourney_claims from anon, authenticated;

create or replace function public._tn_free() returns int language sql immutable as $$ select 5 $$;
create or replace function public._tn_buy() returns int language sql immutable as $$ select 5 $$;
create or replace function public._tn_max_buys() returns int language sql immutable as $$ select 2 $$;

-- Отряд из ответа игры: до 3 зверей {id, p}, id - буквы и цифры, мощь 0..5000.
create or replace function public._tn_clean_squad(p_squad jsonb) returns jsonb language sql immutable as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'p', p) order by n), '[]'::jsonb)
    from (select n, left(regexp_replace(coalesce(e->>'id', ''), '[^A-Za-z0-9_]', '', 'g'), 24) as id,
                 greatest(0, least(coalesce((e->>'p')::numeric, 0)::int, 5000)) as p
            from jsonb_array_elements(case when jsonb_typeof(p_squad) = 'array' then p_squad else '[]'::jsonb end)
                 with ordinality as t(e, n)
           where n <= 3) s
   where id <> ''
$$;

create or replace function public._tn_power(p_squad jsonb) returns int language sql immutable as $$
  select coalesce(sum((e->>'p')::int), 0)::int from jsonb_array_elements(p_squad) e
$$;

-- Моя строка отряда: создать, обновить отряд, сбросить бои на новый день.
create or replace function public._tn_me(p_squad jsonb, p_name text, p_level int) returns tourney_squads
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); s jsonb := _tn_clean_squad(p_squad); r tourney_squads;
begin
  insert into tourney_squads (user_id, name, level, squad, power, day_key)
  values (uid, _rating_clean_name(p_name), greatest(1, least(p_level, 200)), s, _tn_power(s), _al_day())
  on conflict (user_id) do update
     set name = excluded.name, level = greatest(tourney_squads.level, excluded.level),
         squad = case when jsonb_array_length(excluded.squad) > 0 then excluded.squad else tourney_squads.squad end,
         power = case when jsonb_array_length(excluded.squad) > 0 then excluded.power else tourney_squads.power end,
         updated_at = now();
  update tourney_squads set day_key = _al_day(), fights = 0, bought = 0 where user_id = uid and day_key <> _al_day();
  select * into r from tourney_squads where user_id = uid;
  return r;
end $$;

-- Состояние турнира: мой отряд и рейтинг, бои на сегодня, очки недели, защиты, топ недели и прошлая неделя.
create or replace function public.tn_state(p_squad jsonb, p_name text, p_level int)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); me tourney_squads; wk int := _al_week(); last jsonb;
begin
  if uid is null then raise exception 'not signed in'; end if;
  me := _tn_me(p_squad, p_name, p_level);
  select jsonb_build_object('week', wk - 1, 'place', place, 'points', points,
           'claimed', exists (select 1 from tourney_claims c where c.week_key = wk - 1 and c.user_id = uid))
    into last
    from (select user_id, points, row_number() over (order by points desc, wins desc, user_id) as place
            from tourney_points where week_key = wk - 1) t
   where user_id = uid;
  return jsonb_build_object(
    'week', wk,
    'rating', me.rating,
    'squad', me.squad,
    'fights_left', greatest(0, _tn_free() + me.bought * _tn_buy() - me.fights),
    'buys_left', greatest(0, _tn_max_buys() - me.bought),
    'points', coalesce((select points from tourney_points where week_key = wk and user_id = uid), 0),
    'wins', coalesce((select wins from tourney_points where week_key = wk and user_id = uid), 0),
    'log', (select coalesce(jsonb_agg(jsonb_build_object('name', attacker, 'held', held, 'delta', delta,
                      'at', floor(extract(epoch from created_at))::bigint) order by created_at desc), '[]'::jsonb)
              from (select * from tourney_log where defender = uid order by created_at desc limit 10) l),
    'top', (select coalesce(jsonb_agg(jsonb_build_object('place', place, 'name', name, 'level', level,
                      'points', points, 'me', user_id = uid) order by place), '[]'::jsonb)
              from (select user_id, name, level, points,
                           row_number() over (order by points desc, wins desc, user_id) as place
                      from tourney_points where week_key = wk) t
             where place <= 50 or user_id = uid),
    'last', last);
end $$;

-- Бой: соперник по рейтингу (или бот), три поединка, рейтинг и очки недели.
create or replace function public.tn_fight(p_squad jsonb, p_name text, p_level int)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid(); me tourney_squads; opp tourney_squads; wk int := _al_week();
  bot boolean := false; opp_name text; opp_level int; opp_rating int; opp_squad jsonb;
  bots text[] := array['Bramble', 'Clover', 'Hazel', 'Juniper', 'Pip', 'Rowan', 'Sage', 'Thistle', 'Willow', 'Fern'];
  duels jsonb := '[]'; won_n int := 0; i int; a jsonb; b jsonb; ap numeric; bp numeric; ok boolean; won boolean;
  expected numeric; delta int; pts int;
begin
  if uid is null then raise exception 'not signed in'; end if;
  me := _tn_me(p_squad, p_name, p_level);
  if jsonb_array_length(me.squad) = 0 or me.power <= 0 then raise exception 'no squad'; end if;
  if me.fights >= _tn_free() + me.bought * _tn_buy() then raise exception 'no fights'; end if;
  if (select count(*) from tourney_squads where user_id <> uid and power > 0) >= 3 then
    select * into opp from tourney_squads
     where user_id <> uid and power > 0 and user_id is distinct from me.last_opp
       and updated_at > now() - interval '30 days'
     order by abs(rating - me.rating) + random() * 200
     limit 1;
  end if;
  if opp.user_id is null then
    bot := true;
    opp_name := bots[1 + floor(random() * array_length(bots, 1))::int];
    opp_level := me.level;
    opp_rating := me.rating;
    select jsonb_agg(jsonb_build_object('id', e->>'id', 'p', greatest(1, round((e->>'p')::int * (0.75 + random() * 0.45))::int)) order by n)
      into opp_squad from jsonb_array_elements(me.squad) with ordinality as t(e, n);
  else
    opp_name := opp.name; opp_level := opp.level; opp_rating := opp.rating; opp_squad := opp.squad;
  end if;
  for i in 0..2 loop
    a := me.squad -> i;
    b := opp_squad -> i;
    ap := coalesce((a->>'p')::numeric, 0);
    bp := coalesce((b->>'p')::numeric, 0);
    if ap <= 0 then ok := false;
    elsif bp <= 0 then ok := true;
    else ok := random() < power(ap, 1.3) / (power(ap, 1.3) + power(bp, 1.3));
    end if;
    if ok then won_n := won_n + 1; end if;
    duels := duels || jsonb_build_object('a', a->>'id', 'ap', ap, 'b', b->>'id', 'bp', bp, 'won', ok);
  end loop;
  won := won_n >= 2;
  expected := 1.0 / (1.0 + power(10, (opp_rating - me.rating) / 400.0));
  delta := case when won then greatest(1, round(32 * (1 - expected))::int) else -greatest(1, round(32 * expected)::int) end;
  pts := case when won then 3 else 1 end;
  update tourney_squads set rating = greatest(0, rating + delta), fights = fights + 1,
         last_opp = case when bot then last_opp else opp.user_id end
   where user_id = uid;
  insert into tourney_points (week_key, user_id, name, level, points, wins)
  values (wk, uid, me.name, me.level, pts, case when won then 1 else 0 end)
  on conflict (week_key, user_id) do update
     set name = excluded.name, level = excluded.level, points = tourney_points.points + excluded.points,
         wins = tourney_points.wins + excluded.wins;
  if not bot then
    update tourney_squads set rating = greatest(0, rating - delta / 2) where user_id = opp.user_id;
    insert into tourney_log (defender, attacker, held, delta) values (opp.user_id, me.name, not won, -(delta / 2));
  end if;
  return jsonb_build_object(
    'won', won, 'duels', duels, 'delta', delta, 'points', pts,
    'opp', jsonb_build_object('name', opp_name, 'level', opp_level, 'bot', bot),
    'rating', greatest(0, me.rating + delta),
    'fights_left', greatest(0, _tn_free() + me.bought * _tn_buy() - me.fights - 1));
end $$;

-- Купить ещё боёв (кристаллы списывает игра после ответа).
create or replace function public.tn_buy()
returns void
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); me tourney_squads;
begin
  if uid is null then raise exception 'not signed in'; end if;
  me := _tn_me('[]', (select name from tourney_squads where user_id = uid), 1);
  if me.bought >= _tn_max_buys() then raise exception 'limit'; end if;
  update tourney_squads set bought = bought + 1 where user_id = uid;
end $$;

-- Забрать награду за место прошлой недели (один раз). Награду выдаёт игра.
create or replace function public.tn_claim()
returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); wk int := _al_week() - 1; r record;
begin
  if uid is null then raise exception 'not signed in'; end if;
  select * into r from (select user_id, points, row_number() over (order by points desc, wins desc, user_id) as place
                          from tourney_points where week_key = wk) t
   where user_id = uid;
  if not found then raise exception 'nothing'; end if;
  insert into tourney_claims (week_key, user_id) values (wk, uid) on conflict do nothing;
  if not found then raise exception 'already claimed'; end if;
  return jsonb_build_object('week', wk, 'place', r.place, 'points', r.points);
end $$;

-- Чистка: очки и награды старше 8 недель, защиты старше 2 недель, отряды тех, кто не заходил полгода.
create or replace function public.tourney_cleanup() returns void
language sql security definer set search_path = public as $$
  delete from tourney_points where week_key < _al_week() - 8;
  delete from tourney_claims where week_key < _al_week() - 8;
  delete from tourney_log where created_at < now() - interval '14 days';
  delete from tourney_squads where updated_at < now() - interval '180 days';
$$;

revoke all on function public.tn_state(jsonb, text, int) from public, anon;
revoke all on function public.tn_fight(jsonb, text, int) from public, anon;
revoke all on function public.tn_buy() from public, anon;
revoke all on function public.tn_claim() from public, anon;
revoke all on function public.tourney_cleanup() from public, anon, authenticated;
revoke all on function public._tn_me(jsonb, text, int) from public, anon, authenticated;
grant execute on function public.tn_state(jsonb, text, int) to authenticated;
grant execute on function public.tn_fight(jsonb, text, int) to authenticated;
grant execute on function public.tn_buy() to authenticated;
grant execute on function public.tn_claim() to authenticated;
