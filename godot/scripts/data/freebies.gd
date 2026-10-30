class_name Freebies
## Бесплатные награды по таймеру в разделах с покупками: энергия, зелье, товар лавки, попытка подземелья.
## В Game.save: free = {ключ: когда снова можно взять (unix)}. Кнопка FreeButton показывает "Бесплатно"
## или обратный отсчёт до следующей награды.

## Через сколько секунд снова.
const COOLDOWN := {
	"energy": 8.0 * 3600.0,
	"potion": 24.0 * 3600.0,
	"market": 24.0 * 3600.0,
	"dungeon": 48.0 * 3600.0,
}
## Сколько энергии бесплатно.
const ENERGY := 60
## Бесплатный товар лавки меняется по дням.
const MARKET_ITEMS := ["luck30", "ticket1", "coins"]


static func _d() -> Dictionary:
	if not Game.save.get("free") is Dictionary:
		Game.save["free"] = {}
	return Game.save["free"]


static func _now() -> float:
	return Time.get_unix_time_from_system()


static func left(key: String) -> float:
	return maxf(0.0, float(_d().get(key, 0.0)) - _now())


static func ready(key: String) -> bool:
	return left(key) <= 0.0


## Взять награду: false - ещё рано. Саму награду выдаёт вызывающий.
static func take(key: String) -> bool:
	if not ready(key):
		return false
	_d()[key] = _now() + float(COOLDOWN.get(key, 86400.0))
	Game.mark_dirty()
	return true


static func market_item() -> String:
	return MARKET_ITEMS[ShopSystem.day_index() % MARKET_ITEMS.size()]


## Сколько бесплатных наград готово (для значков).
static func ready_count(keys: Array) -> int:
	var n := 0
	for k in keys:
		if ready(k):
			n += 1
	return n
