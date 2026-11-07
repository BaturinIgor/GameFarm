-- Призыв погоды для альянса Harvest Hollow.
-- Запуск: Supabase -> SQL Editor -> вставить файл целиком -> Run (после alliances.sql). Повторный запуск безопасен.
--
-- Глава или заместитель раз в день бесплатно зовёт погоду на 1 час: сейчас или через 30 минут, 1 или 2 часа.
--   Дождь - грядки у всех участников растут вдвое быстрее. Солнце - больше добычи и опыта.
-- Любой участник может позвать ещё до 2 раз в день за кристаллы (их списывает игра после успеха).
-- Пока одна погода ждёт начала или идёт, новую позвать нельзя. Действие погоды считает игра (AllianceWeather).
-- Числа должны совпадать с godot/scripts/data/alliance_weather.gd.

create table if not exists public.alliance_weather (
  alliance_id bigint  primary key references public.alliances (id) on delete cascade,
  kind        text    not null default '',
  starts_at   bigint  not null default 0,
  ends_at     bigint  not null default 0,
  caller      text    not null default '',
  day_key     int     not null default 0,
  free_used   int     not null default 0,
  paid_used   int     not null default 0
);
alter table public.alliance_weather enable row level security;
revoke all on public.alliance_weather from anon, authenticated;

-- Строка погоды альянса (создаёт и обнуляет счётчики в новый день).
create or replace function public._al_weather_row(p_alliance bigint) returns public.alliance_weather
language plpgsql security definer set search_path = public as $$
declare w alliance_weather; d int := _al_day();
begin
  insert into alliance_weather (alliance_id, day_key) values (p_alliance, d) on conflict (alliance_id) do nothing;
  update alliance_weather set day_key = d, free_used = 0, paid_used = 0 where alliance_id = p_alliance and day_key <> d;
  select * into w from alliance_weather where alliance_id = p_alliance for update;
  return w;
end $$;

create or replace function public._al_weather_json(w public.alliance_weather) returns jsonb
language sql stable as $$
  select jsonb_build_object('kind', w.kind, 'starts', w.starts_at, 'ends', w.ends_at, 'caller', w.caller,
    'free_left', greatest(0, 1 - w.free_used), 'paid_left', greatest(0, 2 - w.paid_used),
    'now', extract(epoch from now())::bigint)
$$;

-- Погода моего альянса. Пусто - не в альянсе.
create or replace function public.al_weather()
returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m record;
begin
  if uid is null then raise exception 'not signed in'; end if;
  select * into m from alliance_members where user_id = uid;
  if not found then return null; end if;
  return _al_weather_json(_al_weather_row(m.alliance_id));
end $$;

-- Позвать погоду: p_kind rain или sun, p_delay - через сколько секунд начнётся, p_paid - за кристаллы.
create or replace function public.al_weather_call(p_kind text, p_delay int, p_paid boolean)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m record; w alliance_weather; t bigint := extract(epoch from now())::bigint;
begin
  if uid is null then raise exception 'not signed in'; end if;
  if p_kind not in ('rain', 'sun') then raise exception 'bad kind'; end if;
  if p_delay not in (0, 1800, 3600, 7200) then raise exception 'bad delay'; end if;
  select * into m from alliance_members where user_id = uid;
  if not found then raise exception 'not in alliance'; end if;
  w := _al_weather_row(m.alliance_id);
  if w.ends_at > t then raise exception 'weather busy'; end if;
  if p_paid then
    if w.paid_used >= 2 then raise exception 'limit'; end if;
    update alliance_weather set paid_used = paid_used + 1 where alliance_id = m.alliance_id;
  else
    if m.role not in ('leader', 'officer') then raise exception 'not allowed'; end if;
    if w.free_used >= 1 then raise exception 'limit'; end if;
    update alliance_weather set free_used = free_used + 1 where alliance_id = m.alliance_id;
  end if;
  update alliance_weather set kind = p_kind, starts_at = t + p_delay, ends_at = t + p_delay + 3600, caller = m.name
   where alliance_id = m.alliance_id returning * into w;
  perform _al_system(m.alliance_id, 'weather', m.name, p_kind || ':' || (t + p_delay)::text);
  return _al_weather_json(w);
end $$;

revoke all on function public.al_weather() from public, anon;
revoke all on function public.al_weather_call(text, int, boolean) from public, anon;
revoke all on function public._al_weather_row(bigint) from public, anon, authenticated;
grant execute on function public.al_weather() to authenticated;
grant execute on function public.al_weather_call(text, int, boolean) to authenticated;
