-- Наставник (альянс Harvest Hollow): сильный игрок ведёт новичка из своего альянса.
-- Запуск: Supabase -> SQL Editor -> вставить файл целиком -> Run (после alliances.sql). Повторный запуск безопасен.
--
-- Ученик (уровень до 15) сам выбирает наставника (уровень от 25) в своём альянсе. У наставника до 3 учеников.
-- Когда ученик достигает уровней 10, 15, 20, 25, 30 (выше того, с которого начал), награду забирают оба.
-- Наставник раз в день может послать ученику подарок за кристаллы (их списывает игра), ученик его забирает.
-- Уровень игрок присылает сам (al_mentor), награды выдаёт игра. Числа как в godot/scripts/data/mentor.gd.
-- Ушёл кто-то из альянса - связь пропадает.

create table if not exists public.alliance_mentors (
  apprentice      uuid    primary key references auth.users (id) on delete cascade,
  alliance_id     bigint  not null references public.alliances (id) on delete cascade,
  mentor          uuid    not null references auth.users (id) on delete cascade,
  start_level     int     not null,
  a_claimed       int[]   not null default '{}',
  m_claimed       int[]   not null default '{}',
  gift_day        int     not null default 0,
  gifts           int     not null default 0
);
create index if not exists alliance_mentors_mentor on public.alliance_mentors (mentor);
alter table public.alliance_mentors enable row level security;
revoke all on public.alliance_mentors from anon, authenticated;

create or replace function public._al_mentor_steps() returns int[] language sql immutable as $$
  select array[10, 15, 20, 25, 30]
$$;

-- Связи, где ученик или наставник уже не в том альянсе, удаляются.
create or replace function public._al_mentor_clean(p_user uuid) returns void
language sql security definer set search_path = public as $$
  delete from alliance_mentors x
   where (x.apprentice = p_user or x.mentor = p_user)
     and (not exists (select 1 from alliance_members m where m.user_id = x.apprentice and m.alliance_id = x.alliance_id)
       or not exists (select 1 from alliance_members m where m.user_id = x.mentor and m.alliance_id = x.alliance_id))
$$;

-- Моё наставничество: мой наставник (если я ученик) и мои ученики. p_level - мой уровень сейчас.
create or replace function public.al_mentor(p_level int)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m record;
begin
  if uid is null then raise exception 'not signed in'; end if;
  update alliance_members set level = greatest(level, least(greatest(1, p_level), 200)) where user_id = uid;
  select * into m from alliance_members where user_id = uid;
  if not found then return null; end if;
  perform _al_mentor_clean(uid);
  return jsonb_build_object(
    'mentor', (select jsonb_build_object('id', x.mentor, 'name', mm.name, 'level', mm.level, 'start', x.start_level,
                 'claimed', to_jsonb(x.a_claimed), 'gifts', x.gifts)
               from alliance_mentors x join alliance_members mm on mm.user_id = x.mentor where x.apprentice = uid),
    'apprentices', (select coalesce(jsonb_agg(jsonb_build_object('id', x.apprentice, 'name', am.name, 'level', am.level,
                      'start', x.start_level, 'claimed', to_jsonb(x.m_claimed), 'gift', x.gift_day = _al_day())
                      order by am.level desc), '[]'::jsonb)
                    from alliance_mentors x join alliance_members am on am.user_id = x.apprentice where x.mentor = uid));
end $$;

-- Выбрать наставника (зовёт ученик).
create or replace function public.al_mentor_pick(p_mentor uuid, p_level int)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m record; t record; n int;
begin
  if uid is null then raise exception 'not signed in'; end if;
  if p_mentor = uid then raise exception 'not allowed'; end if;
  perform al_mentor(p_level);
  select * into m from alliance_members where user_id = uid;
  if not found then raise exception 'not in alliance'; end if;
  if m.level > 15 then raise exception 'level too high'; end if;
  if exists (select 1 from alliance_mentors where apprentice = uid) then raise exception 'has mentor'; end if;
  select * into t from alliance_members where user_id = p_mentor and alliance_id = m.alliance_id;
  if not found then raise exception 'not allowed'; end if;
  if t.level < 25 then raise exception 'level too low'; end if;
  perform _al_mentor_clean(p_mentor);
  select count(*) into n from alliance_mentors where mentor = p_mentor;
  if n >= 3 then raise exception 'full'; end if;
  insert into alliance_mentors (apprentice, alliance_id, mentor, start_level) values (uid, m.alliance_id, p_mentor, m.level);
  perform _al_system(m.alliance_id, 'mentor', m.name, t.name);
  return al_mentor(p_level);
end $$;

-- Забрать награду за ступень ученика: p_apprentice - сам ученик (или я, если я ученик).
create or replace function public.al_mentor_claim(p_apprentice uuid, p_step int)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); x alliance_mentors; lvl int;
begin
  if uid is null then raise exception 'not signed in'; end if;
  if not p_step = any(_al_mentor_steps()) then raise exception 'bad step'; end if;
  select * into x from alliance_mentors where apprentice = p_apprentice for update;
  if not found or (uid <> x.apprentice and uid <> x.mentor) then raise exception 'not allowed'; end if;
  select level into lvl from alliance_members where user_id = x.apprentice and alliance_id = x.alliance_id;
  if lvl is null or lvl < p_step or p_step <= x.start_level then raise exception 'too early'; end if;
  if uid = x.apprentice then
    if p_step = any(x.a_claimed) then raise exception 'already claimed'; end if;
    update alliance_mentors set a_claimed = a_claimed || p_step where apprentice = p_apprentice;
  else
    if p_step = any(x.m_claimed) then raise exception 'already claimed'; end if;
    update alliance_mentors set m_claimed = m_claimed || p_step where apprentice = p_apprentice;
  end if;
  return jsonb_build_object('step', p_step, 'role', case when uid = x.apprentice then 'apprentice' else 'mentor' end);
end $$;

-- Подарок ученику (наставник, раз в день на каждого ученика).
create or replace function public.al_mentor_gift(p_apprentice uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); x alliance_mentors;
begin
  if uid is null then raise exception 'not signed in'; end if;
  select * into x from alliance_mentors where apprentice = p_apprentice and mentor = uid for update;
  if not found then raise exception 'not allowed'; end if;
  if x.gift_day = _al_day() then raise exception 'limit'; end if;
  update alliance_mentors set gift_day = _al_day(), gifts = least(gifts + 1, 30) where apprentice = p_apprentice;
end $$;

-- Ученик забирает подарки. Возвращает, сколько их было.
create or replace function public.al_mentor_gifts_take()
returns int
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); n int;
begin
  if uid is null then raise exception 'not signed in'; end if;
  select gifts into n from alliance_mentors where apprentice = uid for update;
  if coalesce(n, 0) <= 0 then return 0; end if;
  update alliance_mentors set gifts = 0 where apprentice = uid;
  return n;
end $$;

-- Ученик заканчивает учёбу (или меняет наставника).
create or replace function public.al_mentor_leave()
returns void
language sql security definer set search_path = public as $$
  delete from alliance_mentors where apprentice = auth.uid()
$$;

revoke all on function public.al_mentor(int) from public, anon;
revoke all on function public.al_mentor_pick(uuid, int) from public, anon;
revoke all on function public.al_mentor_claim(uuid, int) from public, anon;
revoke all on function public.al_mentor_gift(uuid) from public, anon;
revoke all on function public.al_mentor_gifts_take() from public, anon;
revoke all on function public.al_mentor_leave() from public, anon;
revoke all on function public._al_mentor_clean(uuid) from public, anon, authenticated;
grant execute on function public.al_mentor(int) to authenticated;
grant execute on function public.al_mentor_pick(uuid, int) to authenticated;
grant execute on function public.al_mentor_claim(uuid, int) to authenticated;
grant execute on function public.al_mentor_gift(uuid) to authenticated;
grant execute on function public.al_mentor_gifts_take() to authenticated;
grant execute on function public.al_mentor_leave() to authenticated;
