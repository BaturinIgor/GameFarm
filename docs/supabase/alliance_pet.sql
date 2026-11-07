-- Хранитель альянса Harvest Hollow: общий зверь, которого кормит весь альянс.
-- Запуск: Supabase -> SQL Editor -> вставить файл целиком -> Run (после alliance_events.sql). Повторный запуск безопасен.
--
-- Каждый день Хранитель хочет 3 угощения: простое, среднее и редкое (по номеру дня, как AlliancePet.cravings).
-- Участник даёт до 10 порций в день; порция простого - 1 опыт Хранителю, среднего - 2, редкого - 3.
-- Сами продукты списывает игра (размер порции растёт с уровнем героя), сервер считает порции и опыт.
-- Опыт Хранителя идёт и в опыт альянса. 10 стадий роста, каждая даёт бонус всем участникам (считает игра).
-- Вид Хранителя выбирает глава, пока его ещё никто не кормил.

create table if not exists public.alliance_pets (
  alliance_id bigint      primary key references public.alliances (id) on delete cascade,
  kind        text        not null default 'phoenixChick',
  xp          bigint      not null default 0,
  updated_at  timestamptz not null default now()
);
create table if not exists public.alliance_pet_feeds (
  user_id  uuid   primary key references auth.users (id) on delete cascade,
  day_key  int    not null default 0,
  portions int    not null default 0,
  total    bigint not null default 0
);
alter table public.alliance_pets enable row level security;
alter table public.alliance_pet_feeds enable row level security;
revoke all on public.alliance_pets, public.alliance_pet_feeds from anon, authenticated;

-- Стадия по опыту: 1..10 (как AlliancePet.STAGES).
create or replace function public._al_pet_stage(p_xp bigint) returns int language sql immutable as $$
  select 1 + count(*)::int from unnest(array[200, 700, 1600, 3000, 5000, 8000, 12500, 19000, 28000]) t where p_xp >= t
$$;

-- Угощения дня: [простое, среднее, редкое].
create or replace function public._al_pet_cravings(p_day int) returns text[] language sql immutable as $$
  select array[
    (array['wheat', 'carrots', 'egg', 'milk'])[1 + p_day % 4],
    (array['tomato', 'potato', 'strawberry', 'wool'])[1 + (p_day / 2) % 4],
    (array['corn', 'cabbage', 'honey', 'eggplant'])[1 + (p_day / 3) % 4]]
$$;

create or replace function public._al_pet_row(p_alliance bigint) returns alliance_pets
language plpgsql security definer set search_path = public as $$
declare p alliance_pets;
begin
  insert into alliance_pets (alliance_id) values (p_alliance) on conflict do nothing;
  select * into p from alliance_pets where alliance_id = p_alliance;
  return p;
end $$;

-- Хранитель моего альянса: вид, опыт, стадия, угощения дня, сколько порций я дал сегодня, конец дня.
create or replace function public.al_pet()
returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m record; p alliance_pets; f record; d int := _al_day();
begin
  if uid is null then raise exception 'not signed in'; end if;
  select * into m from alliance_members where user_id = uid;
  if not found then return null; end if;
  p := _al_pet_row(m.alliance_id);
  select * into f from alliance_pet_feeds where user_id = uid;
  return jsonb_build_object('kind', p.kind, 'xp', p.xp, 'stage', _al_pet_stage(p.xp), 'day', d,
    'cravings', to_jsonb(_al_pet_cravings(d)),
    'fed', case when f.day_key = d then f.portions else 0 end,
    'total', coalesce(f.total, 0),
    'ends', (d + 1) * 86400,
    'top', (select coalesce(jsonb_agg(jsonb_build_object('name', x.name, 'total', x.total) order by x.total desc), '[]'::jsonb)
              from (select am.name, pf.total from alliance_members am join alliance_pet_feeds pf on pf.user_id = am.user_id
                     where am.alliance_id = m.alliance_id and pf.total > 0 order by pf.total desc limit 3) x));
end $$;

-- Покормить: p_slot - какое угощение (0 простое, 1 среднее, 2 редкое), p_count порций. Возвращает новый опыт и стадию.
create or replace function public.al_pet_feed(p_slot int, p_count int)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m record; p alliance_pets; d int := _al_day(); fed int; n int; gain int; stage_before int;
begin
  if uid is null then raise exception 'not signed in'; end if;
  if p_slot not between 0 and 2 then raise exception 'bad slot'; end if;
  select * into m from alliance_members where user_id = uid;
  if not found then raise exception 'not in alliance'; end if;
  p := _al_pet_row(m.alliance_id);
  insert into alliance_pet_feeds (user_id, day_key) values (uid, d) on conflict do nothing;
  select case when day_key = d then portions else 0 end into fed from alliance_pet_feeds where user_id = uid for update;
  n := least(greatest(p_count, 0), 10 - fed);
  if n <= 0 then raise exception 'limit'; end if;
  gain := n * (p_slot + 1);
  update alliance_pet_feeds set day_key = d, portions = fed + n, total = total + gain where user_id = uid;
  select * into p from alliance_pets where alliance_id = m.alliance_id for update;
  stage_before := _al_pet_stage(p.xp);
  update alliance_pets set xp = xp + gain, updated_at = now() where alliance_id = m.alliance_id;
  if _al_pet_stage(p.xp + gain) > stage_before then
    perform _al_system(m.alliance_id, 'pet', '', _al_pet_stage(p.xp + gain)::text);
  end if;
  perform _al_add_xp(m.alliance_id, gain);
  update alliance_members set total = total + gain, week = week + gain, seen_at = now() where user_id = uid;
  return jsonb_build_object('xp', p.xp + gain, 'stage', _al_pet_stage(p.xp + gain), 'fed', fed + n, 'gain', gain);
end $$;

-- Вид Хранителя: выбирает глава, пока Хранителя ещё не кормили.
create or replace function public.al_pet_kind(p_kind text)
returns void
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m record; p alliance_pets;
begin
  if uid is null then raise exception 'not signed in'; end if;
  if p_kind not in ('phoenixChick', 'pegasus', 'moonUnicorn', 'goldenGoose') then raise exception 'bad kind'; end if;
  select * into m from alliance_members where user_id = uid;
  if not found or m.role <> 'leader' then raise exception 'not leader'; end if;
  p := _al_pet_row(m.alliance_id);
  if p.xp > 0 then raise exception 'pet fed'; end if;
  update alliance_pets set kind = p_kind where alliance_id = m.alliance_id;
end $$;

revoke all on function public.al_pet() from public, anon;
revoke all on function public.al_pet_feed(int, int) from public, anon;
revoke all on function public.al_pet_kind(text) from public, anon;
revoke all on function public._al_pet_row(bigint) from public, anon, authenticated;
grant execute on function public.al_pet() to authenticated;
grant execute on function public.al_pet_feed(int, int) to authenticated;
grant execute on function public.al_pet_kind(text) to authenticated;
