-- Ярмарка альянса Harvest Hollow: участники выставляют товары со склада, другие покупают их за монеты.
-- Запуск: Supabase -> SQL Editor -> вставить файл целиком -> Run (после alliances.sql). Повторный запуск безопасен.
--
-- Лот - один ресурс, количество и цена в монетах за весь лот. Ресурсы и монеты списывает и выдаёт игра:
-- сервер помнит лоты, покупателя и что продавец уже забрал. Прилавок живёт неделю: что не продано,
-- возвращается продавцу. Прилавков у игрока 1, второй - за кристаллы (p_slots, не больше 2).
-- Лучший продавец недели - тот, кто выручил больше всех монет. Числа как в godot/scripts/data/alliance_fair.gd.

create table if not exists public.alliance_fair_lots (
  id          bigserial   primary key,
  alliance_id bigint      not null references public.alliances (id) on delete cascade,
  seller      uuid        not null references auth.users (id) on delete cascade,
  seller_name text        not null,
  kind        text        not null,
  qty         int         not null,
  price       int         not null,
  week_key    int         not null,
  buyer       uuid,
  buyer_name  text,
  sold_at     timestamptz,
  collected   boolean     not null default false,
  created_at  timestamptz not null default now()
);
create index if not exists alliance_fair_lots_alliance on public.alliance_fair_lots (alliance_id, week_key);
create index if not exists alliance_fair_lots_seller on public.alliance_fair_lots (seller) where not collected;
alter table public.alliance_fair_lots enable row level security;
revoke all on public.alliance_fair_lots from anon, authenticated;

-- Ярмарка моего альянса: лоты недели, мои лоты, лучшие продавцы этой недели и лучший прошлой.
create or replace function public.al_fair()
returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m record; wk int := _al_week();
begin
  if uid is null then raise exception 'not signed in'; end if;
  select * into m from alliance_members where user_id = uid;
  if not found then return null; end if;
  return jsonb_build_object(
    'lots', (select coalesce(jsonb_agg(jsonb_build_object('id', id, 'seller', seller_name, 'kind', kind, 'qty', qty,
                      'price', price) order by created_at desc), '[]'::jsonb)
               from alliance_fair_lots
              where alliance_id = m.alliance_id and week_key = wk and buyer is null and not collected and seller <> uid),
    'mine', (select coalesce(jsonb_agg(jsonb_build_object('id', id, 'kind', kind, 'qty', qty, 'price', price,
                      'buyer', buyer_name, 'old', week_key < wk) order by created_at), '[]'::jsonb)
               from alliance_fair_lots where seller = uid and not collected),
    'top', (select coalesce(jsonb_agg(jsonb_build_object('name', seller_name, 'coins', coins, 'sold', n,
                      'me', seller = uid) order by coins desc), '[]'::jsonb)
              from (select seller, max(seller_name) as seller_name, sum(price) as coins, count(*) as n
                      from alliance_fair_lots
                     where alliance_id = m.alliance_id and week_key = wk and buyer is not null
                     group by seller order by 3 desc limit 5) t),
    'best', (select seller_name from alliance_fair_lots
              where alliance_id = m.alliance_id and week_key = wk - 1 and buyer is not null
              group by seller, seller_name order by sum(price) desc limit 1));
end $$;

-- Выставить лот (ресурсы уже сняты со склада игрой).
create or replace function public.al_fair_list(p_kind text, p_qty int, p_price int, p_slots int, p_player text)
returns bigint
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m record; n int; new_id bigint;
begin
  if uid is null then raise exception 'not signed in'; end if;
  select * into m from alliance_members where user_id = uid;
  if not found then raise exception 'not in alliance'; end if;
  if p_kind !~ '^[A-Za-z_]{1,24}$' or p_qty < 1 or p_qty > 500 or p_price < 1 or p_price > 1000000 then
    raise exception 'bad lot';
  end if;
  select count(*) into n from alliance_fair_lots
   where seller = uid and week_key = _al_week() and buyer is null and not collected;
  if n >= least(greatest(p_slots, 1), 2) then raise exception 'full'; end if;
  insert into alliance_fair_lots (alliance_id, seller, seller_name, kind, qty, price, week_key)
  values (m.alliance_id, uid, _rating_clean_name(p_player), p_kind, p_qty, p_price, _al_week())
  returning id into new_id;
  return new_id;
end $$;

-- Купить лот (монеты списывает игра после ответа). Возвращает товар.
create or replace function public.al_fair_buy(p_id bigint, p_player text)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m record; x alliance_fair_lots;
begin
  if uid is null then raise exception 'not signed in'; end if;
  select * into m from alliance_members where user_id = uid;
  if not found then raise exception 'not in alliance'; end if;
  select * into x from alliance_fair_lots where id = p_id for update;
  if not found or x.alliance_id <> m.alliance_id or x.seller = uid then raise exception 'not allowed'; end if;
  if x.buyer is not null or x.collected or x.week_key <> _al_week() then raise exception 'sold'; end if;
  update alliance_fair_lots set buyer = uid, buyer_name = _rating_clean_name(p_player), sold_at = now() where id = p_id;
  return jsonb_build_object('kind', x.kind, 'qty', x.qty, 'price', x.price);
end $$;

-- Снять свой непроданный лот этой недели. Возвращает товар.
create or replace function public.al_fair_cancel(p_id bigint)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); x alliance_fair_lots;
begin
  if uid is null then raise exception 'not signed in'; end if;
  select * into x from alliance_fair_lots where id = p_id and seller = uid for update;
  if not found or x.collected then raise exception 'not allowed'; end if;
  if x.buyer is not null then raise exception 'sold'; end if;
  update alliance_fair_lots set collected = true where id = p_id;
  return jsonb_build_object('kind', x.kind, 'qty', x.qty);
end $$;

-- Забрать выручку за проданные лоты и товар с прошлых недель, который не купили.
create or replace function public.al_fair_collect()
returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); coins bigint; items jsonb;
begin
  if uid is null then raise exception 'not signed in'; end if;
  select coalesce(sum(price), 0) into coins from alliance_fair_lots where seller = uid and not collected and buyer is not null;
  select coalesce(jsonb_agg(jsonb_build_object('kind', kind, 'qty', qty)), '[]'::jsonb) into items
    from alliance_fair_lots where seller = uid and not collected and buyer is null and week_key < _al_week();
  update alliance_fair_lots set collected = true
   where seller = uid and not collected and (buyer is not null or week_key < _al_week());
  return jsonb_build_object('coins', coins, 'items', items);
end $$;

-- Чистка: забранные лоты старше 4 недель.
create or replace function public.al_fair_cleanup() returns void
language sql security definer set search_path = public as $$
  delete from alliance_fair_lots where collected and week_key < _al_week() - 4
$$;

revoke all on function public.al_fair() from public, anon;
revoke all on function public.al_fair_list(text, int, int, int, text) from public, anon;
revoke all on function public.al_fair_buy(bigint, text) from public, anon;
revoke all on function public.al_fair_cancel(bigint) from public, anon;
revoke all on function public.al_fair_collect() from public, anon;
revoke all on function public.al_fair_cleanup() from public, anon, authenticated;
grant execute on function public.al_fair() to authenticated;
grant execute on function public.al_fair_list(text, int, int, int, text) to authenticated;
grant execute on function public.al_fair_buy(bigint, text) to authenticated;
grant execute on function public.al_fair_cancel(bigint) to authenticated;
grant execute on function public.al_fair_collect() to authenticated;
