extends Node
## Состояние игры (порт GameState из iOS-версии). Весь прогресс лежит в словаре save
## с теми же ключами, что и в iOS-сохранении, чтобы файл копии подходил обеим версиям.

signal changed
signal toast(icon: String, text: String)
signal level_up(from_level: int, to_level: int)

const SAVE_PATH := "user://save.json"
const MAX_LEVEL := 60
const MAX_ACTIVE_ANIMALS := 5

var save: Dictionary = {}
var stats := Stats.new()
## Где появиться после перехода через проход (id прохода).
var arrival_gate := ""

var _dirty := false
var _last_write := 0.0


func _ready() -> void:
	save = _load_save()
	recalc()
	process_mode = Node.PROCESS_MODE_ALWAYS


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
	mark_dirty()
	return put


func add_to_storage(kind: String, n: int, counts := true) -> int:
	if n <= 0:
		return 0
	save["storage"][kind] = int(save["storage"].get(kind, 0)) + n
	if counts:
		save["gathered"][kind] = int(save["gathered"].get(kind, 0)) + n
	mark_dirty()
	return n


func deposit_backpack() -> int:
	var total := backpack_count
	if total <= 0:
		return 0
	for kind in save["backpack"]:
		save["storage"][kind] = int(save["storage"].get(kind, 0)) + int(save["backpack"][kind])
	save["backpack"] = {}
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

func recalc() -> void:
	var s := Stats.new()
	var lvl := float(level)
	s.damage_mult = 1.0 + 0.02 * (lvl - 1.0)
	s.capacity = capacity_at(level)
	s.sell_mult = 1.0 + 0.01 * (lvl - 1.0)
	s.speed = Stats.BASE_SPEED
	s.xp_mult = 1.0
	s.respawn_mult = 1.0
	stats = s
