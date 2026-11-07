-- Чистка старых данных, чтобы база не росла (бесплатный план Supabase: 500 МБ).
-- Запуск: Supabase -> SQL Editor -> вставить файл целиком -> Run (после ratings.sql и alliances.sql).
-- Повторный запуск безопасен. Расписание - через pg_cron (Database -> Extensions -> pg_cron включается этим файлом).
--
-- Что удаляется раз в сутки:
--   очки ивентов, которые кончились больше 30 дней назад (награду за место игра забирает сразу после конца ивента);
--   сообщения чата альянсов старше 30 дней и жалобы на них;
--   недели событий альянса старше 8 недель;
--   мощь игроков, которые не заходили полгода;
--   забранные визиты зверей в гости старше 120 дней.

create or replace function public.hh_cleanup() returns void
language plpgsql security definer set search_path = public as $$
begin
  delete from rating_scores where updated_at < now() - interval '30 days';
  delete from alliance_chat where created_at < now() - interval '30 days';
  -- Недели событий альянса (если выполнен alliance_events.sql)
  if to_regproc('public.al_ev_cleanup') is not null then
    perform al_ev_cleanup();
  end if;
  -- Мощь тех, кто не заходил полгода (если выполнен power.sql)
  if to_regproc('public.power_cleanup') is not null then
    perform power_cleanup();
  end if;
  -- Визиты зверей в гости (если выполнен alliance_guests.sql)
  if to_regproc('public.al_guests_cleanup') is not null then
    perform al_guests_cleanup();
  end if;
end $$;

revoke all on function public.hh_cleanup() from public, anon, authenticated;

create extension if not exists pg_cron;

do $$
begin
  perform cron.unschedule(jobid) from cron.job where jobname = 'hh-cleanup';
  perform cron.schedule('hh-cleanup', '17 3 * * *', 'select public.hh_cleanup()');
end $$;
