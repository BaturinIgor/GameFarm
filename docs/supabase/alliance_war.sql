-- Карта войны альянсов Harvest Hollow: недельная лига до 8 альянсов на карте 120x120.
-- Запуск: Supabase -> SQL Editor -> вставить файл целиком -> Run (после alliances.sql, power.sql и alliance_events.sql).
-- Повторный запуск безопасен.
--
-- В центре замок, база каждого альянса на своём краю, между ними 32 аванпоста. Атаковать можно точку,
-- соседнюю с базой или с точкой своего альянса. У игрока 5 атак в день (+3 со «Знаменем войны»).
-- Шанс победы: моя мощь * (1 + буст казны) против гарнизона точки, от 10% до 90%. Каждая победа снимает щит,
-- без щитов точка переходит к альянсу. Свою точку можно укрепить (+1 щит, тратит атаку).
-- Точки приносят очки каждый час, в конце недели - награда по месту в лиге.
-- В лигу альянс попадает сам, когда участник впервые за неделю открывает войну.
-- Числа как в godot/scripts/data/war.gd.

create table if not exists public.war_leagues (
  id         bigint generated always as identity primary key,
  week_key   int    not null,
  strength   bigint not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists war_leagues_week on public.war_leagues (week_key);

create table if not exists public.war_teams (
  league_id   bigint not null references public.war_leagues (id) on delete cascade,
  alliance_id bigint not null references public.alliances (id) on delete cascade,
  week_key    int    not null,
  slot        int    not null,
  strength    bigint not null default 0,
  points      numeric not null default 0,
  chest       bigint not null default 0,
  settled_at  timestamptz not null default now(),
  primary key (league_id, alliance_id),
  unique (week_key, alliance_id),
  unique (league_id, slot)
);

create table if not exists public.war_nodes (
  league_id bigint not null references public.war_leagues (id) on delete cascade,
  node      int    not null,
  owner     bigint references public.alliances (id) on delete set null,
  shields   int    not null,
  garrison  int    not null default 0,
  primary key (league_id, node)
);

create table if not exists public.war_players (
  week_key    int    not null,
  user_id     uuid   not null references auth.users (id) on delete cascade,
  alliance_id bigint,
  day_key     int    not null default 0,
  used        int    not null default 0,
  donates     int    not null default 0,
  attacks     int    not null default 0,
  wins        int    not null default 0,
  pass        boolean not null default false,
  primary key (week_key, user_id)
);

create table if not exists public.war_log (
  id          bigint generated always as identity primary key,
  league_id   bigint not null references public.war_leagues (id) on delete cascade,
  node        int    not null,
  alliance_id bigint,
  name        text   not null,
  act         text   not null,   -- win, lose, capture, reinforce
  created_at  timestamptz not null default now()
);
create index if not exists war_log_league on public.war_log (league_id, id desc);

create table if not exists public.war_claims (
  week_key int  not null,
  user_id  uuid not null references auth.users (id) on delete cascade,
  primary key (week_key, user_id)
);

alter table public.war_leagues enable row level security;
alter table public.war_teams enable row level security;
alter table public.war_nodes enable row level security;
alter table public.war_players enable row level security;
alter table public.war_log enable row level security;
alter table public.war_claims enable row level security;
revoke all on public.war_leagues, public.war_teams, public.war_nodes, public.war_players, public.war_log, public.war_claims
  from anon, authenticated;

-- Рамка статуи «Знамя войны» (как в alliance_chronicle.sql).
create or replace function public._al_frames() returns text[] language sql immutable as $$
  select array['stone', 'bronze', 'gold', 'crystal', 'flame', 'royal', 'war']
$$;

-- ---------- правила (как в war.gd) ----------

-- Точки карты: номер и ярус (0 - база альянса 1..8, 1-3 - аванпосты от края к центру, 4 - замок).
create or replace function public._war_nodes() returns table (n int, tier int) language sql immutable as $$
  values
    (0, 4),
    (1, 0),
    (2, 0),
    (3, 0),
    (4, 0),
    (5, 0),
    (6, 0),
    (7, 0),
    (8, 0),
    (9, 1),
    (10, 1),
    (11, 1),
    (12, 1),
    (13, 1),
    (14, 1),
    (15, 1),
    (16, 1),
    (17, 1),
    (18, 1),
    (19, 1),
    (20, 1),
    (21, 1),
    (22, 1),
    (23, 1),
    (24, 1),
    (25, 2),
    (26, 2),
    (27, 2),
    (28, 2),
    (29, 2),
    (30, 2),
    (31, 2),
    (32, 2),
    (33, 3),
    (34, 3),
    (35, 3),
    (36, 3),
    (37, 3),
    (38, 3),
    (39, 3),
    (40, 3)
$$;

create or replace function public._war_links() returns table (a int, b int) language sql immutable as $$
  values (0,33), (0,34), (0,35), (0,36), (0,37), (0,38), (0,39), (0,40), (1,9), (1,17), (1,24), (2,10), (2,17), (2,18), (3,11), (3,18), (3,19), (4,12), (4,19), (4,20), (5,13), (5,20), (5,21), (6,14), (6,21), (6,22), (7,15), (7,22), (7,23), (8,16), (8,23), (8,24), (9,17), (9,24), (9,25), (9,32), (10,17), (10,18), (10,25), (10,26), (11,18), (11,19), (11,26), (11,27), (12,19), (12,20), (12,27), (12,28), (13,20), (13,21), (13,28), (13,29), (14,21), (14,22), (14,29), (14,30), (15,22), (15,23), (15,30), (15,31), (16,23), (16,24), (16,31), (16,32), (17,25), (18,26), (19,27), (20,28), (21,29), (22,30), (23,31), (24,32), (25,33), (25,34), (26,34), (26,35), (27,35), (27,36), (28,36), (28,37), (29,37), (29,38), (30,38), (30,39), (31,39), (31,40), (32,33), (32,40)
$$;

create or replace function public._war_tier(p_node int) returns int language sql immutable as $$
  select tier from _war_nodes() where n = p_node
$$;
-- Очков в час за точку.
create or replace function public._war_rate(p_tier int) returns int language sql immutable as $$
  select case p_tier when 1 then 10 when 2 then 20 when 3 then 30 when 4 then 100 else 0 end
$$;
-- Щитов у ничьей точки, после захвата и предел укрепления.
create or replace function public._war_neutral_shields(p_tier int) returns int language sql immutable as $$
  select case p_tier when 4 then 4 when 1 then 1 else 2 end
$$;
create or replace function public._war_capture_shields(p_tier int) returns int language sql immutable as $$
  select case when p_tier = 4 then 2 else 1 end
$$;
create or replace function public._war_max_shields(p_tier int) returns int language sql immutable as $$
  select case when p_tier = 4 then 6 else 3 end
$$;
-- Гарнизон ничьей точки: средняя мощь участника лиги, умноженная на ярус.
create or replace function public._war_neutral_mult(p_tier int) returns numeric language sql immutable as $$
  select case p_tier when 1 then 0.6 when 2 then 0.9 when 3 then 1.2 else 1.5 end
$$;
create or replace function public._war_attacks(p_pass boolean) returns int language sql immutable as $$
  select 5 + case when p_pass then 3 else 0 end
$$;
-- Казна: +1% к силе атаки за каждые 100 000 монет, не больше +35%.
create or replace function public._war_boost(p_chest bigint) returns numeric language sql immutable as $$
  select least(0.35, greatest(0, p_chest) / 10000000.0)
$$;
-- Конец недели войны (понедельник 00:00 UTC следующей недели).
create or replace function public._war_end(p_week int) returns timestamptz language sql immutable as $$
  select to_timestamp((p_week * 7 + 4) * 86400.0)
$$;
-- Начислить очки за удержание точек до текущего момента (не дальше конца недели).
create or replace function public._war_settle(p_league bigint) returns void
language plpgsql security definer set search_path = public as $$
declare wk int; t timestamptz;
begin
  select week_key into wk from war_leagues where id = p_league;
  t := least(now(), _war_end(wk));
  update war_teams tm
     set points = tm.points + coalesce((select sum(_war_rate(w.tier)) from war_nodes n join _war_nodes() w on w.n = n.node
                                         where n.league_id = tm.league_id and n.owner = tm.alliance_id), 0)
                              * extract(epoch from (t - tm.settled_at)) / 3600.0,
         settled_at = t
   where tm.league_id = p_league and tm.settled_at < t;
end $$;

-- Записать альянс в лигу этой недели (если ещё не записан). Возвращает лигу.
create or replace function public._war_join(p_alliance bigint) returns bigint
language plpgsql security definer set search_path = public as $$
declare wk int := _al_week(); lg bigint; s bigint; sl int;
begin
  select league_id into lg from war_teams where week_key = wk and alliance_id = p_alliance;
  if found then return lg; end if;
  perform pg_advisory_xact_lock(hashtext('war-join'), wk);
  select league_id into lg from war_teams where week_key = wk and alliance_id = p_alliance;
  if found then return lg; end if;
  s := greatest(1, _al_strength(p_alliance));
  -- Лига похожей силы (в 3 раза слабее или сильнее), где есть место
  select l.id into lg from war_leagues l
   where l.week_key = wk and (select count(*) from war_teams t where t.league_id = l.id) < 8
     and greatest(l.strength, 1) between s / 3 and s * 3
   order by abs(ln(greatest(l.strength, 1)) - ln(s)), l.id limit 1;
  if lg is null then
    insert into war_leagues (week_key, strength) values (wk, s) returning id into lg;
    insert into war_nodes (league_id, node, shields)
      select lg, n, _war_neutral_shields(tier) from _war_nodes() where tier > 0;
  end if;
  select min(x) into sl from generate_series(1, 8) x where x not in (select slot from war_teams where league_id = lg);
  insert into war_teams (league_id, alliance_id, week_key, slot, strength) values (lg, p_alliance, wk, sl, s);
  update war_leagues set strength = (select avg(strength)::bigint from war_teams where league_id = lg) where id = lg;
  perform _al_system(p_alliance, 'war', '', 'join');
  return lg;
end $$;

-- Моя строка войны на эту неделю (сброс дневных счётчиков).
create or replace function public._war_me(p_user uuid, p_alliance bigint) returns war_players
language plpgsql security definer set search_path = public as $$
declare wk int := _al_week(); d int := _al_day(); r war_players;
begin
  insert into war_players (week_key, user_id, alliance_id, day_key) values (wk, p_user, p_alliance, d) on conflict do nothing;
  update war_players set used = 0, donates = 0, day_key = d where week_key = wk and user_id = p_user and day_key <> d;
  update war_players set alliance_id = p_alliance where week_key = wk and user_id = p_user and alliance_id is distinct from p_alliance;
  select * into r from war_players where week_key = wk and user_id = p_user;
  return r;
end $$;

-- Можно ли атаковать точку: рядом с моей базой или моей точкой.
create or replace function public._war_reachable(p_league bigint, p_alliance bigint, p_node int) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from _war_links() l
     cross join lateral (select case when l.a = p_node then l.b else l.a end as other) o
     where (l.a = p_node or l.b = p_node)
       and (o.other = (select slot from war_teams where league_id = p_league and alliance_id = p_alliance)
            or exists (select 1 from war_nodes n where n.league_id = p_league and n.node = o.other and n.owner = p_alliance)))
$$;

-- Гарнизон точки (у ничьей - от средней мощи лиги).
create or replace function public._war_garrison(p_league bigint, p_node int) returns int
language sql stable security definer set search_path = public as $$
  select case when n.owner is null
              then greatest(150, round((select strength from war_leagues where id = p_league) / 30.0 * _war_neutral_mult(_war_tier(p_node))))::int
              else greatest(100, n.garrison) end
    from war_nodes n where n.league_id = p_league and n.node = p_node
$$;

-- Место альянса в лиге по очкам.
create or replace function public._war_place(p_league bigint, p_alliance bigint) returns int
language sql stable security definer set search_path = public as $$
  select place::int from (select alliance_id, row_number() over (order by points desc, strength desc, slot) as place
                            from war_teams where league_id = p_league) t where alliance_id = p_alliance
$$;

-- ---------- для игры ----------

-- Война моего альянса: лига, карта, мои атаки, казна, журнал и награда за прошлую неделю.
create or replace function public.al_war(p_name text, p_level int)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m alliance_members; lg bigint; me war_players; tm war_teams; reward jsonb; prev war_players;
begin
  if uid is null then raise exception 'not signed in'; end if;
  select * into m from alliance_members where user_id = uid;
  if not found then return null; end if;
  -- Награда за прошлую неделю
  select * into prev from war_players where week_key = _al_week() - 1 and user_id = uid and attacks > 0;
  if found and not exists (select 1 from war_claims where week_key = prev.week_key and user_id = uid) then
    select jsonb_build_object('week', prev.week_key, 'place', _war_place(t.league_id, t.alliance_id),
                              'teams', (select count(*) from war_teams x where x.league_id = t.league_id))
      into reward from war_teams t where t.week_key = prev.week_key and t.alliance_id = prev.alliance_id;
  end if;
  lg := _war_join(m.alliance_id);
  perform _war_settle(lg);
  me := _war_me(uid, m.alliance_id);
  select * into tm from war_teams where league_id = lg and alliance_id = m.alliance_id;
  return jsonb_build_object(
    'league', lg, 'reward', reward, 'slot', tm.slot,
    'ends', extract(epoch from _war_end(_al_week()))::bigint,
    'teams', (select coalesce(jsonb_agg(jsonb_build_object('slot', t.slot, 'id', t.alliance_id, 'name', a.name, 'tag', a.tag,
                     'emblem', a.emblem, 'points', floor(t.points)::bigint, 'strength', t.strength, 'me', t.alliance_id = m.alliance_id,
                     'nodes', (select count(*) from war_nodes n where n.league_id = lg and n.owner = t.alliance_id))
                     order by t.points desc, t.strength desc, t.slot), '[]'::jsonb)
                from war_teams t join alliances a on a.id = t.alliance_id where t.league_id = lg),
    'nodes', (select coalesce(jsonb_agg(jsonb_build_array(n.node, coalesce(t.slot, 0), n.shields, _war_garrison(lg, n.node),
                      _war_reachable(lg, m.alliance_id, n.node)) order by n.node), '[]'::jsonb)
                from war_nodes n left join war_teams t on t.league_id = lg and t.alliance_id = n.owner where n.league_id = lg),
    'chest', tm.chest, 'boost', _war_boost(tm.chest),
    'used', me.used, 'max', _war_attacks(me.pass), 'pass', me.pass, 'donates', me.donates, 'wins', me.wins,
    'power', _power_of(uid),
    'log', (select coalesce(jsonb_agg(jsonb_build_object('node', l.node, 'name', l.name, 'act', l.act,
                    'slot', (select slot from war_teams t where t.league_id = lg and t.alliance_id = l.alliance_id),
                    'at', extract(epoch from l.created_at)::bigint) order by l.id desc), '[]'::jsonb)
              from (select * from war_log where league_id = lg order by id desc limit 20) l));
end $$;

-- Атаковать точку или укрепить свою (p_reinforce). Возвращает исход.
create or replace function public.war_attack(p_node int, p_reinforce boolean, p_name text)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m alliance_members; lg bigint; me war_players; tm war_teams; n war_nodes; tier int;
        pw int; a numeric; d int; chance numeric; won boolean := false; captured boolean := false; nm text := _rating_clean_name(p_name);
begin
  if uid is null then raise exception 'not signed in'; end if;
  select * into m from alliance_members where user_id = uid;
  if not found then raise exception 'not in alliance'; end if;
  select league_id into lg from war_teams where week_key = _al_week() and alliance_id = m.alliance_id;
  if lg is null then raise exception 'not allowed'; end if;
  perform 1 from war_leagues where id = lg for update;
  if now() >= _war_end(_al_week()) then raise exception 'not allowed'; end if;
  perform _war_settle(lg);
  me := _war_me(uid, m.alliance_id);
  if me.used >= _war_attacks(me.pass) then raise exception 'limit'; end if;
  select * into n from war_nodes where league_id = lg and node = p_node for update;
  if not found then raise exception 'not allowed'; end if;
  tier := _war_tier(p_node);
  pw := greatest(100, _power_of(uid));
  select * into tm from war_teams where league_id = lg and alliance_id = m.alliance_id;
  if p_reinforce then
    if n.owner is distinct from m.alliance_id or n.shields >= _war_max_shields(tier) then raise exception 'not allowed'; end if;
    update war_nodes set shields = shields + 1, garrison = greatest(garrison, pw) where league_id = lg and node = p_node;
    update war_players set used = used + 1, attacks = attacks + 1 where week_key = me.week_key and user_id = uid;
    insert into war_log (league_id, node, alliance_id, name, act) values (lg, p_node, m.alliance_id, nm, 'reinforce');
    return jsonb_build_object('won', true, 'captured', false, 'reinforced', true, 'shields', n.shields + 1, 'chance', 1);
  end if;
  if n.owner = m.alliance_id or not _war_reachable(lg, m.alliance_id, p_node) then raise exception 'not allowed'; end if;
  a := pw * (1 + _war_boost(tm.chest));
  d := _war_garrison(lg, p_node);
  chance := least(0.9, greatest(0.1, a / (a + d)));
  won := random() < chance;
  update war_players set used = used + 1, attacks = attacks + 1, wins = wins + case when won then 1 else 0 end
   where week_key = me.week_key and user_id = uid;
  if won then
    if n.shields <= 1 then
      captured := true;
      update war_nodes set owner = m.alliance_id, shields = _war_capture_shields(tier), garrison = pw
       where league_id = lg and node = p_node;
      update war_teams set points = points + 20 * tier where league_id = lg and alliance_id = m.alliance_id;
      if tier = 4 then perform _al_system(m.alliance_id, 'war', nm, 'castle'); end if;
      if n.owner is not null and tier = 4 then perform _al_system(n.owner, 'war', '', 'lost'); end if;
    else
      update war_nodes set shields = shields - 1 where league_id = lg and node = p_node;
    end if;
    if to_regproc('public._al_add_xp') is not null then perform _al_add_xp(m.alliance_id, case when captured then 10 else 3 end); end if;
  end if;
  insert into war_log (league_id, node, alliance_id, name, act)
  values (lg, p_node, m.alliance_id, nm, case when captured then 'capture' when won then 'win' else 'lose' end);
  return jsonb_build_object('won', won, 'captured', captured, 'reinforced', false, 'chance', round(chance, 3),
                            'shields', case when captured then _war_capture_shields(tier) when won then n.shields - 1 else n.shields end);
end $$;

-- Вложить монеты в казну войны (монеты списывает игра, 3 раза в день). Возвращает новый буст.
create or replace function public.war_donate(p_coins int)
returns numeric
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m alliance_members; lg bigint; me war_players; c bigint;
begin
  if uid is null then raise exception 'not signed in'; end if;
  select * into m from alliance_members where user_id = uid;
  if not found then raise exception 'not in alliance'; end if;
  if p_coins < 1 or p_coins > 100000 then raise exception 'bad lot'; end if;
  select league_id into lg from war_teams where week_key = _al_week() and alliance_id = m.alliance_id;
  if lg is null then raise exception 'not allowed'; end if;
  me := _war_me(uid, m.alliance_id);
  if me.donates >= 3 then raise exception 'limit'; end if;
  update war_players set donates = donates + 1 where week_key = me.week_key and user_id = uid;
  update war_teams set chest = chest + p_coins where league_id = lg and alliance_id = m.alliance_id returning chest into c;
  return _war_boost(c);
end $$;

-- «Знамя войны» на эту неделю: +3 атаки в день (покупку проверяет игра).
create or replace function public.war_pass()
returns void
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); aid bigint;
begin
  if uid is null then raise exception 'not signed in'; end if;
  select alliance_id into aid from alliance_members where user_id = uid;
  perform _war_me(uid, aid);
  update war_players set pass = true where week_key = _al_week() and user_id = uid;
end $$;

-- Забрать награду за место альянса в прошлой неделе (один раз, если я атаковал). Награду выдаёт игра.
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
                            'teams', (select count(*) from war_teams x where x.league_id = t.league_id));
end $$;

-- Чистка: лиги старше 4 недель, игроки и награды старше 8 недель.
create or replace function public.war_cleanup() returns void
language sql security definer set search_path = public as $$
  delete from war_leagues where week_key < _al_week() - 4;
  delete from war_players where week_key < _al_week() - 8;
  delete from war_claims where week_key < _al_week() - 8;
$$;

do $$
declare f text;
begin
  foreach f in array array['al_war(text, int)', 'war_attack(int, boolean, text)', 'war_donate(int)', 'war_pass()', 'war_claim()'] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  foreach f in array array['_war_settle(bigint)', '_war_join(bigint)', '_war_me(uuid, bigint)', '_war_reachable(bigint, bigint, int)',
                           '_war_garrison(bigint, int)', '_war_place(bigint, bigint)', 'war_cleanup()'] loop
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;
