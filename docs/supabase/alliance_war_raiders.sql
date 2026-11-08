-- Разбойники: альянсы под управлением сервера. Занимают пустые места в лигах войны, чтобы даже первый
-- альянс на сервере воевал не с пустой картой. Держат клетки, сами нападают отрядами (видно на карте)
-- и укрепляют свои клетки. Сила - по лиге, примерно как лагерь 2-3 уровня. Своих клеток не больше RAID_NODES.
-- В поиске и рейтингах альянсов их нет. Имя "@raider:N" игра показывает на языке игрока.
-- Запуск: Supabase -> SQL Editor -> вставить файл целиком -> Run (после alliance_war_shop.sql). Повторный запуск безопасен.

alter table public.alliances add column if not exists raider boolean not null default false;
alter table public.war_marches alter column user_id drop not null;

create or replace function public._war_raid_min() returns int language sql immutable as $$ select 4 $$;
create or replace function public._war_raid_nodes() returns int language sql immutable as $$ select 5 $$;

-- Новый альянс разбойников (у каждого своё место в лиге на неделю, поэтому создаём по необходимости).
create or replace function public._war_raider_new() returns bigint
language plpgsql security definer set search_path = public as $$
declare rid bigint; k int := 1 + floor(random() * 8)::int;
begin
  insert into alliances (name, tag, emblem, about, min_level, raider)
    values ('@raider:' || k || ':' || gen_random_uuid(), 'R' || substr(gen_random_uuid()::text, 1, 8), k - 1, '', 999, true)
    returning alliances.id into rid;
  update alliances set name = '@raider:' || k || ':' || rid, tag = 'R' || rid, flag = k % 6 where alliances.id = rid;
  return rid;
end $$;

-- Дополнить лигу разбойниками до _war_raid_min() команд.
create or replace function public._war_fill(p_league bigint) returns void
language plpgsql security definer set search_path = public as $$
declare wk int; tr int; ls bigint; cnt int; sl int; rid bigint; s bigint;
begin
  select week_key, tier, strength into wk, tr, ls from war_leagues where id = p_league;
  select count(*) into cnt from war_teams where league_id = p_league;
  while cnt < _war_raid_min() loop
    select min(x) into sl from generate_series(1, 8) x where x not in (select slot from war_teams where league_id = p_league);
    exit when sl is null;
    rid := _war_raider_new();
    -- Сила: пятая часть силы лиги (top-30 мощи альянсов), но в пределах лагерей 1-3 уровня этой лиги
    s := round(least(_war_camp_power(3), greatest(_war_camp_power(1), ls / 5.0)) * _war_tier_mult(tr) * (0.8 + random() * 0.3));
    insert into war_teams (league_id, alliance_id, week_key, slot, strength) values (p_league, rid, wk, sl, s);
    cnt := cnt + 1;
  end loop;
end $$;

-- Запись в лигу: как в alliance_war_leagues.sql, только разбойники не считаются в силе лиги, а пустые места
-- занимают разбойники. Живой альянс предпочитает лигу, где живых больше.
create or replace function public._war_join(p_alliance bigint) returns bigint
language plpgsql security definer set search_path = public as $$
declare wk int := _al_week(); lg bigint; s bigint; sl int; tr int;
begin
  select league_id into lg from war_teams where week_key = wk and alliance_id = p_alliance;
  if found then return lg; end if;
  perform pg_advisory_xact_lock(hashtext('war-join'), wk);
  select league_id into lg from war_teams where week_key = wk and alliance_id = p_alliance;
  if found then return lg; end if;
  tr := _war_rank(p_alliance);
  s := greatest(1, _al_strength(p_alliance));
  select l.id into lg from war_leagues l
   where l.week_key = wk and l.tier = tr and (select count(*) from war_teams t where t.league_id = l.id) < 8
   order by abs(ln(greatest(l.strength, 1)) - ln(s)), l.id limit 1;
  if lg is null then
    insert into war_leagues (week_key, strength, tier) values (wk, s, tr) returning id into lg;
    insert into war_nodes (league_id, node, shields)
      select lg, n, _war_neutral_shields(tier) from _war_nodes() where tier > 0;
  end if;
  select min(x) into sl from generate_series(1, 8) x where x not in (select slot from war_teams where league_id = lg);
  insert into war_teams (league_id, alliance_id, week_key, slot, strength) values (lg, p_alliance, wk, sl, s);
  update war_leagues set strength = coalesce((select avg(t.strength)::bigint from war_teams t join alliances a on a.id = t.alliance_id
                                               where t.league_id = lg and not a.raider), s) where id = lg;
  perform _war_fill(lg);
  perform _al_system(p_alliance, 'war', '', 'join');
  return lg;
end $$;

-- Ход разбойников (pg_cron раз в 15 минут): каждый без отряда в пути с вероятностью 1/3 выступает
-- на соседнюю клетку - чужую клетку живого альянса или ничью послабее; иногда укрепляет свою.
create or replace function public.war_raiders_tick() returns void
language plpgsql security definer set search_path = public as $$
declare wk int := _al_week(); r record; target int; tier int; own int;
begin
  if now() >= _war_end(wk) then return; end if;
  for r in select t.league_id, t.alliance_id, t.slot, t.strength from war_teams t join alliances a on a.id = t.alliance_id
            where t.week_key = wk and a.raider loop
    continue when exists (select 1 from war_marches m where m.league_id = r.league_id and m.alliance_id = r.alliance_id and not m.resolved);
    continue when random() > 1.0 / 3.0;
    select count(*) into own from war_nodes where league_id = r.league_id and owner = r.alliance_id;
    if own > 0 and random() < 0.25 then
      -- Укрепить свою клетку
      select node into target from war_nodes where league_id = r.league_id and owner = r.alliance_id order by shields, random() limit 1;
      tier := _war_tier(target);
      insert into war_marches (league_id, user_id, alliance_id, name, node, kind, power, arrive_at)
        values (r.league_id, null, r.alliance_id, '@raider', target, 'reinforce', r.strength, now() + make_interval(secs => _war_march_secs(tier)));
      continue;
    end if;
    select n.node into target from war_nodes n
     where n.league_id = r.league_id and n.node <> 0 and n.owner is distinct from r.alliance_id
       and (n.owner is not null or own < _war_raid_nodes())
       and _war_reachable(r.league_id, r.alliance_id, n.node)
     order by (n.owner is null) , _war_tier(n.node), random() limit 1;
    continue when target is null;
    tier := _war_tier(target);
    insert into war_marches (league_id, user_id, alliance_id, name, node, kind, power, arrive_at)
      values (r.league_id, null, r.alliance_id, '@raider', target, 'attack',
              round(r.strength * (0.7 + random() * 0.5)), now() + make_interval(secs => _war_march_secs(tier)));
  end loop;
  -- Старые разбойники (две недели без лиги) больше не нужны
  delete from alliances a where a.raider and a.created_at < now() - interval '14 days'
     and not exists (select 1 from war_teams t where t.alliance_id = a.id and t.week_key >= wk - 1);
end $$;

-- Поиск и рейтинги - без разбойников (как в alliance_apply.sql, alliances.sql и power.sql).
create or replace function public.al_search(p_query text, p_level int)
returns table (id bigint, name text, tag text, emblem int, about text, min_level int, level int, members bigint, cap int, open boolean)
language sql stable security definer set search_path = public as $$
  select a.id, a.name, a.tag, a.emblem, a.about, a.min_level, _al_level(a.xp),
         (select count(*) from alliance_members m where m.alliance_id = a.id), _al_cap(a.talents), a.open
    from alliances a
   where not a.raider
     and (coalesce(p_query, '') = '' or a.name ilike '%' || p_query || '%' or a.tag ilike p_query)
     and (coalesce(p_query, '') <> '' or a.min_level <= greatest(1, p_level))
   order by a.week_xp desc, a.xp desc
   limit 30
$$;

create or replace function public.al_top()
returns table (place bigint, id bigint, name text, tag text, emblem int, level int, week_xp bigint, xp bigint, me boolean)
language sql stable security definer set search_path = public as $$
  with mine as (select alliance_id from alliance_members where user_id = auth.uid()),
  ranked as (
    select row_number() over (order by case when a.week_key = _al_week() then a.week_xp else 0 end desc, a.xp desc) as place,
           a.id, a.name, a.tag, a.emblem, _al_level(a.xp) as level,
           case when a.week_key = _al_week() then a.week_xp else 0 end as week_xp, a.xp,
           a.id = (select alliance_id from mine) as me
      from alliances a where not a.raider
  )
  select * from ranked where place <= 100 or me order by place
$$;

create or replace function public.al_strength_top()
returns table (place bigint, id bigint, name text, tag text, emblem int, level int, strength bigint, me boolean)
language sql stable security definer set search_path = public as $$
  with mine as (select alliance_id from alliance_members where user_id = auth.uid()),
  ranked as (
    select row_number() over (order by s.strength desc, s.xp desc) as place, s.id, s.name, s.tag, s.emblem,
           _al_level(s.xp) as level, s.strength, s.id = (select alliance_id from mine) as me
      from (select a.*, _al_strength(a.id) as strength from alliances a where not a.raider) s
  )
  select * from ranked where place <= 100 or me order by place
$$;

-- Лиги этой недели, уже созданные до запуска файла, тоже получают разбойников.
do $$
declare l record;
begin
  for l in select id from war_leagues where week_key = _al_week() loop
    perform _war_fill(l.id);
  end loop;
end $$;

do $$
begin
  execute 'revoke all on function public._war_raider_new() from public, anon, authenticated';
  execute 'revoke all on function public._war_fill(bigint) from public, anon, authenticated';
  execute 'revoke all on function public._war_join(bigint) from public, anon, authenticated';
  execute 'revoke all on function public.war_raiders_tick() from public, anon, authenticated';
  execute 'revoke all on function public.al_search(text, int) from public, anon';
  execute 'grant execute on function public.al_search(text, int) to authenticated';
  execute 'revoke all on function public.al_top() from public, anon';
  execute 'grant execute on function public.al_top() to authenticated';
  execute 'revoke all on function public.al_strength_top() from public, anon';
  execute 'grant execute on function public.al_strength_top() to authenticated';
end $$;

-- Расписание (pg_cron включён в cleanup.sql).
create extension if not exists pg_cron;
do $$
begin
  perform cron.unschedule(jobid) from cron.job where jobname = 'hh-war-raiders';
  perform cron.schedule('hh-war-raiders', '*/15 * * * *', 'select public.war_raiders_tick()');
end $$;
