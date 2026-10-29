class_name Tools
## Инструменты и их ступени: сила удара, уровни и цены улучшений.

const KINDS := ["hand", "axe", "pickaxe", "rod", "sword", "armor", "helmet", "boots"]
const GATHERING := ["axe", "pickaxe", "rod"]
const UPGRADABLE := ["axe", "pickaxe", "rod", "sword", "helmet", "armor", "boots"]
const MAX_TIER := 10

const EMOJI := {
	"hand": "✋", "axe": "🪓", "pickaxe": "⛏️", "rod": "🎣", "sword": "🗡️", "armor": "🛡️", "helmet": "⛑️", "boots": "👢",
}

## Сила удара по ступеням. 11-я ступень - только с талантом "Мастер инструмента" на 10-й.
const POWER := [1.0, 1.8, 3.0, 4.6, 6.8, 10.0, 14.5, 21.0, 30.0, 42.0, 56.0]


static func power(tier: int) -> float:
	return POWER[clampi(tier - 1, 0, POWER.size() - 1)]


static func title(tool: String) -> String:
	return L.t("tool." + tool)


static func tier_name(tool: String, tier: int) -> String:
	return L.t("tool.%s.%d" % [tool, clampi(tier, 1, MAX_TIER)])


## Пиксельная иконка ic_<имя>.
static func icon_name(tool: String) -> String:
	match tool:
		"helmet": return "helmet"
		"boots": return "boots"
		"hand": return "hand"
	return "tool_" + tool


static func tier_color(tier: int) -> Color:
	match tier:
		1: return Color(0.62, 0.42, 0.24)
		2: return Color(0.55, 0.57, 0.6)
		3: return Color(0.75, 0.78, 0.84)
		4: return Color(0.98, 0.78, 0.2)
		5: return Color(0.4, 0.88, 1.0)
		6: return Color(0.72, 0.45, 1.0)
		7: return Color(0.42, 0.24, 0.6)
		8: return Color(1.0, 0.93, 0.55)
		9: return Color(0.3, 0.95, 0.85)
	return Color(1.0, 0.55, 0.2)


static func required_level(tool: String, tier: int) -> int:
	var i := clampi(tier - 1, 0, 9)
	match tool:
		"rod": return [1, 11, 16, 24, 32, 40, 45, 52, 56, 59][i]
		"helmet", "boots": return [1, 5, 10, 16, 23, 31, 43, 50, 55, 58][i]
	return [1, 3, 7, 13, 20, 28, 43, 50, 54, 58][i]


## Цена улучшения до ступени: {"coins": n, "items": [[kind, n], ...]}.
static func cost(tool: String, tier: int) -> Dictionary:
	var t: Dictionary = COSTS.get(tool, {})
	var c = t.get(tier, null)
	return c if c != null else {"coins": 0, "items": []}


const COSTS := {
	"axe": {
		2: {"coins": 40, "items": [["wood", 40], ["stone", 20]]},
		3: {"coins": 250, "items": [["wood", 150], ["stone", 60], ["coal", 20]]},
		4: {"coins": 1000, "items": [["wood", 300], ["iron", 50], ["bamboo", 40]]},
		5: {"coins": 4000, "items": [["wood", 600], ["gold", 30], ["cactus", 40]]},
		6: {"coins": 12000, "items": [["wood", 1200], ["diamond", 8], ["ice", 60]]},
		7: {"coins": 30000, "items": [["wood", 2000], ["sulfur", 40], ["pearl", 10]]},
		8: {"coins": 80000, "items": [["wood", 4000], ["obsidian", 60], ["ruby", 10]]},
		9: {"coins": 150000, "items": [["wood", 6000], ["essence", 40], ["stardust", 10]]},
		10: {"coins": 300000, "items": [["wood", 10000], ["essence", 100], ["stardust", 25]]},
	},
	"pickaxe": {
		2: {"coins": 40, "items": [["wood", 25], ["stone", 40]]},
		3: {"coins": 250, "items": [["stone", 150], ["coal", 30]]},
		4: {"coins": 1000, "items": [["stone", 300], ["iron", 60], ["coal", 60]]},
		5: {"coins": 4000, "items": [["iron", 150], ["gold", 40]]},
		6: {"coins": 12000, "items": [["gold", 120], ["diamond", 12], ["ice", 80]]},
		7: {"coins": 30000, "items": [["crystal", 30], ["sulfur", 60], ["coral", 30]]},
		8: {"coins": 80000, "items": [["obsidian", 80], ["ruby", 20]]},
		9: {"coins": 150000, "items": [["obsidian", 150], ["essence", 40], ["stardust", 10]]},
		10: {"coins": 300000, "items": [["ruby", 40], ["essence", 100], ["stardust", 25]]},
	},
	"rod": {
		2: {"coins": 500, "items": [["wood", 100], ["bamboo", 40], ["fish", 30]]},
		3: {"coins": 1500, "items": [["bamboo", 120], ["iron", 40], ["fish", 80]]},
		4: {"coins": 5000, "items": [["gold", 30], ["ice", 40], ["fish", 150]]},
		5: {"coins": 12000, "items": [["diamond", 6], ["fish", 300]]},
		6: {"coins": 25000, "items": [["crystal", 15], ["fish", 500]]},
		7: {"coins": 40000, "items": [["sulfur", 40], ["pearl", 20], ["fish", 800]]},
		8: {"coins": 90000, "items": [["ruby", 15], ["pearl", 40], ["fish", 1500]]},
		9: {"coins": 160000, "items": [["fish", 2500], ["essence", 40], ["pearl", 60]]},
		10: {"coins": 320000, "items": [["fish", 4000], ["essence", 100], ["stardust", 25]]},
	},
	"sword": {
		2: {"coins": 60, "items": [["wood", 30], ["slime", 8]]},
		3: {"coins": 300, "items": [["iron", 20], ["slime", 30]]},
		4: {"coins": 1200, "items": [["iron", 60], ["bone", 30]]},
		5: {"coins": 4000, "items": [["gold", 30], ["bone", 60]]},
		6: {"coins": 12000, "items": [["diamond", 6], ["slime", 150]]},
		7: {"coins": 30000, "items": [["obsidian", 30], ["bone", 200]]},
		8: {"coins": 80000, "items": [["ruby", 10], ["bone", 400]]},
		9: {"coins": 150000, "items": [["tusk", 300], ["essence", 60], ["ruby", 20]]},
		10: {"coins": 300000, "items": [["essence", 150], ["stardust", 30], ["ruby", 30]]},
	},
	"armor": {
		2: {"coins": 80, "items": [["wool", 6], ["slime", 8]]},
		3: {"coins": 400, "items": [["iron", 25], ["slime", 30]]},
		4: {"coins": 1500, "items": [["iron", 80], ["bone", 30]]},
		5: {"coins": 5000, "items": [["gold", 40], ["bone", 80]]},
		6: {"coins": 14000, "items": [["diamond", 8], ["slime", 200]]},
		7: {"coins": 32000, "items": [["obsidian", 40], ["bone", 250]]},
		8: {"coins": 85000, "items": [["ruby", 12], ["bone", 500]]},
		9: {"coins": 160000, "items": [["tusk", 300], ["essence", 60], ["obsidian", 100]]},
		10: {"coins": 320000, "items": [["essence", 150], ["stardust", 30]]},
	},
	"helmet": {
		2: {"coins": 100, "items": [["iron", 10], ["slime", 10]]},
		3: {"coins": 500, "items": [["iron", 30], ["bone", 20]]},
		4: {"coins": 1800, "items": [["gold", 20], ["bone", 40]]},
		5: {"coins": 6000, "items": [["diamond", 4], ["tusk", 20]]},
		6: {"coins": 15000, "items": [["crystal", 10], ["tusk", 60]]},
		7: {"coins": 35000, "items": [["obsidian", 40], ["tusk", 120]]},
		8: {"coins": 90000, "items": [["ruby", 10], ["essence", 20]]},
		9: {"coins": 160000, "items": [["essence", 60], ["tusk", 300]]},
		10: {"coins": 320000, "items": [["essence", 150], ["stardust", 30]]},
	},
	"boots": {
		2: {"coins": 90, "items": [["wool", 10], ["slime", 6]]},
		3: {"coins": 450, "items": [["clay", 30], ["bone", 15]]},
		4: {"coins": 1600, "items": [["iron", 50], ["bone", 40]]},
		5: {"coins": 5500, "items": [["gold", 30], ["tusk", 15]]},
		6: {"coins": 14000, "items": [["ice", 80], ["tusk", 50]]},
		7: {"coins": 33000, "items": [["coral", 40], ["tusk", 100]]},
		8: {"coins": 85000, "items": [["cloud", 40], ["essence", 20]]},
		9: {"coins": 150000, "items": [["essence", 60], ["feather", 200]]},
		10: {"coins": 300000, "items": [["essence", 150], ["stardust", 25]]},
	},
}
