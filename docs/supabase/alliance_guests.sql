-- Звери в гости (альянс Harvest Hollow): участник отправляет своего зверя к другу из альянса на сутки.
-- Запуск: Supabase -> SQL Editor -> вставить файл целиком -> Run (после alliances.sql). Повторный запуск безопасен.
--
-- Пока зверь гостит, хозяин дома получает бонус к добыче (считает игра по списку гостей).
-- Через сутки зверь возвращается, хозяин зверя забирает подарок (выдаёт игра по ответу al_guest_claim).
-- Мест для отправки: 1, второе покупается за кристаллы (игра присылает p_slots, сервер не даёт больше 2).
-- Один дом принимает не больше 3 гостей сразу. Каждый вернувшийся гость - визит дружбы между двумя игроками.
-- Числа должны совпадать с godot/scripts/data/guests.gd.

create table if not exists public.alliance_guests (
  id          bigint generated always as identity primary key,
  alliance_id bigint      not null references public.alliances (id) on delete cascade,
  owner       uuid        not null references auth.users (id) on delete cascade,
  owner_name  text        not null,
  host        uuid        not null references auth.users (id) on delete cascade,
  host_name   text        not null,
  animal      text        not null,
  stars       int         not null default 1,
  sent_at     bigint      not null,
  returns_at  bigint      not null,
  claimed     boolean     not null default false
);
create index if not exists alliance_guests_owner on public.alliance_guests (owner, claimed);
create index if not exists alliance_guests_host on public.alliance_guests (host, returns_at);
alter table public.alliance_guests enable row level security;
revoke all on public.alliance_guests from anon, authenticated;

create or replace function public._al_now() returns bigint language sql stable as $$
  select extract(epoch from now())::bigint
$$;

-- Мои гости: кого я отправил (out), кто гостит у меня (in), с кем больше всего визитов (friends).
create or replace function public.al_guests()
returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m record; t bigint := _al_now();
begin
  if uid is null then raise exception 'not signed in'; end if;
  select * into m from alliance_members where user_id = uid;
  if not found then return null; end if;
  return jsonb_build_object('now', t,
    'out', (select coalesce(jsonb_agg(jsonb_build_object('id', g.id, 'name', g.host_name, 'animal', g.animal,
              'stars', g.stars, 'returns', g.returns_at) order by g.id), '[]'::jsonb)
            from alliance_guests g where g.owner = uid and not g.claimed),
    'in', (select coalesce(jsonb_agg(jsonb_build_object('id', g.id, 'name', g.owner_name, 'animal', g.animal,
              'stars', g.stars, 'returns', g.returns_at) order by g.id), '[]'::jsonb)
           from alliance_guests g where g.host = uid and g.returns_at > t),
    'friends', (select coalesce(jsonb_agg(jsonb_build_object('name', f.name, 'visits', f.visits) order by f.visits desc), '[]'::jsonb)
                from (select am.name, count(*) as visits
                        from alliance_guests g
                        join alliance_members am on am.user_id = case when g.owner = uid then g.host else g.owner end
                       where (g.owner = uid or g.host = uid) and g.returns_at <= t and am.alliance_id = m.alliance_id
                       group by am.name order by visits desc limit 5) f));
end $$;

-- Отправить зверя в гости к участнику своего альянса на сутки.
create or replace function public.al_guest_send(p_host uuid, p_animal text, p_stars int, p_slots int)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m record; h record; t bigint := _al_now(); busy int; hosted int;
begin
  if uid is null then raise exception 'not signed in'; end if;
  if p_host = uid then raise exception 'not allowed'; end if;
  if p_animal !~ '^[a-zA-Z]{2,24}$' then raise exception 'bad animal'; end if;
  select * into m from alliance_members where user_id = uid;
  if not found then raise exception 'not in alliance'; end if;
  select * into h from alliance_members where user_id = p_host and alliance_id = m.alliance_id;
  if not found then raise exception 'not allowed'; end if;
  select count(*) into busy from alliance_guests where owner = uid and not claimed;
  if busy >= least(2, greatest(1, p_slots)) then raise exception 'limit'; end if;
  if exists (select 1 from alliance_guests where owner = uid and animal = p_animal and not claimed) then
    raise exception 'guest away';
  end if;
  select count(*) into hosted from alliance_guests where host = p_host and returns_at > t;
  if hosted >= 3 then raise exception 'host full'; end if;
  insert into alliance_guests (alliance_id, owner, owner_name, host, host_name, animal, stars, sent_at, returns_at)
    values (m.alliance_id, uid, m.name, p_host, h.name, p_animal, least(10, greatest(1, p_stars)), t, t + 86400);
  perform _al_system(m.alliance_id, 'guest', m.name, p_animal || ':' || h.name);
  return al_guests();
end $$;

-- Зверь вернулся: забрать подарок. Возвращает {animal, stars}; рано или уже забрано - ошибка.
create or replace function public.al_guest_claim(p_id bigint)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); g alliance_guests;
begin
  if uid is null then raise exception 'not signed in'; end if;
  select * into g from alliance_guests where id = p_id and owner = uid for update;
  if not found or g.claimed then raise exception 'already claimed'; end if;
  if g.returns_at > _al_now() then raise exception 'too early'; end if;
  update alliance_guests set claimed = true where id = p_id;
  return jsonb_build_object('animal', g.animal, 'stars', g.stars, 'host', g.host_name);
end $$;

-- Чистка: забранные визиты старше 120 дней (для дружбы хватает).
create or replace function public.al_guests_cleanup() returns void
language sql security definer set search_path = public as $$
  delete from alliance_guests where claimed and returns_at < _al_now() - 120 * 86400
$$;

revoke all on function public.al_guests() from public, anon;
revoke all on function public.al_guest_send(uuid, text, int, int) from public, anon;
revoke all on function public.al_guest_claim(bigint) from public, anon;
revoke all on function public.al_guests_cleanup() from public, anon, authenticated;
grant execute on function public.al_guests() to authenticated;
grant execute on function public.al_guest_send(uuid, text, int, int) to authenticated;
grant execute on function public.al_guest_claim(bigint) to authenticated;
