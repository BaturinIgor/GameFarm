-- Тестовые боты и альянсы Harvest Hollow (Supabase / Postgres).
-- Запуск: Supabase -> SQL Editor -> вставить файл целиком -> Run (после всех остальных файлов, cleanup.sql тоже).
-- Повторный запуск безопасен: если боты уже есть, второй раз они не создаются.
-- Убрать всё: test_bots_remove.sql.
--
-- Что создаётся:
--   200 бот-аккаунтов (auth.users, анонимные, без почты и пароля, войти под ними нельзя);
--   8 альянсов с тегами BT1..BT8 и названиями "BOT ...", уровни от 1 до ~20, 6..35 участников;
--   153 бота в альянсах (лидер, 2 офицера, остальные участники), 47 ботов без альянса;
--   мощь каждого бота (рейтинг мощи и сила альянсов), вклады, таланты, немного сообщений в чате;
--   все 8 альянсов записываются в войну альянсов этой недели.
-- Все боты и альянсы помечены явно: имена "Bot ...", альянсы "BOT ...", теги BTn.
-- Альянсы открыты с 5 уровня и не заполнены до конца, так что в любой можно вступить из игры.
--
-- Раз в час (pg_cron, задача hh-test-bots) боты "живут": вносят вклад в таланты, пишут в чат,
-- немного растут в мощи и заново записываются в войну на новой неделе.

create table if not exists public.test_bots (
  user_id uuid primary key references auth.users (id) on delete cascade,
  name    text not null
);
create table if not exists public.test_bot_alliances (
  alliance_id bigint primary key references public.alliances (id) on delete cascade
);
alter table public.test_bots enable row level security;
alter table public.test_bot_alliances enable row level security;
revoke all on public.test_bots, public.test_bot_alliances from anon, authenticated;

-- Таланты, открытые на уровне альянса lvl.
create or replace function public._bot_open_talents(p_level int) returns text[] language sql immutable as $$
  select array_agg(t) from unnest(array['harvest','strength','garden','beasts','guard',
    'workshop','vitality','swift','scholar','merchant','warcry',
    'fortune','thrift','tamer','crit','bounty','gold',
    'rest','gems','helpers','regrow','packs','ranch']) t
   where public._al_talent_level(t) <= p_level
$$;

-- Один бот вносит n очков в случайные открытые таланты своего альянса.
create or replace function public._bot_contribute(p_user uuid, p_n int) returns void
language plpgsql security definer set search_path = public as $$
declare m record; a record; open text[]; t text; pts int; i int; lvl int;
begin
  select * into m from alliance_members where user_id = p_user;
  if not found then return; end if;
  perform _al_roll(m.alliance_id);
  for i in 1..p_n loop
    select * into a from alliances where id = m.alliance_id;
    open := _bot_open_talents(_al_level(a.xp)) || array['seats'];
    t := open[1 + floor(random() * array_length(open, 1))::int];
    pts := coalesce((a.talents ->> t)::int, 0);
    continue when pts >= _al_talent_max(t);
    lvl := _al_level(a.xp);
    update alliances set xp = xp + 1, week_xp = week_xp + 1,
           talents = jsonb_set(talents, array[t], to_jsonb(pts + 1)) where id = a.id;
    if _al_level(a.xp + 1) > lvl then perform _al_system(a.id, 'level', '', _al_level(a.xp + 1)::text); end if;
  end loop;
  update alliance_members set total = total + p_n, week = week + p_n, seen_at = now() where user_id = p_user;
end $$;

-- Фразы для чата ботов.
create or replace function public._bot_line() returns text language sql volatile as $$
  select (array[
    'Всем привет!', 'Кто идёт бить стража?', 'Внёс в таланты, качаем урожай', 'Доброе утро, фермеры',
    'Нужны кирпичи, у кого лишние?', 'Сегодня откроем новый ранг', 'Отличная неделя, держимся в топе',
    'Hi all!', 'Donated to talents', 'Who is up for the guardian?', 'Good luck in the war this week',
    'Захватил аванпост на карте', 'Не забываем про ежедневный вклад', 'Спасибо за помощь!'
  ])[1 + floor(random() * 14)::int]
$$;

-- Раз в час: часть ботов в альянсах вносит вклад, иногда пишет в чат, мощь чуть растёт, альянсы записаны в войну.
create or replace function public.bots_tick() returns void
language plpgsql security definer set search_path = public as $$
declare b record; al bigint;
begin
  for b in select m.user_id, m.alliance_id, m.name from alliance_members m join test_bots t on t.user_id = m.user_id
            where random() < 0.25 loop
    perform _bot_contribute(b.user_id, 1 + floor(random() * 6)::int);
    if random() < 0.15 then
      insert into alliance_chat (alliance_id, user_id, name, body) values (b.alliance_id, b.user_id, b.name, _bot_line());
    end if;
  end loop;
  update player_power p set power = least(100000000, power + floor(random() * 1500)::int), updated_at = now()
    from test_bots t where t.user_id = p.user_id and random() < 0.3;
  if to_regproc('public._war_join') is not null then
    for al in select alliance_id from test_bot_alliances loop perform _war_join(al); end loop;
  end if;
end $$;

-- ---------- создание ----------

do $$
declare
  words text[] := array['Clover','Fern','Maple','Thistle','Willow','Acorn','Barley','Cedar','Daisy','Ember',
    'Hazel','Juniper','Lark','Moss','Nettle','Olive','Poppy','Quill','Rowan','Sage','Tansy','Umber','Violet','Wren',
    'Yarrow','Basil','Pip','Bramble','Cricket','Dew'];
  -- имя, тег, эмблема, участников, опыт альянса
  defs jsonb := '[
    ["BOT Oak Grove",     "BT1",  1, 32, 160000],
    ["BOT Sunny Meadow",  "BT2",  4, 28, 105000],
    ["BOT Honey Hive",    "BT3",  7, 24,  60000],
    ["BOT Iron Pick",     "BT4", 10, 21,  42000],
    ["BOT Moon Orchard",  "BT5", 12, 18,  20000],
    ["BOT Fox Den",       "BT6",  2, 14,   9000],
    ["BOT River Mill",    "BT7",  5, 10,   2500],
    ["BOT Seedlings",     "BT8",  9,  6,    200]
  ]';
  d jsonb; aid bigint; uid uuid; nm text; lvl int; i int; k int; n int := 0; xp bigint; seats int;
  open text[]; tal jsonb; rest bigint; share int; t text; wk int := public._al_week(); talk text[];
begin
  if exists (select 1 from public.test_bots) then
    raise notice 'Боты уже созданы, пропускаю. Чтобы пересоздать - сначала test_bots_remove.sql.';
    return;
  end if;
  perform setseed(0.42);

  -- 200 аккаунтов
  for i in 1..200 loop
    uid := gen_random_uuid();
    nm := 'Bot ' || words[1 + (i - 1) % 30] || ' ' || i;
    insert into auth.users (instance_id, id, aud, role, raw_app_meta_data, raw_user_meta_data, is_anonymous, created_at, updated_at)
    values ('00000000-0000-0000-0000-000000000000', uid, 'authenticated', 'authenticated',
            '{"provider":"anonymous","providers":["anonymous"]}', '{"test_bot":true}', true, now(), now());
    insert into public.test_bots (user_id, name) values (uid, nm);
    lvl := 5 + floor(power(random(), 1.6) * 60)::int;
    insert into public.player_power (user_id, name, level, power)
    values (uid, nm, lvl, lvl * 10000 + 100 * lvl * lvl + floor(random() * lvl * 14000)::int);
  end loop;

  -- 8 альянсов
  for d in select * from jsonb_array_elements(defs) loop
    xp := (d ->> 4)::bigint;
    if exists (select 1 from public.alliances where lower(tag) = lower(d ->> 1) or lower(name) = lower(d ->> 0)) then
      raise notice 'Альянс % уже есть, пропускаю', d ->> 0; continue;
    end if;
    -- места: 25 + 5 за ранг таланта seats; оставляем 3+ свободных места
    seats := greatest(0, ceil(((d ->> 3)::int + 3 - 25) / 5.0)::int);
    tal := '{}'::jsonb;
    if seats > 0 then tal := jsonb_build_object('seats', public._al_talent_points('seats', seats)); end if;
    open := public._bot_open_talents(public._al_level(xp));
    rest := greatest(0, xp - coalesce((tal ->> 'seats')::int, 0));
    foreach t in array open loop
      share := least(public._al_talent_max(t), floor(rest / array_length(open, 1) * (0.5 + random()))::int);
      tal := tal || jsonb_build_object(t, share);
    end loop;
    insert into public.alliances (name, tag, emblem, about, min_level, xp, week_xp, week_key, talents)
    values (d ->> 0, d ->> 1, (d ->> 2)::int, 'Тестовый альянс ботов / Test bot alliance', 5,
            xp, floor(xp * 0.04 + random() * 300)::bigint, wk, tal)
    returning id into aid;
    insert into public.test_bot_alliances values (aid);

    for k in 1..(d ->> 3)::int loop
      n := n + 1;
      select b.user_id, b.name, p.level into uid, nm, lvl
        from public.test_bots b join public.player_power p on p.user_id = b.user_id
       order by b.name offset n - 1 limit 1;
      insert into public.alliance_members (user_id, alliance_id, name, level, role, total, week, week_key, joined_at, seen_at)
      values (uid, aid, nm, lvl, case when k = 1 then 'leader' when k <= 3 then 'officer' else 'member' end,
              floor(xp / (d ->> 3)::int * (0.3 + random() * 1.4))::bigint, floor(random() * 120)::int, wk,
              now() - (random() * interval '40 days'), now() - (random() * interval '30 hours'));
      if k <= 4 then
        insert into public.alliance_chat (alliance_id, user_id, name, body, created_at)
        values (aid, uid, nm, public._bot_line(), now() - (random() * interval '20 hours'));
      end if;
    end loop;
    if to_regproc('public._war_join') is not null then perform public._war_join(aid); end if;
  end loop;
  raise notice 'Готово: 200 ботов, % в альянсах', n;
end $$;

-- Расписание (pg_cron включён в cleanup.sql).
create extension if not exists pg_cron;
do $$
begin
  perform cron.unschedule(jobid) from cron.job where jobname = 'hh-test-bots';
  perform cron.schedule('hh-test-bots', '23 * * * *', 'select public.bots_tick()');
end $$;
