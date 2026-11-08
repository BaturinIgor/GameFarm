-- Ратуша и живой чат альянса Harvest Hollow (Supabase / Postgres).
-- Запуск: Supabase -> SQL Editor -> вставить файл целиком -> Run (после alliances.sql). Повторный запуск безопасен.
--
-- Чат: реакции на сообщения (5 значков), закреплённое сообщение (глава и старейшины), роль автора у сообщения.
-- Ратуша:
--   кто в сети (заходил за последние 15 минут);
--   помощь со стройкой: игрок просит помочь, каждый участник жмёт «Помочь» один раз -
--     стройка просителя короче на 3 минуты (до 10 помощей), помощник получает монеты (до 20 помощей в день);
--   подарки альянсу: покупка в магазине дарит всем остальным участникам сундучок (до 5 подарков в день от игрока);
--   цель дня: все вклады в таланты за день (бесплатные, монеты, кристаллы) против 3 вкладов на участника (до 150);
--     когда цель достигнута, каждый, кто сегодня вкладывал, забирает награду;
--   похвала: раз в день можно похвалить одного участника, в ратуше видно, кого хвалили за неделю.
-- Награды выдаёт игра по ответу сервера. Числа должны совпадать с godot/scripts/data/hall.gd.

alter table public.alliances add column if not exists pin_id bigint;

create table if not exists public.alliance_reacts (
  message_id  bigint      not null references public.alliance_chat (id) on delete cascade,
  user_id     uuid        not null references auth.users (id) on delete cascade,
  kind        text        not null,
  primary key (message_id, user_id)
);

create table if not exists public.alliance_help (
  id          bigint generated always as identity primary key,
  alliance_id bigint      not null references public.alliances (id) on delete cascade,
  user_id     uuid        not null references auth.users (id) on delete cascade,
  name        text        not null,
  target      text        not null,
  need        int         not null default 10,
  got         int         not null default 0,
  created_at  timestamptz not null default now(),
  closed      boolean     not null default false
);
create index if not exists alliance_help_by_alliance on public.alliance_help (alliance_id, created_at desc);

create table if not exists public.alliance_help_by (
  help_id     bigint      not null references public.alliance_help (id) on delete cascade,
  user_id     uuid        not null references auth.users (id) on delete cascade,
  day         int         not null,
  primary key (help_id, user_id)
);
create index if not exists alliance_help_by_user on public.alliance_help_by (user_id, day);

create table if not exists public.alliance_gifts (
  id          bigint generated always as identity primary key,
  alliance_id bigint      not null references public.alliances (id) on delete cascade,
  user_id     uuid        references auth.users (id) on delete set null,
  name        text        not null,
  product     text        not null,
  created_at  timestamptz not null default now()
);
create index if not exists alliance_gifts_by_alliance on public.alliance_gifts (alliance_id, created_at desc);

create table if not exists public.alliance_gift_claims (
  gift_id     bigint      not null references public.alliance_gifts (id) on delete cascade,
  user_id     uuid        not null references auth.users (id) on delete cascade,
  primary key (gift_id, user_id)
);

create table if not exists public.alliance_goal_claims (
  day         int         not null,
  user_id     uuid        not null references auth.users (id) on delete cascade,
  primary key (day, user_id)
);

create table if not exists public.alliance_praise (
  day         int         not null,
  from_user   uuid        not null references auth.users (id) on delete cascade,
  to_user     uuid        not null references auth.users (id) on delete cascade,
  alliance_id bigint      not null references public.alliances (id) on delete cascade,
  primary key (day, from_user)
);
create index if not exists alliance_praise_by_alliance on public.alliance_praise (alliance_id, day);

alter table public.alliance_reacts enable row level security;
alter table public.alliance_help enable row level security;
alter table public.alliance_help_by enable row level security;
alter table public.alliance_gifts enable row level security;
alter table public.alliance_gift_claims enable row level security;
alter table public.alliance_goal_claims enable row level security;
alter table public.alliance_praise enable row level security;
revoke all on public.alliance_reacts, public.alliance_help, public.alliance_help_by, public.alliance_gifts,
  public.alliance_gift_claims, public.alliance_goal_claims, public.alliance_praise from anon, authenticated;

-- ---------- правила (как в hall.gd) ----------

create or replace function public._hall_reacts() returns text[] language sql immutable as $$
  select array['heart', 'fist', 'star', 'clover', 'flame']
$$;
create or replace function public._hall_help_need() returns int language sql immutable as $$ select 10 $$;
create or replace function public._hall_helps_per_day() returns int language sql immutable as $$ select 20 $$;
create or replace function public._hall_gifts_per_day() returns int language sql immutable as $$ select 5 $$;
-- Цель дня: 3 вклада на участника, не больше 150.
create or replace function public._hall_goal(p_members int) returns int language sql immutable as $$
  select least(150, greatest(10, 3 * p_members))
$$;

-- Сколько вкладов альянс сделал сегодня (поля day_* живут в alliance_members).
create or replace function public._hall_goal_done(p_alliance bigint) returns int language sql stable as $$
  select coalesce(sum(day_free + day_coins + day_gems), 0)::int
    from alliance_members where alliance_id = p_alliance and day_key = _al_day()
$$;

-- ---------- чат ----------

-- Новые сообщения (с ролью автора), реакции на последние 60 сообщений, закреп и сколько участников в сети.
create or replace function public.al_chat(p_after bigint)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m record; pin jsonb; low bigint;
begin
  select * into m from alliance_members where user_id = uid;
  if not found then return null; end if;
  update alliance_members set seen_at = now() where user_id = uid;
  select coalesce(min(id), 0) into low from (
    select id from alliance_chat where alliance_id = m.alliance_id order by id desc limit 60) t;
  select jsonb_build_object('id', c.id, 'name', c.name, 'body', c.body) into pin
    from alliances a join alliance_chat c on c.id = a.pin_id and not c.hidden
   where a.id = m.alliance_id;
  return jsonb_build_object(
    'msgs', (select coalesce(jsonb_agg(row_to_json(t) order by t.id), '[]'::jsonb) from (
        select c.id, c.user_id, c.name, c.kind, c.body, extract(epoch from c.created_at)::bigint as at,
               c.user_id = uid as me, coalesce(x.role, '') as role
          from alliance_chat c left join alliance_members x on x.user_id = c.user_id and x.alliance_id = c.alliance_id
         where c.alliance_id = m.alliance_id and c.id > coalesce(p_after, 0) and not c.hidden
           and (c.user_id is null or c.user_id not in (select blocked from alliance_blocks where user_id = uid))
         order by c.id desc limit 50) t),
    'reacts', (select coalesce(jsonb_agg(jsonb_build_object('id', r.message_id, 'kind', r.kind, 'n', r.n, 'mine', r.mine)), '[]'::jsonb) from (
        select x.message_id, x.kind, count(*) as n, bool_or(x.user_id = uid) as mine
          from alliance_reacts x join alliance_chat c on c.id = x.message_id
         where c.alliance_id = m.alliance_id and c.id >= low
         group by x.message_id, x.kind) r),
    'pin', pin,
    'online', (select count(*) from alliance_members where alliance_id = m.alliance_id and seen_at > now() - interval '15 minutes'));
end $$;

-- Реакция на сообщение: одна на игрока, та же ещё раз - снять, пустая - снять.
create or replace function public.al_react(p_message bigint, p_kind text)
returns void
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); c record; old text;
begin
  select * into c from alliance_chat where id = p_message;
  if not found or not exists (select 1 from alliance_members where user_id = uid and alliance_id = c.alliance_id) then
    raise exception 'not in alliance';
  end if;
  select kind into old from alliance_reacts where message_id = p_message and user_id = uid;
  delete from alliance_reacts where message_id = p_message and user_id = uid;
  if coalesce(p_kind, '') = '' or p_kind = old or not (p_kind = any (_hall_reacts())) then return; end if;
  insert into alliance_reacts (message_id, user_id, kind) values (p_message, uid, p_kind);
end $$;

-- Закрепить сообщение (0 - открепить): глава и старейшины.
create or replace function public.al_pin(p_message bigint)
returns void
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m record;
begin
  select * into m from alliance_members where user_id = uid;
  if not found or m.role not in ('leader', 'officer') then raise exception 'not allowed'; end if;
  if coalesce(p_message, 0) <> 0 and not exists (
      select 1 from alliance_chat where id = p_message and alliance_id = m.alliance_id and kind = 'text') then
    raise exception 'not found';
  end if;
  update alliances set pin_id = nullif(p_message, 0) where id = m.alliance_id;
end $$;

-- ---------- ратуша ----------

create or replace function public.al_hall()
returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m record; n int; d int := _al_day();
begin
  select * into m from alliance_members where user_id = uid;
  if not found then return null; end if;
  perform _al_roll(m.alliance_id);
  update alliance_members set seen_at = now() where user_id = uid;
  select * into m from alliance_members where user_id = uid;
  select count(*) into n from alliance_members where alliance_id = m.alliance_id;
  return jsonb_build_object(
    'online', (select coalesce(jsonb_agg(x.user_id), '[]'::jsonb) from alliance_members x
                where x.alliance_id = m.alliance_id and x.seen_at > now() - interval '15 minutes'),
    'help', (select coalesce(jsonb_agg(jsonb_build_object('id', h.id, 'user', h.user_id, 'name', h.name, 'target', h.target,
                'got', h.got, 'need', h.need, 'me', h.user_id = uid,
                'helped', exists (select 1 from alliance_help_by b where b.help_id = h.id and b.user_id = uid),
                'at', extract(epoch from h.created_at)::bigint) order by h.created_at desc), '[]'::jsonb)
               from alliance_help h
              where h.alliance_id = m.alliance_id and not h.closed and h.created_at > now() - interval '12 hours'),
    'helps_today', (select count(*) from alliance_help_by where user_id = uid and day = d),
    'gifts', (select coalesce(jsonb_agg(jsonb_build_object('id', g.id, 'name', g.name, 'product', g.product,
                'at', extract(epoch from g.created_at)::bigint) order by g.id), '[]'::jsonb)
               from alliance_gifts g
              where g.alliance_id = m.alliance_id and g.created_at > now() - interval '3 days'
                and g.created_at > m.joined_at and g.user_id is distinct from uid
                and not exists (select 1 from alliance_gift_claims c where c.gift_id = g.id and c.user_id = uid)),
    'goal', jsonb_build_object('done', _hall_goal_done(m.alliance_id), 'need', _hall_goal(n),
                'mine', case when m.day_key = d then m.day_free + m.day_coins + m.day_gems else 0 end,
                'claimed', exists (select 1 from alliance_goal_claims where day = d and user_id = uid)),
    'praise', jsonb_build_object(
                'given', (select to_user from alliance_praise where day = d and from_user = uid),
                'week', (select coalesce(jsonb_object_agg(t.to_user, t.n), '{}'::jsonb) from (
                    select to_user, count(*) as n from alliance_praise
                     where alliance_id = m.alliance_id and day > d - 7 group by to_user) t)));
end $$;

-- Попросить помощи со стройкой. Одна открытая просьба на игрока; новую - когда старая собрана или ей 12 часов.
create or replace function public.al_help_ask(p_target text, p_player text)
returns bigint
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m record; hid bigint;
begin
  select * into m from alliance_members where user_id = uid;
  if not found then raise exception 'not in alliance'; end if;
  if exists (select 1 from alliance_help where user_id = uid and not closed and got < need
               and created_at > now() - interval '12 hours') then
    raise exception 'already asked';
  end if;
  update alliance_help set closed = true where user_id = uid and not closed;
  insert into alliance_help (alliance_id, user_id, name, target, need)
  values (m.alliance_id, uid, _rating_clean_name(p_player), _al_clean(p_target, 24), _hall_help_need())
  returning id into hid;
  return hid;
end $$;

-- Помочь: +1 к просьбе. Свою нельзя, дважды одну нельзя, не больше 20 помощей в день.
create or replace function public.al_help_give(p_help bigint)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m record; h record; d int := _al_day();
begin
  select * into m from alliance_members where user_id = uid;
  if not found then raise exception 'not in alliance'; end if;
  select * into h from alliance_help where id = p_help for update;
  if not found or h.alliance_id <> m.alliance_id or h.closed or h.got >= h.need then raise exception 'help closed'; end if;
  if h.user_id = uid then raise exception 'own help'; end if;
  if (select count(*) from alliance_help_by where user_id = uid and day = d) >= _hall_helps_per_day() then
    raise exception 'no helps left';
  end if;
  insert into alliance_help_by (help_id, user_id, day) values (p_help, uid, d) on conflict do nothing;
  if not found then raise exception 'already helped'; end if;
  update alliance_help set got = got + 1 where id = p_help;
  return jsonb_build_object('got', h.got + 1, 'helps_today', (select count(*) from alliance_help_by where user_id = uid and day = d));
end $$;

-- Подарок альянсу после покупки (игра зовёт после успешной покупки, не больше 5 в день).
create or replace function public.al_gift_send(p_product text, p_player text)
returns void
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m record;
begin
  select * into m from alliance_members where user_id = uid;
  if not found then return; end if;
  if (select count(*) from alliance_gifts where user_id = uid and created_at > now() - interval '1 day') >= _hall_gifts_per_day() then
    return;
  end if;
  insert into alliance_gifts (alliance_id, user_id, name, product)
  values (m.alliance_id, uid, _rating_clean_name(p_player), _al_clean(p_product, 32));
end $$;

-- Забрать подарок: отвечает, какой товар купили (по нему игра выбирает сундучок).
create or replace function public.al_gift_claim(p_gift bigint)
returns text
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m record; g record;
begin
  select * into m from alliance_members where user_id = uid;
  if not found then raise exception 'not in alliance'; end if;
  select * into g from alliance_gifts where id = p_gift;
  if not found or g.alliance_id <> m.alliance_id or g.user_id is not distinct from uid
     or g.created_at < now() - interval '3 days' or g.created_at <= m.joined_at then
    raise exception 'no gift';
  end if;
  insert into alliance_gift_claims (gift_id, user_id) values (p_gift, uid) on conflict do nothing;
  if not found then raise exception 'already claimed'; end if;
  return g.product;
end $$;

-- Награда цели дня: цель достигнута, я сегодня вкладывал, ещё не забирал.
create or replace function public.al_goal_claim()
returns boolean
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m record; n int; d int := _al_day();
begin
  select * into m from alliance_members where user_id = uid;
  if not found then raise exception 'not in alliance'; end if;
  select count(*) into n from alliance_members where alliance_id = m.alliance_id;
  if _hall_goal_done(m.alliance_id) < _hall_goal(n) then raise exception 'goal not done'; end if;
  if m.day_key <> d or m.day_free + m.day_coins + m.day_gems < 1 then raise exception 'no contribution'; end if;
  insert into alliance_goal_claims (day, user_id) values (d, uid) on conflict do nothing;
  return found;
end $$;

-- Похвалить участника (раз в день, не себя).
create or replace function public.al_praise(p_user uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m record;
begin
  select * into m from alliance_members where user_id = uid;
  if not found then raise exception 'not in alliance'; end if;
  if p_user = uid or not exists (select 1 from alliance_members where user_id = p_user and alliance_id = m.alliance_id) then
    raise exception 'bad user';
  end if;
  insert into alliance_praise (day, from_user, to_user, alliance_id) values (_al_day(), uid, p_user, m.alliance_id)
  on conflict do nothing;
  if not found then raise exception 'already praised'; end if;
end $$;

-- Чистка (зовёт hh_cleanup из cleanup.sql): просьбы старше 3 дней, подарки старше 7, похвалы и награды цели старше 14.
create or replace function public.al_hall_cleanup() returns void
language plpgsql security definer set search_path = public as $$
begin
  delete from alliance_help where created_at < now() - interval '3 days';
  delete from alliance_gifts where created_at < now() - interval '7 days';
  delete from alliance_praise where day < _al_day() - 14;
  delete from alliance_goal_claims where day < _al_day() - 14;
end $$;

do $$
declare f text;
begin
  foreach f in array array[
    'al_chat(bigint)', 'al_react(bigint, text)', 'al_pin(bigint)', 'al_hall()', 'al_help_ask(text, text)',
    'al_help_give(bigint)', 'al_gift_send(text, text)', 'al_gift_claim(bigint)', 'al_goal_claim()', 'al_praise(uuid)'
  ] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  foreach f in array array['_hall_goal_done(bigint)', 'al_hall_cleanup()'] loop
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;
