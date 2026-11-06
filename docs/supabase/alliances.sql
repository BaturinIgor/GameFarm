-- Альянсы Harvest Hollow (Supabase / Postgres), шаг 1: альянс, участники, таланты, вклады, чат.
-- Запуск: Supabase -> SQL Editor -> вставить файл целиком -> Run. Повторный запуск безопасен.
-- Нужен уже выполненный ratings.sql (анонимный вход и функция _rating_clean_name).
--
-- Как и рейтинги: RLS включён, прямой записи в таблицы нет, всё через функции security definer,
-- которые проверяют auth.uid(). Правила (лимиты вкладов, уровни, места) считает сервер, а не игра.
-- Числа должны совпадать с godot/scripts/data/alliances.gd.

-- ---------- таблицы ----------

create table if not exists public.alliances (
  id          bigint generated always as identity primary key,
  name        text        not null,
  tag         text        not null,
  emblem      int         not null default 0,
  about       text        not null default '',
  min_level   int         not null default 10,
  xp          bigint      not null default 0,
  week_xp     bigint      not null default 0,
  week_key    int         not null default 0,
  talents     jsonb       not null default '{}'::jsonb,   -- талант -> очки
  created_at  timestamptz not null default now()
);
create unique index if not exists alliances_name on public.alliances (lower(name));
create unique index if not exists alliances_tag on public.alliances (lower(tag));
create index if not exists alliances_xp on public.alliances (xp desc);

create table if not exists public.alliance_members (
  user_id     uuid        primary key references auth.users (id) on delete cascade,
  alliance_id bigint      not null references public.alliances (id) on delete cascade,
  name        text        not null,
  level       int         not null default 1,
  role        text        not null default 'member',      -- leader, officer, member
  total       bigint      not null default 0,             -- вклад за всё время
  week        int         not null default 0,             -- вклад за неделю
  week_key    int         not null default 0,
  day_key     int         not null default 0,
  day_free    int         not null default 0,
  day_coins   int         not null default 0,
  day_gems    int         not null default 0,
  joined_at   timestamptz not null default now(),
  seen_at     timestamptz not null default now()
);
create index if not exists alliance_members_by_alliance on public.alliance_members (alliance_id);

create table if not exists public.alliance_chat (
  id          bigint generated always as identity primary key,
  alliance_id bigint      not null references public.alliances (id) on delete cascade,
  user_id     uuid        references auth.users (id) on delete set null,
  name        text        not null,
  kind        text        not null default 'text',        -- text, join, leave, kick, level, talent
  body        text        not null default '',
  reports     int         not null default 0,
  hidden      boolean     not null default false,
  created_at  timestamptz not null default now()
);
create index if not exists alliance_chat_by_alliance on public.alliance_chat (alliance_id, id desc);

create table if not exists public.alliance_reports (
  message_id  bigint      not null references public.alliance_chat (id) on delete cascade,
  user_id     uuid        not null references auth.users (id) on delete cascade,
  reason      text        not null default '',
  created_at  timestamptz not null default now(),
  primary key (message_id, user_id)
);

create table if not exists public.alliance_blocks (
  user_id     uuid        not null references auth.users (id) on delete cascade,
  blocked     uuid        not null references auth.users (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (user_id, blocked)
);

-- Слова, которые чат заменяет звёздочками (дополняется из SQL Editor: insert into alliance_badwords values ('...')).
create table if not exists public.alliance_badwords (word text primary key);

alter table public.alliances enable row level security;
alter table public.alliance_members enable row level security;
alter table public.alliance_chat enable row level security;
alter table public.alliance_reports enable row level security;
alter table public.alliance_blocks enable row level security;
alter table public.alliance_badwords enable row level security;
revoke all on public.alliances, public.alliance_members, public.alliance_chat, public.alliance_reports,
  public.alliance_blocks, public.alliance_badwords from anon, authenticated;

-- ---------- правила (как в alliances.gd) ----------

-- Номер дня и недели (UTC, неделя с понедельника) - как DailySystem.week_index в игре.
create or replace function public._al_day() returns int language sql stable as $$
  select floor(extract(epoch from now()) / 86400)::int
$$;
create or replace function public._al_week() returns int language sql stable as $$
  select floor((floor(extract(epoch from now()) / 86400) + 3) / 7.0)::int
$$;

-- Уровень альянса по опыту: на уровень L нужно 400 * (L-1)^1.7 опыта, до 20 уровня.
create or replace function public._al_level(p_xp bigint) returns int language sql immutable as $$
  select least(20, 1 + coalesce((select max(l) from generate_series(1, 19) l where 400 * power(l, 1.7) <= p_xp), 0))
$$;
-- Мест: 25 на первом уровне, +5 за уровень, не больше 100.
create or replace function public._al_cap(p_xp bigint) returns int language sql immutable as $$
  select least(100, 25 + 5 * (public._al_level(p_xp) - 1))
$$;

-- Таланты: id -> с какого уровня альянса открыт.
create or replace function public._al_talent_level(p_talent text) returns int language sql immutable as $$
  select case p_talent
    when 'harvest' then 1 when 'strength' then 1
    when 'garden' then 3 when 'beasts' then 3
    when 'workshop' then 6 when 'vitality' then 6
    when 'fortune' then 10 when 'thrift' then 10
    else null end
$$;
-- Сколько очков нужно на все 10 рангов таланта (дальше вклад в него не принимается).
create or replace function public._al_talent_max(p_talent text) returns int language sql immutable as $$
  select (60 * 55 * case when public._al_talent_level(p_talent) >= 10 then 3
                         when public._al_talent_level(p_talent) >= 6 then 2
                         when public._al_talent_level(p_talent) >= 3 then 1.5 else 1 end)::int
$$;

create or replace function public._al_clean(p_text text, p_len int) returns text language sql stable as $$
  select left(regexp_replace(trim(coalesce(p_text, '')), E'[\\x00-\\x1f<>`\\\\]', '', 'g'), p_len)
$$;

-- Фильтр чата: слова из alliance_badwords -> звёздочки.
create or replace function public._al_filter(p_text text) returns text language plpgsql stable as $$
declare w text; res text := p_text;
begin
  for w in select word from alliance_badwords loop
    res := regexp_replace(res, '(?i)' || regexp_replace(w, '([.*+?^${}()|\[\]\\])', '\\\1', 'g'), repeat('*', length(w)), 'g');
  end loop;
  return res;
end $$;

-- Неделя сменилась - обнуляем недельные очки.
create or replace function public._al_roll(p_alliance bigint) returns void
language plpgsql security definer set search_path = public as $$
declare wk int := _al_week();
begin
  update alliances set week_xp = 0, week_key = wk where id = p_alliance and week_key <> wk;
  update alliance_members set week = 0, week_key = wk where alliance_id = p_alliance and week_key <> wk;
end $$;

create or replace function public._al_system(p_alliance bigint, p_kind text, p_name text, p_body text) returns void
language sql security definer set search_path = public as $$
  insert into alliance_chat (alliance_id, user_id, name, kind, body) values (p_alliance, null, p_name, p_kind, p_body)
$$;

-- ---------- чтение ----------

-- Мой альянс целиком: сам альянс, участники, мои лимиты на сегодня. Пусто - я не в альянсе.
create or replace function public.al_me()
returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m record; a record;
begin
  if uid is null then raise exception 'not signed in'; end if;
  select * into m from alliance_members where user_id = uid;
  if not found then return null; end if;
  perform _al_roll(m.alliance_id);
  update alliance_members set seen_at = now() where user_id = uid;
  select * into a from alliances where id = m.alliance_id;
  select * into m from alliance_members where user_id = uid;
  return jsonb_build_object(
    'id', a.id, 'name', a.name, 'tag', a.tag, 'emblem', a.emblem, 'about', a.about, 'min_level', a.min_level,
    'xp', a.xp, 'week_xp', a.week_xp, 'level', _al_level(a.xp), 'cap', _al_cap(a.xp), 'talents', a.talents,
    'role', m.role,
    'day', jsonb_build_object('free', case when m.day_key = _al_day() then m.day_free else 0 end,
                              'coins', case when m.day_key = _al_day() then m.day_coins else 0 end,
                              'gems', case when m.day_key = _al_day() then m.day_gems else 0 end),
    'members', (select coalesce(jsonb_agg(jsonb_build_object('id', x.user_id, 'name', x.name, 'level', x.level,
                  'role', x.role, 'week', x.week, 'total', x.total, 'seen', extract(epoch from x.seen_at)::bigint,
                  'me', x.user_id = uid) order by x.week desc, x.total desc), '[]'::jsonb)
                from alliance_members x where x.alliance_id = a.id));
end $$;

-- Поиск альянсов (пустой запрос - лучшие по опыту, где есть места и подходит мой уровень).
create or replace function public.al_search(p_query text, p_level int)
returns table (id bigint, name text, tag text, emblem int, about text, min_level int, level int, members bigint, cap int)
language sql stable security definer set search_path = public as $$
  select a.id, a.name, a.tag, a.emblem, a.about, a.min_level, _al_level(a.xp),
         (select count(*) from alliance_members m where m.alliance_id = a.id), _al_cap(a.xp)
    from alliances a
   where (coalesce(p_query, '') = '' or a.name ilike '%' || p_query || '%' or a.tag ilike p_query)
     and (coalesce(p_query, '') <> '' or a.min_level <= greatest(1, p_level))
   order by a.week_xp desc, a.xp desc
   limit 30
$$;

-- Рейтинг альянсов: по опыту за неделю и место моего альянса.
create or replace function public.al_top()
returns table (place bigint, id bigint, name text, tag text, emblem int, level int, week_xp bigint, xp bigint, me boolean)
language sql stable security definer set search_path = public as $$
  with mine as (select alliance_id from alliance_members where user_id = auth.uid()),
  ranked as (
    select row_number() over (order by case when a.week_key = _al_week() then a.week_xp else 0 end desc, a.xp desc) as place,
           a.id, a.name, a.tag, a.emblem, _al_level(a.xp) as level,
           case when a.week_key = _al_week() then a.week_xp else 0 end as week_xp, a.xp,
           a.id = (select alliance_id from mine) as me
      from alliances a
  )
  select * from ranked where place <= 100 or me order by place
$$;

-- Сообщения после p_after (0 - последние 50), без скрытых жалобами и без заблокированных мной.
create or replace function public.al_messages(p_after bigint)
returns table (id bigint, user_id uuid, name text, kind text, body text, at bigint, me boolean)
language sql stable security definer set search_path = public as $$
  select * from (
    select c.id, c.user_id, c.name, c.kind, c.body, extract(epoch from c.created_at)::bigint, c.user_id = auth.uid()
      from alliance_chat c
     where c.alliance_id = (select alliance_id from alliance_members where user_id = auth.uid())
       and c.id > coalesce(p_after, 0) and not c.hidden
       and (c.user_id is null or c.user_id not in (select blocked from alliance_blocks where user_id = auth.uid()))
     order by c.id desc limit 50
  ) t order by id
$$;

-- ---------- действия ----------

-- Создать альянс. Цену (кристаллы или монеты) списывает игра после успеха.
create or replace function public.al_create(p_name text, p_tag text, p_emblem int, p_about text, p_min_level int,
  p_player text, p_level int)
returns bigint
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); nm text := _al_clean(p_name, 20); tg text := upper(_al_clean(p_tag, 4)); aid bigint;
begin
  if uid is null then raise exception 'not signed in'; end if;
  if exists (select 1 from alliance_members where user_id = uid) then raise exception 'already in alliance'; end if;
  if p_level < 15 then raise exception 'level too low'; end if;
  if length(nm) < 3 or tg !~ '^[A-Z0-9]{2,4}$' then raise exception 'bad name'; end if;
  if _al_filter(nm) <> nm or _al_filter(tg) <> tg then raise exception 'bad name'; end if;
  if exists (select 1 from alliances where lower(name) = lower(nm)) then raise exception 'name taken'; end if;
  if exists (select 1 from alliances where lower(tag) = lower(tg)) then raise exception 'tag taken'; end if;
  insert into alliances (name, tag, emblem, about, min_level, week_key)
  values (nm, tg, greatest(0, least(p_emblem, 15)), _al_filter(_al_clean(p_about, 120)), greatest(10, least(p_min_level, 100)), _al_week())
  returning id into aid;
  insert into alliance_members (user_id, alliance_id, name, level, role, week_key)
  values (uid, aid, _rating_clean_name(p_player), greatest(1, least(p_level, 200)), 'leader', _al_week());
  perform _al_system(aid, 'create', _rating_clean_name(p_player), nm);
  return aid;
end $$;

create or replace function public.al_join(p_alliance bigint, p_player text, p_level int)
returns void
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); a record; n int;
begin
  if uid is null then raise exception 'not signed in'; end if;
  if exists (select 1 from alliance_members where user_id = uid) then raise exception 'already in alliance'; end if;
  select * into a from alliances where id = p_alliance for update;
  if not found then raise exception 'no alliance'; end if;
  if p_level < a.min_level then raise exception 'level too low'; end if;
  select count(*) into n from alliance_members where alliance_id = a.id;
  if n >= _al_cap(a.xp) then raise exception 'full'; end if;
  insert into alliance_members (user_id, alliance_id, name, level, week_key)
  values (uid, a.id, _rating_clean_name(p_player), greatest(1, least(p_level, 200)), _al_week());
  perform _al_system(a.id, 'join', _rating_clean_name(p_player), '');
end $$;

-- Выйти. Уходит глава - главой становится заместитель (или самый активный); последний - альянс удаляется.
create or replace function public.al_leave()
returns void
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m record; heir uuid;
begin
  select * into m from alliance_members where user_id = uid;
  if not found then return; end if;
  delete from alliance_members where user_id = uid;
  if not exists (select 1 from alliance_members where alliance_id = m.alliance_id) then
    delete from alliances where id = m.alliance_id;
    return;
  end if;
  perform _al_system(m.alliance_id, 'leave', m.name, '');
  if m.role = 'leader' then
    select user_id into heir from alliance_members where alliance_id = m.alliance_id
     order by (role = 'officer') desc, total desc, joined_at limit 1;
    update alliance_members set role = 'leader' where user_id = heir;
  end if;
end $$;

-- Глава и заместители: исключить участника (заместитель - только рядового).
create or replace function public.al_kick(p_user uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare me record; t record;
begin
  select * into me from alliance_members where user_id = auth.uid();
  select * into t from alliance_members where user_id = p_user;
  if me is null or t is null or me.alliance_id <> t.alliance_id or me.user_id = t.user_id then raise exception 'not allowed'; end if;
  if not (me.role = 'leader' or (me.role = 'officer' and t.role = 'member')) then raise exception 'not allowed'; end if;
  delete from alliance_members where user_id = p_user;
  perform _al_system(me.alliance_id, 'kick', t.name, '');
end $$;

-- Глава: назначить роль (officer, member) или передать главенство (leader).
create or replace function public.al_set_role(p_user uuid, p_role text)
returns void
language plpgsql security definer set search_path = public as $$
declare me record; t record;
begin
  select * into me from alliance_members where user_id = auth.uid();
  select * into t from alliance_members where user_id = p_user;
  if me is null or t is null or me.alliance_id <> t.alliance_id or me.role <> 'leader' or me.user_id = t.user_id
     or p_role not in ('leader', 'officer', 'member') then raise exception 'not allowed'; end if;
  if p_role = 'leader' then
    update alliance_members set role = 'officer' where user_id = me.user_id;
  end if;
  update alliance_members set role = p_role where user_id = p_user;
end $$;

-- Глава: описание и минимальный уровень.
create or replace function public.al_edit(p_about text, p_min_level int, p_emblem int)
returns void
language plpgsql security definer set search_path = public as $$
declare me record;
begin
  select * into me from alliance_members where user_id = auth.uid();
  if me is null or me.role <> 'leader' then raise exception 'not allowed'; end if;
  update alliances set about = _al_filter(_al_clean(p_about, 120)), min_level = greatest(10, least(p_min_level, 100)),
         emblem = greatest(0, least(p_emblem, 15))
   where id = me.alliance_id;
end $$;

-- Вклад в талант: p_kind = free (20 в день), coins (20 в день), gems (без лимита).
-- Монеты и кристаллы списывает игра после успеха. Возвращает новые очки таланта.
create or replace function public.al_contribute(p_talent text, p_kind text, p_player text, p_level int)
returns int
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m record; a record; d int := _al_day(); pts int; lvl int;
begin
  if uid is null then raise exception 'not signed in'; end if;
  select * into m from alliance_members where user_id = uid for update;
  if not found then raise exception 'not in alliance'; end if;
  perform _al_roll(m.alliance_id);
  select * into a from alliances where id = m.alliance_id for update;
  lvl := _al_talent_level(p_talent);
  if lvl is null or _al_level(a.xp) < lvl then raise exception 'talent locked'; end if;
  pts := coalesce((a.talents ->> p_talent)::int, 0);
  if pts >= _al_talent_max(p_talent) then raise exception 'talent maxed'; end if;
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
  update alliance_members set total = total + 1, week = week + 1, name = _rating_clean_name(p_player),
         level = greatest(1, least(p_level, 200)), seen_at = now()
   where user_id = uid;
  update alliances set xp = xp + 1, week_xp = week_xp + 1,
         talents = jsonb_set(talents, array[p_talent], to_jsonb(pts + 1))
   where id = a.id;
  if _al_level(a.xp + 1) > _al_level(a.xp) then
    perform _al_system(a.id, 'level', '', _al_level(a.xp + 1)::text);
  end if;
  return pts + 1;
end $$;

-- Сообщение в чат: до 200 знаков, не чаще раза в 3 секунды и 20 в минуту, со звёздочками вместо плохих слов.
create or replace function public.al_say(p_text text, p_player text)
returns void
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m record; body text := _al_clean(p_text, 200);
begin
  select * into m from alliance_members where user_id = uid;
  if not found then raise exception 'not in alliance'; end if;
  if body = '' then return; end if;
  if exists (select 1 from alliance_chat where user_id = uid and created_at > now() - interval '3 seconds')
     or (select count(*) from alliance_chat where user_id = uid and created_at > now() - interval '1 minute') >= 20 then
    raise exception 'too fast';
  end if;
  insert into alliance_chat (alliance_id, user_id, name, body)
  values (m.alliance_id, uid, _rating_clean_name(p_player), _al_filter(body));
end $$;

-- Жалоба на сообщение. После 3 жалоб сообщение скрывается для всех; модератор видит их в alliance_reports.
create or replace function public.al_report(p_message bigint, p_reason text)
returns void
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); c record;
begin
  select * into c from alliance_chat where id = p_message;
  if not found or c.user_id is null or c.user_id = uid then return; end if;
  if not exists (select 1 from alliance_members where user_id = uid and alliance_id = c.alliance_id) then return; end if;
  insert into alliance_reports (message_id, user_id, reason) values (p_message, uid, _al_clean(p_reason, 200))
  on conflict do nothing;
  update alliance_chat set reports = (select count(*) from alliance_reports where message_id = p_message),
         hidden = (select count(*) from alliance_reports where message_id = p_message) >= 3
   where id = p_message;
end $$;

-- Заблокировать или разблокировать игрока: его сообщения у меня не показываются.
create or replace function public.al_block(p_user uuid, p_on boolean)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or p_user is null or p_user = auth.uid() then return; end if;
  if p_on then
    insert into alliance_blocks (user_id, blocked) values (auth.uid(), p_user) on conflict do nothing;
  else
    delete from alliance_blocks where user_id = auth.uid() and blocked = p_user;
  end if;
end $$;

-- Чистка: сообщения старше 30 дней (можно запускать по расписанию через pg_cron).
create or replace function public.al_cleanup() returns void
language sql security definer set search_path = public as $$
  delete from alliance_chat where created_at < now() - interval '30 days'
$$;

do $$
declare f text;
begin
  foreach f in array array[
    'al_me()', 'al_search(text, int)', 'al_top()', 'al_messages(bigint)',
    'al_create(text, text, int, text, int, text, int)', 'al_join(bigint, text, int)', 'al_leave()',
    'al_kick(uuid)', 'al_set_role(uuid, text)', 'al_edit(text, int, int)',
    'al_contribute(text, text, text, int)', 'al_say(text, text)', 'al_report(bigint, text)', 'al_block(uuid, boolean)'
  ] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  foreach f in array array['_al_roll(bigint)', '_al_system(bigint, text, text, text)', 'al_cleanup()'] loop
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;
