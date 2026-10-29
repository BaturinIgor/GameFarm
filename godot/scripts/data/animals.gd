class_name Animals
## Звери: что дают, где водятся, сколько стоят (порт Animals.swift, Awakening и Shiny из Collection.swift).
## Эффекты - словари в формате recalc: {"type", "v", "cat", "kind", "interval", "spec"}.

const MAX_STARS := 5

const IDS := [
	# Лавка
	"chicken", "cow", "horse", "sheep", "bee", "rooster", "pig", "unicorn",
	# Дикие
	"mouse", "goose", "duck", "frog", "butterfly", "swan", "goldenGoose",
	# Из стартового набора
	"duckHat",
]

## Старые звери из прошлых версий: во что они превращаются в сохранении.
const MIGRATION := {
	"dog": "mouse", "cat": "butterfly", "hamster": "horse", "turkey": "chicken", "owl": "rooster", "llama": "sheep",
	"panda": "pig", "rabbit": "mouse", "squirrel": "mouse", "goat": "goose", "hedgehog": "goose", "beaver": "goose",
	"otter": "duck", "turtle": "swan", "crocodile": "pig", "camel": "horse", "lizard": "butterfly", "penguin": "duck",
	"fox": "swan", "polarBear": "pig", "bat": "butterfly", "dragon": "unicorn", "parrot": "butterfly", "monkey": "pig",
	"crab": "duck", "phoenix": "goldenGoose", "lavasaur": "unicorn", "eagle": "swan", "dove": "goldenGoose", "lion": "duckHat",
}

## source: "shop" (price, level), "wild" (location, cost, weight) или "premium" (только из платного набора).
const SPECS := {
	"chicken": {"emoji": "🐔", "source": "shop", "price": 200, "level": 2,
		"effects": [{"type": "produce", "kind": "egg", "interval": 25.0}]},
	"cow": {"emoji": "🐄", "source": "shop", "price": 700, "level": 5,
		"effects": [{"type": "produce", "kind": "milk", "interval": 35.0}]},
	"horse": {"emoji": "🐎", "source": "shop", "price": 1200, "level": 8,
		"effects": [{"type": "speed", "v": 0.12}, {"type": "backpack", "v": 20}]},
	"sheep": {"emoji": "🐑", "source": "shop", "price": 1600, "level": 11,
		"effects": [{"type": "produce", "kind": "wool", "interval": 40.0}]},
	"bee": {"emoji": "🐝", "source": "shop", "price": 2500, "level": 14,
		"effects": [{"type": "produce", "kind": "honey", "interval": 45.0}, {"type": "yield", "cat": "food", "v": 0.1}]},
	"rooster": {"emoji": "🐓", "source": "shop", "price": 5000, "level": 18,
		"effects": [{"type": "helper", "spec": {"damage": 4.0, "interval": 1.0, "tools": ["hand", "axe", "pickaxe"], "max_tier": 4}},
			{"type": "xp", "v": 0.1}]},
	"pig": {"emoji": "🐖", "source": "shop", "price": 15000, "level": 26,
		"effects": [{"type": "helper", "spec": {"damage": 12.0, "interval": 1.2, "tools": ["hand", "axe", "pickaxe"], "max_tier": 6}},
			{"type": "yield", "cat": "food", "v": 0.15}]},
	"unicorn": {"emoji": "🦄", "source": "shop", "price": 60000, "level": 40,
		"effects": [{"type": "helper", "spec": {"damage": 28.0, "interval": 1.0, "tools": ["hand", "axe", "pickaxe", "rod"], "max_tier": 8}},
			{"type": "yield", "v": 0.12}, {"type": "xp", "v": 0.15}]},

	"mouse": {"emoji": "🐁", "source": "wild", "location": "meadow", "weight": 1.0,
		"cost": {"coins": 0, "items": [["berries", 20], ["apples", 10]]},
		"effects": [{"type": "helper", "spec": {"damage": 1.0, "interval": 1.1, "tools": ["hand", "axe"], "max_tier": 2}},
			{"type": "yield", "cat": "food", "v": 0.05}]},
	"goose": {"emoji": "🪿", "source": "wild", "location": "hills", "weight": 1.0,
		"cost": {"coins": 0, "items": [["carrots", 25], ["berries", 20]]},
		"effects": [{"type": "helper", "spec": {"damage": 2.5, "interval": 1.1, "tools": ["hand", "pickaxe"], "max_tier": 3}},
			{"type": "crit", "v": 0.02}]},
	"duck": {"emoji": "🦆", "source": "wild", "location": "lake", "weight": 1.0,
		"cost": {"coins": 0, "items": [["fish", 25], ["carrots", 20]]},
		"effects": [{"type": "helper", "spec": {"damage": 3.5, "interval": 1.1, "tools": ["rod", "hand"], "max_tier": 4}},
			{"type": "produce", "kind": "feather", "interval": 40.0}]},
	"frog": {"emoji": "🐸", "source": "wild", "location": "swamp", "weight": 1.0,
		"cost": {"coins": 0, "items": [["herbs", 30], ["mushrooms", 30]]},
		"effects": [{"type": "respawn", "v": 0.12}, {"type": "yield", "cat": "food", "v": 0.12}]},
	"butterfly": {"emoji": "🦋", "source": "wild", "location": "desert", "weight": 1.0,
		"cost": {"coins": 0, "items": [["cactus", 30], ["coconut", 20]]},
		"effects": [{"type": "xp", "v": 0.2}, {"type": "sell", "v": 0.06}]},
	"swan": {"emoji": "🦢", "source": "wild", "location": "snow", "weight": 1.0,
		"cost": {"coins": 0, "items": [["fish", 80], ["ice", 30]]},
		"effects": [{"type": "crit", "v": 0.05}, {"type": "backpack", "v": 40}]},
	"goldenGoose": {"emoji": "🪿", "source": "wild", "location": "caves", "weight": 0.4,
		"cost": {"coins": 0, "items": [["crystal", 10], ["diamond", 10], ["coconut", 50]]},
		"effects": [{"type": "produce", "kind": "gold", "interval": 40.0}, {"type": "yield", "cat": "gem", "v": 0.12}]},

	"duckHat": {"emoji": "🦆", "source": "premium",
		"effects": [{"type": "yield", "v": 0.08}, {"type": "xp", "v": 0.1}, {"type": "sell", "v": 0.1}]},
}

# Пробуждение зверей
const AWAKEN_MAX := 3
const AWAKEN_COSTS := [
	{"coins": 2500, "items": [["slime", 20], ["bone", 10]]},
	{"coins": 9000, "items": [["crystal", 15], ["bone", 40]]},
	{"coins": 30000, "items": [["stardust", 8], ["ruby", 8]]},
]
## Цвет ауры: бронза, серебро, золото.
const AWAKEN_COLORS := [Color("cd7f32"), Color("d8dee8"), Color("ffd54a")]

# Редкая окраска: 3% диких зверей бывают другого цвета
const SHINY_CHANCE := 0.03
const SHINY_BONUS := 0.1
## Цвет перекраски: зверь становится сиреневым с переливом.
const SHINY_TINT := Color(0.75, 0.45, 1.0)


static func spec(id: String) -> Dictionary:
	return SPECS.get(id, {})


static func name_of(id: String) -> String:
	return L.t("animal." + id)


## Id из сохранения с учётом старых зверей ("" - такого нет).
static func from(raw: String) -> String:
	if SPECS.has(raw):
		return raw
	return MIGRATION.get(raw, "")


## Множитель силы зверя от звёзд. step - прибавка за каждую звезду после первой.
static func star_multiplier(stars: int, step := 0.25) -> float:
	return 1.0 + step * float(maxi(1, stars) - 1)


static func effects(id: String) -> Array:
	return spec(id).get("effects", [])


static func _has_effect(id: String, type: String) -> bool:
	for e in effects(id):
		if e["type"] == type:
			return true
	return false


static func is_helper(id: String) -> bool:
	return _has_effect(id, "helper")


static func is_producer(id: String) -> bool:
	return _has_effect(id, "produce")


static func role(id: String) -> String:
	if is_helper(id):
		return L.t("role.helper")
	if is_producer(id):
		return L.t("role.producer")
	return L.t("role.bonus")


static func is_premium(id: String) -> bool:
	return spec(id).get("source", "") == "premium"


## Уровень, с которого зверь продаётся в лавке (-1 - не продаётся).
static func shop_level(id: String) -> int:
	var s := spec(id)
	return int(s["level"]) if s.get("source", "") == "shop" else -1


static func shop_base_price(id: String) -> int:
	var s := spec(id)
	return int(s["price"]) if s.get("source", "") == "shop" else -1


## Где водится дикий зверь ("" - не дикий).
static func wild_location(id: String) -> String:
	var s := spec(id)
	return str(s["location"]) if s.get("source", "") == "wild" else ""


static func wild_weight(id: String) -> float:
	return float(spec(id).get("weight", 1.0))


## Базовая цена приручения ({} - не дикий).
static func wild_cost(id: String) -> Dictionary:
	var s := spec(id)
	return s["cost"] if s.get("source", "") == "wild" else {}


## Текст эффекта с учётом силы зверя m. Эмодзи ресурсов и инструментов в шрифте нет:
## их место пустое, окна ставят рядом пиксельные иконки (см. effect_icons).
static func effect_text(e: Dictionary, m: float) -> String:
	var v := float(e.get("v", 0.0))
	var out := ""
	match e["type"]:
		"xp": out = L.t("effect.xp", [Fmt.pct(v * m)])
		"yield":
			var cat := str(e.get("cat", ""))
			out = L.t("effect.yield." + (cat if cat != "" else "all"), [Fmt.pct(v * m)])
		"yieldKind": out = L.t("effect.yieldKind", [Fmt.pct(v * m), Res.name_of(e["kind"])])
		"speed": out = L.t("effect.speed", [Fmt.pct(v * m)])
		"respawn": out = L.t("effect.respawn", [Fmt.pct(v * m)])
		"crit": out = L.t("effect.crit", [Fmt.pct(v * m)])
		"backpack": out = L.t("effect.backpack", [int(v * m)])
		"sell": out = L.t("effect.sell", [Fmt.pct(v * m)])
		"produce":
			out = L.t("effect.produce", ["", Res.name_of(e["kind"]), Fmt.seconds(float(e["interval"]) / m)])
		"helper":
			var h: Dictionary = e["spec"]
			out = L.t("effect.helper", ["", int(h["max_tier"]), "%.1f" % (float(h["damage"]) * m)])
	return out.replace("  ", " ").strip_edges()


## Пиксельные иконки к эффекту: продукт производителя или инструменты помощника.
static func effect_icons(e: Dictionary) -> Array:
	match e["type"]:
		"produce":
			return [str(e["kind"])]
		"helper":
			var out: Array = []
			var tools: Array = e["spec"]["tools"]
			for t in Tools.KINDS:
				if t in tools:
					out.append("fist" if t == "hand" else Tools.icon_name(t))
			return out
	return []


static func awaken_multiplier(level: int) -> float:
	return 1.0 + 0.25 * float(level)


static func awaken_cost(next_level: int) -> Dictionary:
	return AWAKEN_COSTS[clampi(next_level, 1, AWAKEN_MAX) - 1]


static func awaken_color(level: int) -> Color:
	return AWAKEN_COLORS[clampi(level, 1, AWAKEN_MAX) - 1]


static func awaken_title(level: int) -> String:
	return L.t("awaken.level.%d" % clampi(level, 1, AWAKEN_MAX))
