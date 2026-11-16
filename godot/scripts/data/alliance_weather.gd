class_name AllianceWeather
## Призыв погоды альянса (docs/supabase/alliance_weather.sql): час дождя или солнца для всех участников.
## Дождь - грядки растут вдвое быстрее, солнце - больше добычи и опыта.

const KINDS := ["rain", "sun"]
const ICONS := {"rain": "watering_can", "sun": "spark"}
const DURATION := 3600
## Через сколько секунд может начаться: сейчас, через 30 минут, 1 или 2 часа.
const DELAYS := [0, 1800, 3600, 7200]
const FREE_PER_DAY := 1
const PAID_PER_DAY := 2
## Лишний призыв за кристаллы (может любой участник).
const PAID_CRYSTALS := 120
## Солнце: прибавка к добыче и к опыту.
const SUN_YIELD := 0.25
const SUN_XP := 0.25


## Какая погода идёт в момент t ("" - никакая).
static func active(w: Dictionary, t: float) -> String:
	var kind := str(w.get("kind", ""))
	if not kind in KINDS:
		return ""
	return kind if t >= float(w.get("starts", 0)) and t < float(w.get("ends", 0)) else ""


## Погода назначена и ещё не началась.
static func pending(w: Dictionary, t: float) -> bool:
	return str(w.get("kind", "")) in KINDS and t < float(w.get("starts", 0))


## Сколько секунд дождя пришлось на отрезок [from, to].
static func rain_overlap(w: Dictionary, from: float, to: float) -> float:
	if str(w.get("kind", "")) != "rain":
		return 0.0
	return maxf(0.0, minf(to, float(w.get("ends", 0))) - maxf(from, float(w.get("starts", 0))))


## Дождь ускоряет грядку: за каждую секунду дождя, пока грядка росла, - секунда сверху.
static func rain_boost(bed: Dictionary, w: Dictionary, from: float, to: float) -> float:
	if Farming.is_empty(bed) or not bed.has("plantedAt"):
		return 0.0
	var ready := Farming.ready_at(bed)
	return rain_overlap(w, maxf(from, float(bed["plantedAt"])), minf(to, ready))
