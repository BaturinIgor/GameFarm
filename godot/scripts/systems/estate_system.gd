class_name EstateSystem
extends RefCounted
## Усадьба: уровни зданий, стройка со строителями и ускорением, производство товаров, лимит склада,
## доска заказов и повозка. В Game.save:
## estate = {здание: {level, until (конец стройки, 0 - не строится), since (с какого времени копится товар),
##   recipe}}, builder3 (купленный третий строитель), speedAds = {day, n},
## orders = [{id, items: [[вид, n], ...], coins, xp, crystals, cart, wait (до какого времени пусто)}], cartAt.

## Сколько заказов на доске (по уровню доски) и через сколько появляется новый.
const ORDERS_MIN := 3
const ORDERS_MAX := 6
const ORDER_WAIT := 15.0 * 60.0
const ORDER_SKIP_WAIT := 10.0 * 60.0
const ORDER_PAY := 1.6
## Повозка: большой заказ раз в 6 часов.
const CART_EVERY := 6.0 * 3600.0
const CART_CRYSTALS := 2

## Что достроилось с прошлой проверки: для тостов и окна.
var just_built: Array = []


func defaults(save: Dictionary) -> void:
	var raw: Variant = save.get("estate", {})
	var clean := {}
	for id in Estate.IDS:
		var b: Dictionary = raw.get(id, {}) if raw is Dictionary and raw.get(id) is Dictionary else {}
		var level := clampi(int(b.get("level", 0)), 0, Estate.max_level(id))
		# Главный дом и склад есть с самого начала
		if id == "main" or id == "storage" or id == "barn":
			level = maxi(1, level)
		var recipe := str(b.get("recipe", ""))
		if Estate.produces(id) and not recipe in Estate.recipes(id):
			recipe = Estate.recipes(id)[0]
		clean[id] = {"level": level, "until": _num(b.get("until"), 0.0), "since": _num(b.get("since"), _now()),
			"recipe": recipe}
	save["estate"] = clean
	save["builder3"] = bool(save.get("builder3", false))
	var ads: Variant = save.get("speedAds", {})
	save["speedAds"] = {"day": int(ads.get("day", 0)) if ads is Dictionary else 0,
		"n": int(ads.get("n", 0)) if ads is Dictionary else 0}
	var orders: Array = []
	var raw_orders: Variant = save.get("orders", [])
	if raw_orders is Array:
		for o in raw_orders:
			if o is Dictionary and o.get("items") is Array:
				var items: Array = []
				for it in o["items"]:
					if it is Array and it.size() == 2 and str(it[0]) in Res.KINDS:
						items.append([str(it[0]), int(it[1])])
				orders.append({"id": str(o.get("id", "")), "items": items, "coins": int(o.get("coins", 0)),
					"xp": int(o.get("xp", 0)), "crystals": int(o.get("crystals", 0)), "cart": bool(o.get("cart", false)),
					"wait": _num(o.get("wait"), 0.0)})
	save["orders"] = orders
	save["cartAt"] = _num(save.get("cartAt"), 0.0)


static func _num(v: Variant, fallback: float) -> float:
	return float(v) if (v is float or v is int) else fallback


static func _now() -> float:
	return Time.get_unix_time_from_system()


func _b(id: String) -> Dictionary:
	return Game.save["estate"][id]


# MARK: Уровни и открытие

func level(id: String) -> int:
	return int(_b(id)["level"])


## Уровень, на котором здание работает: не выше уровень героя / 3 + 1.
func working_level(id: String) -> int:
	return mini(level(id), Game.level / 3 + 1)


## Здание открыто: герой хоть раз доходил до нужного уровня (после перерождения не закрывается).
func is_open(id: String) -> bool:
	return maxi(Game.level, int(Game.save.get("bestLevel", 1))) >= Estate.hero_level(id)


func building(id: String) -> bool:
	return float(_b(id)["until"]) > 0.0


func build_left(id: String) -> float:
	return maxf(0.0, float(_b(id)["until"]) - _now())


func builders_total() -> int:
	var n := Estate.BUILDERS
	if bool(Game.save.get("builder3", false)):
		n += 1
	if Game.premium.owns("pro"):
		n += 1
	if Game.shop.max_active():
		n += 1
	if Game.premium.owns("builder"):
		n += 1
	return n


func builders_busy() -> int:
	var n := 0
	for id in Estate.IDS:
		if building(id):
			n += 1
	return n


## Почему нельзя улучшить ("" - можно). Ключ строки и аргументы: [ключ, аргументы].
func upgrade_block(id: String) -> Array:
	var next := level(id) + 1
	if not is_open(id):
		return ["estate.block.hero", [Estate.hero_level(id)]]
	if building(id):
		return ["estate.block.building", []]
	if next > Estate.max_level(id):
		return ["estate.block.max", []]
	if id == "main":
		if Game.level < Estate.main_hero_level(next):
			return ["estate.block.hero", [Estate.main_hero_level(next)]]
	elif next > level("main"):
		return ["estate.block.main", [next]]
	if builders_busy() >= builders_total():
		return ["estate.block.builders", []]
	return []


func can_afford(id: String) -> bool:
	return Game.can_afford(Estate.build_cost(id, level(id) + 1))


func start_upgrade(id: String) -> bool:
	if not upgrade_block(id).is_empty():
		return false
	var cost := Estate.build_cost(id, level(id) + 1)
	if not Game.can_afford(cost):
		return false
	collect(id)
	Game.pay(cost)
	_b(id)["until"] = _now() + Estate.build_seconds(id, level(id) + 1)
	Sound.play("unlock")
	Game.mark_dirty()
	Game.save_now()
	return true


## Стройка закончилась: уровень выше, немного опыта. Зовётся раз в секунду из HUD и при открытии окна.
func tick() -> void:
	var now := _now()
	for id in Estate.IDS:
		var b := _b(id)
		var until := float(b["until"])
		if until > 0.0 and until <= now:
			collect(id)
			b["until"] = 0.0
			b["level"] = mini(Estate.max_level(id), int(b["level"]) + 1)
			just_built.append(id)
			Game.show_toast("px:hammer", L.t("estate.built", [Estate.name_of(id), int(b["level"])]))
			Sound.play("levelUp")
			Game.gain_xp(int(float(maxi(5, Game.xp_needed * 3 / 100)) * Game.academy.mult("insight")))
			Game.emit_event("build", {"id": id, "level": int(b["level"])})
			Game.recalc()
			Game.mark_dirty()
			Game.save_now()
	_refill_orders()
	Game.academy.tick()


func speedup_cost(id: String) -> int:
	return Estate.speedup_crystals(build_left(id))


func speed_up(id: String) -> bool:
	if not building(id):
		return false
	if not Game.shop.spend_crystals(speedup_cost(id)):
		return false
	_b(id)["until"] = _now()
	tick()
	return true


func ad_speedups_left() -> int:
	var ads: Dictionary = Game.save["speedAds"]
	if int(ads["day"]) != ShopSystem.day_index():
		return Estate.AD_SPEEDUPS_PER_DAY
	return maxi(0, Estate.AD_SPEEDUPS_PER_DAY - int(ads["n"]))


## Ролик: минус 15 минут стройки (5 раз в день).
func ad_speed_up(id: String) -> void:
	if not building(id) or ad_speedups_left() <= 0:
		return
	var ads: Dictionary = Game.save["speedAds"]
	var today := ShopSystem.day_index()
	if int(ads["day"]) != today:
		ads["day"] = today
		ads["n"] = 0
	ads["n"] = int(ads["n"]) + 1
	_b(id)["until"] = float(_b(id)["until"]) - Estate.AD_SPEEDUP
	tick()
	Game.mark_dirty()


func buy_builder() -> bool:
	if bool(Game.save.get("builder3", false)) or not Game.shop.spend_crystals(Estate.BUILDER_CRYSTALS):
		return false
	Game.save["builder3"] = true
	Sound.play("purchase")
	Game.mark_dirty()
	Game.save_now()
	return true


# MARK: Склад

## Вместимость хранилища ("storage" или "barn").
func capacity(store: String) -> int:
	return int(round(float(Estate.capacity(store, level(store))) * Game.academy.mult("storage")))


## Сколько лежит в хранилище всего.
func stored(store: String) -> int:
	var n := 0
	var st: Dictionary = Game.save["storage"]
	for kind in st:
		if Estate.store_of(str(kind)) == store:
			n += int(st[kind])
	return n


## Вместимость хранилища, где лежит этот ресурс (для текстов).
func storage_limit_of(kind: String) -> int:
	return capacity(Estate.store_of(kind))


## Сколько ещё влезет: общее свободное место в нужном хранилище.
func storage_room(kind: String) -> int:
	var store := Estate.store_of(kind)
	return maxi(0, capacity(store) - stored(store))


# MARK: Производство

func recipe(id: String) -> String:
	return str(_b(id)["recipe"])


func set_recipe(id: String, good: String) -> void:
	if not good in Estate.recipes(id) or good == recipe(id):
		return
	collect(id)
	_b(id)["recipe"] = good
	_b(id)["since"] = _now()
	Game.mark_dirty()


func rate(id: String) -> float:
	if not Estate.produces(id) or building(id):
		return 0.0
	return Estate.per_hour(recipe(id), working_level(id)) * Game.academy.mult("workshops") * Game.residents.friend_mult(id)


func cap_hours() -> float:
	return (Estate.CAP_HOURS_PRO if Game.premium.has_pro() else Estate.CAP_HOURS) + Game.academy.mult("stockpile")


## Сколько товара накопилось (без учёта сырья).
func pending(id: String) -> float:
	var r := rate(id)
	if r <= 0.0:
		return 0.0
	var hours := clampf((_now() - float(_b(id)["since"])) / 3600.0, 0.0, cap_hours())
	return r * hours


## Сколько штук можно сделать из сырья на складе.
func affordable(id: String) -> int:
	var best := 1 << 30
	for it in Estate.RECIPES.get(recipe(id), []):
		best = mini(best, int(Game.save["storage"].get(it[0], 0)) / maxi(1, int(it[1])))
	return best


## Сколько заберём сейчас: накоплено, но не больше, чем позволяет сырьё и место на складе.
func ready(id: String) -> int:
	return mini(int(floor(pending(id))), mini(affordable(id), storage_room(recipe(id))))


## Сколько всего накопится за окно (8 или 12 часов).
func capacity_of(id: String) -> int:
	return int(floor(rate(id) * cap_hours()))


## Секунд до заполнения (0 - уже полно или не работает).
func until_full(id: String) -> float:
	if rate(id) <= 0.0:
		return 0.0
	return maxf(0.0, cap_hours() * 3600.0 - (_now() - float(_b(id)["since"])))


func full(id: String) -> bool:
	return rate(id) > 0.0 and (_now() - float(_b(id)["since"])) / 3600.0 >= cap_hours()


## Забрать товар: сырьё со склада, товар на склад. Остаток часа не пропадает, если мешало не сырьё.
func collect(id: String) -> int:
	if not Estate.produces(id):
		return 0
	var b := _b(id)
	var p := pending(id)
	var n := ready(id)
	if n > 0:
		for it in Estate.RECIPES[recipe(id)]:
			Game.save["storage"][it[0]] = int(Game.save["storage"].get(it[0], 0)) - int(it[1]) * n
		Game.save["storage"][recipe(id)] = int(Game.save["storage"].get(recipe(id), 0)) + n
		Game.emit_event("produce", {"kind": recipe(id), "amount": n})
	# Несобранное (не хватило сырья или места, дробная часть) не сгорает, а ждёт: в пределах тех же 8 часов
	var r := rate(id)
	if r > 0.0:
		b["since"] = _now() - (p - float(n)) / r * 3600.0
	else:
		b["since"] = _now()
	if n > 0:
		Game.mark_dirty()
	return n


func collect_all() -> int:
	var total := 0
	for id in Estate.IDS:
		var n := collect(id)
		if n > 0:
			total += n
			Game.show_toast("res:" + recipe(id), "+%d %s" % [n, Res.name_of(recipe(id))])
	if total > 0:
		Sound.play("coin")
		Game.save_now()
	return total


## Есть что забрать (для точки на плашке усадьбы).
func ready_count() -> int:
	var n := 0
	for id in Estate.IDS:
		if ready(id) > 0:
			n += 1
	return n


# MARK: Заказы

func orders() -> Array:
	return Game.save.get("orders", [])


func orders_open() -> bool:
	return level("board") > 0


func orders_slots() -> int:
	return clampi(ORDERS_MIN + level("board") / 2, ORDERS_MIN, ORDERS_MAX)


## Пустое место на доске заполняется новым заказом, когда прошло ожидание; повозка - раз в 6 часов.
func _refill_orders() -> void:
	if not orders_open():
		return
	var list := orders()
	var now := _now()
	var changed := false
	while list.filter(func(o: Dictionary) -> bool: return not o["cart"]).size() < orders_slots():
		list.append(_new_order(false))
		changed = true
	for i in list.size():
		var o: Dictionary = list[i]
		if (o["items"] as Array).is_empty() and float(o["wait"]) <= now:
			list[i] = _new_order(bool(o["cart"]))
			changed = true
	var has_cart := list.any(func(o: Dictionary) -> bool: return o["cart"])
	if not has_cart and now >= float(Game.save.get("cartAt", 0.0)):
		list.append(_new_order(true))
		changed = true
	if changed:
		Game.save["orders"] = list
		Game.mark_dirty()


## Что можно просить: сырьё открытых локаций и товары построенных зданий.
func _order_kinds() -> Array:
	var kinds: Array = Game.quests.gatherable_kinds().duplicate()
	for id in Estate.IDS:
		if Estate.produces(id) and level(id) > 0:
			for g in Estate.recipes(id):
				# Масло - только когда подсолнух уже растёт
				var ok := true
				for it in Estate.RECIPES[g]:
					if not (it[0] in kinds or Game.storage_of(it[0]) > 0):
						ok = false
				if ok:
					kinds.append(g)
	return kinds


func _new_order(cart: bool) -> Dictionary:
	var kinds := _order_kinds()
	kinds.shuffle()
	var count := randi_range(4, 6) if cart else randi_range(2, mini(4, maxi(2, kinds.size())))
	var picked: Array = kinds.slice(0, mini(count, kinds.size()))
	var value := (60.0 + 35.0 * float(Game.level)) * randf_range(0.8, 1.25) * (2.0 if cart else 1.0)
	var items: Array = []
	var total := 0.0
	for kind in picked:
		var p := float(Estate.price(kind))
		var n := maxi(1, int(round(value / float(picked.size()) / p)))
		# Не больше, чем влезает на склад
		n = mini(n, maxi(1, storage_limit_of(kind) / 6))
		items.append([kind, n])
		total += p * float(n)
	var pay := ORDER_PAY
	# Половину обычных заказов дают жители деревни
	var from := ""
	var people: Array = Game.residents.arrived_list()
	if not cart and not people.is_empty() and randf() < 0.5:
		from = people[randi() % people.size()]
	return {"id": "%d" % randi(), "items": items, "coins": int(round(total * pay * Game.academy.mult("orders") * Game.residents.friend_mult("orders"))),
		"xp": maxi(3, int(total / 4.0)), "crystals": CART_CRYSTALS if cart else (1 if randf() < 0.08 else 0),
		"cart": cart, "wait": 0.0, "from": from}


func can_complete(o: Dictionary) -> bool:
	if (o["items"] as Array).is_empty():
		return false
	for it in o["items"]:
		if Game.storage_of(it[0]) < int(it[1]):
			return false
	return true


func complete_order(order_id: String) -> bool:
	var list := orders()
	for o in list:
		if o["id"] != order_id or not can_complete(o):
			continue
		for it in o["items"]:
			Game.save["storage"][it[0]] = Game.storage_of(it[0]) - int(it[1])
		Game.add_coins(int(o["coins"]))
		Game.gain_xp(int(float(o["xp"]) * Game.academy.mult("insight")))
		if int(o["crystals"]) > 0:
			Game.shop.add_crystals(int(o["crystals"]), true)
		Game.emit_event("order", {"cart": o["cart"]})
		Sound.play("coinBig")
		_empty(o, ORDER_WAIT * _wait_mult())
		if o["cart"]:
			Game.save["cartAt"] = _now() + CART_EVERY
		Game.mark_dirty()
		Game.save_now()
		return true
	return false


## Снять заказ: место освободится через 10 минут.
func skip_order(order_id: String) -> void:
	for o in orders():
		if o["id"] == order_id and not (o["items"] as Array).is_empty():
			_empty(o, ORDER_SKIP_WAIT)
			if o["cart"]:
				Game.save["cartAt"] = _now() + CART_EVERY
			Game.mark_dirty()


func _empty(o: Dictionary, wait: float) -> void:
	o["items"] = []
	o["coins"] = 0
	o["xp"] = 0
	o["crystals"] = 0
	o["wait"] = _now() + wait


## Доска выше уровнем - новые заказы быстрее.
func _wait_mult() -> float:
	return maxf(0.4, 1.0 - 0.06 * float(level("board") - 1))


func ready_orders() -> int:
	var n := 0
	for o in orders():
		if can_complete(o):
			n += 1
	return n
