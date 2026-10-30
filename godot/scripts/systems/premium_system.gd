class_name PremiumSystem
extends RefCounted
## Покупки, Pro, сад, удача, билеты, экспедиции (порт Premium.swift, Expeditions.swift и части GameState).
## В Game.save: purchases, granted, consumed (идентификаторы магазина), starterOfferUntil, starterOffers,
## luckUntil, luckReadyAt, adsWatched, gardenChestAt, tickets, maps, lastFreeTicket,
## expedition = {location, endsAt, returnTo, loot: {вид: n}, coins} (как ExpeditionRun); нет экспедиции - нет ключа.

const PRO_OFFLINE_HOURS := 12.0
const STARTER_BACKPACK := 30
const CAPYBARA_YIELD := 0.1
const STARTER_COINS := 2500
const STARTER_LEVEL := 5
const STARTER_SECOND_LEVEL := 15
const STARTER_WINDOW := 48.0 * 3600.0
const LUCK_DURATION := 10.0 * 60.0
const LUCK_COOLDOWN := 10.0 * 60.0
## Удача не чаще 3 раз в день (и с Pro, и в тестовой сборке): награда, а не постоянный бонус.
const LUCK_PER_DAY := 3
## Королевский сундук открывается раз в сутки.
const GARDEN_CHEST_EVERY := 22.0 * 3600.0

## Итог последней экспедиции для окна после возвращения: {location, items: [[вид, n], ...], coins} или null.
var expedition_report = null
## Что выпало из королевского сундука: {coins, items: [[вид, n], ...]} или null.
var garden_chest_found = null


func defaults(save: Dictionary) -> void:
	for key in ["purchases", "granted", "consumed"]:
		var list: Array = []
		var raw = save.get(key, [])
		if raw is Array:
			for v in raw:
				list.append(str(v))
		save[key] = list
	for key in ["starterOffers", "adsWatched"]:
		save[key] = int(save.get(key, 0)) if _is_number(save.get(key)) else 0
	for key in ["starterOfferUntil", "luckUntil", "luckReadyAt", "gardenChestAt"]:
		if not _is_number(save.get(key)):
			save.erase(key)
	_repair_timers(save)
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


## Если часы на телефоне перевели назад, таймеры могли улететь далеко в будущее. Сбрасываем такие.
static func _repair_timers(save: Dictionary) -> bool:
	var now := _now()
	var fixed := false
	# Удачу можно купить за кристаллы, поэтому она бывает длиннее: сбрасываем только явно сбитые часы
	if _is_number(save.get("luckReadyAt")) and float(save["luckReadyAt"]) - now > 24.0 * 3600.0:
		save.erase("luckUntil")
		save.erase("luckReadyAt")
		fixed = true
	if _is_number(save.get("starterOfferUntil")) and float(save["starterOfferUntil"]) - now > STARTER_WINDOW + 60.0:
		save["starterOfferUntil"] = now + STARTER_WINDOW
		fixed = true
	return fixed


## Проверка таймеров при возвращении в игру (repairTimers).
func repair_timers() -> void:
	if _repair_timers(Game.save):
		Game.mark_dirty()


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


# MARK: Покупки

## Куплено ли (ключ покупки или идентификатор магазина).
func owns(product: String) -> bool:
	return Products.id(product) in Game.save.get("purchases", [])


## Pro куплен или действует подписка MAX (в ней всё из Pro).
func has_pro() -> bool:
	return owns("pro") or Game.shop.max_active()


## Выдаёт покупку. Разовые награды (монеты, зверь) выдаются один раз даже при повторном восстановлении.
func grant(product: String, transaction := "") -> void:
	var key := Products.key(product)
	if key == "":
		return
	var id := Products.id(key)
	if Products.consumable(key):
		# Билеты можно покупать много раз: каждую покупку выдаём ровно один раз.
		if transaction != "":
			var used: Array = Game.save.get("consumed", [])
			if transaction in used:
				return
			used.append(transaction)
			Game.save["consumed"] = used
		if key == "max" or Products.is_crystals(key) or Products.shop_granted(key):
			# Кристаллы и MAX: свой тост в ShopSystem
			Game.shop.grant(key)
			Sound.play("purchase")
			Game.recalc()
			Game.mark_dirty()
			Game.save_now()
			return
		if key == "eventPass":
			Game.events.activate_vip()
		else:
			Game.save["tickets"] = tickets() + Expeditions.TICKET_PACK
		Game.show_toast("px:chest_gold", L.t("toast.purchased", [Products.title(key)]))
		Game.mark_dirty()
		Game.save_now()
		return
	var purchases: Array = Game.save.get("purchases", [])
	if not id in purchases:
		purchases.append(id)
	Game.save["purchases"] = purchases
	var granted: Array = Game.save.get("granted", [])
	if not id in granted:
		granted.append(id)
		Game.save["granted"] = granted
		match key:
			"starter":
				Game.save["coins"] = int(Game.save["coins"]) + STARTER_COINS
				if Game.animals.stars("duckHat") == 0:
					Game.animals.add_star("duckHat", 1)
				Game.save["skin"] = "robot"
				Game.save.erase("starterOfferUntil")
			"pro":
				Game.save["skin"] = "genie"
			"garden":
				Game.save["skin"] = "knight"
				Game.save.erase("gardenChestAt")
				Game.combat.grant_weapon("royalSword")
			_:
				if Products.is_level_bundle(key) or Products.shop_granted(key):
					Game.shop.grant(key)
		Game.show_toast("px:chest_gold", L.t("toast.purchased", [Products.title(key)]))
		Sound.play("purchase")
	Game.recalc()
	Game.quests.ensure_quests()
	Game.mark_dirty()
	Game.save_now()


## Покупку вернули: убираем её, образ сбрасываем, если он был из неё.
func revoke(product: String) -> void:
	var key := Products.key(product)
	if key == "" or Products.consumable(key) or not owns(key):
		return
	var purchases: Array = Game.save.get("purchases", [])
	purchases.erase(Products.id(key))
	Game.save["purchases"] = purchases
	_after_revoke()


## Тестовая сборка: забыть все покупки (выданные награды остаются).
func reset_test_purchases() -> void:
	Game.save["purchases"] = []
	_after_revoke()


func _after_revoke() -> void:
	if not Skins.is_unlocked(Skins.current()):
		Game.save["skin"] = "farmer"
	Game.recalc()
	var qs: Array = Game.save.get("quests", [])
	if qs.size() > Game.quests.quest_slots:
		Game.save["quests"] = qs.slice(0, Game.quests.quest_slots)
	Game.mark_dirty()
	Game.save_now()


# MARK: Стартовый набор

func starter_available() -> bool:
	var until = Game.save.get("starterOfferUntil")
	return not owns("starter") and _is_number(until) and float(until) > _now()


## Открывает окно стартового набора на 48 часов: на 5 уровне и ещё раз на 15.
func check_starter_offer() -> void:
	if owns("starter") or starter_available():
		return
	var offers := int(Game.save.get("starterOffers", 0))
	var due := (offers == 0 and Game.level >= STARTER_LEVEL) or (offers == 1 and Game.level >= STARTER_SECOND_LEVEL)
	if not due:
		return
	Game.save["starterOffers"] = offers + 1
	Game.save["starterOfferUntil"] = _now() + STARTER_WINDOW
	Game.mark_dirty()


# MARK: Удача за рекламу

## Удача: x2 ресурсов, пока не вышло время.
func luck_active() -> bool:
	var until = Game.save.get("luckUntil")
	return _is_number(until) and float(until) > _now()


func luck_ready() -> bool:
	var ready_at = Game.save.get("luckReadyAt")
	return not luck_active() and (not _is_number(ready_at) or float(ready_at) <= _now())


func activate_luck(from_ad: bool) -> void:
	if not luck_ready():
		return
	var until := _now() + LUCK_DURATION * (ShopSystem.MAX_LUCK_MULT if Game.shop.max_active() else 1.0)
	Game.save["luckUntil"] = until
	Game.save["luckReadyAt"] = until + LUCK_COOLDOWN
	# Дневной лимит: после третьей удачи следующая - завтра
	var today := ShopSystem.day_index()
	var used := int(Game.save.get("luckUses", 0)) if int(Game.save.get("luckDay", 0)) == today else 0
	Game.save["luckDay"] = today
	Game.save["luckUses"] = used + 1
	if used + 1 >= LUCK_PER_DAY:
		Game.save["luckReadyAt"] = maxf(until + LUCK_COOLDOWN, House.start_of_day() + 86400.0)
	if from_ad:
		Game.save["adsWatched"] = int(Game.save.get("adsWatched", 0)) + 1
	Game.show_toast("px:clover", L.t("toast.luck"))
	Sound.play("luck")
	Game.mark_dirty()


## Удача из лавки: продлевает текущую (или начинает новую), бесплатная удача ждёт, пока эта не кончится.
func add_luck(seconds: float) -> void:
	var now := _now()
	var until = Game.save.get("luckUntil")
	var from := maxf(now, float(until) if _is_number(until) else 0.0)
	Game.save["luckUntil"] = from + seconds
	var ready_at = Game.save.get("luckReadyAt")
	Game.save["luckReadyAt"] = maxf(float(ready_at) if _is_number(ready_at) else 0.0, from + seconds)
	Game.show_toast("px:clover", L.t("toast.luck"))
	Sound.play("luck")
	Game.mark_dirty()


# MARK: Королевский сад

func garden_chest_ready() -> bool:
	var at = Game.save.get("gardenChestAt")
	return owns("garden") and (not _is_number(at) or float(at) <= _now())


## Королевский сундук раз в сутки: много монет, ресурсы и билет. Итог - в garden_chest_found.
func open_garden_chest() -> void:
	if not garden_chest_ready():
		return
	var level := Game.level
	var coins := int(float(300 + level * 120) * randf_range(0.9, 1.2))
	var items: Array = []
	var pool: Array = Game.quests.gatherable_kinds()
	pool.shuffle()
	for kind in pool.slice(0, 3):
		var n := maxi(2, int(float(60 + level * 8) / pow(float(Res.price(kind)), 0.6)))
		items.append([kind, n])
	Game.add_coins(coins)
	for it in items:
		Game.add_to_storage(it[0], it[1])
	Game.save["tickets"] = mini(Expeditions.MAX_TICKETS, tickets() + 1)
	Game.save["gardenChestAt"] = _now() + GARDEN_CHEST_EVERY
	garden_chest_found = {"coins": coins, "items": items}
	Sound.play("treasure")
	Game.mark_dirty()
	Game.save_now()


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
	Sound.play("coin")
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
	Sound.play("success")
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
