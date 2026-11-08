-- Мощь игроков Harvest Hollow (Supabase / Postgres): рейтинг игроков по мощи и сила альянсов.
-- Запуск: Supabase -> SQL Editor -> вставить файл целиком -> Run (после alliances.sql и до alliance_events.sql).
-- Повторный запуск безопасен.
--
-- Мощь считает игра (Power.total в godot/scripts/data/power.gd): уровень, снаряжение, таланты, звери.
-- Сервер принимает её не больше 100 000 000. Сила альянса - сумма мощи 30 самых сильных участников.
-- Мощь добавляет урон по стражу альянса (al_ev_attack в alliance_events.sql: +1 за каждые 10 000 мощи).

create table if not exists public.player_power (
  user_id    uuid        primary key references auth.users (id) on delete cascade,
  name       text        not null,
  level      int         not null default 1,
  power      int         not null default 0,
  updated_at timestamptz not null default now()
);
create index if not exists player_power_top on public.player_power (power desc);

alter table public.player_power enable row level security;
revoke all on public.player_power from anon, authenticated;

-- Мощь игрока (раз в несколько минут, если изменилась).
create or replace function public.submit_power(p_power int, p_name text, p_level int)
returns void
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not signed in'; end if;
  insert into player_power (user_id, name, level, power)
  values (uid, _rating_clean_name(p_name), greatest(1, least(p_level, 200)), greatest(0, least(p_power, 100000000)))
  on conflict (user_id) do update
     set name = excluded.name, level = excluded.level, power = excluded.power, updated_at = now();
end $$;

-- Мощь игрока для урона по стражу (0, если ещё не присылал).
create or replace function public._power_of(p_user uuid) returns int language sql stable as $$
  select coalesce((select power from player_power where user_id = p_user), 0)
$$;

-- Топ игроков по мощи и моё место. Альянс - тег, если игрок в альянсе.
create or replace function public.power_top()
returns table (place bigint, name text, level int, power int, tag text, me boolean)
language sql stable security definer set search_path = public as $$
  with ranked as (
    select row_number() over (order by p.power desc, p.updated_at) as place, p.name, p.level, p.power,
           (select a.tag from alliance_members m join alliances a on a.id = m.alliance_id where m.user_id = p.user_id) as tag,
           p.user_id = auth.uid() as me
      from player_power p
  )
  select * from ranked where place <= 100 or me order by place
$$;

-- Сила альянса: сумма мощи 30 самых сильных участников.
create or replace function public._al_strength(p_alliance bigint) returns bigint language sql stable as $$
  select coalesce(sum(power), 0) from (
    select coalesce(p.power, 0) as power
      from alliance_members m left join player_power p on p.user_id = m.user_id
     where m.alliance_id = p_alliance
     order by 1 desc limit 30) t
$$;

-- Рейтинг альянсов по силе и место моего альянса.
create or replace function public.al_strength_top()
returns table (place bigint, id bigint, name text, tag text, emblem int, level int, strength bigint, me boolean)
language sql stable security definer set search_path = public as $$
  with mine as (select alliance_id from alliance_members where user_id = auth.uid()),
  ranked as (
    select row_number() over (order by s.strength desc, s.xp desc) as place, s.id, s.name, s.tag, s.emblem,
           _al_level(s.xp) as level, s.strength, s.id = (select alliance_id from mine) as me
      from (select a.*, _al_strength(a.id) as strength from alliances a) s
  )
  select * from ranked where place <= 100 or me order by place
$$;

-- Мощь участников моего альянса: [{id, power}] (игра дописывает её в список участников).
create or replace function public.al_member_powers()
returns table (id uuid, power int)
language sql stable security definer set search_path = public as $$
  select m.user_id, coalesce(p.power, 0)
    from alliance_members m left join player_power p on p.user_id = m.user_id
   where m.alliance_id = (select alliance_id from alliance_members where user_id = auth.uid())
$$;

-- Чистка: мощь тех, кто не заходил полгода (hh_cleanup в cleanup.sql).
create or replace function public.power_cleanup() returns void
language sql security definer set search_path = public as $$
  delete from player_power where updated_at < now() - interval '180 days'
$$;

revoke all on function public.submit_power(int, text, int) from public, anon;
revoke all on function public.power_top() from public, anon;
revoke all on function public.al_strength_top() from public, anon;
revoke all on function public.al_member_powers() from public, anon;
revoke all on function public.power_cleanup() from public, anon, authenticated;
revoke all on function public._power_of(uuid) from public, anon, authenticated;
revoke all on function public._al_strength(bigint) from public, anon, authenticated;
grant execute on function public.submit_power(int, text, int) to authenticated;
grant execute on function public.power_top() to authenticated;
grant execute on function public.al_strength_top() to authenticated;
grant execute on function public.al_member_powers() to authenticated;
