class_name Ratings
## Рейтинги ивентов: лига (группа до 50 игроков, пришедших в ивент примерно в одно время) и мировой топ.
## Сервер - Supabase (docs/supabase/ratings.sql), адрес и публичный ключ - в OnlineConfig.
## Награда выдаётся один раз после конца ивента по итоговому месту; доски растут с уровнем героя.

const LEAGUE_SIZE := 50
## Как часто отправлять очки и обновлять таблицы (секунды).
const SUBMIT_EVERY := 60.0
const FETCH_EVERY := 45.0

## Награды лиги: [до какого места включительно, кристаллы, доски].
const LEAGUE := [[1, 50, 40], [3, 30, 25], [10, 15, 15], [25, 5, 8]]
## Награды мирового топа: [до какого места, кристаллы, доски]; последняя строка - топ 10% участников.
const GLOBAL := [[1, 500, 300], [10, 250, 150], [100, 100, 60]]
const GLOBAL_TOP_PCT := 10
const GLOBAL_PCT_REWARD := [30, 20]


## Награда за место в лиге: {crystals, planks} или пусто.
static func league_reward(place: int) -> Dictionary:
	for r in LEAGUE:
		if place >= 1 and place <= int(r[0]):
			return {"crystals": int(r[1]), "planks": int(r[2])}
	return {}


## Награда за место в мире (total - сколько всего участников).
static func global_reward(place: int, total: int) -> Dictionary:
	for r in GLOBAL:
		if place >= 1 and place <= int(r[0]):
			return {"crystals": int(r[1]), "planks": int(r[2])}
	if place >= 1 and total > 0 and place <= maxi(1, total * GLOBAL_TOP_PCT / 100):
		return {"crystals": int(GLOBAL_PCT_REWARD[0]), "planks": int(GLOBAL_PCT_REWARD[1])}
	return {}


static func planks_scaled(n: int, level: int) -> int:
	return int(round(float(n) * (1.0 + float(level) * 0.05)))


## Подпись строки таблицы наград: "1 место", "2-3 место".
static func place_label(from: int, to: int) -> String:
	return L.t("rating.place", [from]) if from == to else L.t("rating.placeRange", [from, to])


## Имя ивента по ключу рейтинга (праздник "harvestFest-3" или фарм "farm-lumberjack-5").
static func event_name(key: String) -> String:
	var parts := key.split("-")
	if parts.size() >= 3 and parts[0] == "farm":
		return FarmEvents.name_of(parts[1])
	return Events.name_of(parts[0])
