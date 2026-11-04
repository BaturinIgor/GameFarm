class_name OnlineConfig
## Сервер рейтингов (Supabase). Пустой адрес - рейтинги выключены, игра работает как раньше.
## ANON_KEY - публичный ключ проекта (Project Settings -> API -> anon public): он и так виден в сборке,
## права ограничены функциями из docs/supabase/ratings.sql. Ключ service_role сюда класть нельзя.

const URL := ""
const ANON_KEY := ""


static func enabled() -> bool:
	return URL != "" and ANON_KEY != ""
