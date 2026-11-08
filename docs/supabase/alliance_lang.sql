-- Язык альянса: глава выбирает при создании (и может сменить), в поиске альянсы на моём языке идут первыми.
-- Коды как в godot/scripts/core/l10n.gd (CODES). Пустой язык - "любой".
-- Запуск: Supabase -> SQL Editor -> вставить файл целиком -> Run (после alliance_bank.sql). Повторный запуск безопасен.

alter table public.alliances add column if not exists lang text not null default '';

create or replace function public._al_langs() returns text[] language sql immutable as $$
  select array['en', 'ru', 'de', 'fr', 'es', 'pt-BR', 'it', 'tr', 'pl', 'zh-Hans', 'zh-Hant', 'ja', 'ko', 'id', 'vi', 'th', 'hi']
$$;

-- Язык моего альянса.
create or replace function public.al_lang() returns text
language sql stable security definer set search_path = public as $$
  select a.lang from alliances a join alliance_members m on m.alliance_id = a.id where m.user_id = auth.uid()
$$;

-- Сменить язык альянса (только глава).
create or replace function public.al_set_lang(p_lang text)
returns text
language plpgsql security definer set search_path = public as $$
declare m record; lg text := coalesce(p_lang, '');
begin
  select * into m from alliance_members where user_id = auth.uid();
  if not found then raise exception 'not in alliance'; end if;
  if m.role <> 'leader' then raise exception 'not allowed'; end if;
  if lg <> '' and not (lg = any(_al_langs())) then raise exception 'bad kind'; end if;
  update alliances set lang = lg where id = m.alliance_id;
  return lg;
end $$;

-- Поиск: как al_search (alliance_war_raiders.sql), плюс язык; альянсы на p_lang - первыми, потом без языка.
create or replace function public.al_search_lang(p_query text, p_level int, p_lang text)
returns table (id bigint, name text, tag text, emblem int, about text, min_level int, level int, members bigint, cap int,
               open boolean, lang text)
language sql stable security definer set search_path = public as $$
  select a.id, a.name, a.tag, a.emblem, a.about, a.min_level, _al_level(a.xp),
         (select count(*) from alliance_members m where m.alliance_id = a.id), _al_cap(a.talents), a.open, a.lang
    from alliances a
   where not a.raider
     and (coalesce(p_query, '') = '' or a.name ilike '%' || p_query || '%' or a.tag ilike p_query)
     and (coalesce(p_query, '') <> '' or a.min_level <= greatest(1, p_level))
   order by case when a.lang = coalesce(p_lang, '') then 0 when a.lang = '' then 1 else 2 end, a.week_xp desc, a.xp desc
   limit 30
$$;

do $$
declare f text;
begin
  foreach f in array array['al_lang()', 'al_set_lang(text)', 'al_search_lang(text, int, text)'] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
