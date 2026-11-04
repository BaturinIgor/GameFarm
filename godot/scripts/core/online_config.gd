class_name OnlineConfig
## Сервер рейтингов (Supabase). Пустой адрес - рейтинги выключены, игра работает как раньше.
## ANON_KEY - публичный ключ проекта (Project Settings -> API -> anon public): он и так виден в сборке,
## права ограничены функциями из docs/supabase/ratings.sql. Ключ service_role сюда класть нельзя.

const URL := "https://lyfiktmgpsqhsrzfncop.supabase.co"
const ANON_KEY := "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx5ZmlrdG1ncHNxaHNyemZuY29wIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTM4MTc1OTYsImV4cCI6MjEwOTM5MzU5Nn0.V2ClWy12FcPDZ54ORkmZUAsv6fWUlUfF5vuMJ2nMQl4"


static func enabled() -> bool:
	return URL != "" and ANON_KEY != ""
