class_name HouseSystem
extends RefCounted
## Дом, уют, украшения, кухня и блюда, календарь входа (порт House.swift и части GameState).
## Данные в Game.save: houseFloors, decor, eventDecor, kitchenLevel, dishes, cooking, meals, loginDay, loginClaims.

## Бесплатный билет экспедиции раз в столько секунд (Expedition.freeTicketEvery).
const FREE_TICKET_EVERY := 20.0 * 3600.0


func defaults(save: Dictionary) -> void:
	var floors: Array = []
	for f in save.get("houseFloors", ["ground"]):
		if str(f) in House.FLOORS and not str(f) in floors:
			floors.append(str(f))
	if not "ground" in floors:
		floors.append("ground")
	save["houseFloors"] = floors

	var decor := {}
	var raw_decor = save.get("decor", {})
	if raw_decor is Dictionary:
		for slot in raw_decor:
			if str(raw_decor[slot]) in House.DECOR:
				decor[str(slot)] = str(raw_decor[slot])
	save["decor"] = decor
	var event_decor: Array = []
	for d in save.get("eventDecor", []):
		event_decor.append(str(d))
	save["eventDecor"] = event_decor

	var dishes := {}
	var raw_dishes = save.get("dishes", {})
	if raw_dishes is Dictionary:
		for d in raw_dishes:
			if str(d) in House.DISHES:
				dishes[str(d)] = int(raw_dishes[d])
	save["dishes"] = dishes

	var cooking: Array = []
	var raw_cooking = save.get("cooking", [])
	if raw_cooking is Array:
		for job in raw_cooking:
			if job is Dictionary and str(job.get("dish", "")) in House.DISHES:
				cooking.append({"id": str(job.get("id", _uuid())), "dish": str(job["dish"]),
					"readyAt": float(job.get("readyAt", 0.0))})
	save["cooking"] = cooking

	var meals := {}
	var raw_meals = save.get("meals", {})
	if raw_meals is Dictionary:
		for d in raw_meals:
			if str(d) in House.DISHES:
				meals[str(d)] = float(raw_meals[d])
	# Старые сохранения: одно блюдо.
	if str(save.get("meal", "")) in House.DISHES and save.get("mealUntil") != null:
		meals[str(save["meal"])] = float(save["mealUntil"])
	save.erase("meal")
	save.erase("mealUntil")
	save["meals"] = meals

	save["loginDay"] = int(save.get("loginDay", 0))
	save["loginClaims"] = int(save.get("loginClaims", 0))
	# Раньше вторая плита давалась подвалом: такие сохранения начинают со второго уровня кухни.
	save["kitchenLevel"] = maxi(2 if "basement" in floors else 1, int(save.get("kitchenLevel", 1)))
	# Этаж из сохранения ещё не построен: на поляну.
	var here := House.floor_of(str(save.get("current", "meadow")))
	if here != "" and not here in floors:
		save["current"] = "meadow"


## Идентификатор блюда на плите (UUID, как в iOS-сохранении).
static func _uuid() -> String:
	var hex := ""
	for i in 16:
		var b := randi() % 256
		if i == 6:
			b = (b & 0x0f) | 0x40
		elif i == 8:
			b = (b & 0x3f) | 0x80
		hex += "%02X" % b
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]


static func _now() -> float:
	return Time.get_unix_time_from_system()


# MARK: Этажи

func is_built(id: String) -> bool:
	return id in Game.save.get("houseFloors", ["ground"])


func can_build(id: String) -> bool:
	return not is_built(id) and Game.level >= House.floor_level(id) and Game.can_afford(House.floor_cost(id))


func build(id: String) -> bool:
	if not can_build(id):
		return false
	Game.pay(House.floor_cost(id))
	Game.save["houseFloors"].append(id)
	Game.recalc()
	Game.emit_event("build", {"floor": id})
	Game.mark_dirty()
	Game.save_now()
	return true


## Этаж, на котором сейчас герой ("" - не в доме).
func current_floor() -> String:
	return House.floor_of(Game.current)


## Войти в дом с поляны: появляемся у двери на первом этаже.
func enter_house() -> void:
	Game.arrival_station = "exit"
	Game.arrival_gate = ""
	Game.save["current"] = House.floor_location("ground")
	Game.mark_dirty()


## Выйти из дома на поляну, к двери.
func leave_house() -> void:
	Game.arrival_station = ""
	Game.arrive_at_door = true
	Game.arrival_gate = ""
	Game.save["current"] = "meadow"
	Game.mark_dirty()


## Подняться или спуститься по лестнице (via - "up" или "down").
func go_floor(id: String, via: String) -> void:
	if not is_built(id):
		return
	Game.arrival_station = "down" if via == "up" else "up"
	Game.save["current"] = House.floor_location(id)
	Game.mark_dirty()


## Перейти на другой этаж кнопкой: появляемся в середине комнаты.
func switch_floor(id: String) -> void:
	if not is_built(id) or current_floor() == id:
		return
	Game.arrival_station = ""
	Game.save["current"] = House.floor_location(id)
	Game.mark_dirty()


## Поспать: здоровье полностью восстанавливается.
func rest() -> void:
	if Game.combat.has_method("heal_full"):
		Game.combat.call("heal_full")
	Game.show_toast("px:bed", L.t("toast.rest"))


## Чердак с подзорной трубой: бесплатный билет вдвое чаще.
func free_ticket_interval() -> float:
	return FREE_TICKET_EVERY / 2.0 if is_built("attic") else FREE_TICKET_EVERY


# MARK: Уровень кухни

func kitchen_level() -> int:
	return int(Game.save.get("kitchenLevel", 1))


## Цена следующего уровня кухни ({} - уровень наибольший).
func next_kitchen_cost() -> Dictionary:
	var lvl := kitchen_level()
	return House.kitchen_cost(lvl + 1) if lvl < House.KITCHEN_MAX else {}


func can_upgrade_kitchen() -> bool:
	var cost := next_kitchen_cost()
	if cost.is_empty():
		return false
	return Game.level >= House.kitchen_required_level(kitchen_level() + 1) and Game.can_afford(cost)


func upgrade_kitchen() -> void:
	if not can_upgrade_kitchen():
		return
	Game.pay(next_kitchen_cost())
	Game.save["kitchenLevel"] = kitchen_level() + 1
	Game.show_toast("px:dish_omelette", L.t("toast.kitchen", [kitchen_level()]))
	Game.mark_dirty()
	Game.save_now()


# MARK: Украшения и уют

## Украшение на месте ("" - пусто).
func decor_at(slot: String) -> String:
	return str(Game.save.get("decor", {}).get(slot, ""))


func comfort() -> int:
	var n := 0
	for id in Game.save.get("decor", {}).values():
		n += House.decor_comfort(str(id))
	return n


## Бонус уюта: +1% за очко, не больше 30%.
func comfort_bonus() -> float:
	return House.comfort_bonus(comfort())


## Украшение ивента можно поставить, только если оно получено, и только одно.
func has_decor(id: String) -> bool:
	return House.decor_event(id) == "" or id in Game.save.get("eventDecor", [])


func can_place(id: String) -> bool:
	if House.decor_event(id) != "":
		return has_decor(id) and not id in Game.save.get("decor", {}).values()
	return Game.can_afford(House.decor_cost(id))


func place(id: String, slot: String) -> bool:
	if decor_at(slot) != "" or not can_place(id):
		return false
	Game.pay(House.decor_cost(id))
	Game.save["decor"][slot] = id
	Game.recalc()
	Game.emit_event("decor", {"item": id})
	Game.mark_dirty()
	return true


func remove_decor(slot: String) -> void:
	if decor_at(slot) == "":
		return
	Game.save["decor"].erase(slot)
	Game.recalc()
	Game.mark_dirty()


# MARK: Кухня

func cook_slots() -> int:
	return House.kitchen_slots(kitchen_level())


func cook_time(dish: String) -> float:
	return House.dish_cook_time(dish) * House.kitchen_speed(kitchen_level()) * Game.stats.cook_mult


func dishes(dish: String) -> int:
	return int(Game.save.get("dishes", {}).get(dish, 0))


func total_dishes() -> int:
	var n := 0
	for v in Game.save.get("dishes", {}).values():
		n += int(v)
	return n


## Блюда на плите: [{id, dish, readyAt}].
func cooking() -> Array:
	return Game.save.get("cooking", [])


## Есть ли готовые блюда на плите.
func has_ready_dishes() -> bool:
	var now := _now()
	for job in cooking():
		if float(job["readyAt"]) <= now:
			return true
	return false


func can_cook(dish: String) -> bool:
	return cooking().size() < cook_slots() and Game.can_afford(House.dish_cost(dish))


func cook(dish: String) -> bool:
	collect_dishes()
	if not can_cook(dish):
		return false
	Game.pay(House.dish_cost(dish))
	Game.save["cooking"].append({"id": _uuid(), "dish": dish, "readyAt": _now() + cook_time(dish)})
	Game.emit_event("cook", {"dish": dish})
	Game.mark_dirty()
	return true


## Готовые блюда с плиты переходят в запасы. Возвращает, сколько забрали.
func collect_dishes() -> int:
	var now := _now()
	var left: Array = []
	var ready := 0
	for job in cooking():
		if float(job["readyAt"]) <= now:
			var d: String = job["dish"]
			Game.save["dishes"][d] = dishes(d) + 1
			ready += 1
		else:
			left.append(job)
	if ready == 0:
		return 0
	Game.save["cooking"] = left
	Game.mark_dirty()
	return ready


## Сколько блюд может действовать одновременно.
func meal_slots() -> int:
	return House.kitchen_meal_slots(kitchen_level())


## Действующие блюда: [{dish, until}], ближайшее к концу первым.
func active_meal_list() -> Array:
	var now := _now()
	var out: Array = []
	var meals: Dictionary = Game.save.get("meals", {})
	for d in meals:
		if float(meals[d]) > now:
			out.append({"dish": str(d), "until": float(meals[d])})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["until"]) < float(b["until"]))
	return out


## Блюда, которые сейчас действуют (id блюд).
func active_meals() -> Array:
	var out: Array = []
	for m in active_meal_list():
		out.append(m["dish"])
	return out


## Что даёт блюдо: {"yield", "xp", "speed", "sell", "crit", "animals"}.
func meal_buff(dish: String) -> Dictionary:
	return House.dish_buff(dish)


## Сколько действует блюдо: подвал продлевает в 1.5 раза, таланты и наследие - ещё.
func meal_duration(dish: String) -> float:
	return House.dish_duration(dish) * (1.5 if is_built("basement") else 1.0) * Game.stats.meal_mult


func _meal_active(dish: String) -> bool:
	return float(Game.save.get("meals", {}).get(dish, 0.0)) > _now()


## Можно ли съесть: есть в запасах и есть свободное место (или это блюдо уже действует и продлится).
func can_eat(dish: String) -> bool:
	if dishes(dish) <= 0:
		return false
	return _meal_active(dish) or active_meal_list().size() < meal_slots()


func eat(dish: String) -> bool:
	if dishes(dish) <= 0:
		return false
	if not can_eat(dish):
		Game.show_toast("px:dish_stew", L.t("toast.mealsFull", [meal_slots()]))
		return false
	if Game.combat.has_method("heal"):
		Game.combat.call("heal", 0.4)
	Game.save["dishes"][dish] = dishes(dish) - 1
	# То же блюдо ещё раз продлевает его действие.
	var now := _now()
	var start := maxf(now, float(Game.save["meals"].get(dish, 0.0)))
	var duration := meal_duration(dish)
	Game.save["meals"][dish] = minf(start + duration, now + duration * 3.0)
	Game.recalc()
	Game.show_toast("px:" + House.dish_icon(dish), L.t("toast.meal", [House.dish_name(dish)]))
	Game.mark_dirty()
	Game.save_now()
	return true


## Блюдо закончилось: убираем бонус. Готовое с плиты - в запасы.
func refresh_meal() -> void:
	var now := _now()
	var meals: Dictionary = Game.save.get("meals", {})
	var left := {}
	for d in meals:
		if float(meals[d]) > now:
			left[d] = meals[d]
	if left.size() != meals.size():
		Game.save["meals"] = left
		Game.recalc()
		Game.mark_dirty()
	collect_dishes()


# MARK: Календарь

func _day_index() -> int:
	return int(House.start_of_day() / 86400.0)


func can_claim_login() -> bool:
	return int(Game.save.get("loginDay", 0)) != _day_index()


func login_claims() -> int:
	return int(Game.save.get("loginClaims", 0))


func login_reward(claim: int) -> Dictionary:
	return House.login_reward(claim, Game.level)


## Когда можно забрать следующую награду (unix-секунды).
func next_login_at() -> float:
	return House.start_of_day() + 86400.0


func claim_login() -> void:
	if not can_claim_login():
		return
	var r := login_reward(login_claims())
	match str(r["type"]):
		"coins":
			Game.add_coins(int(r["coins"]))
		"seeds":
			var seeds: Dictionary = Game.save.get("seeds", {})
			seeds[r["crop"]] = int(seeds.get(r["crop"], 0)) + int(r["n"])
			Game.save["seeds"] = seeds
		"tickets":
			Game.save["tickets"] = int(Game.save.get("tickets", 0)) + int(r["n"])
		"coinsAndWood":
			Game.add_coins(int(r["coins"]))
			Game.add_to_storage("wood", int(r["wood"]), false)
		"dish":
			Game.save["dishes"][r["dish"]] = dishes(r["dish"]) + 1
		"resource":
			Game.add_to_storage(r["kind"], int(r["n"]), false)
		"chest":
			Game.save["tickets"] = int(Game.save.get("tickets", 0)) + int(r["tickets"])
			Game.add_coins(int(r["coins"]))
			if Game.collection.has_method("random_card"):
				Game.collection.call("random_card")
	Game.save["loginDay"] = _day_index()
	Game.save["loginClaims"] = login_claims() + 1
	Game.mark_dirty()
	Game.save_now()
