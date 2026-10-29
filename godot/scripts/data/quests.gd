class_name Quests
## Задания доски и постоянные достижения (порт Quests.swift).
## Задание - словарь как в iOS-сохранении: id (UUID), type, resource (только у сбора), target, progress, coins, xp.

const TYPES := ["gather", "harvest", "sell", "deposit", "tame", "treasure"]

## Иконки заданий (в iOS эмодзи: ⛏️ 🪙 📦 🐾 🎁), у сбора - иконка ресурса.
const ICONS := {
	"gather": "tool_pickaxe", "harvest": "tool_pickaxe", "sell": "coins",
	"deposit": "chest", "tame": "paw", "treasure": "chest_gold",
}

## Звери из покупок не считаются в достижении "Звери".
const PREMIUM_ANIMALS := ["duckHat"]
## Сколько всего зверей без премиальных (в iOS считается по таблице зверей).
const ANIMALS_TOTAL := 15

static var _all: Array = []


# MARK: Задания

static func kind(q: Dictionary) -> String:
	var r = q.get("resource")
	return r if r is String and r in Res.KINDS else ""


static func is_done(q: Dictionary) -> bool:
	return int(q.get("progress", 0)) >= int(q.get("target", 0))


static func fraction(q: Dictionary) -> float:
	return minf(1.0, float(q.get("progress", 0)) / float(maxi(1, int(q.get("target", 0)))))


## Иконка для UiKit.icon_any.
static func icon(q: Dictionary) -> String:
	if q["type"] == "gather" and kind(q) != "":
		return "res:" + kind(q)
	return "px:" + str(ICONS.get(q["type"], "quest"))


static func title(q: Dictionary) -> String:
	var target := int(q.get("target", 0))
	match q["type"]:
		"gather":
			var k := kind(q)
			return L.t("quest.gather", [Res.name_of(k) if k != "" else ""])
		"harvest": return L.t("quest.harvest", [Fmt.n(target)])
		"sell": return L.t("quest.sell", [Fmt.n(target)])
		"deposit": return L.t("quest.deposit", [Fmt.n(target)])
		"tame": return L.t("quest.tame")
		_: return L.t("quest.treasures", [target]) if target > 1 else L.t("quest.treasure")


## Новое задание (порт Quest.make): не повторяет типы и ресурсы из avoid, кроме сбора.
static func make(level: int, available: Array, producers: Array, avoid: Array) -> Dictionary:
	var used_types: Array = []
	var used_kinds: Array = []
	for q in avoid:
		used_types.append(q["type"])
		if kind(q) != "":
			used_kinds.append(kind(q))
	var options: Array = ["gather", "gather", "harvest", "sell", "deposit", "gather", "treasure"]
	if level >= 2:
		options.append("tame")
	options = options.filter(func(t: String) -> bool: return t == "gather" or not t in used_types)
	var type: String = options.pick_random() if not options.is_empty() else "gather"
	var xp_base := float(Game.xp_to_next(level))
	var lvl := float(level)

	match type:
		"gather":
			var pool: Array = (available + producers).filter(func(k: String) -> bool: return not k in used_kinds)
			var k: String = pool.pick_random() if not pool.is_empty() else "wood"
			var price := Res.price(k)
			var raw := (40.0 + lvl * 6.0) / pow(float(price), 0.55)
			var target := maxi(5, int(round(raw / 5.0)) * 5)
			return _quest("gather", k, target, int(float(target * price) * 1.5) + level * 20, int(xp_base * 0.18))
		"harvest":
			return _quest("harvest", "", 20 + level * 2, 40 + level * 30, int(xp_base * 0.2))
		"sell":
			var target := maxi(100, int(round(pow(lvl, 1.5) * 40.0 / 50.0)) * 50)
			return _quest("sell", "", target, target / 4 + level * 10, int(xp_base * 0.15))
		"deposit":
			return _quest("deposit", "", 50 + level * 10, 30 + level * 25, int(xp_base * 0.18))
		"tame":
			return _quest("tame", "", 1, 100 + level * 40, int(xp_base * 0.25))
		_:
			return _quest("treasure", "", 2 if level >= 15 else 1, 60 + level * 30, int(xp_base * 0.2))


static func _quest(type: String, resource: String, target: int, coins: int, xp: int) -> Dictionary:
	var q := {"id": uuid(), "type": type, "target": target, "progress": 0, "coins": coins, "xp": xp}
	if resource != "":
		q["resource"] = resource
	return q


## Случайный UUID в записи Swift (UUID().uuidString).
static func uuid() -> String:
	var b := PackedByteArray()
	for i in 16:
		b.append(randi() % 256)
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	var h := b.hex_encode().to_upper()
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]


# MARK: Достижения

## Все достижения: {id, family, icon, metric, arg, target, coins, points}.
## Иконки - пиксельные вместо эмодзи iOS.
static func achievements() -> Array:
	if not _all.is_empty():
		return _all
	var list: Array = []
	_family(list, "wood", "tool_axe", "gathered", "wood", [200, 2_000, 20_000, 100_000],
		[100, 1_000, 8_000, 30_000], [0, 0, 1, 1])
	_family(list, "stone", "stone", "gathered", "stone", [200, 2_000, 20_000],
		[100, 1_000, 8_000], [0, 0, 1])
	_family(list, "ore", "tool_pickaxe", "category", "ore", [100, 1_500, 15_000],
		[300, 3_000, 20_000], [0, 1, 1])
	_family(list, "gem", "gem", "category", "gem", [20, 300, 3_000],
		[1_000, 10_000, 60_000], [0, 1, 1])
	_family(list, "fish", "tool_rod", "gathered", "fish", [50, 800, 8_000],
		[200, 3_000, 20_000], [0, 0, 1])
	_family(list, "food", "apples", "category", "food", [300, 3_000, 30_000],
		[150, 2_000, 15_000], [0, 0, 1])
	_family(list, "farm", "egg", "category", "farm", [50, 600, 6_000],
		[300, 3_000, 20_000], [0, 0, 1])
	_family(list, "treasure", "shell", "category", "treasure", [100, 2_000],
		[5_000, 50_000], [0, 1])
	_family(list, "harvest", "fist", "harvests", "", [500, 5_000, 25_000, 100_000],
		[200, 2_000, 10_000, 40_000], [0, 1, 1, 1])
	_family(list, "coins", "moneybag", "coinsEarned", "", [2_000, 100_000, 2_000_000],
		[200, 5_000, 50_000], [0, 1, 1])
	_family(list, "animals", "paw", "animals", "", [3, 8, ANIMALS_TOTAL],
		[300, 5_000, 50_000], [0, 1, 2])
	_family(list, "stars", "star", "stars", "", [10, 50, 120],
		[500, 5_000, 30_000], [0, 1, 1])
	_family(list, "locations", "map", "locations", "", [3, 6, Locations.world().size()],
		[500, 5_000, 50_000], [0, 1, 2])
	_family(list, "level", "trophy", "level", "", [10, 25, 40, 60],
		[500, 4_000, 20_000, 100_000], [1, 1, 1, 2])
	_family(list, "tools", "tool_hammer", "minTool", "", [3, 6, 8],
		[500, 8_000, 60_000], [0, 1, 2])
	_family(list, "talents", "stardust", "talents", "", [10, 35, 70],
		[300, 4_000, 30_000], [0, 1, 1])
	_family(list, "quests", "scroll", "quests", "", [10, 60, 250],
		[500, 5_000, 40_000], [0, 1, 1])
	_family(list, "chests", "chest_gold", "treasures", "", [10, 100],
		[500, 10_000], [0, 1])
	_family(list, "crops", "wheat", "category", "crop", [50, 600, 6_000],
		[300, 3_000, 20_000], [0, 1, 1])
	_family(list, "house", "door", "floors", "", [2, 4],
		[1_000, 10_000], [1, 1])
	_family(list, "kills", "swords", "kills", "", [20, 200, 2_000],
		[300, 4_000, 30_000], [0, 1, 1])
	_all = list
	return _all


static func _family(list: Array, key: String, icon_name: String, metric: String, arg: String,
		targets: Array, coins: Array, points: Array) -> void:
	for i in targets.size():
		list.append({
			"id": "%s_%d" % [key, i + 1], "family": key, "icon": icon_name, "metric": metric, "arg": arg,
			"target": int(targets[i]), "coins": int(coins[mini(i, coins.size() - 1)]),
			"points": int(points[mini(i, points.size() - 1)]),
		})


static func achievement_title(a: Dictionary) -> String:
	return L.t("ach." + str(a["id"]))


static func achievement_detail(a: Dictionary) -> String:
	return L.t("ach." + str(a["family"]) + ".detail", [Fmt.n(int(a["target"]))])


## Прогресс достижения по статистике сохранения.
static func progress(a: Dictionary) -> int:
	var s := Game.save
	match a["metric"]:
		"gathered":
			return int(s.get("gathered", {}).get(a["arg"], 0))
		"category":
			var sum := 0
			var gathered: Dictionary = s.get("gathered", {})
			for k in gathered:
				if Res.category(k) == a["arg"]:
					sum += int(gathered[k])
			return sum
		"harvests": return int(s.get("harvests", 0))
		"coinsEarned": return int(s.get("coinsEarned", 0))
		"animals":
			var n := 0
			for id in s.get("animals", {}):
				if not id in PREMIUM_ANIMALS:
					n += 1
			return n
		"stars":
			var stars := 0
			for v in s.get("animals", {}).values():
				stars += int(v)
			return stars
		"locations": return s.get("unlocked", []).size()
		"level": return Game.level
		"minTool":
			var low := 1 << 30
			for t in Tools.GATHERING:
				low = mini(low, Game.tier(t))
			return low
		"talents":
			return int(Game.talents.call("points_spent")) if Game.talents.has_method("points_spent") else 0
		"quests": return int(s.get("questsDone", 0))
		"treasures": return int(s.get("treasures", 0))
		"floors": return s.get("houseFloors", ["ground"]).size()
		"kills": return int(s.get("kills", 0))
	return 0
