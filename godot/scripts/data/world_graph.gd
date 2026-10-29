class_name WorldGraph
## Проходы между локациями родной планеты (порт GateSpec и WorldGraph), планеты и пути по карте.
## Проход - словарь {id, a, b, cost, group, royal}: открыть можно с любой стороны.
## Проходы одной группы (group) открываются вместе (перекрёсток). Королевские ворота в сад открываются покупкой.

const GATES := [
	{"id": "meadow_hills", "a": "meadow", "b": "hills", "group": "", "royal": false,
		"cost": {"coins": 0, "items": [["wood", 60], ["stone", 40], ["berries", 20]]}},
	{"id": "meadow_lake", "a": "meadow", "b": "lake", "group": "", "royal": false,
		"cost": {"coins": 300, "items": [["wood", 200], ["stone", 150], ["coal", 40], ["carrots", 40]]}},
	{"id": "lake_swamp", "a": "lake", "b": "swamp", "group": "", "royal": false,
		"cost": {"coins": 800, "items": [["wood", 300], ["iron", 40], ["fish", 40], ["bamboo", 30]]}},
	{"id": "meadow_desert", "a": "meadow", "b": "desert", "group": "", "royal": false,
		"cost": {"coins": 2000, "items": [["wood", 400], ["iron", 80], ["fish", 60], ["carrots", 80]]}},
	{"id": "swamp_desert", "a": "swamp", "b": "desert", "group": "", "royal": false,
		"cost": {"coins": 1500, "items": [["wood", 300], ["clay", 40], ["herbs", 60], ["fish", 40]]}},
	{"id": "hills_snow", "a": "hills", "b": "snow", "group": "snowpass", "royal": false,
		"cost": {"coins": 6000, "items": [["iron", 200], ["gold", 60], ["coconut", 50], ["clay", 80]]}},
	{"id": "desert_snow", "a": "desert", "b": "snow", "group": "snowpass", "royal": false,
		"cost": {"coins": 6000, "items": [["iron", 200], ["gold", 60], ["coconut", 50], ["clay", 80]]}},
	{"id": "snow_caves", "a": "snow", "b": "caves", "group": "", "royal": false,
		"cost": {"coins": 15000, "items": [["gold", 200], ["ice", 150], ["diamond", 15]]}},
	{"id": "swamp_island", "a": "swamp", "b": "island", "group": "", "royal": false,
		"cost": {"coins": 25000, "items": [["crystal", 40], ["diamond", 40], ["cactus", 150], ["coconut", 150]]}},
	{"id": "caves_volcano", "a": "caves", "b": "volcano", "group": "firepass", "royal": false,
		"cost": {"coins": 50000, "items": [["crystal", 60], ["coral", 40], ["pearl", 10], ["banana", 100]]}},
	{"id": "island_volcano", "a": "island", "b": "volcano", "group": "firepass", "royal": false,
		"cost": {"coins": 50000, "items": [["crystal", 60], ["coral", 40], ["pearl", 10], ["banana", 100]]}},
	{"id": "volcano_sky", "a": "volcano", "b": "sky", "group": "", "royal": false,
		"cost": {"coins": 100000, "items": [["obsidian", 100], ["ruby", 20], ["sulfur", 100], ["pineapple", 200]]}},
	{"id": "meadow_garden", "a": "meadow", "b": "garden", "group": "", "royal": true,
		"cost": {"coins": 0, "items": []}},
]

## Планеты: родная с картой мира и две дальние, которые открываются в конце игры.
const PLANETS := ["home", "ember", "azure"]

## С какого уровня можно лететь.
const PLANET_LEVEL := {"home": 1, "ember": 45, "azure": 54}

## Цвета шара планеты: светлый и тёмный.
const PLANET_COLORS := {
	"home": [Color("7cc86a"), Color("2e6b3a")],
	"ember": [Color("ff9a4a"), Color("7a1a0e")],
	"azure": [Color("a8b4ff"), Color("2a2a7a")],
}


## Проход по id ({} - нет такого).
static func gate(id: String) -> Dictionary:
	for g in GATES:
		if g["id"] == id:
			return g
	return {}


## Проходы, которые ведут из локации.
static func gates_of(location: String) -> Array:
	return GATES.filter(func(g: Dictionary) -> bool: return connects(g, location))


static func connects(g: Dictionary, location: String) -> bool:
	return g["a"] == location or g["b"] == location


static func other(g: Dictionary, from: String) -> String:
	return g["b"] if g["a"] == from else g["a"]


## Уровень прохода: больший из уровней двух сторон.
static func level(g: Dictionary) -> int:
	return maxi(int(Locations.spec(g["a"])["level"]), int(Locations.spec(g["b"])["level"]))


## Все проходы группы (или сам проход, если он не в группе).
static func bundle(g: Dictionary) -> Array:
	if str(g.get("group", "")) == "":
		return [g]
	return GATES.filter(func(x: Dictionary) -> bool: return x["group"] == g["group"])


## Локации, куда можно дойти от луга через открытые проходы.
static func reachable(open: Array) -> Array:
	var seen: Array = ["meadow"]
	var queue: Array = ["meadow"]
	while not queue.is_empty():
		var cur: String = queue.pop_back()
		for g in gates_of(cur):
			if g["royal"] or not g["id"] in open:
				continue
			var next := other(g, cur)
			if not next in seen:
				seen.append(next)
				queue.append(next)
	return seen


## Кратчайшая цепочка проходов от луга до локации (для переноса старых сохранений).
## allowed - локации, через которые можно идти (null - любые). null, если не дойти.
static func path(target: String, allowed = null) -> Variant:
	var prev := {}
	var seen: Array = ["meadow"]
	var queue: Array = ["meadow"]
	var i := 0
	while i < queue.size():
		var cur: String = queue[i]
		i += 1
		if cur == target:
			break
		for g in gates_of(cur):
			if g["royal"]:
				continue
			var next := other(g, cur)
			if allowed is Array and not next in allowed:
				continue
			if not next in seen:
				seen.append(next)
				prev[next] = [cur, g["id"]]
				queue.append(next)
	if not target in seen:
		return null
	var out: Array = []
	var step := target
	while step != "meadow" and prev.has(step):
		out.push_front(prev[step][1])
		step = prev[step][0]
	return out


# MARK: Планеты

static func planet_name(p: String) -> String:
	return L.t("planet." + p)


static func planet_blurb(p: String) -> String:
	return L.t("planet." + p + ".blurb")


static func planet_level(p: String) -> int:
	return int(PLANET_LEVEL.get(p, 1))


static func planet_colors(p: String) -> Array:
	return PLANET_COLORS.get(p, PLANET_COLORS["home"])


## Обычные локации планеты (без сада, экспедиций и прочего).
static func planet_locations(p: String) -> Array:
	return Locations.IDS.filter(func(id: String) -> bool:
		return Locations.kind(id) == "world" and Locations.planet(id) == p)
