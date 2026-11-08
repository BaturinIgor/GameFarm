-- Лиги войны альянсов: 8 лиг от Бронзы до Легенды. В лиге недели до 8 альянсов одной лиги.
-- По итогам недели 1-2 места поднимаются на лигу выше, два последних (если в лиге было 6 и больше альянсов)
-- опускаются, остальные остаются. Сила лагерей на клетках и замка растёт с лигой (множитель от x1 до x18),
-- так сильные альянсы со временем приходят туда, где им снова трудно. Награда за место растёт с лигой.
-- Запуск: Supabase -> SQL Editor -> вставить файл целиком -> Run (после alliance_war_battle.sql). Повторный запуск безопасен.
-- Числа как в godot/scripts/data/war.gd (LEAGUES, LEAGUE_MULT).

alter table public.war_leagues add column if not exists tier int not null default 1;

create table if not exists public.war_ranks (
  alliance_id bigint primary key references public.alliances (id) on delete cascade,
  tier        int    not null default 1,
  week_key    int    not null default 0,   -- за какую неделю уже пересчитана лига
  last_move   int    not null default 0    -- +1 поднялись, -1 опустились, 0 остались
);
alter table public.war_ranks enable row level security;
revoke all on public.war_ranks from anon, authenticated;

create or replace function public._war_tier_mult(p_tier int) returns numeric language sql immutable as $$
  select (array[1, 1.4, 1.9, 2.5, 3.2, 4, 5, 6.5])[greatest(1, least(8, p_tier))]::numeric
$$;

-- Лига альянса на эту неделю: пересчёт по месту в прошлой неделе (один раз за неделю).
create or replace function public._war_rank(p_alliance bigint) returns int
language plpgsql security definer set search_path = public as $$
declare wk int := _al_week(); r war_ranks; t war_teams; place int; teams int; mv int := 0;
begin
  insert into war_ranks (alliance_id) values (p_alliance) on conflict do nothing;
  select * into r from war_ranks where alliance_id = p_alliance for update;
  if r.week_key >= wk then return r.tier; end if;
  select * into t from war_teams where week_key = wk - 1 and alliance_id = p_alliance;
  if found then
    perform _war_settle(t.league_id);
    place := _war_place(t.league_id, p_alliance);
    select count(*) into teams from war_teams where league_id = t.league_id;
    if place <= 2 and teams >= 2 then mv := 1;
    elsif teams >= 6 and place >= teams - 1 then mv := -1;
    end if;
  end if;
  update war_ranks set tier = greatest(1, least(8, tier + mv)), week_key = wk, last_move = mv where alliance_id = p_alliance;
  return greatest(1, least(8, r.tier + mv));
end $$;

-- Записать альянс в лигу этой недели: только к альянсам той же лиги, по похожей силе.
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
  update war_leagues set strength = (select avg(strength)::bigint from war_teams where league_id = lg) where id = lg;
  perform _al_system(p_alliance, 'war', '', 'join');
  return lg;
end $$;

-- Гарнизон: у ничьей клетки - лагерь по уровню клетки и лиге, у чужой - сила того, кто её держит.
create or replace function public._war_garrison(p_league bigint, p_node int) returns int
language sql stable security definer set search_path = public as $$
  select case when n.owner is null
              then round(_war_camp_power(_war_level(p_node)) * _war_tier_mult((select tier from war_leagues where id = p_league)))::int
              else greatest(10000, n.garrison) end
    from war_nodes n where n.league_id = p_league and n.node = p_node
$$;

-- Карта: как в alliance_war_march.sql, плюс лига (tier) и куда альянс сдвинулся после прошлой недели (move).
create or replace function public.war_map(p_name text, p_level int)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m alliance_members; lg bigint; base jsonb;
begin
  if uid is null then raise exception 'not signed in'; end if;
  select * into m from alliance_members where user_id = uid;
  if not found then return null; end if;
  lg := _war_join(m.alliance_id);
  perform _war_resolve(lg);
  base := al_war(p_name, p_level);
  return base || jsonb_build_object(
    'now', extract(epoch from now())::bigint,
    'tier', (select tier from war_leagues where id = lg),
    'move', (select last_move from war_ranks where alliance_id = m.alliance_id),
    'reward_tier', (select l.tier from war_teams t join war_leagues l on l.id = t.league_id
                     where t.week_key = _al_week() - 1 and t.alliance_id = m.alliance_id),
    'marches', (select coalesce(jsonb_agg(jsonb_build_object('id', x.id, 'name', x.name, 'node', x.node, 'kind', x.kind,
                    'slot', (select slot from war_teams t where t.league_id = lg and t.alliance_id = x.alliance_id),
                    'from', extract(epoch from x.started_at)::bigint, 'at', extract(epoch from x.arrive_at)::bigint,
                    'me', x.user_id = uid, 'animal', x.animal) order by x.arrive_at), '[]'::jsonb)
                from war_marches x where x.league_id = lg and not x.resolved),
    'rallies', (select coalesce(jsonb_agg(jsonb_build_object('id', r.id, 'node', r.node, 'leader', r.leader_name,
                    'slot', (select slot from war_teams t where t.league_id = lg and t.alliance_id = r.alliance_id),
                    'fires', extract(epoch from r.fires_at)::bigint, 'power', r.power, 'members', r.members,
                    'mine', r.alliance_id = m.alliance_id,
                    'joined', exists (select 1 from war_rally_members k where k.rally_id = r.id and k.user_id = uid))
                    order by r.fires_at), '[]'::jsonb)
                from war_rallies r where r.league_id = lg and not r.resolved),
    'guards', (select coalesce(jsonb_agg(jsonb_build_array(n.node, n.animal, n.guard)), '[]'::jsonb)
                from war_nodes n where n.league_id = lg and n.animal is not null),
    'results', (select coalesce(jsonb_agg(jsonb_build_object('id', x.id, 'node', x.node, 'kind', x.kind, 'result', x.result)
                    order by x.id), '[]'::jsonb)
                from war_marches x where x.user_id = uid and x.resolved and x.arrive_at > now() - interval '10 minutes'));
end $$;

-- Награда за прошлую неделю: место и лига (игра умножает награду на лигу).
create or replace function public.war_claim()
returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); wk int := _al_week() - 1; p war_players; t war_teams;
begin
  if uid is null then raise exception 'not signed in'; end if;
  select * into p from war_players where week_key = wk and user_id = uid and attacks > 0;
  if not found then raise exception 'nothing'; end if;
  select * into t from war_teams where week_key = wk and alliance_id = p.alliance_id;
  if not found then raise exception 'nothing'; end if;
  insert into war_claims (week_key, user_id) values (wk, uid) on conflict do nothing;
  if not found then raise exception 'already claimed'; end if;
  return jsonb_build_object('week', wk, 'place', _war_place(t.league_id, t.alliance_id),
                            'teams', (select count(*) from war_teams x where x.league_id = t.league_id),
                            'tier', (select tier from war_leagues where id = t.league_id));
end $$;

revoke all on function public._war_rank(bigint) from public, anon, authenticated;
revoke all on function public._war_join(bigint) from public, anon, authenticated;
revoke all on function public._war_garrison(bigint, int) from public, anon, authenticated;
revoke all on function public.war_map(text, int) from public, anon;
grant execute on function public.war_map(text, int) to authenticated;
revoke all on function public.war_claim() from public, anon;
grant execute on function public.war_claim() to authenticated;
