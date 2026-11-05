class_name AnimalSystem
extends RefCounted
## Звери (порт части GameState): звёзды, лавка, приручение, спутники, пробуждение, редкие окраски
## и добыча производителей за время без игры.

## Итог последнего подсчёта времени без игры: {duration, items: [[kind, n], ...], sold: [[kind, n], ...],
## sold_coins, doubled}. Не сохраняется.
var offline_report: Dictionary = {}

## Места рядом с героем сверх пяти: цена в кристаллах по порядку.
const SLOT_PRICES := [300, 800]
## Без игры звери работают вполсилы.
const OFFLINE_RATE := 0.5
## Что не влезло на склад без игры, само продаётся скупщику за такую долю цены.
const OVERFLOW_PRICE := 0.5


## Звери из старых версий переходят в новых, числа из JSON - в целые (как SaveData.swift).
func defaults(save: Dictionary) -> void:
	var raw: Dictionary = save.get("animals", {})
	var animals := {}
	for key in raw:
		var id := Animals.from(str(key))
		if id == "":
			continue
		# Если двое стали одним, берём больше звёзд
		animals[id] = maxi(int(animals.get(id, 0)), mini(Animals.MAX_STARS, int(raw[key])))
	save["animals"] = animals

	var team: Array = []
	for raw_id in save.get("active", []):
		var id := Animals.from(str(raw_id))
		if id != "" and not id in team and animals.has(id):
			team.append(id)
	save["animalSlots"] = clampi(int(save.get("animalSlots", 0)), 0, SLOT_PRICES.size())
	var cap := Game.MAX_ACTIVE_ANIMALS + (1 if int(save.get("talents", {}).get("beastLord", 0)) > 0 else 0) \
		+ int(save["animalSlots"])
	if team.size() > cap:
		team = team.slice(0, cap)
	save["active"] = team

	var levels := {}
	var raw_levels: Dictionary = save.get("awaken", {})
	for key in raw_levels:
		var id := Animals.from(str(key))
		if id != "":
			levels[id] = int(raw_levels[key])
	save["awaken"] = levels

	var rare: Array = []
	for raw_id in save.get("shiny", []):
		var id := Animals.from(str(raw_id))
		if id != "":
			rare.append(id)
	save["shiny"] = rare


func stars(id: String) -> int:
	return int(Game.save.get("animals", {}).get(id, 0))


func owned() -> Array:
	return Animals.IDS.filter(func(id: String) -> bool: return stars(id) > 0)


func active() -> Array:
	return Game.save.get("active", [])


func is_active(id: String) -> bool:
	return id in active()


## Сколько зверей можно взять с собой: суперталант "Повелитель зверей" и места за кристаллы.
func max_active() -> int:
	return Game.MAX_ACTIVE_ANIMALS + (1 if Game.talents.rank("beastLord") > 0 else 0) + bought_slots()


## Сколько мест куплено за кристаллы.
func bought_slots() -> int:
	return int(Game.save.get("animalSlots", 0))


## Цена следующего места (-1 - больше не купить).
func slot_price() -> int:
	var n := bought_slots()
	return int(SLOT_PRICES[n]) if n < SLOT_PRICES.size() else -1


func buy_slot() -> bool:
	var price := slot_price()
	if price < 0 or not Game.shop.spend_crystals(price):
		return false
	Game.save["animalSlots"] = bought_slots() + 1
	Sound.play("purchase")
	Game.show_toast("px:paw", L.t("animals.slotBought", [max_active()]))
	Game.recalc()
	Game.mark_dirty()
	Game.save_now()
	return true


## Сила зверя для текстов в окнах: звёзды и общий бонус к зверям.
func multiplier(id: String, extra_stars := 0) -> float:
	return Game.stats.star_multiplier(maxi(1, stars(id) + extra_stars)) * Game.stats.animal_mult


## Эффекты зверя: [{"type": "xp", "v": 0.1}, {"type": "yield", "cat": "wood", "v": 0.1}, ...].
func effects(id: String) -> Array:
	return Animals.effects(id)


# MARK: Лавка и приручение

## Цена в лавке (-1 - зверь не продаётся).
func shop_price(id: String) -> int:
	var price := Animals.shop_base_price(id)
	if price < 0:
		return -1
	return int(round(float(price) * pow(1.8, float(stars(id))) * Game.stats.shop_mult))


## Цена приручения дикого зверя ({} - зверь не дикий).
func tame_cost(id: String) -> Dictionary:
	var cost := Animals.wild_cost(id)
	if cost.is_empty():
		return {}
	var factor := (1.0 + 0.5 * float(stars(id))) * Game.stats.tame_mult
	var items: Array = []
	for it in cost.get("items", []):
		items.append([it[0], maxi(1, int(ceil(float(it[1]) * factor)))])
	return {"coins": int(ceil(float(cost.get("coins", 0)) * factor)), "items": items}


## Сколько зверей ждут игрока: можно купить звезду в лавке, пробудить или взять с собой на свободное место.
func upgradable_count() -> int:
	var c := tab_counts()
	return int(c["mine"]) + int(c["shop"])


## Что доступно по вкладкам окна зверей: mine - пробуждение и свободное место рядом с героем,
## shop - звёзды, на которые хватает монет, wild - отряды вернулись с добычей.
func tab_counts() -> Dictionary:
	var mine := 0
	var shop := 0
	var coins := int(Game.save["coins"])
	for id in Animals.IDS:
		var lvl := Animals.shop_level(id)
		if lvl >= 0 and Game.level >= lvl and stars(id) < Animals.MAX_STARS:
			var price := shop_price(id)
			if price >= 0 and coins >= price:
				shop += 1
				continue
		if can_awaken(id):
			mine += 1
	# Есть свободное место рядом с героем и зверь, который сидит дома
	if active().size() < max_active():
		for id in owned():
			if not is_active(id) and not Game.wild.on_squad(id):
				mine += 1
				break
	return {"mine": mine, "shop": shop, "wild": Game.wild.ready_count() if Game.wild.open() else 0}


## Цена звезды зверя за кристаллы (-1 - зверь не за кристаллы).
func crystal_price(id: String) -> int:
	if not Animals.is_crystal(id):
		return -1
	return int(round(float(Animals.spec(id)["price"]) * pow(Animals.CRYSTAL_GROWTH, float(stars(id)))))


func buy_crystal(id: String) -> bool:
	var level := Animals.crystal_level(id)
	if level < 0 or Game.level < level or stars(id) >= Animals.MAX_STARS:
		return false
	if not Game.shop.spend_crystals(crystal_price(id)):
		return false
	add_star(id, 1)
	Sound.play("purchase")
	Game.save_now()
	return true


func buy(id: String) -> bool:
	var level := Animals.shop_level(id)
	if level < 0 or Game.level < level or stars(id) >= Animals.MAX_STARS:
		return false
	var price := shop_price(id)
	if price < 0 or int(Game.save["coins"]) < price:
		return false
	Game.save["coins"] = int(Game.save["coins"]) - price
	add_star(id, 1)
	Sound.play("purchase")
	return true


## Приручить дикого зверя (shiny - у него редкая окраска).
func tame(id: String, shiny := false) -> bool:
	if stars(id) >= Animals.MAX_STARS:
		return false
	var cost := tame_cost(id)
	if cost.is_empty() or not Game.can_afford(cost):
		return false
	Game.pay(cost)
	var bonus := 2 if randf() < Game.stats.double_star_chance else 1
	add_star(id, bonus)
	if bonus > 1:
		Game.show_toast("px:stardust", L.t("toast.doubleStar"))
	Game.gain_xp(10 + 2 * Game.level)
	if shiny:
		mark_shiny(id)
	return true


## Звезда за покупку, приручение или набор. Новый зверь сразу идёт с героем, если есть место.
func add_star(id: String, count: int) -> void:
	if randf() < 0.35 and Game.collection.has_method("gain_animal_card"):
		Game.collection.call("gain_animal_card", id)
	var is_new := stars(id) == 0
	Game.save["animals"][id] = mini(Animals.MAX_STARS, stars(id) + count)
	Game.emit_event("tame", {"animal": id})
	var name := Animals.name_of(id)
	if is_new:
		if active().size() < max_active():
			Game.save["active"].append(id)
			Game.show_toast("an:" + id, L.t("toast.animalJoined", [name]))
		else:
			Game.show_toast("an:" + id, L.t("toast.animalPen", [name]))
	else:
		Game.show_toast("an:" + id, "%s: %d/%d" % [name, stars(id), Animals.MAX_STARS])
	Game.recalc()
	Game.mark_dirty()


func toggle_active(id: String) -> bool:
	var list: Array = Game.save["active"]
	var index := list.find(id)
	if index >= 0:
		list.remove_at(index)
	else:
		if stars(id) <= 0 or list.size() >= max_active():
			return false
		# Зверь в походе по диким землям не может идти с героем
		if Game.wild.on_squad(id):
			Game.show_toast("px:compass", L.t("wild.onSquad"))
			return false
		list.append(id)
	Game.recalc()
	Game.mark_dirty()
	return true


# MARK: Пробуждение и редкие окраски

func awaken_level(id: String) -> int:
	return int(Game.save.get("awaken", {}).get(id, 0))


func is_shiny(id: String) -> bool:
	return id in Game.save.get("shiny", [])


## Множитель пробуждения и редкого окраса.
func boost(id: String) -> float:
	return Animals.awaken_multiplier(awaken_level(id)) * (1.0 + Animals.SHINY_BONUS if is_shiny(id) else 1.0)


## Цена следующего пробуждения ({} - нельзя: не 5 звёзд или уже золото).
func awaken_cost(id: String) -> Dictionary:
	var next := awaken_level(id) + 1
	if stars(id) < Animals.MAX_STARS or next > Animals.AWAKEN_MAX:
		return {}
	return Animals.awaken_cost(next)


func can_awaken(id: String) -> bool:
	var cost := awaken_cost(id)
	return not cost.is_empty() and Game.can_afford(cost) and Game.story.shards() >= int(cost.get("shards", 0))


func awaken(id: String) -> void:
	if not can_awaken(id):
		return
	var cost := awaken_cost(id)
	Game.pay(cost)
	Game.story.spend_shards(int(cost.get("shards", 0)))
	if not Game.save.has("awaken"):
		Game.save["awaken"] = {}
	Game.save["awaken"][id] = awaken_level(id) + 1
	Game.recalc()
	Sound.play("levelUp")
	Game.show_toast("px:star", L.t("toast.awaken", [Animals.name_of(id), "%d/%d" % [awaken_level(id), Animals.AWAKEN_MAX]]))
	Game.save_now()


func mark_shiny(id: String) -> void:
	if is_shiny(id):
		return
	if not Game.save.has("shiny"):
		Game.save["shiny"] = []
	Game.save["shiny"].append(id)
	Game.show_toast("px:rainbow", L.t("toast.shiny", [Animals.name_of(id)]))
	Game.recalc()
	Game.mark_dirty()


# MARK: Пока игры не было

## Производители работали и без игрока (не дольше offline_hours). Возвращает отчёт или {}.
func apply_offline() -> Dictionary:
	var now := Clock.now()
	var last_seen := float(Game.save.get("lastSeen", now))
	# Часы перевели назад: время "вне игры" не начисляется заново, считаем от самой поздней отметки.
	var elapsed := maxf(0.0, minf(now - last_seen, Game.stats.offline_hours * 3600.0))
	Game.save["lastSeen"] = maxf(last_seen, now)
	if elapsed <= 90.0:
		return {}
	var s := Game.stats
	var totals := {}
	for p in s.producers:
		var n := int(elapsed * OFFLINE_RATE * s.producer_mult / float(p["interval"]) * (1.0 + s.double_product_chance))
		if n > 0:
			totals[p["kind"]] = int(totals.get(p["kind"], 0)) + n
	if totals.is_empty():
		return {}
	var items: Array = []
	var sold: Array = []
	var coins := 0
	for kind in Res.KINDS:
		if totals.has(kind):
			var put := Game.add_to_storage(kind, totals[kind])
			if put > 0:
				items.append([kind, put])
			# Не влезло на склад: не сгорает, а уходит скупщику за полцены
			var rest := int(totals[kind]) - put
			if rest > 0:
				sold.append([kind, rest])
				coins += overflow_coins(kind, rest)
	Game.add_coins(coins)
	offline_report = {"duration": elapsed, "items": items, "sold": sold, "sold_coins": coins, "doubled": false}
	Game.save_now()
	return offline_report


## Монеты за то, что не влезло на склад.
static func overflow_coins(kind: String, n: int) -> int:
	if n <= 0:
		return 0
	return maxi(1, int(round(float(n) * float(Estate.price(kind)) * OVERFLOW_PRICE)))


## Удваивает добычу зверей за время отсутствия (кнопка за рекламу или с Pro).
func double_offline(from_ad: bool) -> void:
	if offline_report.is_empty() or offline_report["doubled"]:
		return
	var coins := 0
	for it in offline_report["items"]:
		var put := Game.add_to_storage(it[0], it[1])
		coins += overflow_coins(it[0], int(it[1]) - put)
	Game.add_coins(coins)
	if from_ad:
		Game.save["adsWatched"] = int(Game.save.get("adsWatched", 0)) + 1
	offline_report = {}
	Game.show_toast("px:bed", L.t("toast.offlineDoubled"))
	Sound.play("success")
	Game.save_now()
