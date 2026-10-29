extends Node
## Состояние игры (порт GameState из iOS-версии). Весь прогресс лежит в словаре save
## с теми же ключами, что и в iOS-сохранении, чтобы файл копии подходил обеим версиям.

signal changed
signal toast(icon: String, text: String)
signal level_up(from_level: int, to_level: int)
## События для заданий и других систем: gather, harvest, deposit, sell, tame, kill, ...
signal event(name: String, data: Dictionary)

const SAVE_PATH := "user://save.json"
const MAX_LEVEL := 60
const MAX_ACTIVE_ANIMALS := 5

var save: Dictionary = {}
var stats := Stats.new()

var talents := TalentSystem.new()
var workshop := ToolSystem.new()
var animals := AnimalSystem.new()
var quests := QuestSystem.new()
var house := HouseSystem.new()
var garden := GardenSystem.new()
var combat := CombatSystem.new()
var dungeons := DungeonSystem.new()
var events := EventSystem.new()
var collection := CollectionSystem.new()
var legacy := LegacySystem.new()
var premium := PremiumSystem.new()
var world_map := WorldMapSystem.new()

## Все системы по порядку: для значений по умолчанию и событий.
var systems: Array:
	get: return [talents, workshop, animals, quests, house, garden, combat, dungeons, events, collection, legacy, premium, world_map]
## Где появиться после перехода через проход (id прохода).
var arrival_gate := ""
## В доме: у какой станции появиться (exit, up, down); на лугу - у двери дома.
var arrival_station := ""
var arrive_at_door := false

var _dirty := false
var _last_write := 0.0


func _ready() -> void:
	save = _load_save()
	for sys in systems:
		sys.defaults(save)
	event.connect(func(name: String, data: Dictionary) -> void:
		for sys in systems:
			if sys.has_method("on_event"):
				sys.on_event(name, data))
	recalc()
	process_mode = Node.PROCESS_MODE_ALWAYS


func emit_event(name: String, data := {}) -> void:
	event.emit(name, data)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		save_now()


# MARK: Сохранение

static func default_save() -> Dictionary:
	return {
		"level": 1, "xp": 0, "coins": 30,
		"storage": {}, "backpack": {},
		"tools": {"axe": 1, "pickaxe": 1, "rod": 1, "sword": 1, "armor": 1},
		"talents": {}, "unlocked": ["meadow"], "current": "meadow",
		"animals": {}, "active": [], "gathered": {},
		"harvests": 0, "coinsEarned": 0, "lastSeen": Time.get_unix_time_from_system(),
		"tutorialDone": false, "openGates": [], "tickets": 1, "bestLevel": 1,
		"skin": "farmer",
	}


func _load_save() -> Dictionary:
	var data := default_save()
	if FileAccess.file_exists(SAVE_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if parsed is Dictionary:
			for k in parsed:
				data[k] = parsed[k]
	# Числа из JSON приходят дробными: приводим счётчики к целым
	for key in ["level", "xp", "coins", "harvests", "coinsEarned", "tickets", "bestLevel"]:
		data[key] = int(data.get(key, 0))
	for dict_key in ["storage", "backpack", "tools", "talents", "animals", "gathered"]:
		var d: Dictionary = data.get(dict_key, {})
		for k in d.keys():
			d[k] = int(d[k])
		data[dict_key] = d
	if not "meadow" in data["unlocked"]:
		data["unlocked"].insert(0, "meadow")
	if not Locations.SPECS.has(str(data["current"])):
		data["current"] = "meadow"
	return data


func mark_dirty() -> void:
	_dirty = true
	changed.emit()


func save_if_needed() -> void:
	if _dirty and Time.get_ticks_msec() / 1000.0 - _last_write > 4.0:
		save_now()


func save_now() -> void:
	save["lastSeen"] = maxf(float(save.get("lastSeen", 0.0)), Time.get_unix_time_from_system())
	var f := FileAccess.open(SAVE_PATH + ".tmp", FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(save))
	f.close()
	DirAccess.rename_absolute(SAVE_PATH + ".tmp", SAVE_PATH)
	_dirty = false
	_last_write = Time.get_ticks_msec() / 1000.0


func show_toast(icon: String, text: String) -> void:
	toast.emit(icon, text)


# MARK: Уровень и опыт

static func xp_to_next(level: int) -> int:
	return int(round(22.0 * pow(float(level), 1.5)))


static func talent_points_at(level: int) -> int:
	return level + level / 10


static func capacity_at(level: int) -> int:
	return 30 + 5 * level


static func level_coin_reward(level: int) -> int:
	return 25 * level


var level: int:
	get: return int(save["level"])


var xp_needed: int:
	get: return xp_to_next(level)


var level_progress: float:
	get:
		if level >= MAX_LEVEL:
			return 1.0
		return minf(1.0, float(save["xp"]) / float(maxi(1, xp_needed)))


func gain_xp(base: int) -> void:
	if level >= MAX_LEVEL or base <= 0:
		return
	var amount := maxi(1, int(round(base * stats.xp_mult)))
	save["xp"] = int(save["xp"]) + amount
	var from := level
	while level < MAX_LEVEL and int(save["xp"]) >= xp_to_next(level):
		save["xp"] = int(save["xp"]) - xp_to_next(level)
		save["level"] = level + 1
		save["coins"] = int(save["coins"]) + level_coin_reward(level)
	if level >= MAX_LEVEL:
		save["xp"] = 0
	if level > int(save.get("bestLevel", 1)):
		save["bestLevel"] = level
	if level > from:
		recalc()
		level_up.emit(from, level)
		Sound.play("levelUp")
	mark_dirty()


# MARK: Ресурсы

func amount(kind: String) -> int:
	return int(save["storage"].get(kind, 0)) + int(save["backpack"].get(kind, 0))


func storage_of(kind: String) -> int:
	return int(save["storage"].get(kind, 0))


var backpack_count: int:
	get:
		var n := 0
		for v in save["backpack"].values():
			n += int(v)
		return n


var backpack_free: int:
	get: return maxi(0, stats.capacity - backpack_count)


## Кладёт добычу в рюкзак. Возвращает, сколько поместилось.
func add_to_backpack(kind: String, n: int) -> int:
	if n <= 0:
		return 0
	if stats.auto_deposit and backpack_free < n:
		var moved := deposit_backpack()
		if moved > 0:
			show_toast("px:portal", L.t("toast.portal", [moved]))
	var put := mini(n, backpack_free)
	if put <= 0:
		return 0
	save["backpack"][kind] = int(save["backpack"].get(kind, 0)) + put
	save["gathered"][kind] = int(save["gathered"].get(kind, 0)) + put
	emit_event("gather", {"kind": kind, "amount": put})
	mark_dirty()
	return put


func add_to_storage(kind: String, n: int, counts := true) -> int:
	if n <= 0:
		return 0
	save["storage"][kind] = int(save["storage"].get(kind, 0)) + n
	if counts:
		save["gathered"][kind] = int(save["gathered"].get(kind, 0)) + n
		emit_event("gather", {"kind": kind, "amount": n})
	mark_dirty()
	return n


func deposit_backpack() -> int:
	var total := backpack_count
	if total <= 0:
		return 0
	for kind in save["backpack"]:
		save["storage"][kind] = int(save["storage"].get(kind, 0)) + int(save["backpack"][kind])
	save["backpack"] = {}
	emit_event("deposit", {"amount": total})
	if stats.storekeeper_xp > 0:
		gain_xp(stats.storekeeper_xp * (total / 10))
	mark_dirty()
	return total


## Учитывает добычу: опыт и монеты "Золотого касания". Возвращает монеты.
func register_harvest(xp: int) -> int:
	save["harvests"] = int(save["harvests"]) + 1
	var coins := 0
	if stats.golden_touch:
		coins = int(round(float(1 + level / 5) * stats.gold_mult))
		add_coins(coins)
	emit_event("harvest", {"amount": 1})
	gain_xp(xp)
	return coins


func add_coins(n: int) -> void:
	if n <= 0:
		return
	save["coins"] = int(save["coins"]) + n
	save["coinsEarned"] = int(save["coinsEarned"]) + n
	mark_dirty()


func sell_price(kind: String) -> int:
	var bonus := 1.0 + float(stats.sell_category.get(Res.category(kind), 0.0))
	return maxi(1, int(round(Res.price(kind) * stats.sell_mult * bonus)))


func sell(kind: String, n: int) -> int:
	var have := storage_of(kind)
	var count := mini(n, have)
	if count <= 0:
		return 0
	save["storage"][kind] = have - count
	var earned := count * sell_price(kind)
	add_coins(earned)
	emit_event("sell", {"amount": earned})
	Sound.play("coin")
	return earned


# MARK: Инструменты

func tier(tool: String) -> int:
	return int(save["tools"].get(tool, 1))


func effective_tier(tool: String) -> int:
	return 1 if tool == "hand" else tier(tool) + stats.tool_bonus


func can_harvest(spec: Dictionary) -> bool:
	return spec["tool"] == "hand" or effective_tier(spec["tool"]) >= int(spec["tier"])


func damage_against(spec: Dictionary) -> float:
	var s := stats
	var base := 1.0
	match spec["tool"]:
		"hand": base = s.hand_mult * (1.0 + 0.04 * float(level - 1))
		"rod": base = Tools.power(effective_tier("rod")) * s.hand_mult
		"axe": base = Tools.power(effective_tier("axe")) * (1.0 + s.wood_bonus)
		"pickaxe": base = Tools.power(effective_tier("pickaxe")) * (1.0 + s.stone_bonus)
	if int(spec["tier"]) >= 5:
		base *= 1.0 + s.high_tier_bonus
	return base * s.damage_mult * s.node_mult


# MARK: Локации

var current: String:
	get: return str(save["current"])


func travel(to: String, via_gate := "") -> void:
	if to == current:
		return
	arrival_gate = via_gate
	save["current"] = to
	if not to in save["unlocked"]:
		save["unlocked"].append(to)
	mark_dirty()


# MARK: Характеристики

func can_afford(cost: Dictionary) -> bool:
	if int(save["coins"]) < int(cost.get("coins", 0)):
		return false
	for it in cost.get("items", []):
		if amount(it[0]) < int(it[1]):
			return false
	return true


## Списывает цену: сначала со склада, недостающее - из рюкзака.
func pay(cost: Dictionary) -> void:
	save["coins"] = int(save["coins"]) - int(cost.get("coins", 0))
	for it in cost.get("items", []):
		var kind: String = it[0]
		var need := int(it[1])
		var from_storage := mini(need, storage_of(kind))
		save["storage"][kind] = storage_of(kind) - from_storage
		need -= from_storage
		if need > 0:
			save["backpack"][kind] = maxi(0, int(save["backpack"].get(kind, 0)) - need)
	mark_dirty()


## Цена со скидкой "Бережливого".
func discounted(cost: Dictionary) -> Dictionary:
	var k := stats.discount
	var items: Array = []
	for it in cost.get("items", []):
		items.append([it[0], maxi(1, int(ceil(float(it[1]) * k)))])
	return {"coins": int(ceil(float(cost.get("coins", 0)) * k)), "items": items}


## Полный порт recalc() из Swift: таланты, наследие, уют, блюда, созвездия, звери, снаряжение, усиления ивента.
func recalc() -> void:
	var s := Stats.new()
	var r := func(id: String) -> float: return float(talents.rank(id))
	var lg := func(perk: String) -> float: return legacy.value(perk)
	var lvl := float(level)

	s.damage_mult = (1.0 + 0.02 * (lvl - 1.0)) * (1.0 + 0.12 * r.call("power"))
	s.wood_bonus = 0.2 * r.call("lumberjack")
	s.stone_bonus = 0.2 * r.call("miner")
	s.high_tier_bonus = 0.15 * r.call("crusher")
	s.hand_mult = 1.0 + 0.4 * r.call("strongHands")
	s.hit_interval = 0.55 / ((1.0 + 0.07 * r.call("quickHands")) * (1.0 + 0.05 * r.call("tireless")))
	s.crit_mult = 2.0 + 0.3 * r.call("critPower")
	s.shatter_chance = 0.04 * r.call("shatter")
	s.double_strike_chance = 0.05 * r.call("doubleStrike")
	s.execute_threshold = 0.06 * r.call("execute")
	s.quake = r.call("quake") > 0
	s.quake_power = 0.4 * (1.0 + 0.25 * r.call("shockwave"))
	s.quake_radius = 110.0 * (1.0 + 0.25 * r.call("shockwave"))
	s.tool_bonus = 1 if r.call("toolMaster") > 0 else 0
	# Суперталант "Титан" и ряд за ним
	s.titan = r.call("titan") > 0
	s.node_mult = (1.25 if r.call("titan") > 0 else 1.0) * (1.0 + 0.1 * r.call("mountainBreaker"))
	s.crit_mult += 0.25 * r.call("keenEdge")

	s.yield_all = 0.1 * r.call("bounty") + 0.06 * r.call("fertile") + (0.1 if r.call("abundance") > 0 else 0.0) \
		+ (PremiumSystem.CAPYBARA_YIELD if premium.owns("garden") else 0.0)
	s.yield_category["food"] = 0.2 * r.call("farmer")
	s.yield_category["crop"] = 0.2 * r.call("farmer")
	s.yield_category["ore"] = 0.1 * r.call("oreHunter")
	s.yield_category["gem"] = 0.1 * r.call("oreHunter")
	s.regrow_chance = 0.06 * r.call("gardener")
	s.double_chance = 0.05 * r.call("doubleDrop")
	s.triple_chance = 0.03 * r.call("triple")
	s.finder_chance = 0.04 * r.call("finder")
	s.gem_chance = 0.015 * r.call("gemFinder")
	s.golden_touch = r.call("goldenTouch") > 0
	# Суперталант "Рог изобилия" и ряд за ним
	s.cornucopia = r.call("cornucopia") > 0
	s.yield_all += 0.15 if r.call("cornucopia") > 0 else 0.0
	s.triple_chance += 0.02 * r.call("fortune")
	_add(s.yield_category, "food", 0.12 * r.call("forager"))
	_add(s.yield_category, "wood", 0.12 * r.call("forager"))
	var motherlode: float = 0.12 * r.call("motherlode")
	_add(s.yield_category, "stone", motherlode)
	_add(s.yield_category, "ore", motherlode)
	_add(s.yield_category, "gem", motherlode)
	s.gold_mult = 1.0 + 0.5 * r.call("goldRush")
	var jeweler: float = 0.15 * r.call("jeweler")
	s.sell_category["ore"] = jeweler
	s.sell_category["gem"] = jeweler
	s.sell_category["treasure"] = jeweler

	s.reach = Stats.BASE_REACH * (1.0 + 0.12 * r.call("reach"))
	s.deposit_radius = 92.0 * (1.0 + 0.3 * r.call("depotReach"))
	s.tame_mult = (1.0 - 0.15 * r.call("tamer")) * (1.0 - 0.1 * r.call("catcher")) * (1.0 - 0.08 * r.call("charmer"))
	s.shop_mult = 1.0 - 0.08 * r.call("bargain")
	s.spawn_mult = (1.0 + 0.25 * r.call("tamer")) * (1.0 + 0.2 * r.call("tracker")) * (1.0 + 0.12 * r.call("pathfinder"))
	s.keep_pack = r.call("windwalker") > 0
	s.storekeeper_xp = int(r.call("storekeeper"))
	s.discount = 1.0 - 0.07 * r.call("thrift")
	s.auto_deposit = r.call("portal") > 0 or premium.has_pro()

	# Сила зверей складывается, а не перемножается
	s.animal_mult = 1.0 + 0.12 * r.call("beastBond") + 0.05 * r.call("animalFriend") + (0.3 if r.call("soul") > 0 else 0.0) \
		+ 0.05 * r.call("kinship")
	s.helper_mult = (1.0 + 0.25 * r.call("packLeader")) * (1.0 + 0.1 * r.call("alpha")) * (1.0 + 0.1 * r.call("packHunt"))
	s.helper_speed = 1.0 + 0.08 * r.call("training")
	s.helper_range = 260.0 * (1.0 + 0.2 * r.call("keenEye"))
	s.helper_tier_bonus = int(r.call("packTier"))
	s.helper_yield = 1.0 + 0.15 * r.call("beastLoot")
	s.producer_mult = (1.0 + 0.2 * r.call("nightShift")) * (1.0 + 0.1 * r.call("herdsman")) * (1.0 + 0.1 * r.call("herd"))
	s.double_product_chance = 0.08 * r.call("rancher")
	s.offline_hours = (PremiumSystem.PRO_OFFLINE_HOURS if premium.has_pro() else 6.0) + 2.0 * r.call("pasture")
	s.star_step = 0.25 + 0.05 * r.call("starFood")
	s.double_star_chance = 0.15 * r.call("starHunter")

	# Огород
	s.grow_mult = 1.0 / (1.0 + 0.06 * r.call("greenThumb"))
	s.extra_crop_chance = 0.12 * r.call("bigHarvest")
	s.seed_back_chance = 0.08 * r.call("seedSaver")
	s.water_mult = 1.0 + 0.15 * r.call("rainmaker")
	s.fert_save_chance = 0.12 * r.call("composter")
	s.fert_extra = int(r.call("deepRoots"))
	s.meal_mult = 1.0 + 0.15 * r.call("chef")
	s.cook_mult = 1.0 - 0.1 * r.call("quickCook")
	_add(s.sell_category, "crop", 0.1 * r.call("marketDay"))
	s.seed_mult = 1.0 - 0.06 * r.call("seedTrader")
	_add(s.sell_category, "crop", 0.06 * r.call("seedTrader"))
	s.golden_harvest = r.call("goldenHarvest") > 0
	s.harvest_xp_mult = 2.0 if r.call("harvestMoon") > 0 else 1.0
	# Суперталант "Хозяин земли" и ряд за ним
	if r.call("landlord") > 0:
		s.grow_mult /= 1.25
		s.extra_crop_chance += 0.2
	_add(s.yield_category, "crop", 0.12 * r.call("richSoil"))
	_add(s.sell_category, "crop", 0.1 * r.call("fairTrade"))

	# Бой
	var warlord := 0.15 if r.call("warlord") > 0 else 0.0
	s.hp_mult = (1.0 + 0.08 * r.call("toughness")) * (1.0 + warlord)
	s.weapon_mult = (1.0 + 0.07 * r.call("bladeMaster")) * (1.0 + warlord)
	s.defense_bonus = 0.03 * r.call("stance")
	s.dodge_bonus = 0.02 * r.call("evasion")
	s.lifesteal = 0.02 * r.call("vampirism")
	s.potion_bonus = 0.1 * r.call("alchemist")
	s.berserk = 0.12 * r.call("berserk")
	s.boss_bonus = 0.08 * r.call("bossSlayer")
	s.last_stand = r.call("lastStand") > 0
	s.dungeon_bonus = 0.1 * r.call("delver")
	s.regen = 0.005 * r.call("regen")
	# Суперталант "Чемпион" и ряд за ним
	if r.call("champion") > 0:
		s.weapon_mult *= 1.2
		s.hp_mult *= 1.2
		s.kill_heal = 0.04
	s.defense_bonus += 0.03 * r.call("fortress")
	s.boss_bonus += 0.1 * r.call("executioner")
	s.lifesteal += 0.01 * r.call("bloodlust")

	# Наследие: вечные бонусы за перерождения
	s.yield_all += lg.call("harvest")
	s.weapon_mult *= 1.0 + lg.call("fighter")
	s.hp_mult *= 1.0 + lg.call("vigor")
	s.grow_mult /= 1.0 + lg.call("gardener")
	s.meal_mult *= 1.0 + lg.call("chef")
	# Уют дома и блюда, которые сейчас действуют
	var cozy := house.comfort_bonus()
	s.yield_all += cozy
	var meal := {"yield": 0.0, "xp": 0.0, "speed": 0.0, "sell": 0.0, "crit": 0.0, "animals": 0.0}
	var gourmet: float = 1.0 + 0.1 * r.call("gourmet")
	for dish in house.active_meals():
		var b: Dictionary = house.meal_buff(dish)
		for k in meal:
			meal[k] += float(b.get(k, 0.0)) * gourmet
	s.yield_all += meal["yield"]
	# Созвездия
	var c_harvest := collection.constellation_bonus("harvest")
	var c_forest := collection.constellation_bonus("forest")
	var c_depths := collection.constellation_bonus("depths")
	var c_sea := collection.constellation_bonus("sea")
	_add(s.yield_category, "crop", c_harvest)
	_add(s.yield_category, "wood", c_forest)
	_add(s.yield_category, "food", c_forest)
	_add(s.yield_category, "stone", c_depths)
	_add(s.yield_category, "ore", c_depths)
	_add(s.yield_category, "gem", c_depths)
	_add(s.yield_kind, "fish", c_sea)
	_add(s.yield_category, "treasure", c_sea)
	s.sword_mult = 1.0 + collection.constellation_bonus("monsters")
	s.animal_mult += collection.constellation_bonus("beasts")
	s.grow_mult /= 1.0 + collection.constellation_bonus("garden")
	s.weapon_mult *= 1.0 + collection.constellation_bonus("dungeon")
	s.producer_mult *= 1.0 + collection.constellation_bonus("birds")
	if house.is_built("upper"):
		s.offline_hours += 2.0

	var speed_bonus: float = 0.07 * r.call("swift") + 0.05 * r.call("tailwind") + lg.call("boots")
	var crit_bonus: float = 0.05 * r.call("crit") + lg.call("luck")
	var respawn_bonus: float = 0.08 * r.call("regrowth") + (0.5 if r.call("abundance") > 0 else 0.0) + lg.call("growth")
	var xp_bonus: float = 0.1 * r.call("scholar") + 0.06 * r.call("sage") + lg.call("wisdom") + cozy + meal["xp"] \
		+ collection.constellation_bonus("sky") + 0.08 * r.call("enlightened")
	var sell_bonus: float = 0.08 * r.call("trader") + lg.call("merchant") + meal["sell"] + 0.06 * r.call("haggler") \
		+ (0.1 if r.call("windwalker") > 0 else 0.0)
	speed_bonus += meal["speed"]
	crit_bonus += meal["crit"]
	s.animal_mult += meal["animals"]
	var capacity: float = float(capacity_at(level)) + 15.0 * r.call("bigPack") \
		+ (float(PremiumSystem.STARTER_BACKPACK) if premium.owns("starter") else 0.0) + lg.call("pack")

	for id in save.get("active", []):
		var m := s.star_multiplier(int(save["animals"].get(id, 1))) * s.animal_mult * animals.boost(id)
		for e in animals.effects(id):
			var v := float(e.get("v", 0.0))
			match e["type"]:
				"xp": xp_bonus += v * m
				"yield":
					if str(e.get("cat", "")) != "":
						_add(s.yield_category, e["cat"], v * m)
					else:
						s.yield_all += v * m
				"yieldKind": _add(s.yield_kind, e["kind"], v * m)
				"speed": speed_bonus += v * m
				"respawn": respawn_bonus += v * m
				"crit": crit_bonus += v * m
				"backpack": capacity += v * m
				"sell": sell_bonus += v * m
				"produce": s.producers.append({"animal": id, "kind": e["kind"], "interval": float(e["interval"]) / m})
				"helper": s.helpers.append({"animal": id, "spec": e["spec"], "damage": float(e["spec"]["damage"]) * m})

	# Снаряжение: бонусы ступеней и особое оружие
	var crit_before := s.crit_chance
	var g: Dictionary = combat.collect_gear(s)
	crit_bonus += s.crit_chance - crit_before
	speed_bonus += float(g.get("speed", 0.0)) + combat.hero_speed(tier("boots"))
	if str(save.get("weapon", "forged")) == "boneSaber":
		crit_bonus += 0.1
		s.crit_mult += 0.2
	combat.gear = g

	# Усиления этапов ивента (только на его картах)
	if Locations.kind(current) == "event":
		s.damage_mult *= 1.0 + events.boon("damage")
		s.hp_mult *= 1.0 + events.boon("vitality")
		speed_bonus += events.boon("swift")
		crit_bonus += events.boon("lucky")
		s.regen += events.boon("regen")
		respawn_bonus += events.boon("regrowth")

	var strider := 1.25 if r.call("strider") > 0 else 1.0
	capacity *= (1.0 + 0.1 * r.call("packMaster")) * strider
	if r.call("windwalker") > 0:
		speed_bonus += 0.15
	s.speed = Stats.BASE_SPEED * minf(Stats.MAX_SPEED_MULT, (1.0 + speed_bonus) * strider)
	s.crit_chance = minf(0.75, crit_bonus)
	s.respawn_mult = 1.0 / (1.0 + respawn_bonus)
	s.xp_mult = 1.0 + xp_bonus
	s.sell_mult = 1.0 + 0.01 * (lvl - 1.0) + sell_bonus
	s.capacity = int(capacity)
	stats = s


static func _add(d: Dictionary, key: String, v: float) -> void:
	d[key] = float(d.get(key, 0.0)) + v
