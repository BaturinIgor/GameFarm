-- Живые бои за клетки карты войны: у каждой клетки уровень 1-5, на ничьей стоит лагерь монстров
-- своей силы, чужую клетку берут штурмом базы. Бой игрок ведёт сам (цели, умения, щит от тяжёлых ударов),
-- игра присылает оценку тактики 0..1 - она добавляет до +25% к силе удара. Исход решает сервер.
-- Отряд разбит или отступил - игра присылает -1: атака потрачена, поражение без броска.
-- Запуск: Supabase -> SQL Editor -> вставить файл целиком -> Run (после alliance_war_march.sql). Повторный запуск безопасен.
-- Числа как в godot/scripts/data/war.gd (level, CAMP_POWER, TACTIC_MAX).

-- Уровень клетки: 1 - у своей базы, 2 - между двумя базами, 3 и 4 - кольца к центру, 5 - замок; у баз 0.
create or replace function public._war_level(p_node int) returns int language sql immutable as $$
  select case when p_node = 0 then 5
              when p_node between 1 and 8 then 0
              when p_node between 9 and 16 then 1
              when p_node between 17 and 24 then 2
              when p_node between 25 and 32 then 3
              when p_node between 33 and 40 then 4
              else 0 end
$$;

-- Сила лагеря монстров на ничьей клетке.
create or replace function public._war_camp_power(p_level int) returns int language sql immutable as $$
  select case p_level when 1 then 100000 when 2 then 250000 when 3 then 500000 when 4 then 1000000 when 5 then 3000000 else 100000 end
$$;

-- Гарнизон: у ничьей клетки - лагерь по уровню, у чужой - сила того, кто её держит (и зверя в гарнизоне).
create or replace function public._war_garrison(p_league bigint, p_node int) returns int
language sql stable security definer set search_path = public as $$
  select case when n.owner is null then _war_camp_power(_war_level(p_node))
              else greatest(10000, n.garrison) end
    from war_nodes n where n.league_id = p_league and n.node = p_node
$$;

-- Бой за клетку: сразу, без похода. p_tactic 0..1 - тактика боя, -1 - отряд разбит.
create or replace function public.war_battle(p_node int, p_name text, p_tactic numeric)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m alliance_members; lg bigint; me war_players; n war_nodes; pw numeric; res text;
        nm text := _rating_clean_name(p_name); t numeric := coalesce(p_tactic, 0);
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
  select * into n from war_nodes where league_id = lg and node = p_node;
  if not found or p_node = 0 or n.owner = m.alliance_id or not _war_reachable(lg, m.alliance_id, p_node) then
    raise exception 'not allowed';
  end if;
  update war_players set used = used + 1, attacks = attacks + 1 where week_key = me.week_key and user_id = uid;
  if t < 0 then
    insert into war_log (league_id, node, alliance_id, name, act) values (lg, p_node, m.alliance_id, nm, 'lose');
    return jsonb_build_object('result', 'lose', 'retreat', true);
  end if;
  pw := greatest(10000, _power_of(uid)) * (1 + 0.25 * least(1, t));
  res := _war_hit(lg, m.alliance_id, p_node, pw, nm, 1, uid);
  return jsonb_build_object('result', res,
    'shields', (select shields from war_nodes where league_id = lg and node = p_node));
end $$;

revoke all on function public.war_battle(int, text, numeric) from public, anon;
grant execute on function public.war_battle(int, text, numeric) to authenticated;
revoke all on function public._war_garrison(bigint, int) from public, anon, authenticated;
