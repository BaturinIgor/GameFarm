class_name Animals
## Звери: что дают, где водятся, сколько стоят (порт Animals.swift, Awakening и Shiny из Collection.swift).
## Эффекты - словари в формате recalc: {"type", "v", "cat", "kind", "interval", "spec"}.

const MAX_STARS := 5

const IDS := [
	# Лавка
	"chicken", "cow", "horse", "sheep", "bee", "rooster", "pig", "unicorn",
	# Дикие
	"mouse", "goose", "duck", "frog", "butterfly", "swan", "goldenGoose",
	# Дикие жители дальних биомов (перекраска листа другого зверя, см. base и recolor)
	"jerboa", "crystalMouse", "salamander", "amberButterfly", "starButterfly",
	# Из стартового набора
	"duckHat",
	# За кристаллы: перекрашенные звери пака
	"draftHorse", "emberRooster", "moonUnicorn",
	# Гибриды из Гнезда (Incubator.RECIPES): только скрещиванием
	"goldenHen", "pegasus", "honeyToad", "cloudSheep",
]

## Старые звери из прошлых версий: во что они превращаются в сохранении.
const MIGRATION := {
	"dog": "mouse", "cat": "butterfly", "hamster": "horse", "turkey": "chicken", "owl": "rooster", "llama": "sheep",
	"panda": "pig", "rabbit": "mouse", "squirrel": "mouse", "goat": "goose", "hedgehog": "goose", "beaver": "goose",
	"otter": "duck", "turtle": "swan", "crocodile": "pig", "camel": "horse", "lizard": "butterfly", "penguin": "duck",
	"fox": "swan", "polarBear": "pig", "bat": "butterfly", "dragon": "unicorn", "parrot": "butterfly", "monkey": "pig",
	"crab": "duck", "phoenix": "goldenGoose", "lavasaur": "unicorn", "eagle": "swan", "dove": "goldenGoose", "lion": "duckHat",
}

## source: "shop" (price, level), "wild" (location, cost, weight), "premium" (только из платного набора)
## или "crystal" (price в кристаллах, level). sheet - чей лист спрайтов взять, tint - во что перекрасить.
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
	"butterfly": {"emoji": "🦋", "source": "wild", "location": "island", "weight": 1.0,
		"cost": {"coins": 0, "items": [["coconut", 30], ["banana", 15]]},
		"effects": [{"type": "xp", "v": 0.2}, {"type": "sell", "v": 0.06}]},
	"swan": {"emoji": "🦢", "source": "wild", "location": "snow", "weight": 1.0,
		"cost": {"coins": 0, "items": [["fish", 80], ["ice", 30]]},
		"effects": [{"type": "crit", "v": 0.05}, {"type": "backpack", "v": 40}]},
	"goldenGoose": {"emoji": "🪿", "source": "wild", "location": "sky", "weight": 0.4,
		"cost": {"coins": 0, "items": [["cloud", 30], ["diamond", 10], ["crystal", 10]]},
		"effects": [{"type": "produce", "kind": "gold", "interval": 40.0}, {"type": "yield", "cat": "gem", "v": 0.12}]},

	# base - чей лист перекрашивается, recolor - три цвета (тень, середина, свет) по яркости пикселя
	"jerboa": {"emoji": "🐁", "source": "wild", "location": "desert", "weight": 1.0,
		"base": "mouse", "recolor": [Color("8a5a2b"), Color("d9a45a"), Color("f6dfa8")],
		"cost": {"coins": 0, "items": [["cactus", 30], ["carrots", 30]]},
		"effects": [{"type": "speed", "v": 0.06}, {"type": "yield", "cat": "food", "v": 0.08}]},
	"crystalMouse": {"emoji": "🐁", "source": "wild", "location": "caves", "weight": 0.8,
		"base": "mouse", "recolor": [Color("3b2f8a"), Color("7f6ee8"), Color("bff3ff")],
		"cost": {"coins": 0, "items": [["crystal", 8], ["mushrooms", 40]]},
		"effects": [{"type": "helper", "spec": {"damage": 6.0, "interval": 1.1, "tools": ["hand", "pickaxe"], "max_tier": 6}},
			{"type": "yield", "cat": "gem", "v": 0.06}]},
	"salamander": {"emoji": "🦎", "source": "wild", "location": "volcano", "weight": 1.0,
		"base": "frog", "recolor": [Color("6e1a12"), Color("e2501f"), Color("ffc24a")],
		"cost": {"coins": 0, "items": [["obsidian", 15], ["sulfur", 15]]},
		"effects": [{"type": "helper", "spec": {"damage": 10.0, "interval": 1.1, "tools": ["hand", "pickaxe"], "max_tier": 7}},
			{"type": "crit", "v": 0.04}]},
	"amberButterfly": {"emoji": "🦋", "source": "wild", "location": "amberWoods", "weight": 1.0,
		"base": "butterfly", "recolor": [Color("7a3a0c"), Color("e8962a"), Color("ffe08a")],
		"cost": {"coins": 0, "items": [["goldenApple", 10], ["honey", 20]]},
		"effects": [{"type": "xp", "v": 0.15}, {"type": "yield", "cat": "wood", "v": 0.1}]},
	"starButterfly": {"emoji": "🦋", "source": "wild", "location": "starMeadows", "weight": 0.8,
		"base": "butterfly", "recolor": [Color("2a2a7a"), Color("7d7df0"), Color("f4f0ff")],
		"cost": {"coins": 0, "items": [["stardust", 6], ["cloud", 20]]},
		"effects": [{"type": "xp", "v": 0.25}, {"type": "sell", "v": 0.08}]},

	"duckHat": {"emoji": "🦆", "source": "premium",
		"effects": [{"type": "yield", "v": 0.08}, {"type": "xp", "v": 0.1}, {"type": "sell", "v": 0.1}]},

	# За кристаллы: покупка и каждая звезда - в кристаллах
	"draftHorse": {"emoji": "🐎", "source": "crystal", "price": 150, "level": 8, "sheet": "horse",
		"tint": Color(0.68, 0.5, 0.36),
		"effects": [{"type": "produce", "kind": "planks", "interval": 120.0}, {"type": "speed", "v": 0.06}]},
	"emberRooster": {"emoji": "🐓", "source": "crystal", "price": 120, "level": 12, "sheet": "rooster",
		"tint": Color(1.0, 0.62, 0.42),
		"effects": [{"type": "xp", "v": 0.12}, {"type": "respawn", "v": 0.1}]},
	"moonUnicorn": {"emoji": "🦄", "source": "crystal", "price": 300, "level": 20, "sheet": "unicorn",
		"tint": Color(0.66, 0.74, 1.0),
		"effects": [{"type": "helper", "spec": {"damage": 20.0, "interval": 1.0, "tools": ["hand", "axe", "pickaxe"], "max_tier": 7}},
			{"type": "yield", "v": 0.08}]},
}

# Гибриды: появляются только из яйца Гнезда (пара родителей по рецепту), перекраска листа родителя
const HYBRID_SPECS := {
	"goldenHen": {"emoji": "🐔", "source": "hybrid", "base": "chicken",
		"recolor": [Color("8a5a10"), Color("e8b020"), Color("fff1a0")],
		"effects": [{"type": "produce", "kind": "gold", "interval": 50.0}, {"type": "yield", "cat": "food", "v": 0.1}]},
	"pegasus": {"emoji": "🐎", "source": "hybrid", "base": "horse",
		"recolor": [Color("5a6f9e"), Color("cfe0ff"), Color("ffffff")],
		"effects": [{"type": "speed", "v": 0.15}, {"type": "backpack", "v": 40}]},
	"honeyToad": {"emoji": "🐸", "source": "hybrid", "base": "frog",
		"recolor": [Color("7a4a08"), Color("e8a820"), Color("ffe680")],
		"effects": [{"type": "produce", "kind": "honey", "interval": 35.0}, {"type": "respawn", "v": 0.1}]},
	"cloudSheep": {"emoji": "🐑", "source": "hybrid", "base": "sheep",
		"recolor": [Color("8a7aa8"), Color("f0eaff"), Color("ffffff")],
		"effects": [{"type": "produce", "kind": "cloud", "interval": 60.0}, {"type": "xp", "v": 0.12}]},
}

## Звезда зверя за кристаллы дороже предыдущей во столько раз.
const CRYSTAL_GROWTH := 1.4

# Пробуждение зверей
## 4-я ступень - мифическая: кроме ресурсов нужны Осколки Древних (shards).
const AWAKEN_MAX := 4
const AWAKEN_COSTS := [
	{"coins": 2500, "items": [["slime", 20], ["bone", 10]]},
	{"coins": 9000, "items": [["crystal", 15], ["bone", 40]]},
	{"coins": 30000, "items": [["stardust", 8], ["ruby", 8]]},
	{"coins": 80000, "items": [["stardust", 15], ["ruby", 15]], "shards": 2},
]
## Цвет ауры: бронза, серебро, золото, мифическая (сиренево-голубая).
const AWAKEN_COLORS := [Color("cd7f32"), Color("d8dee8"), Color("ffd54a"), Color("9fd8ff")]

# Редкая окраска: 3% диких зверей бывают другого цвета
const SHINY_CHANCE := 0.03
const SHINY_BONUS := 0.1
## Цвет перекраски: зверь становится сиреневым с переливом.
const SHINY_TINT := Color(0.75, 0.45, 1.0)


static func spec(id: String) -> Dictionary:
	return SPECS.get(id, HYBRID_SPECS.get(id, {}))


static func is_hybrid(id: String) -> bool:
	return HYBRID_SPECS.has(id)


static func name_of(id: String) -> String:
	return L.t("animal." + id)


## Id из сохранения с учётом старых зверей ("" - такого нет).
static func from(raw: String) -> String:
	if SPECS.has(raw) or HYBRID_SPECS.has(raw):
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


## Чей лист рисует зверя (перекрашенные звери берут лист другого).
static func base_sheet(id: String) -> String:
	return str(spec(id).get("base", id))


## Цвета перекраски [тень, середина, свет] или [] для зверя со своим листом.
static func recolor(id: String) -> Array:
	return spec(id).get("recolor", [])


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


## Зверь за кристаллы.
static func is_crystal(id: String) -> bool:
	return spec(id).get("source", "") == "crystal"


## С какого уровня продаётся за кристаллы (-1 - не продаётся).
static func crystal_level(id: String) -> int:
	return int(spec(id)["level"]) if is_crystal(id) else -1


## Чей лист спрайтов (у перекрашенных зверей - чужой).
static func sheet_of(id: String) -> String:
	return str(spec(id).get("sheet", id))


## Перекраска (умножение цвета) или белый, если зверь свой.
static func tint(id: String) -> Color:
	return spec(id).get("tint", Color.WHITE)


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
