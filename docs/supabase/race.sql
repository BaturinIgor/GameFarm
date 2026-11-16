-- Гонка к Сердцу долины Harvest Hollow: комнаты на 4 игрока, ход соперников, итоги и рейтинги дня и месяца.
-- Запуск: Supabase -> SQL Editor -> вставить файл целиком -> Run (после ratings.sql). Повторный запуск безопасен.
--
-- Гонка асинхронная: каждый идёт свои 15 минут от своего входа. Комната набирает живых игроков 45 секунд
-- (или пока не наберётся 4), пустые места занимают странники - их считает игра по seed комнаты
-- (godot/scripts/systems/race_run.gd), сервер их не хранит.
-- Ход игрока - times: секунды от его старта, когда пройден очередной этап (3 ворот, 3 осколка, Сердце = 7 этапов).
-- Соперник показывается на поле по своим times в ту же секунду гонки, что и у меня.
-- Место считает игра, когда итог известен (все живые соперники дошли, их время вышло или уже не могут обогнать).
-- Рейтинг дня - сумма трофеев 10 лучших гонок за день (UTC), месяца - сумма таких дней за месяц.
-- Числа как в godot/scripts/data/race.gd.
-- Уютные действия: смайлик над своим бегуном (race_emote) и «Подбодрить» (race_cheer: отстающему 5 ресурсов,
-- до 3 раз за гонку). Награды за места рейтинга вчерашнего дня (топ-10) и прошлого месяца (топ-100) забираются
-- через race_prizes / race_prize_claim, сколько кристаллов за место - решает игра.

create table if not exists public.race_rooms (
  id         bigserial   primary key,
  seed       int         not null,
  humans     int         not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists race_rooms_open on public.race_rooms (created_at) where humans < 4;

create table if not exists public.race_seats (
  room_id    bigint      not null references public.race_rooms (id) on delete cascade,
  seat       int         not null check (seat between 0 and 3),
  user_id    uuid        not null references auth.users (id) on delete cascade,
  name       text        not null,
  skin       text        not null default '',
  times      jsonb       not null default '[]',
  joined_at  timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (room_id, seat),
  unique (room_id, user_id)
);
create index if not exists race_seats_user on public.race_seats (user_id, joined_at desc);
-- Лига (оформление бегуна), сколько раз меня подбодрили и сколько раз подбодрил я, последний смайлик.
alter table public.race_seats add column if not exists league   int         not null default 0;
alter table public.race_seats add column if not exists gifts    int         not null default 0;
alter table public.race_seats add column if not exists cheers   int         not null default 0;
alter table public.race_seats add column if not exists emote    text        not null default '';
alter table public.race_seats add column if not exists emote_at timestamptz;

create table if not exists public.race_results (
  room_id    bigint      not null,
  user_id    uuid        not null references auth.users (id) on delete cascade,
  name       text        not null,
  place      int         not null,
  trophies   int         not null,
  day_key    int         not null,
  month_key  int         not null,
  created_at timestamptz not null default now(),
  primary key (room_id, user_id)
);
create index if not exists race_results_day on public.race_results (day_key, user_id);
create index if not exists race_results_month on public.race_results (month_key, user_id);

-- Забранные награды за место в рейтинге: period 'day' или 'month', key - номер дня или месяца.
create table if not exists public.race_prizes (
  user_id    uuid        not null references auth.users (id) on delete cascade,
  period     text        not null check (period in ('day', 'month')),
  key        int         not null,
  place      int         not null,
  created_at timestamptz not null default now(),
  primary key (user_id, period, key)
);

alter table public.race_rooms enable row level security;
alter table public.race_seats enable row level security;
alter table public.race_results enable row level security;
alter table public.race_prizes enable row level security;
revoke all on public.race_rooms, public.race_seats, public.race_results, public.race_prizes from anon, authenticated;

-- Сколько секунд комната ждёт живых игроков, длина гонки, самый быстрый честный путь до Сердца.
create or replace function public._race_open_secs() returns int language sql immutable as $$ select 45 $$;
create or replace function public._race_duration() returns int language sql immutable as $$ select 900 $$;
create or replace function public._race_min_finish() returns int language sql immutable as $$ select 240 $$;
-- Подбодрить можно не больше 3 раз за гонку, смайлик - не чаще раза в 3 с.
create or replace function public._race_cheer_max() returns int language sql immutable as $$ select 3 $$;
-- Награды: топ-10 дня (за последние 3 дня), топ-100 прошлого месяца.
create or replace function public._race_day_prize_top() returns int language sql immutable as $$ select 10 $$;
create or replace function public._race_month_prize_top() returns int language sql immutable as $$ select 100 $$;
-- Гонок в сутки на игрока (флажков 5 и 1 в час, плюс за рекламу - с запасом).
create or replace function public._race_day_limit() returns int language sql immutable as $$ select 60 $$;

create or replace function public._race_day() returns int language sql stable as $$
  select floor(extract(epoch from now()) / 86400)::int
$$;
create or replace function public._race_month() returns int language sql stable as $$
  select (extract(year from now() at time zone 'utc') * 12 + extract(month from now() at time zone 'utc') - 1)::int
$$;

create or replace function public._race_name(p_name text) returns text language sql immutable as $$
  select coalesce(nullif(left(btrim(coalesce(p_name, '')), 24), ''), 'Farmer')
$$;

-- Ход из ответа игры: до 7 чисел по возрастанию, не раньше 10 с, не позже прошедшего с входа времени
-- (и не позже конца гонки), Сердце - не раньше _race_min_finish(). Неверное число обрывает список.
create or replace function public._race_clean_times(p_times jsonb, p_joined timestamptz) returns jsonb
language plpgsql stable as $$
declare
  res  jsonb := '[]'::jsonb;
  prev numeric := 0;
  t    numeric;
  e    jsonb;
  n    int := 0;
  lim  numeric := least(extract(epoch from now() - p_joined) + 15, _race_duration() + 5);
begin
  if p_times is null or jsonb_typeof(p_times) <> 'array' then
    return res;
  end if;
  for e in select value from jsonb_array_elements(p_times) loop
    exit when n >= 7 or jsonb_typeof(e) <> 'number';
    t := (e #>> '{}')::numeric;
    exit when t < prev or t < 10 or t > lim or (n = 6 and t < _race_min_finish());
    res := res || to_jsonb(round(t, 1));
    prev := t;
    n := n + 1;
  end loop;
  return res;
end $$;

-- Войти в гонку: свободное место в открытой комнате или новая комната. Ответ: {room, seed, seat}.
-- p_league - лига игрока (только оформление бегуна у соперников).
drop function if exists public.race_join(text, text);
create or replace function public.race_join(p_name text, p_skin text, p_league int)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid  uuid := auth.uid();
  r    race_rooms;
  s    int;
begin
  if uid is null then
    raise exception 'auth';
  end if;
  if (select count(*) from race_seats where user_id = uid and joined_at > now() - interval '1 day') >= _race_day_limit() then
    raise exception 'limit';
  end if;
  select * into r from race_rooms
   where humans < 4 and created_at > now() - make_interval(secs => _race_open_secs())
     and not exists (select 1 from race_seats x where x.room_id = race_rooms.id and x.user_id = uid)
   order by created_at
   limit 1
   for update skip locked;
  if r.id is null then
    insert into race_rooms (seed) values (floor(random() * 2000000000)::int) returning * into r;
  end if;
  select g into s from generate_series(0, 3) g
   where not exists (select 1 from race_seats x where x.room_id = r.id and x.seat = g)
   order by random()
   limit 1;
  insert into race_seats (room_id, seat, user_id, name, skin, league)
  values (r.id, s, uid, _race_name(p_name), left(regexp_replace(coalesce(p_skin, ''), '[^A-Za-z0-9_]', '', 'g'), 24),
          greatest(0, least(coalesce(p_league, 0), 5)));
  update race_rooms set humans = humans + 1 where id = r.id;
  return jsonb_build_object('room', r.id, 'seed', r.seed, 'seat', s);
end $$;

-- Свой ход и ход соперников. Ответ: {open, gifts (сколько раз меня подбодрили), seats: [{seat, name, skin, league,
-- times, age (с от входа), done, emote, emote_age (с назад)}]}.
create or replace function public.race_sync(p_room bigint, p_times jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  me  race_seats;
  r   race_rooms;
  t   jsonb;
begin
  select * into me from race_seats where room_id = p_room and user_id = uid;
  if me.user_id is null then
    raise exception 'room';
  end if;
  t := _race_clean_times(p_times, me.joined_at);
  if jsonb_array_length(t) > jsonb_array_length(me.times) then
    update race_seats set times = t, updated_at = now() where room_id = p_room and user_id = uid;
  end if;
  select * into r from race_rooms where id = p_room;
  return jsonb_build_object(
    'open', r.humans < 4 and r.created_at > now() - make_interval(secs => _race_open_secs()),
    'gifts', me.gifts,
    'seats', coalesce((
      select jsonb_agg(jsonb_build_object('seat', s.seat, 'name', s.name, 'skin', s.skin, 'league', s.league,
               'times', s.times, 'emote', s.emote,
               'emote_age', case when s.emote_at is null then null
                                 else round(extract(epoch from now() - s.emote_at)::numeric, 1) end,
               'age', round(extract(epoch from now() - s.joined_at)::numeric, 1),
               'done', jsonb_array_length(s.times) >= 7
                       or s.joined_at < now() - make_interval(secs => _race_duration() + 5)))
        from race_seats s
       where s.room_id = p_room and s.user_id <> uid), '[]'::jsonb));
end $$;

-- Подбодрить живого соперника на месте p_seat: ему 5 ресурсов (их кладёт его игра), мне очко дружбы.
-- Не больше _race_cheer_max() раз за гонку, только пока моя гонка идёт. Ответ: {cheers} - сколько раз я подбодрил.
create or replace function public.race_cheer(p_room bigint, p_seat int)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  me  race_seats;
begin
  select * into me from race_seats where room_id = p_room and user_id = uid for update;
  if me.user_id is null then
    raise exception 'room';
  end if;
  if me.cheers >= _race_cheer_max() or me.seat = p_seat
     or me.joined_at < now() - make_interval(secs => _race_duration() + 5) then
    raise exception 'cheer';
  end if;
  update race_seats set gifts = gifts + 1 where room_id = p_room and seat = p_seat;
  if not found then
    raise exception 'cheer';
  end if;
  update race_seats set cheers = cheers + 1 where room_id = p_room and user_id = uid;
  return jsonb_build_object('cheers', me.cheers + 1);
end $$;

-- Смайлик над своим бегуном: heart, star, flame, clover, fist, trophy (как Race.EMOTES). Не чаще раза в 3 с.
create or replace function public.race_emote(p_room bigint, p_emote text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
begin
  if p_emote not in ('heart', 'star', 'flame', 'clover', 'fist', 'trophy') then
    raise exception 'emote';
  end if;
  update race_seats set emote = p_emote, emote_at = now()
   where room_id = p_room and user_id = uid
     and (emote_at is null or emote_at < now() - interval '3 seconds');
  return jsonb_build_object('ok', found);
end $$;

-- Итог гонки для рейтинга: место 1..4 (его считает игра), трофеи 30/18/10/4. Один раз за комнату.
-- Принимается, когда игрок дошёл до Сердца или его время почти вышло.
create or replace function public.race_result(p_room bigint, p_place int, p_times jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  me  race_seats;
  t   jsonb;
  pl  int := greatest(1, least(coalesce(p_place, 4), 4));
begin
  select * into me from race_seats where room_id = p_room and user_id = uid;
  if me.user_id is null then
    raise exception 'room';
  end if;
  t := _race_clean_times(p_times, me.joined_at);
  if jsonb_array_length(t) > jsonb_array_length(me.times) then
    update race_seats set times = t, updated_at = now() where room_id = p_room and user_id = uid;
    me.times := t;
  end if;
  if jsonb_array_length(me.times) < 7 and me.joined_at > now() - make_interval(secs => _race_duration() - 30) then
    raise exception 'early';
  end if;
  insert into race_results (room_id, user_id, name, place, trophies, day_key, month_key)
  values (p_room, uid, me.name, pl, (array[30, 18, 10, 4])[pl], _race_day(), _race_month())
  on conflict do nothing;
  return jsonb_build_object('ok', true);
end $$;

-- Места рейтинга дня (p_month = false, p_key - номер дня) или месяца: очки - трофеи 10 лучших гонок каждого дня.
create or replace function public._race_rank(p_month boolean, p_key int)
returns table (user_id uuid, name text, points int, races int, place int)
language sql stable security definer set search_path = public as $$
  with best as (
    select r.user_id, r.name, r.trophies, r.created_at,
           row_number() over (partition by r.user_id, r.day_key order by r.trophies desc, r.created_at) as n
      from race_results r
     where (p_month and r.month_key = p_key) or (not p_month and r.day_key = p_key)
  ), sums as (
    select b.user_id, sum(b.trophies)::int as points, count(*)::int as races,
           (array_agg(b.name order by b.created_at desc))[1] as name, max(b.created_at) as last_at
      from best b
     where b.n <= 10
     group by b.user_id
  )
  select s.user_id, s.name, s.points, s.races, (row_number() over (order by s.points desc, s.last_at))::int
    from sums s
$$;

-- Рейтинг: p_period 'day' (сегодня) или 'month' (этот месяц). Ответ: {period, top: [{place, name, points, races, me}]
-- (50), me: {place, points} или null}.
create or replace function public.race_top(p_period text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  uid  uuid := auth.uid();
  mon  boolean := p_period = 'month';
  top  jsonb;
  mine jsonb;
begin
  select coalesce(jsonb_agg(jsonb_build_object('place', k.place, 'name', k.name, 'points', k.points, 'races', k.races,
                                               'me', k.user_id = uid) order by k.place) filter (where k.place <= 50), '[]'::jsonb),
         (select jsonb_build_object('place', x.place, 'points', x.points)
            from _race_rank(mon, case when mon then _race_month() else _race_day() end) x where x.user_id = uid)
    into top, mine
    from _race_rank(mon, case when mon then _race_month() else _race_day() end) k;
  return jsonb_build_object('period', case when mon then 'month' else 'day' end, 'top', top, 'me', mine);
end $$;

-- Незабранные награды за места: дни (3 последних прошедших, топ-10) и прошлый месяц (топ-100).
-- Ответ: [{period, key, place, points}].
create or replace function public.race_prizes()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  out jsonb := '[]'::jsonb;
  k   int;
  x   record;
begin
  if uid is null then
    return out;
  end if;
  for k in select g from generate_series(_race_day() - 3, _race_day() - 1) g loop
    select * into x from _race_rank(false, k) r where r.user_id = uid;
    if x.place is not null and x.place <= _race_day_prize_top()
       and not exists (select 1 from race_prizes p where p.user_id = uid and p.period = 'day' and p.key = k) then
      out := out || jsonb_build_array(jsonb_build_object('period', 'day', 'key', k, 'place', x.place, 'points', x.points));
    end if;
  end loop;
  k := _race_month() - 1;
  select * into x from _race_rank(true, k) r where r.user_id = uid;
  if x.place is not null and x.place <= _race_month_prize_top()
     and not exists (select 1 from race_prizes p where p.user_id = uid and p.period = 'month' and p.key = k) then
    out := out || jsonb_build_array(jsonb_build_object('period', 'month', 'key', k, 'place', x.place, 'points', x.points));
  end if;
  return out;
end $$;

-- Забрать награду: место проверяет сервер, один раз. Ответ: {period, key, place}; ошибка 'prize' - не положена.
create or replace function public.race_prize_claim(p_period text, p_key int)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  mon boolean := p_period = 'month';
  pl  int;
  lim int := case when p_period = 'month' then _race_month_prize_top() else _race_day_prize_top() end;
begin
  if uid is null or p_period not in ('day', 'month')
     or (mon and p_key <> _race_month() - 1)
     or (not mon and (p_key < _race_day() - 3 or p_key >= _race_day())) then
    raise exception 'prize';
  end if;
  select r.place into pl from _race_rank(mon, p_key) r where r.user_id = uid;
  if pl is null or pl > lim then
    raise exception 'prize';
  end if;
  insert into race_prizes (user_id, period, key, place) values (uid, p_period, p_key, pl)
  on conflict do nothing;
  if not found then
    raise exception 'prize';
  end if;
  return jsonb_build_object('period', p_period, 'key', p_key, 'place', pl);
end $$;

-- Чистка: комнаты старше 2 суток (места удаляются с ними), итоги и забранные награды старше 62 дней.
create or replace function public.race_cleanup() returns void
language plpgsql security definer set search_path = public as $$
begin
  delete from race_rooms where created_at < now() - interval '2 days';
  delete from race_results where created_at < now() - interval '62 days';
  delete from race_prizes where created_at < now() - interval '62 days';
end $$;

revoke all on function public.race_join(text, text, int) from public, anon;
revoke all on function public.race_cheer(bigint, int) from public, anon;
revoke all on function public.race_emote(bigint, text) from public, anon;
revoke all on function public.race_prizes() from public, anon;
revoke all on function public.race_prize_claim(text, int) from public, anon;
revoke all on function public._race_rank(boolean, int) from public, anon, authenticated;
revoke all on function public.race_sync(bigint, jsonb) from public, anon;
revoke all on function public.race_result(bigint, int, jsonb) from public, anon;
revoke all on function public.race_top(text) from public, anon;
revoke all on function public.race_cleanup() from public, anon, authenticated;
revoke all on function public._race_clean_times(jsonb, timestamptz) from public, anon, authenticated;
grant execute on function public.race_join(text, text, int) to authenticated;
grant execute on function public.race_cheer(bigint, int) to authenticated;
grant execute on function public.race_emote(bigint, text) to authenticated;
grant execute on function public.race_prizes() to authenticated;
grant execute on function public.race_prize_claim(text, int) to authenticated;
grant execute on function public.race_sync(bigint, jsonb) to authenticated;
grant execute on function public.race_result(bigint, int, jsonb) to authenticated;
grant execute on function public.race_top(text) to authenticated;
