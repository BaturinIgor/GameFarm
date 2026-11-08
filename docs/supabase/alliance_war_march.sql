-- Война альянсов на живой карте: походы отрядов, сборы на замок и звери в гарнизоне.
-- Запуск: Supabase -> SQL Editor -> вставить файл целиком -> Run (после alliance_war.sql). Повторный запуск безопасен.
--
-- Атака больше не мгновенная: игрок отправляет отряд, он идёт к точке 1-3 минуты (по ярусу точки),
-- исход считается, когда отряд дошёл (при следующем обращении любого участника лиги к карте).
-- В пути у игрока до 2 отрядов. Атака тратится при отправке.
-- Замок берётся только сбором: участник открывает сбор (5 минут), остальные присоединяются своей атакой,
-- в конце мощь всех участников сбора идёт одним ударом; победа снимает 2 щита.
-- Укрепление тоже идёт отрядом; можно оставить в гарнизоне зверя - его мощь добавляется к гарнизону точки.
-- Числа как в godot/scripts/data/war.gd.

alter table public.war_nodes add column if not exists animal text;
alter table public.war_nodes add column if not exists guard text;

create table if not exists public.war_marches (
  id           bigint generated always as identity primary key,
  league_id    bigint not null references public.war_leagues (id) on delete cascade,
  user_id      uuid   not null references auth.users (id) on delete cascade,
  alliance_id  bigint not null,
  name         text   not null,
  node         int    not null,
  kind         text   not null,               -- attack, reinforce
  power        int    not null,
  animal       text,
  animal_power int    not null default 0,
  started_at   timestamptz not null default now(),
  arrive_at    timestamptz not null,
  resolved     boolean not null default false,
  result       text
);
create index if not exists war_marches_league on public.war_marches (league_id, resolved, arrive_at);
create index if not exists war_marches_user on public.war_marches (user_id, resolved);

create table if not exists public.war_rallies (
  id           bigint generated always as identity primary key,
  league_id    bigint not null references public.war_leagues (id) on delete cascade,
  alliance_id  bigint not null,
  node         int    not null,
  leader       uuid   references auth.users (id) on delete set null,
  leader_name  text   not null,
  started_at   timestamptz not null default now(),
  fires_at     timestamptz not null,
  power        bigint not null default 0,
  members      int    not null default 0,
  resolved     boolean not null default false,
  result       text
);
create index if not exists war_rallies_league on public.war_rallies (league_id, resolved);

create table if not exists public.war_rally_members (
  rally_id  bigint not null references public.war_rallies (id) on delete cascade,
  user_id   uuid   not null references auth.users (id) on delete cascade,
  name      text   not null,
  power     int    not null,
  primary key (rally_id, user_id)
);

alter table public.war_marches enable row level security;
alter table public.war_rallies enable row level security;
alter table public.war_rally_members enable row level security;
revoke all on public.war_marches, public.war_rallies, public.war_rally_members from anon, authenticated;

-- ---------- правила (как в war.gd) ----------

-- Время похода в секундах: ярус 1 - минута, 2 - две, 3 - три.
create or replace function public._war_march_secs(p_tier int) returns int language sql immutable as $$
  select 60 * greatest(1, least(3, p_tier))
$$;
create or replace function public._war_rally_secs() returns int language sql immutable as $$ select 300 $$;
create or replace function public._war_max_marches() returns int language sql immutable as $$ select 2 $$;
create or replace function public._war_rally_max() returns int language sql immutable as $$ select 30 $$;
-- Зверь в гарнизоне: не больше 500 000 мощи (как предел зверя в турнире).
create or replace function public._war_animal_cap() returns int language sql immutable as $$ select 500000 $$;

-- Удар по точке (общая часть похода и сбора). p_strip - сколько щитов снимает победа.
create or replace function public._war_hit(p_league bigint, p_alliance bigint, p_node int, p_power numeric, p_name text,
  p_strip int, p_user uuid) returns text
language plpgsql security definer set search_path = public as $$
declare n war_nodes; tm war_teams; tier int := _war_tier(p_node); a numeric; d int; chance numeric; won boolean; res text;
begin
  select * into n from war_nodes where league_id = p_league and node = p_node for update;
  if not found or n.owner = p_alliance then return 'void'; end if;
  -- Пока отряд шёл, точку могли отрезать: без связи с нашей территорией отряд возвращается ни с чем
  if not _war_reachable(p_league, p_alliance, p_node) then return 'cut'; end if;
  select * into tm from war_teams where league_id = p_league and alliance_id = p_alliance;
  a := p_power * (1 + _war_boost(tm.chest));
  d := _war_garrison(p_league, p_node);
  chance := least(0.9, greatest(0.1, a / (a + d)));
  won := random() < chance;
  if won then
    if n.shields <= p_strip then
      res := 'capture';
      update war_nodes set owner = p_alliance, shields = _war_capture_shields(tier), garrison = least(p_power, 2000000000)::int,
             animal = null, guard = null
       where league_id = p_league and node = p_node;
      update war_teams set points = points + 20 * tier where league_id = p_league and alliance_id = p_alliance;
      if tier = 4 then perform _al_system(p_alliance, 'war', p_name, 'castle'); end if;
      if n.owner is not null and tier = 4 then perform _al_system(n.owner, 'war', '', 'lost'); end if;
    else
      res := 'win';
      update war_nodes set shields = shields - p_strip where league_id = p_league and node = p_node;
    end if;
    if p_user is not null then
      update war_players set wins = wins + 1 where week_key = _al_week() and user_id = p_user;
    end if;
    if to_regproc('public._al_add_xp') is not null then perform _al_add_xp(p_alliance, case when res = 'capture' then 10 else 3 end); end if;
  else
    res := 'lose';
  end if;
  insert into war_log (league_id, node, alliance_id, name, act) values (p_league, p_node, p_alliance, p_name, res);
  return res;
end $$;

-- Дошедшие отряды и закончившиеся сборы - по порядку прибытия.
create or replace function public._war_resolve(p_league bigint) returns void
language plpgsql security definer set search_path = public as $$
declare x record; res text; n war_nodes; tier int;
begin
  perform pg_advisory_xact_lock(hashtext('war-resolve'), p_league::int);
  for x in select * from (
      select 'm' as src, id, arrive_at as at from war_marches where league_id = p_league and not resolved and arrive_at <= now()
      union all
      select 'r', id, fires_at from war_rallies where league_id = p_league and not resolved and fires_at <= now()) t
    order by at, id loop
    if x.src = 'm' then
      declare mm war_marches;
      begin
        select * into mm from war_marches where id = x.id;
        if mm.kind = 'reinforce' then
          select * into n from war_nodes where league_id = p_league and node = mm.node for update;
          tier := _war_tier(mm.node);
          if n.owner is distinct from mm.alliance_id then
            res := 'lost';
          else
            update war_nodes set shields = least(_war_max_shields(tier), shields + 1),
                   garrison = greatest(garrison, mm.power + mm.animal_power),
                   animal = coalesce(mm.animal, animal), guard = case when mm.animal is not null then mm.name else guard end
             where league_id = p_league and node = mm.node;
            insert into war_log (league_id, node, alliance_id, name, act) values (p_league, mm.node, mm.alliance_id, mm.name, 'reinforce');
            res := 'reinforce';
          end if;
        else
          res := _war_hit(p_league, mm.alliance_id, mm.node, mm.power, mm.name, 1, mm.user_id);
        end if;
        update war_marches set resolved = true, result = res where id = mm.id;
      end;
    else
      declare rr war_rallies;
      begin
        select * into rr from war_rallies where id = x.id;
        res := _war_hit(p_league, rr.alliance_id, rr.node, rr.power, rr.leader_name, 2, null);
        if res in ('win', 'capture') then
          update war_players set wins = wins + 1 where week_key = _al_week()
             and user_id in (select user_id from war_rally_members where rally_id = rr.id);
        end if;
        update war_rallies set resolved = true, result = res where id = rr.id;
      end;
    end if;
  end loop;
end $$;

-- ---------- для игры ----------

-- Карта целиком: то же, что al_war, плюс отряды в пути, сборы, звери в гарнизонах и мои недавние исходы.
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

-- Отправить отряд: атака (p_reinforce = false) или укрепление своей точки (можно со зверем в гарнизон).
create or replace function public.war_march(p_node int, p_reinforce boolean, p_name text, p_animal text, p_animal_power int)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m alliance_members; lg bigint; me war_players; n war_nodes; tier int; pw int; secs int;
        mid bigint; nm text := _rating_clean_name(p_name); ap int := 0; an text := null;
begin
  if uid is null then raise exception 'not signed in'; end if;
  select * into m from alliance_members where user_id = uid;
  if not found then raise exception 'not in alliance'; end if;
  select league_id into lg from war_teams where week_key = _al_week() and alliance_id = m.alliance_id;
  if lg is null or now() >= _war_end(_al_week()) then raise exception 'not allowed'; end if;
  perform 1 from war_leagues where id = lg for update;
  perform _war_settle(lg);
  perform _war_resolve(lg);
  me := _war_me(uid, m.alliance_id);
  if me.used >= _war_attacks(me.pass) then raise exception 'limit'; end if;
  if (select count(*) from war_marches where user_id = uid and not resolved) >= _war_max_marches() then raise exception 'busy'; end if;
  select * into n from war_nodes where league_id = lg and node = p_node;
  if not found then raise exception 'not allowed'; end if;
  tier := _war_tier(p_node);
  pw := greatest(10000, _power_of(uid));
  if p_reinforce then
    if n.owner is distinct from m.alliance_id then raise exception 'not allowed'; end if;
    if n.shields >= _war_max_shields(tier) and coalesce(p_animal, '') = '' then raise exception 'not allowed'; end if;
    if coalesce(p_animal, '') <> '' then
      an := _al_clean(p_animal, 24);
      ap := greatest(0, least(coalesce(p_animal_power, 0), _war_animal_cap()));
    end if;
  else
    if n.owner = m.alliance_id or tier = 4 or not _war_reachable(lg, m.alliance_id, p_node) then raise exception 'not allowed'; end if;
  end if;
  secs := _war_march_secs(tier);
  insert into war_marches (league_id, user_id, alliance_id, name, node, kind, power, animal, animal_power, arrive_at)
  values (lg, uid, m.alliance_id, nm, p_node, case when p_reinforce then 'reinforce' else 'attack' end, pw, an, ap,
          now() + make_interval(secs => secs))
  returning id into mid;
  update war_players set used = used + 1, attacks = attacks + 1 where week_key = me.week_key and user_id = uid;
  return jsonb_build_object('id', mid, 'secs', secs);
end $$;

-- Открыть сбор на замок (или другую чужую точку рядом): 5 минут на сбор, открывший сразу в нём.
create or replace function public.war_rally(p_node int, p_name text)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m alliance_members; lg bigint; me war_players; n war_nodes; pw int; rid bigint;
        nm text := _rating_clean_name(p_name);
begin
  if uid is null then raise exception 'not signed in'; end if;
  select * into m from alliance_members where user_id = uid;
  if not found then raise exception 'not in alliance'; end if;
  select league_id into lg from war_teams where week_key = _al_week() and alliance_id = m.alliance_id;
  if lg is null or now() >= _war_end(_al_week()) - make_interval(secs => _war_rally_secs()) then raise exception 'not allowed'; end if;
  perform 1 from war_leagues where id = lg for update;
  perform _war_resolve(lg);
  me := _war_me(uid, m.alliance_id);
  if me.used >= _war_attacks(me.pass) then raise exception 'limit'; end if;
  if exists (select 1 from war_rallies where league_id = lg and alliance_id = m.alliance_id and not resolved) then
    raise exception 'busy';
  end if;
  select * into n from war_nodes where league_id = lg and node = p_node;
  if not found or n.owner = m.alliance_id or not _war_reachable(lg, m.alliance_id, p_node) then raise exception 'not allowed'; end if;
  pw := greatest(10000, _power_of(uid));
  insert into war_rallies (league_id, alliance_id, node, leader, leader_name, fires_at, power, members)
  values (lg, m.alliance_id, p_node, uid, nm, now() + make_interval(secs => _war_rally_secs()), pw, 1)
  returning id into rid;
  insert into war_rally_members (rally_id, user_id, name, power) values (rid, uid, nm, pw);
  update war_players set used = used + 1, attacks = attacks + 1 where week_key = me.week_key and user_id = uid;
  perform _al_system(m.alliance_id, 'war', nm, 'rally');
  return jsonb_build_object('id', rid, 'secs', _war_rally_secs());
end $$;

-- Присоединиться к сбору своего альянса (тратит атаку, до 30 участников).
create or replace function public.war_rally_join(p_rally bigint, p_name text)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m alliance_members; r war_rallies; me war_players; pw int; nm text := _rating_clean_name(p_name);
begin
  if uid is null then raise exception 'not signed in'; end if;
  select * into m from alliance_members where user_id = uid;
  if not found then raise exception 'not in alliance'; end if;
  select * into r from war_rallies where id = p_rally for update;
  if not found or r.alliance_id <> m.alliance_id or r.resolved or r.fires_at <= now() then raise exception 'not allowed'; end if;
  if r.members >= _war_rally_max() then raise exception 'full'; end if;
  me := _war_me(uid, m.alliance_id);
  if me.used >= _war_attacks(me.pass) then raise exception 'limit'; end if;
  pw := greatest(10000, _power_of(uid));
  insert into war_rally_members (rally_id, user_id, name, power) values (p_rally, uid, nm, pw) on conflict do nothing;
  if not found then raise exception 'not allowed'; end if;
  update war_rallies set power = power + pw, members = members + 1 where id = p_rally;
  update war_players set used = used + 1, attacks = attacks + 1 where week_key = me.week_key and user_id = uid;
  return jsonb_build_object('power', r.power + pw, 'members', r.members + 1);
end $$;

do $$
declare f text;
begin
  foreach f in array array['war_map(text, int)', 'war_march(int, boolean, text, text, int)', 'war_rally(int, text)',
                           'war_rally_join(bigint, text)'] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  foreach f in array array['_war_hit(bigint, bigint, int, numeric, text, int, uuid)', '_war_resolve(bigint)'] loop
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;
