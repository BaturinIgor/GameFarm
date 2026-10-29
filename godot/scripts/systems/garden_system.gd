class_name GardenSystem
extends RefCounted
## Огород, семена, лейка, удобрения, лавка и бродячий торговец (порт огородной части GameState).

## Что случилось с грядками по кнопкам в интерфейсе (сцена покажет эффект):
## {bed, kind: "planted" | "harvested" | "boosted", got: {kind, amount}}.
var garden_events: Array = []
## Рядом с каким торговцем герой: "", "stall" или "wanderer".
var trader_prompt := ""
## Бродячий торговец (не сохраняется): {location, until, offers, bought} или пустой словарь.
var wanderer: Dictionary = {}


func defaults(save: Dictionary) -> void:
	var beds: Array = []
	var raw = save.get("beds", [])
	if raw is Array:
		for b in raw:
			beds.append(_clean_bed(b))
	save["beds"] = beds
	save["seeds"] = _counts(save.get("seeds", {}), Farming.CROPS)
	save["fertilizers"] = _counts(save.get("fertilizers", {}), Farming.FERTILIZERS)
	_clean_choice(save, "selectedSeed", Farming.CROPS)
	_clean_choice(save, "selectedFertilizer", Farming.FERTILIZERS)
	save["cropsHarvested"] = int(save.get("cropsHarvested", 0))
	save["dealsDay"] = int(save.get("dealsDay", 0))
	var bought: Array = []
	var raw_bought = save.get("dealsBought", [])
	if raw_bought is Array:
		for v in raw_bought:
			bought.append(int(v))
	save["dealsBought"] = bought
	save["canLevel"] = maxi(1, int(save.get("canLevel", 1)))
	save["maps"] = int(save.get("maps", 0))


func _clean_bed(raw) -> Dictionary:
	if not raw is Dictionary:
		return Farming.empty_bed()
	var b: Dictionary = raw
	var out := {"boost": float(b.get("boost", 0.0)), "watered": bool(b.get("watered", false))}
	var crop = b.get("crop", null)
	if crop is String and Farming.is_crop(crop):
		out["crop"] = crop
		if b.get("plantedAt", null) != null:
			out["plantedAt"] = float(b["plantedAt"])
		if b.get("speed", null) != null:
			out["speed"] = float(b["speed"])
		if b.get("fertilized", null) != null:
			out["fertilized"] = bool(b["fertilized"])
		if b.get("extra", null) != null:
			out["extra"] = int(b["extra"])
	return out


func _counts(raw, known: Dictionary) -> Dictionary:
	var out := {}
	if raw is Dictionary:
		for k in raw:
			if known.has(str(k)):
				out[str(k)] = int(raw[k])
	return out


func _clean_choice(save: Dictionary, key: String, known: Dictionary) -> void:
	var v = save.get(key, null)
	if not (v is String and known.has(v)):
		save.erase(key)


static func now() -> float:
	return Time.get_unix_time_from_system()


# MARK: Грядки

func bed_count() -> int:
	return Farming.beds_at(Game.level)


func bed(index: int) -> Dictionary:
	var beds: Array = Game.save["beds"]
	if index >= 0 and index < beds.size():
		return beds[index]
	return Farming.empty_bed()


func _set_bed(index: int, b: Dictionary) -> void:
	var beds: Array = Game.save["beds"]
	while beds.size() <= index:
		beds.append(Farming.empty_bed())
	beds[index] = b
	Game.mark_dirty()


func seeds(crop: String) -> int:
	return int(Game.save["seeds"].get(crop, 0))


func total_seeds() -> int:
	var n := 0
	for v in Game.save["seeds"].values():
		n += int(v)
	return n


func _add_seeds(crop: String, n: int) -> void:
	Game.save["seeds"][crop] = seeds(crop) + n


func select_seed(crop: String) -> void:
	if str(Game.save.get("selectedSeed", "")) == crop:
		return
	Game.save["selectedSeed"] = crop
	Game.mark_dirty()


func seed_cost(crop: String, count: int) -> int:
	var s := Game.stats
	return maxi(1, int(ceil(float(int(Farming.spec(crop)["seed_price"]) * count) * s.shop_mult * s.seed_mult)))


func buy_seeds(crop: String, count: int) -> bool:
	var cost := seed_cost(crop, count)
	if Game.level < int(Farming.spec(crop)["level"]) or int(Game.save["coins"]) < cost:
		return false
	Game.save["coins"] = int(Game.save["coins"]) - cost
	_add_seeds(crop, count)
	var selected := str(Game.save.get("selectedSeed", ""))
	if selected == "" or seeds(selected) == 0:
		Game.save["selectedSeed"] = crop
	Game.mark_dirty()
	return true


## Выбранные семена, если они ещё есть ("" - нет).
func chosen_seed() -> String:
	var chosen := str(Game.save.get("selectedSeed", ""))
	if chosen == "" or seeds(chosen) <= 0:
		return ""
	return chosen


## Посадить выбранные семена на пустую грядку.
func plant(index: int, crop := "") -> bool:
	var c := crop if crop != "" else chosen_seed()
	if c == "" or seeds(c) <= 0 or index < 0 or index >= bed_count() or not Farming.is_empty(bed(index)):
		return false
	Game.save["seeds"][c] = seeds(c) - 1
	var speed := (Farming.GREENHOUSE_SPEED if Game.house.is_built("greenhouse") else 1.0) * Game.stats.grow_mult
	_set_bed(index, {"crop": c, "plantedAt": now(), "boost": 0.0, "watered": false, "speed": speed})
	garden_events.append({"bed": index, "kind": "planted"})
	Game.emit_event("plant", {"crop": c})
	return true


## Засадить все пустые грядки выбранными семенами. Возвращает, сколько посажено.
func plant_all() -> int:
	var crop := chosen_seed()
	if crop == "":
		return 0
	var n := 0
	for i in bed_count():
		if Farming.is_empty(bed(i)) and seeds(crop) > 0 and plant(i, crop):
			n += 1
	return n


## Собрать одну грядку с кнопки.
func harvest_one(index: int) -> bool:
	var got := harvest_bed(index)
	if got.is_empty():
		return false
	garden_events.append({"bed": index, "kind": "harvested", "got": got})
	return true


## Собрать все спелые грядки.
func harvest_all() -> int:
	var n := 0
	for i in bed_count():
		if not Farming.is_ripe(bed(i), now()):
			continue
		var got := harvest_bed(i)
		if not got.is_empty():
			garden_events.append({"bed": i, "kind": "harvested", "got": got})
			n += 1
	return n


## Полить растущую грядку: оставшееся время роста сокращается. Хорошая лейка поливает всё сразу.
func water(index: int) -> bool:
	if not _water_one(index):
		return false
	if Farming.can_waters_all(can_level()):
		for i in bed_count():
			if i != index and _water_one(i):
				garden_events.append({"bed": i, "kind": "boosted"})
	return true


func _water_one(index: int) -> bool:
	var b := bed(index).duplicate()
	var t := now()
	if Farming.is_empty(b) or bool(b.get("watered", false)) or Farming.is_ripe(b, t) or not b.has("plantedAt"):
		return false
	var cut := minf(Farming.CAN_MAX_CUT, Farming.can_boost(can_level()) * Game.stats.water_mult)
	b["boost"] = float(b.get("boost", 0.0)) + maxf(0.0, Farming.ready_at(b) - t) * cut
	b["watered"] = true
	_set_bed(index, b)
	return true


## Собрать спелый урожай: сразу на склад (огород у дома), плюс опыт.
func harvest_bed(index: int) -> Dictionary:
	var b := bed(index)
	if Farming.is_empty(b) or not Farming.is_ripe(b, now()):
		return {}
	var crop: String = b["crop"]
	var spec := Farming.spec(crop)
	var produce: String = spec["produce"]
	var s := Game.stats
	var amount := maxi(1, int(round(float(spec["yield"]) * s.yield_multiplier(produce)))) + int(b.get("extra", 0))
	if randf() < s.extra_crop_chance:
		amount += maxi(1, amount / 5)
	Game.add_to_storage(produce, amount)
	if randf() < s.seed_back_chance:
		_add_seeds(crop, 1)
	if s.golden_harvest and randf() < 0.1:
		Game.add_to_storage("goldenApple", 1)
	Game.collection.roll_card(produce, 0.05)
	_set_bed(index, Farming.empty_bed())
	Game.save["cropsHarvested"] = int(Game.save.get("cropsHarvested", 0)) + 1
	Game.emit_event("crop", {"crop": crop, "amount": amount})
	Game.gain_xp(int(float(spec["xp"]) * s.harvest_xp_mult))
	return {"kind": produce, "amount": amount}


func ripe_beds() -> int:
	var t := now()
	var n := 0
	for i in bed_count():
		if Farming.is_ripe(bed(i), t):
			n += 1
	return n


func empty_beds() -> int:
	var n := 0
	for i in bed_count():
		if Farming.is_empty(bed(i)):
			n += 1
	return n


# MARK: Удобрения и лейка

func fertilizers(id: String) -> int:
	return int(Game.save["fertilizers"].get(id, 0))


## Выбранное удобрение, если оно ещё есть ("" - нет).
func chosen_fertilizer() -> String:
	var id := str(Game.save.get("selectedFertilizer", ""))
	if id == "" or fertilizers(id) <= 0:
		return ""
	return id


## "" снимает выбор.
func select_fertilizer(id: String) -> void:
	if str(Game.save.get("selectedFertilizer", "")) == id:
		return
	if id == "":
		Game.save.erase("selectedFertilizer")
	else:
		Game.save["selectedFertilizer"] = id
	Game.mark_dirty()


func _recipe(id: String, count: int) -> Dictionary:
	return Farming.scaled(Farming.FERTILIZERS[id]["recipe"], float(count))


func can_craft(id: String, count := 1) -> bool:
	return Game.level >= int(Farming.FERTILIZERS[id]["level"]) and Game.can_afford(_recipe(id, count))


func craft(id: String, count := 1) -> bool:
	if not can_craft(id, count):
		return false
	Game.pay(_recipe(id, count))
	Game.save["fertilizers"][id] = fertilizers(id) + count
	if chosen_fertilizer() == "":
		Game.save["selectedFertilizer"] = id
	Game.mark_dirty()
	return true


## Удобрить растущую грядку выбранным удобрением.
func fertilize(index: int, with_id := "") -> bool:
	var id := with_id if with_id != "" else chosen_fertilizer()
	if id == "" or fertilizers(id) <= 0:
		return false
	var b := bed(index).duplicate()
	var t := now()
	if Farming.is_empty(b) or b.get("fertilized", false) == true or Farming.is_ripe(b, t) or not b.has("plantedAt"):
		return false
	var f: Dictionary = Farming.FERTILIZERS[id]
	var cut := float(f["cut"])
	b["boost"] = float(b.get("boost", 0.0)) + maxf(0.0, Farming.ready_at(b) - t) * cut + (1.0 if cut >= 1.0 else 0.0)
	b["fertilized"] = true
	b["extra"] = int(b.get("extra", 0)) + int(f["extra"]) + Game.stats.fert_extra
	if randf() >= Game.stats.fert_save_chance:
		Game.save["fertilizers"][id] = fertilizers(id) - 1
	_set_bed(index, b)
	garden_events.append({"bed": index, "kind": "boosted"})
	return true


## Удобрить все растущие грядки, пока хватает удобрения.
func fertilize_all() -> int:
	var id := chosen_fertilizer()
	if id == "":
		return 0
	var n := 0
	for i in bed_count():
		if fertilizers(id) > 0 and fertilize(i, id):
			n += 1
	return n


## Сколько грядок можно удобрить прямо сейчас.
func fertilizable_beds() -> int:
	var t := now()
	var n := 0
	for i in bed_count():
		var b := bed(i)
		if not Farming.is_empty(b) and b.get("fertilized", false) != true and not Farming.is_ripe(b, t):
			n += 1
	return n


func can_level() -> int:
	return maxi(1, int(Game.save.get("canLevel", 1)))


## Цена следующего уровня лейки (пусто - лейка на максимуме).
func next_can_cost() -> Dictionary:
	var next := can_level() + 1
	return Farming.can_cost(next) if next <= Farming.CAN_MAX_LEVEL else {}


func can_upgrade_can() -> bool:
	var cost := next_can_cost()
	if cost.is_empty():
		return false
	return Game.level >= Farming.can_required_level(can_level() + 1) and Game.can_afford(cost)


func upgrade_can() -> void:
	if not can_upgrade_can():
		return
	Game.pay(next_can_cost())
	Game.save["canLevel"] = can_level() + 1
	Game.show_toast("px:watering_can", L.t("toast.can", [can_level()]))
	Game.mark_dirty()
	Game.save_now()


# MARK: Лавка

## Номер текущего дня по местной полуночи (как startOfDay в Swift).
static func today() -> int:
	return int(_day_start() / 86400.0)


## Когда обмены сменятся (следующая местная полночь), unix-секунды.
static func next_deals_at() -> float:
	return _day_start() + 86400.0


static func _day_start() -> float:
	var bias := float(Time.get_time_zone_from_system().get("bias", 0)) * 60.0
	return floor((now() + bias) / 86400.0) * 86400.0 - bias


## Три обмена дня: {id, give: [[вид, n]], coins_price, reward: {type: coins|ticket|seeds, n, crop}}.
## Одинаковые весь день, меняются в полночь.
func daily_deals() -> Array:
	var level := Game.level
	var rng := Farming.DayRandom.new(today() * 7919 + int(Game.save.get("rebirths", 0)) * 31 + level / 10)
	var pool: Array = Game.quests.gatherable_kinds().duplicate()
	pool.sort()
	if pool.is_empty():
		pool = ["wood", "stone"]
	var deals: Array = []

	# Ресурсы за монеты вдвое дороже обычной продажи
	var a: String = rng.pick(pool)
	var n := maxi(5, (40 + 15 * level) / maxi(1, Res.price(a)))
	deals.append({"id": 0, "give": [[a, n]], "coins_price": 0,
		"reward": {"type": "coins", "n": n * Game.sell_price(a) * 2}})

	# Ресурсы за билет в экспедицию
	var b: String = rng.pick(pool)
	var m := maxi(20, (700 + 60 * level) / maxi(1, Res.price(b)))
	deals.append({"id": 1, "give": [[b, m]], "coins_price": 0, "reward": {"type": "ticket"}})

	# Набор семян за полцены
	var crops := Farming.CROP_IDS.filter(func(c: String) -> bool: return int(Farming.spec(c)["level"]) <= level)
	var crop: String = "wheat" if crops.is_empty() else rng.pick(crops)
	deals.append({"id": 2, "give": [], "coins_price": maxi(1, int(Farming.spec(crop)["seed_price"]) * 6 / 2),
		"reward": {"type": "seeds", "crop": crop, "n": 6}})
	return deals


func _deal_cost(deal: Dictionary) -> Dictionary:
	return {"coins": int(deal["coins_price"]), "items": deal["give"]}


func deal_bought(deal: Dictionary) -> bool:
	return int(Game.save.get("dealsDay", 0)) == today() and int(deal["id"]) in Game.save.get("dealsBought", [])


func can_trade(deal: Dictionary) -> bool:
	return not deal_bought(deal) and Game.can_afford(_deal_cost(deal))


func trade(deal: Dictionary) -> bool:
	if not can_trade(deal):
		return false
	Game.pay(_deal_cost(deal))
	var reward: Dictionary = deal["reward"]
	match str(reward["type"]):
		"coins": Game.add_coins(int(reward["n"]))
		"ticket": Game.save["tickets"] = int(Game.save.get("tickets", 0)) + 1
		"seeds": _add_seeds(str(reward["crop"]), int(reward["n"]))
	var day := today()
	if int(Game.save.get("dealsDay", 0)) != day:
		Game.save["dealsDay"] = day
		Game.save["dealsBought"] = []
	Game.save["dealsBought"].append(int(deal["id"]))
	Game.emit_event("trade", {})
	Game.mark_dirty()
	return true


# MARK: Бродячий торговец

## Бродячий торговец приходит в локацию на три минуты с тремя редкими товарами.
## Товар: {id, goods: {type: ticket|map|seeds|resource, crop, kind, n}, price}.
func spawn_wanderer(location: String) -> void:
	var t := now()
	var rng := Farming.DayRandom.new(int(t) / 60)
	var level := Game.level
	var offers: Array = []
	if rng.next_mod(2) == 0:
		offers.append({"id": 0, "goods": {"type": "ticket"}, "price": 800 + 80 * level})
	else:
		offers.append({"id": 0, "goods": {"type": "map"}, "price": Farming.wanderer_map_price(level)})
	var crops := Farming.CROP_IDS.filter(func(c: String) -> bool: return int(Farming.spec(c)["level"]) <= level + 4)
	var crop: String = rng.pick(crops.slice(maxi(0, crops.size() - 4)))
	offers.append({"id": 1, "goods": {"type": "seeds", "crop": crop, "n": 6},
		"price": maxi(10, int(float(int(Farming.spec(crop)["seed_price"]) * 6) * 0.6))})
	var kind: String = rng.pick(Farming.WANDERER_RARE)
	var count := rng.int_in(2, 4)
	offers.append({"id": 2, "goods": {"type": "resource", "kind": kind, "n": count},
		"price": int(float(Game.sell_price(kind) * count) * 1.5)})
	wanderer = {"location": location, "until": t + Farming.WANDERER_STAY, "offers": offers, "bought": []}
	Game.changed.emit()


func dismiss_wanderer() -> void:
	wanderer = {}
	if trader_prompt == "wanderer":
		trader_prompt = ""
	Game.changed.emit()


func wanderer_bought(offer: Dictionary) -> bool:
	return wanderer.is_empty() or int(offer["id"]) in wanderer["bought"]


func buy_wanderer(offer: Dictionary) -> bool:
	var price := int(offer["price"])
	if wanderer_bought(offer) or int(Game.save["coins"]) < price:
		return false
	Game.save["coins"] = int(Game.save["coins"]) - price
	var goods: Dictionary = offer["goods"]
	match str(goods["type"]):
		"ticket": Game.save["tickets"] = int(Game.save.get("tickets", 0)) + 1
		"map": Game.save["maps"] = int(Game.save.get("maps", 0)) + 1
		"seeds": _add_seeds(str(goods["crop"]), int(goods["n"]))
		"resource": Game.add_to_storage(str(goods["kind"]), int(goods["n"]), false)
	wanderer["bought"].append(int(offer["id"]))
	Game.emit_event("trade", {})
	Game.mark_dirty()
	return true
