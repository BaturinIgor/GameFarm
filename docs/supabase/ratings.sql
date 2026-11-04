-- Рейтинги ивентов Harvest Hollow (Supabase / Postgres).
-- Запуск: Supabase -> SQL Editor -> вставить файл целиком -> Run. Повторный запуск безопасен.
-- Перед этим: Authentication -> Sign In / Providers -> включить "Allow anonymous sign-ins".
--
-- Игрок входит анонимно (auth.users), очки шлёт только через submit_score. Прямой записи в таблицы нет:
-- RLS включён, политик на запись нет, функции security definer проверяют auth.uid().
-- Лиги: в каждом ивенте игроки по порядку прихода делятся на группы по 50 (league = номер группы).

create table if not exists public.rating_scores (
  event_key  text        not null,
  user_id    uuid        not null references auth.users (id) on delete cascade,
  name       text        not null,
  level      int         not null default 1,
  score      int         not null default 0,
  league     int         not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (event_key, user_id)
);

create index if not exists rating_scores_top on public.rating_scores (event_key, score desc);
create index if not exists rating_scores_league on public.rating_scores (event_key, league, score desc);

alter table public.rating_scores enable row level security;
revoke all on public.rating_scores from anon, authenticated;

create or replace function public._rating_clean_name(p_name text) returns text
language sql immutable as $$
  select coalesce(nullif(left(regexp_replace(trim(coalesce(p_name, '')), E'[\\x00-\\x1f<>"''`\\\\]', '', 'g'), 16), ''), 'Farmer')
$$;

-- Очки ивента. Принимается только рост, и не быстрее разумного темпа (защита от подмены сохранения):
-- p_rate - сколько очков в минуту максимум, плюс запас p_slack.
create or replace function public.submit_score(p_event text, p_score int, p_name text, p_level int)
returns void
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  old record;
  cap int;
  rate int := case when p_event like 'farm-%' then 60 else 250 end;
  slack int := 600;
  n int;
begin
  if uid is null then raise exception 'not signed in'; end if;
  if p_event !~ '^[A-Za-z]+-[0-9]+$' and p_event !~ '^farm-[A-Za-z]+-[0-9]+$' then raise exception 'bad event'; end if;
  select * into old from rating_scores where event_key = p_event and user_id = uid;
  if not found then
    select count(*) into n from rating_scores where event_key = p_event;
    insert into rating_scores (event_key, user_id, name, level, score, league)
    values (p_event, uid, _rating_clean_name(p_name), greatest(1, least(p_level, 100)), least(greatest(p_score, 0), slack), n / 50);
    return;
  end if;
  cap := old.score + slack + (extract(epoch from (now() - old.updated_at)) / 60.0 * rate)::int;
  update rating_scores
     set score = greatest(old.score, least(p_score, cap)),
         name = _rating_clean_name(p_name),
         level = greatest(1, least(p_level, 100)),
         updated_at = now()
   where event_key = p_event and user_id = uid;
end $$;

-- Лига игрока: все её участники по очкам.
create or replace function public.get_league(p_event text)
returns table (place bigint, name text, level int, score int, me boolean)
language sql stable security definer set search_path = public as $$
  with mine as (select league from rating_scores where event_key = p_event and user_id = auth.uid())
  select row_number() over (order by s.score desc, s.updated_at), s.name, s.level, s.score, s.user_id = auth.uid()
    from rating_scores s, mine
   where s.event_key = p_event and s.league = mine.league
   order by s.score desc, s.updated_at
$$;

-- Мировой топ и место игрока.
create or replace function public.get_global(p_event text, p_limit int default 100)
returns table (place bigint, name text, level int, score int, me boolean)
language sql stable security definer set search_path = public as $$
  with ranked as (
    select row_number() over (order by score desc, updated_at) as place, name, level, score, user_id = auth.uid() as me
      from rating_scores where event_key = p_event
  )
  select * from ranked where place <= least(p_limit, 200) or me order by place
$$;

-- Итог для наград: место в лиге, место в мире и сколько всего участников.
create or replace function public.my_result(p_event text)
returns table (league_place bigint, global_place bigint, total bigint, score int)
language sql stable security definer set search_path = public as $$
  with me as (select * from rating_scores where event_key = p_event and user_id = auth.uid())
  select
    (select count(*) + 1 from rating_scores s, me where s.event_key = p_event and s.league = me.league
       and (s.score > me.score or (s.score = me.score and s.updated_at < me.updated_at))),
    (select count(*) + 1 from rating_scores s, me where s.event_key = p_event
       and (s.score > me.score or (s.score = me.score and s.updated_at < me.updated_at))),
    (select count(*) from rating_scores where event_key = p_event),
    me.score
  from me
$$;

revoke all on function public.submit_score(text, int, text, int) from public, anon;
revoke all on function public.get_league(text) from public, anon;
revoke all on function public.get_global(text, int) from public, anon;
revoke all on function public.my_result(text) from public, anon;
grant execute on function public.submit_score(text, int, text, int) to authenticated;
grant execute on function public.get_league(text) to authenticated;
grant execute on function public.get_global(text, int) to authenticated;
grant execute on function public.my_result(text) to authenticated;
