-- Донат в войне альянсов: доп. атаки за кристаллы (до 3 в день), атаки из «Военного сундука»
-- и флаг альянса на карте (узор выбирает глава). Кристаллы и покупку списывает игра, как везде.
-- Запуск: Supabase -> SQL Editor -> вставить файл целиком -> Run (после alliance_war_leagues.sql). Повторный запуск безопасен.
-- Числа как в godot/scripts/data/war.gd (BUY_ATTACKS, CHEST_ATTACKS, FLAGS).

alter table public.war_players add column if not exists bought int not null default 0;
alter table public.alliances add column if not exists flag int not null default 0;

-- Моя строка войны на эту неделю: в новый день сбрасываются атаки, вклады и купленные атаки.
create or replace function public._war_me(p_user uuid, p_alliance bigint) returns war_players
language plpgsql security definer set search_path = public as $$
declare wk int := _al_week(); d int := _al_day(); r war_players;
begin
  insert into war_players (week_key, user_id, alliance_id, day_key) values (wk, p_user, p_alliance, d) on conflict do nothing;
  update war_players set used = 0, donates = 0, bought = 0, day_key = d where week_key = wk and user_id = p_user and day_key <> d;
  update war_players set alliance_id = p_alliance where week_key = wk and user_id = p_user and alliance_id is distinct from p_alliance;
  select * into r from war_players where week_key = wk and user_id = p_user;
  return r;
end $$;

-- Ещё атаки на сегодня: p_kind = crystals (одна, до 3 в день) или chest (5 из «Военного сундука»).
create or replace function public.war_buy_attack(p_kind text)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m alliance_members; me war_players; n int;
begin
  if uid is null then raise exception 'not signed in'; end if;
  select * into m from alliance_members where user_id = uid;
  if not found then raise exception 'not in alliance'; end if;
  perform _war_join(m.alliance_id);
  me := _war_me(uid, m.alliance_id);
  if p_kind = 'crystals' then
    if me.bought >= 3 then raise exception 'limit'; end if;
    n := 1;
  elsif p_kind = 'chest' then
    n := 5;
  else
    raise exception 'not allowed';
  end if;
  update war_players set used = used - n, bought = bought + case when p_kind = 'crystals' then 1 else 0 end
   where week_key = me.week_key and user_id = uid;
  return jsonb_build_object('used', me.used - n, 'bought', me.bought + case when p_kind = 'crystals' then 1 else 0 end);
end $$;

-- Глава: узор флага альянса на карте войны (0..5).
create or replace function public.al_set_flag(p_flag int)
returns void
language plpgsql security definer set search_path = public as $$
declare me alliance_members;
begin
  select * into me from alliance_members where user_id = auth.uid();
  if not found or me.role <> 'leader' then raise exception 'not allowed'; end if;
  update alliances set flag = greatest(0, least(coalesce(p_flag, 0), 5)) where id = me.alliance_id;
end $$;

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
    'flags', (select coalesce(jsonb_object_agg(t.slot::text, a.flag), '{}'::jsonb)
                from war_teams t join alliances a on a.id = t.alliance_id where t.league_id = lg),
    'bought', (select bought from war_players where week_key = _al_week() and user_id = uid),
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


do $$
declare f text;
begin
  foreach f in array array['war_buy_attack(text)', 'al_set_flag(int)', 'war_map(text, int)'] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  execute 'revoke all on function public._war_me(uuid, bigint) from public, anon, authenticated';
end $$;
