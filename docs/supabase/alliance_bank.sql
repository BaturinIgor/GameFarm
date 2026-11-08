-- Банк альянса. Каждый вклад (бесплатный, монетами, кристаллами) идёт в общий банк (1 очко), а игрок получает
-- личные монеты альянса (медали): 1, за кристаллы 3, плюс 10% за уровень Сокровищницы.
-- Глава и офицеры тратят банк: ранги талантов (сколько очков не хватает до ранга) и постройки альянса.
-- Медали игрок тратит в магазине альянса (лимит на неделю; товар выдаёт игра).
-- Журнал банка: кто и на что потратил.
-- Числа как в godot/scripts/data/alliances.gd (BUILDINGS, BUILD_COSTS, SHOP).
-- Запуск: Supabase -> SQL Editor -> вставить файл целиком -> Run (после alliance_war_raiders.sql). Повторный запуск безопасен.

alter table public.alliances add column if not exists bank bigint not null default 0;
alter table public.alliances add column if not exists buildings jsonb not null default '{}'::jsonb;
alter table public.alliance_members add column if not exists medals bigint not null default 0;

create table if not exists public.alliance_bank_log (
  id          bigint generated always as identity primary key,
  alliance_id bigint not null references public.alliances (id) on delete cascade,
  name        text   not null,
  kind        text   not null,   -- talent, build
  what        text   not null,
  lvl         int    not null,
  cost        bigint not null,
  created_at  timestamptz not null default now()
);
create index if not exists alliance_bank_log_by on public.alliance_bank_log (alliance_id, id desc);

create table if not exists public.alliance_shop_buys (
  user_id  uuid not null references auth.users (id) on delete cascade,
  week_key int  not null,
  item     text not null,
  n        int  not null default 0,
  primary key (user_id, week_key, item)
);

alter table public.alliance_bank_log enable row level security;
alter table public.alliance_shop_buys enable row level security;
revoke all on public.alliance_bank_log, public.alliance_shop_buys from anon, authenticated;

-- Постройки: до 5 уровней. Цена уровня L (в очках банка).
create or replace function public._al_build_max() returns int language sql immutable as $$ select 5 $$;
create or replace function public._al_build_cost(p_level int) returns int language sql immutable as $$
  select (array[600, 1500, 3000, 5000, 8000])[greatest(1, least(5, p_level))]
$$;
create or replace function public._al_build(p_alliance bigint, p_id text) returns int language sql stable as $$
  select coalesce((buildings ->> p_id)::int, 0) from alliances where id = p_alliance
$$;

-- Магазин: цена в медалях и сколько можно купить за неделю.
create or replace function public._al_shop_price(p_item text) returns int language sql immutable as $$
  select case p_item when 'keyCopper' then 20 when 'keySilver' then 60 when 'keyStar' then 200
                     when 'eggBlue' then 80 when 'eggPurple' then 250 when 'energy' then 15 else null end
$$;
create or replace function public._al_shop_limit(p_item text) returns int language sql immutable as $$
  select case p_item when 'keyCopper' then 5 when 'keySilver' then 3 when 'keyStar' then 1
                     when 'eggBlue' then 2 when 'eggPurple' then 1 when 'energy' then 5 else 0 end
$$;

-- Вклад в банк. Возвращает {bank, medals}.
create or replace function public.al_give(p_kind text, p_player text, p_level int)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m record; a record; d int := _al_day(); md int;
begin
  if uid is null then raise exception 'not signed in'; end if;
  select * into m from alliance_members where user_id = uid for update;
  if not found then raise exception 'not in alliance'; end if;
  perform _al_roll(m.alliance_id);
  select * into a from alliances where id = m.alliance_id for update;
  if m.day_key <> d then
    update alliance_members set day_key = d, day_free = 0, day_coins = 0, day_gems = 0 where user_id = uid;
    select * into m from alliance_members where user_id = uid;
  end if;
  if p_kind = 'free' then
    if m.day_free >= 20 then raise exception 'limit'; end if;
    update alliance_members set day_free = day_free + 1 where user_id = uid;
  elsif p_kind = 'coins' then
    if m.day_coins >= 20 then raise exception 'limit'; end if;
    update alliance_members set day_coins = day_coins + 1 where user_id = uid;
  elsif p_kind = 'gems' then
    if m.day_gems >= 1000 then raise exception 'limit'; end if;
    update alliance_members set day_gems = day_gems + 1 where user_id = uid;
  else
    raise exception 'bad kind';
  end if;
  md := round((case when p_kind = 'gems' then 3 else 1 end) * (1 + 0.1 * coalesce((a.buildings ->> 'treasury')::int, 0)));
  update alliance_members set total = total + 1, week = week + 1, medals = medals + md, name = _rating_clean_name(p_player),
         level = greatest(1, least(p_level, 200)), seen_at = now()
   where user_id = uid;
  update alliances set xp = xp + 1, week_xp = week_xp + 1, bank = bank + 1 where id = a.id;
  if _al_level(a.xp + 1) > _al_level(a.xp) then
    perform _al_system(a.id, 'level', '', _al_level(a.xp + 1)::text);
  end if;
  return jsonb_build_object('bank', a.bank + 1, 'medals', m.medals + md);
end $$;

-- Глава или офицер покупает следующий ранг таланта за банк. Возвращает очки таланта.
create or replace function public.al_bank_talent(p_talent text, p_player text)
returns int
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m record; a record; pts int; rk int; need int; cost int;
begin
  select * into m from alliance_members where user_id = uid;
  if not found then raise exception 'not in alliance'; end if;
  if m.role not in ('leader', 'officer') then raise exception 'not allowed'; end if;
  select * into a from alliances where id = m.alliance_id for update;
  if _al_talent_level(p_talent) is null or _al_level(a.xp) < _al_talent_level(p_talent) then raise exception 'talent locked'; end if;
  pts := coalesce((a.talents ->> p_talent)::int, 0);
  rk := _al_rank(p_talent, pts);
  if rk >= 15 then raise exception 'talent maxed'; end if;
  need := _al_talent_points(p_talent, rk + 1);
  cost := need - pts;
  if a.bank < cost then raise exception 'bank'; end if;
  update alliances set bank = bank - cost, talents = jsonb_set(talents, array[p_talent], to_jsonb(need)) where id = a.id;
  insert into alliance_bank_log (alliance_id, name, kind, what, lvl, cost)
    values (a.id, _rating_clean_name(p_player), 'talent', p_talent, rk + 1, cost);
  perform _al_system(a.id, 'bank', _rating_clean_name(p_player), 'talent:' || p_talent || ':' || (rk + 1));
  return need;
end $$;

-- Глава или офицер строит следующий уровень постройки. Возвращает уровень.
create or replace function public.al_bank_build(p_id text, p_player text)
returns int
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m record; a record; lv int; cost int;
begin
  if p_id not in ('barracks', 'walls', 'treasury', 'granary') then raise exception 'bad kind'; end if;
  select * into m from alliance_members where user_id = uid;
  if not found then raise exception 'not in alliance'; end if;
  if m.role not in ('leader', 'officer') then raise exception 'not allowed'; end if;
  select * into a from alliances where id = m.alliance_id for update;
  lv := coalesce((a.buildings ->> p_id)::int, 0);
  if lv >= _al_build_max() then raise exception 'talent maxed'; end if;
  cost := _al_build_cost(lv + 1);
  if a.bank < cost then raise exception 'bank'; end if;
  update alliances set bank = bank - cost, buildings = jsonb_set(buildings, array[p_id], to_jsonb(lv + 1)) where id = a.id;
  insert into alliance_bank_log (alliance_id, name, kind, what, lvl, cost)
    values (a.id, _rating_clean_name(p_player), 'build', p_id, lv + 1, cost);
  perform _al_system(a.id, 'bank', _rating_clean_name(p_player), 'build:' || p_id || ':' || (lv + 1));
  return lv + 1;
end $$;

-- Покупка в магазине альянса за медали. Возвращает остаток медалей.
create or replace function public.al_shop_buy(p_item text)
returns bigint
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m record; price int := _al_shop_price(p_item); wk int := _al_week(); got int;
begin
  if price is null then raise exception 'bad kind'; end if;
  select * into m from alliance_members where user_id = uid for update;
  if not found then raise exception 'not in alliance'; end if;
  select coalesce((select n from alliance_shop_buys where user_id = uid and week_key = wk and item = p_item), 0) into got;
  if got >= _al_shop_limit(p_item) then raise exception 'limit'; end if;
  if m.medals < price then raise exception 'medals'; end if;
  update alliance_members set medals = medals - price where user_id = uid;
  insert into alliance_shop_buys (user_id, week_key, item, n) values (uid, wk, p_item, 1)
    on conflict (user_id, week_key, item) do update set n = alliance_shop_buys.n + 1;
  return m.medals - price;
end $$;

-- Банк: сумма, постройки, мои медали и покупки за неделю, журнал трат (20 последних).
create or replace function public.al_bank()
returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m record; a record;
begin
  select * into m from alliance_members where user_id = uid;
  if not found then return null; end if;
  select * into a from alliances where id = m.alliance_id;
  return jsonb_build_object('bank', a.bank, 'buildings', a.buildings, 'medals', m.medals,
    'buys', (select coalesce(jsonb_object_agg(item, n), '{}'::jsonb) from alliance_shop_buys where user_id = uid and week_key = _al_week()),
    'log', (select coalesce(jsonb_agg(jsonb_build_object('name', l.name, 'kind', l.kind, 'what', l.what, 'lvl', l.lvl, 'cost', l.cost,
                    'at', extract(epoch from l.created_at)::bigint) order by l.id desc), '[]'::jsonb)
              from (select * from alliance_bank_log where alliance_id = a.id order by id desc limit 20) l),
    'top', (select coalesce(jsonb_agg(jsonb_build_object('name', x.name, 'week', x.week) order by x.week desc), '[]'::jsonb)
              from (select name, week from alliance_members where alliance_id = a.id and week_key = _al_week() and week > 0
                     order by week desc limit 5) x));
end $$;

-- Война: Казарма +4% к удару за уровень (как alliance_war_march.sql, плюс казарма).
create or replace function public._war_hit(p_league bigint, p_alliance bigint, p_node int, p_power numeric, p_name text,
  p_strip int, p_user uuid) returns text
language plpgsql security definer set search_path = public as $$
declare n war_nodes; tm war_teams; tier int := _war_tier(p_node); a numeric; d int; chance numeric; won boolean; res text;
begin
  select * into n from war_nodes where league_id = p_league and node = p_node for update;
  if not found or n.owner = p_alliance then return 'void'; end if;
  if not _war_reachable(p_league, p_alliance, p_node) then return 'cut'; end if;
  select * into tm from war_teams where league_id = p_league and alliance_id = p_alliance;
  a := p_power * (1 + _war_boost(tm.chest) + 0.04 * _al_build(p_alliance, 'barracks'));
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

-- Гарнизон: как в alliance_war_leagues.sql, плюс Стены владельца +8% за уровень.
create or replace function public._war_garrison(p_league bigint, p_node int) returns int
language sql stable security definer set search_path = public as $$
  select case when n.owner is null
              then round(_war_camp_power(_war_level(p_node)) * _war_tier_mult((select tier from war_leagues where id = p_league)))::int
              else round(greatest(10000, n.garrison) * (1 + 0.08 * _al_build(n.owner, 'walls')))::int end
    from war_nodes n where n.league_id = p_league and n.node = p_node
$$;

do $$
declare f text;
begin
  foreach f in array array['al_give(text, text, int)', 'al_bank_talent(text, text)', 'al_bank_build(text, text)',
                           'al_shop_buy(text)', 'al_bank()'] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  foreach f in array array['_al_build(bigint, text)', '_war_hit(bigint, bigint, int, numeric, text, int, uuid)',
                           '_war_garrison(bigint, int)'] loop
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;
