class_name PremiumSystem
extends RefCounted
## Покупки, Pro, сад, удача, билеты, экспедиции (порт Premium.swift, Expeditions.swift и части GameState).
## Покупки (owns, has_pro) и удача за рекламу - этап 6. В Game.save: tickets, maps, lastFreeTicket,
## expedition = {location, endsAt, returnTo, loot: {вид: n}, coins} (как ExpeditionRun); нет экспедиции - нет ключа.

const PRO_OFFLINE_HOURS := 12.0
const STARTER_BACKPACK := 20
const CAPYBARA_YIELD := 0.1

## Итог последней экспедиции для окна после возвращения: {location, items: [[вид, n], ...], coins} или null.
var expedition_report = null


func defaults(save: Dictionary) -> void:
	save["tickets"] = int(save.get("tickets", 1))
	save["maps"] = int(save.get("maps", 0))
	if not _is_number(save.get("lastFreeTicket")):
		save.erase("lastFreeTicket")
	var run = _clean_run(save.get("expedition"))
	if run == null:
		save.erase("expedition")
	else:
		save["expedition"] = run
	# Карта экспедиции без самой экспедиции: на луг
	if Locations.kind(str(save.get("current", "meadow"))) == "expedition" and run == null:
		save["current"] = "meadow"


## Экспедиция из сохранения в чистом виде (числа - целые) или null, если запись битая.
static func _clean_run(raw) -> Variant:
	if not raw is Dictionary:
		return null
	if not (raw.get("location") is String and raw.get("returnTo") is String and _is_number(raw.get("endsAt"))):
		return null
	var loot := {}
	var raw_loot = raw.get("loot", {})
	if raw_loot is Dictionary:
		for k in raw_loot:
			if _is_number(raw_loot[k]):
				loot[str(k)] = int(raw_loot[k])
	var coins = raw.get("coins", 0)
	return {"location": raw["location"], "endsAt": float(raw["endsAt"]), "returnTo": raw["returnTo"],
		"loot": loot, "coins": int(coins) if _is_number(coins) else 0}


static func _is_number(v) -> bool:
	return v is float or v is int


static func _now() -> float:
	return Time.get_unix_time_from_system()


func owns(product: String) -> bool:
	return product in Game.save.get("purchases", []) or product in Game.save.get("granted", [])


func has_pro() -> bool:
	return owns("pro")


## Удача за рекламу: x2 ресурсов, пока не вышло время (сама реклама - этап 6).
func luck_active() -> bool:
	var until = Game.save.get("luckUntil")
	return _is_number(until) and float(until) > _now()


# MARK: Билеты

func tickets() -> int:
	return int(Game.save.get("tickets", 0))


## Карты сокровищ: вторая валюта экспедиций.
func maps() -> int:
	return int(Game.save.get("maps", 0))


func free_ticket_ready() -> bool:
	var last = Game.save.get("lastFreeTicket")
	if tickets() >= Expeditions.MAX_TICKETS:
		return false
	return not _is_number(last) or float(last) + Game.house.free_ticket_interval() <= _now()


## Когда будет следующий бесплатный билет (unix-секунды) или null, если уже можно забрать.
func next_free_ticket() -> Variant:
	var last = Game.save.get("lastFreeTicket")
	if not _is_number(last):
		return null
	var next := float(last) + Game.house.free_ticket_interval()
	return next if next > _now() else null


func claim_free_ticket() -> void:
	if not free_ticket_ready():
		return
	var n := 2 if has_pro() else 1
	Game.save["tickets"] = mini(Expeditions.MAX_TICKETS, tickets() + n)
	Game.save["lastFreeTicket"] = _now()
	Game.show_toast("px:ticket", L.t("toast.ticket", [n]))
	Game.mark_dirty()
	Game.save_now()


# MARK: Экспедиции

## Идущая экспедиция ({location, endsAt, returnTo, loot, coins}) или null.
func expedition() -> Variant:
	var run = Game.save.get("expedition")
	return run if run is Dictionary else null


## Экспедиция, на карте которой стоит герой (или null).
func _run_here() -> Variant:
	var run = expedition()
	if run != null and str(run["location"]) == Game.current:
		return run
	return null


func in_expedition() -> bool:
	return Locations.kind(Game.current) == "expedition" and expedition() != null


## Множитель добычи в текущей экспедиции.
func expedition_yield_bonus(location: String) -> float:
	return Expeditions.yield_bonus(location)


## Во сколько раз быстрее восстанавливаются ресурсы в экспедиции (множитель времени).
func expedition_respawn_mult() -> float:
	return Expeditions.RESPAWN_MULT


## Сколько секунд осталось до конца экспедиции.
func expedition_left() -> float:
	var run = expedition()
	return maxf(0.0, float(run["endsAt"]) - _now()) if run != null else 0.0


func can_start_expedition(id: String) -> bool:
	return Locations.kind(id) == "expedition" and expedition() == null and Game.dungeons.run == null \
		and tickets() >= Expeditions.cost(id) and maps() >= Expeditions.maps(id)


## Уйти в экспедицию по билету. Возвращаемся туда, откуда ушли.
func start_expedition(id: String) -> bool:
	if not can_start_expedition(id):
		return false
	Game.save["tickets"] = tickets() - Expeditions.cost(id)
	Game.save["maps"] = maps() - Expeditions.maps(id)
	Game.save["expedition"] = {"location": id, "endsAt": _now() + Expeditions.duration(id), "returnTo": Game.current,
		"loot": {}, "coins": 0}
	if Game.backpack_count > 0:
		Game.deposit_backpack()
	Game.arrival_gate = ""
	Game.save["current"] = id
	Game.recalc()
	Game.mark_dirty()
	Game.save_now()
	return true


## Добыча в экспедиции копится для итога (Game шлёт gather из add_to_backpack и add_to_storage).
func on_event(name: String, data: Dictionary) -> void:
	if name != "gather":
		return
	var run = _run_here()
	var n := int(data.get("amount", 0))
	if run == null or n <= 0:
		return
	var kind := str(data.get("kind", ""))
	run["loot"][kind] = int(run["loot"].get(kind, 0)) + n


func note_expedition_coins(n: int) -> void:
	var run = _run_here()
	if run == null or n <= 0:
		return
	run["coins"] = int(run["coins"]) + n


## Время вышло (или игрок ушёл сам): показываем итог и возвращаемся.
func finish_expedition() -> void:
	var run = expedition()
	if run == null:
		return
	if Game.collection.has_method("random_card"):
		Game.collection.call("random_card")
	if Game.backpack_count > 0:
		Game.deposit_backpack()
	var id := str(run["location"])
	if Locations.SPECS.has(id):
		expedition_report = {"location": id, "items": _items(run["loot"]), "coins": int(run["coins"])}
	Game.save.erase("expedition")
	Game.arrival_gate = ""
	var home := str(run["returnTo"])
	Game.save["current"] = home if Locations.SPECS.has(home) and Game.world_map.is_unlocked(home) else "meadow"
	Game.recalc()
	Game.mark_dirty()
	Game.save_now()


## Добыча по порядку ресурсов: [[вид, n], ...].
static func _items(loot: Dictionary) -> Array:
	var out: Array = []
	for kind in Res.KINDS:
		var n := int(loot.get(kind, 0))
		if n > 0:
			out.append([kind, n])
	return out
