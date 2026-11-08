-- Удалить тестовых ботов и их альянсы (созданы test_bots.sql). Повторный запуск безопасен.
-- Удаляются: задача hh-test-bots, 8 альянсов BT1..BT8 (с чатом, войной, событиями), 200 бот-аккаунтов
-- (с мощью, вкладами и всем, что на них ссылается). Живые игроки, которые вступили в бот-альянс, просто остаются без альянса.

do $$
begin
  if to_regclass('cron.job') is not null then
    perform cron.unschedule(jobid) from cron.job where jobname = 'hh-test-bots';
  end if;
  if to_regclass('public.test_bot_alliances') is not null then
    delete from public.alliances where id in (select alliance_id from public.test_bot_alliances);
  end if;
  if to_regclass('public.test_bots') is not null then
    delete from auth.users where id in (select user_id from public.test_bots);
  end if;
end $$;

drop function if exists public.bots_tick();
drop function if exists public._bot_contribute(uuid, int);
drop function if exists public._bot_line();
drop function if exists public._bot_open_talents(int);
drop table if exists public.test_bot_alliances;
drop table if exists public.test_bots;
