-- Вступление по заявкам: глава выбирает, свободный вход или по заявкам. Заявку принимают или отклоняют
-- глава и заместители, она живёт 3 дня. У игрока не больше 3 заявок сразу.
-- Запуск: Supabase -> SQL Editor -> вставить файл целиком -> Run (после alliances.sql). Повторный запуск безопасен.

alter table public.alliances add column if not exists open boolean not null default true;

create table if not exists public.alliance_apps (
  alliance_id bigint not null references public.alliances (id) on delete cascade,
  user_id     uuid   not null references auth.users (id) on delete cascade,
  name        text   not null,
  level       int    not null,
  created_at  timestamptz not null default now(),
  primary key (alliance_id, user_id)
);
create index if not exists alliance_apps_user on public.alliance_apps (user_id);
alter table public.alliance_apps enable row level security;
revoke all on public.alliance_apps from anon, authenticated;

-- Вступить сразу (только в открытый альянс).
create or replace function public.al_join(p_alliance bigint, p_player text, p_level int)
returns void
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); a record; n int;
begin
  if uid is null then raise exception 'not signed in'; end if;
  if exists (select 1 from alliance_members where user_id = uid) then raise exception 'already in alliance'; end if;
  select * into a from alliances where id = p_alliance for update;
  if not found then raise exception 'no alliance'; end if;
  if not a.open then raise exception 'apply only'; end if;
  if p_level < a.min_level then raise exception 'level too low'; end if;
  select count(*) into n from alliance_members where alliance_id = a.id;
  if n >= _al_cap(a.talents) then raise exception 'full'; end if;
  insert into alliance_members (user_id, alliance_id, name, level, week_key)
  values (uid, a.id, _rating_clean_name(p_player), greatest(1, least(p_level, 200)), _al_week());
  delete from alliance_apps where user_id = uid;
  perform _al_system(a.id, 'join', _rating_clean_name(p_player), '');
end $$;

-- Вступить или подать заявку: 'joined' или 'applied'.
create or replace function public.al_apply(p_alliance bigint, p_player text, p_level int)
returns text
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); a record;
begin
  if uid is null then raise exception 'not signed in'; end if;
  if exists (select 1 from alliance_members where user_id = uid) then raise exception 'already in alliance'; end if;
  select * into a from alliances where id = p_alliance;
  if not found then raise exception 'no alliance'; end if;
  if a.open then
    perform al_join(p_alliance, p_player, p_level);
    return 'joined';
  end if;
  if p_level < a.min_level then raise exception 'level too low'; end if;
  delete from alliance_apps where created_at < now() - interval '3 days';
  if (select count(*) from alliance_apps where user_id = uid) >= 3
     and not exists (select 1 from alliance_apps where user_id = uid and alliance_id = p_alliance) then
    raise exception 'limit';
  end if;
  insert into alliance_apps (alliance_id, user_id, name, level) values (p_alliance, uid, _rating_clean_name(p_player), greatest(1, least(p_level, 200)))
  on conflict (alliance_id, user_id) do update set created_at = now(), level = excluded.level;
  return 'applied';
end $$;

-- Заявки: в мой альянс (для главы и заместителей) и мои заявки (если я не в альянсе).
create or replace function public.al_apps()
returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m alliance_members;
begin
  if uid is null then raise exception 'not signed in'; end if;
  delete from alliance_apps where created_at < now() - interval '3 days';
  select * into m from alliance_members where user_id = uid;
  return jsonb_build_object(
    'open', (select open from alliances where id = m.alliance_id),
    'apps', case when m.role in ('leader', 'officer') then
              (select coalesce(jsonb_agg(jsonb_build_object('id', p.user_id, 'name', p.name, 'level', p.level,
                       'power', coalesce((select power from player_power w where w.user_id = p.user_id), 0),
                       'at', extract(epoch from p.created_at)::bigint) order by p.created_at), '[]'::jsonb)
                 from alliance_apps p where p.alliance_id = m.alliance_id)
            else '[]'::jsonb end,
    'mine', (select coalesce(jsonb_agg(p.alliance_id), '[]'::jsonb) from alliance_apps p where p.user_id = uid));
end $$;

-- Принять или отклонить заявку (глава и заместители).
create or replace function public.al_app_decide(p_user uuid, p_accept boolean)
returns void
language plpgsql security definer set search_path = public as $$
declare me alliance_members; ap alliance_apps; a record; n int;
begin
  select * into me from alliance_members where user_id = auth.uid();
  if not found or me.role not in ('leader', 'officer') then raise exception 'not allowed'; end if;
  select * into ap from alliance_apps where alliance_id = me.alliance_id and user_id = p_user for update;
  if not found then raise exception 'not allowed'; end if;
  delete from alliance_apps where alliance_id = me.alliance_id and user_id = p_user;
  if not p_accept then return; end if;
  if exists (select 1 from alliance_members where user_id = p_user) then raise exception 'already in alliance'; end if;
  select * into a from alliances where id = me.alliance_id for update;
  select count(*) into n from alliance_members where alliance_id = a.id;
  if n >= _al_cap(a.talents) then raise exception 'full'; end if;
  insert into alliance_members (user_id, alliance_id, name, level, week_key)
  values (p_user, a.id, ap.name, ap.level, _al_week());
  delete from alliance_apps where user_id = p_user;
  perform _al_system(a.id, 'join', ap.name, '');
end $$;

-- Глава: свободный вход или по заявкам.
create or replace function public.al_set_open(p_open boolean)
returns void
language plpgsql security definer set search_path = public as $$
declare me alliance_members;
begin
  select * into me from alliance_members where user_id = auth.uid();
  if not found or me.role <> 'leader' then raise exception 'not allowed'; end if;
  update alliances set open = coalesce(p_open, true) where id = me.alliance_id;
end $$;

-- Поиск: как в alliances.sql, плюс open.
drop function if exists public.al_search(text, int);
create or replace function public.al_search(p_query text, p_level int)
returns table (id bigint, name text, tag text, emblem int, about text, min_level int, level int, members bigint, cap int, open boolean)
language sql stable security definer set search_path = public as $$
  select a.id, a.name, a.tag, a.emblem, a.about, a.min_level, _al_level(a.xp),
         (select count(*) from alliance_members m where m.alliance_id = a.id), _al_cap(a.talents), a.open
    from alliances a
   where (coalesce(p_query, '') = '' or a.name ilike '%' || p_query || '%' or a.tag ilike p_query)
     and (coalesce(p_query, '') <> '' or a.min_level <= greatest(1, p_level))
   order by a.week_xp desc, a.xp desc
   limit 30
$$;

do $$
declare f text;
begin
  foreach f in array array['al_join(bigint, text, int)', 'al_apply(bigint, text, int)', 'al_apps()', 'al_app_decide(uuid, boolean)',
                           'al_set_open(boolean)', 'al_search(text, int)'] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
