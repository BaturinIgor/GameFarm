class_name Talents
## Таланты: ветки, ряды, ранги, стоимость и суперталанты (порт Talents.swift).

const BRANCHES := ["mining", "gathering", "travel", "beasts", "farming", "combat"]

## Пиксельная иконка ветки.
const BRANCH_ICONS := {
	"mining": "tool_pickaxe", "gathering": "basket", "travel": "boots",
	"beasts": "paw", "farming": "watering_can", "combat": "sword",
}

const BRANCH_COLORS := {
	"mining": Color(0.95, 0.45, 0.25),
	"gathering": Color(0.3, 0.75, 0.35),
	"travel": Color(0.3, 0.6, 1.0),
	"beasts": Color(0.9, 0.4, 0.75),
	"farming": Color(0.85, 0.65, 0.15),
	"combat": Color(0.85, 0.25, 0.3),
}

## Уровень персонажа, с которого открывается ряд дерева.
const TIER_LEVELS := [1, 3, 6, 10, 15, 21, 28, 35, 42, 48, 55]

## Сколько очков стоит ранг суперталанта.
const SUPER_COST := 3

## id: [ветка, иконка, макс. ранг, ряд, колонка, родители, прибавка за ранг, единица, цена ранга (если не 1)].
## Единица: percent - процент, flat - число, flag - без числа. Порядок как в TalentID.allCases.
## Суперталант (цена больше 1) открывается, только когда родители прокачаны до максимума.
const SPECS := {
	# Добыча
	"power": ["mining", "fist", 8, 0, 1, [], 0.12, "percent"],
	"lumberjack": ["mining", "tool_axe", 3, 1, 0, ["power"], 0.2, "percent"],
	"miner": ["mining", "tool_pickaxe", 3, 1, 2, ["power"], 0.2, "percent"],
	"quickHands": ["mining", "bolt", 5, 2, 1, ["power"], 0.07, "percent"],
	"crit": ["mining", "target", 4, 3, 0, ["lumberjack"], 0.05, "percent"],
	"shatter": ["mining", "shards", 3, 3, 2, ["miner"], 0.04, "percent"],
	"critPower": ["mining", "flame", 3, 4, 0, ["crit"], 0.3, "percent"],
	"strongHands": ["mining", "hammer", 3, 4, 2, ["shatter"], 0.4, "percent"],
	"quake": ["mining", "quake", 1, 5, 1, ["quickHands"], 1.0, "flag"],
	# Сбор
	"bounty": ["gathering", "basket", 8, 0, 1, [], 0.1, "percent"],
	"regrowth": ["gathering", "sprout", 5, 1, 0, ["bounty"], 0.08, "percent"],
	"scholar": ["gathering", "book", 5, 1, 2, ["bounty"], 0.1, "percent"],
	"doubleDrop": ["gathering", "dice", 4, 2, 1, ["bounty"], 0.05, "percent"],
	"farmer": ["gathering", "wheat", 3, 3, 0, ["regrowth"], 0.2, "percent"],
	"trader": ["gathering", "coins", 5, 3, 2, ["scholar"], 0.08, "percent"],
	"gardener": ["gathering", "sunflower", 3, 4, 0, ["farmer"], 0.06, "percent"],
	"gemFinder": ["gathering", "diamond", 3, 4, 2, ["trader"], 0.015, "percent"],
	"goldenTouch": ["gathering", "goldenApple", 1, 5, 1, ["doubleDrop"], 1.0, "flag"],
	# Странник
	"swift": ["travel", "boots", 7, 0, 1, [], 0.07, "percent"],
	"bigPack": ["travel", "bag", 5, 1, 0, ["swift"], 15.0, "flat"],
	"reach": ["travel", "magnet", 3, 1, 2, ["swift"], 0.12, "percent"],
	"tamer": ["travel", "lasso", 3, 2, 1, ["swift"], 0.15, "percent"],
	"beastBond": ["travel", "heart", 4, 3, 0, ["bigPack"], 0.12, "percent"],
	"packLeader": ["travel", "paw", 4, 3, 2, ["reach"], 0.25, "percent"],
	"thrift": ["travel", "tag", 3, 4, 0, ["beastBond"], 0.07, "percent"],
	"nightShift": ["travel", "moon", 3, 4, 2, ["packLeader"], 0.2, "percent"],
	"portal": ["travel", "portal", 1, 5, 1, ["tamer"], 1.0, "flag"],
	# Добыча, поздние ряды
	"doubleStrike": ["mining", "swords", 4, 6, 0, ["critPower"], 0.05, "percent"],
	"shockwave": ["mining", "wave", 3, 6, 1, ["quake"], 0.25, "percent"],
	"oreHunter": ["mining", "gold", 4, 6, 2, ["strongHands"], 0.1, "percent"],
	"execute": ["mining", "skull", 3, 7, 0, ["doubleStrike"], 0.06, "percent"],
	"crusher": ["mining", "tool_hammer", 3, 7, 1, ["shockwave"], 0.15, "percent"],
	"tireless": ["mining", "hourglass", 4, 7, 2, ["oreHunter"], 0.05, "percent"],
	"toolMaster": ["mining", "trophy", 1, 8, 1, ["crusher"], 1.0, "flag"],
	# Сбор, поздние ряды
	"finder": ["gathering", "magnifier", 4, 6, 0, ["gardener"], 0.04, "percent"],
	"goldRush": ["gathering", "chest_gold", 3, 6, 1, ["goldenTouch"], 0.5, "percent"],
	"jeweler": ["gathering", "ruby", 3, 6, 2, ["gemFinder"], 0.15, "percent"],
	"fertile": ["gathering", "berries", 5, 7, 0, ["finder"], 0.06, "percent"],
	"triple": ["gathering", "clover", 3, 7, 1, ["goldRush"], 0.03, "percent"],
	"sage": ["gathering", "owl", 5, 7, 2, ["jeweler"], 0.06, "percent"],
	"abundance": ["gathering", "rainbow", 1, 8, 1, ["triple"], 1.0, "flag"],
	# Странник, поздние ряды
	"packMaster": ["travel", "chest", 4, 6, 0, ["thrift"], 0.1, "percent"],
	"tailwind": ["travel", "wind", 4, 6, 1, ["portal"], 0.05, "percent"],
	"depotReach": ["travel", "map", 3, 6, 2, ["nightShift"], 0.3, "percent"],
	"bargain": ["travel", "moneybag", 3, 7, 0, ["packMaster"], 0.08, "percent"],
	"tracker": ["travel", "compass", 3, 7, 1, ["tailwind"], 0.2, "percent"],
	"storekeeper": ["travel", "plan", 3, 7, 2, ["depotReach"], 1.0, "flat"],
	"strider": ["travel", "wing", 1, 8, 1, ["tracker"], 1.0, "flag"],
	# Звери
	"animalFriend": ["beasts", "heart_plus", 8, 0, 1, [], 0.05, "percent"],
	"training": ["beasts", "ball", 5, 1, 0, ["animalFriend"], 0.08, "percent"],
	"rancher": ["beasts", "milk", 5, 1, 2, ["animalFriend"], 0.08, "percent"],
	"keenEye": ["beasts", "eye", 3, 2, 1, ["animalFriend"], 0.2, "percent"],
	"packTier": ["beasts", "paw", 2, 3, 0, ["training"], 1.0, "flat"],
	"pasture": ["beasts", "pen", 3, 3, 2, ["rancher"], 2.0, "flat"],
	"starFood": ["beasts", "star", 4, 4, 1, ["keenEye"], 0.05, "percent"],
	"beastLoot": ["beasts", "bone", 4, 5, 0, ["packTier"], 0.15, "percent"],
	"catcher": ["beasts", "net", 3, 5, 2, ["pasture"], 0.1, "percent"],
	"alpha": ["beasts", "crown", 5, 6, 1, ["starFood"], 0.1, "percent"],
	"herdsman": ["beasts", "wool", 3, 7, 0, ["beastLoot"], 0.1, "percent"],
	"starHunter": ["beasts", "stardust", 3, 7, 2, ["catcher"], 0.15, "percent"],
	"soul": ["beasts", "spark", 1, 8, 1, ["alpha"], 1.0, "flag"],
	# Огород
	"greenThumb": ["farming", "sprout", 5, 0, 1, [], 0.06, "percent"],
	"bigHarvest": ["farming", "pumpkin", 3, 1, 0, ["greenThumb"], 0.12, "percent"],
	"seedSaver": ["farming", "seed_sunflower", 5, 1, 2, ["greenThumb"], 0.08, "percent"],
	"rainmaker": ["farming", "watering_can", 3, 2, 1, ["greenThumb"], 0.15, "percent"],
	"composter": ["farming", "compost", 3, 3, 0, ["bigHarvest"], 0.12, "percent"],
	"chef": ["farming", "dish_stew", 4, 3, 2, ["seedSaver"], 0.15, "percent"],
	"quickCook": ["farming", "stopwatch", 3, 4, 0, ["composter"], 0.1, "percent"],
	"marketDay": ["farming", "moneybag", 4, 4, 2, ["chef"], 0.1, "percent"],
	"goldenHarvest": ["farming", "goldenApple", 1, 5, 1, ["rainmaker"], 1.0, "flag"],
	"deepRoots": ["farming", "fert_magic", 2, 6, 0, ["quickCook"], 1.0, "flat"],
	"seedTrader": ["farming", "tag", 3, 6, 2, ["marketDay"], 0.1, "percent"],
	"harvestMoon": ["farming", "moon", 1, 7, 1, ["goldenHarvest"], 1.0, "flag"],
	# Бой
	"toughness": ["combat", "heart", 5, 0, 1, [], 0.08, "percent"],
	"bladeMaster": ["combat", "sword", 5, 1, 0, ["toughness"], 0.07, "percent"],
	"stance": ["combat", "shield", 4, 1, 2, ["toughness"], 0.03, "percent"],
	"vampirism": ["combat", "fang", 3, 2, 1, ["toughness"], 0.02, "percent"],
	"evasion": ["combat", "wind", 4, 3, 0, ["bladeMaster"], 0.02, "percent"],
	"alchemist": ["combat", "potion", 3, 3, 2, ["stance"], 0.1, "percent"],
	"berserk": ["combat", "flame", 3, 4, 0, ["evasion"], 0.12, "percent"],
	"bossSlayer": ["combat", "skull", 4, 4, 2, ["alchemist"], 0.08, "percent"],
	"lastStand": ["combat", "heart_shield", 1, 5, 1, ["vampirism"], 1.0, "flag"],
	"delver": ["combat", "key", 3, 6, 0, ["berserk"], 0.1, "percent"],
	"regen": ["combat", "heart_plus", 3, 6, 2, ["bossSlayer"], 0.005, "percent"],
	"warlord": ["combat", "crown", 1, 7, 1, ["lastStand"], 1.0, "flag"],
	# Суперталанты и ряды за ними
	"titan": ["mining", "super_titan", 1, 9, 1, ["execute", "toolMaster", "tireless"], 1.0, "flag", SUPER_COST],
	"keenEdge": ["mining", "flame", 3, 10, 0, ["titan"], 0.25, "percent"],
	"mountainBreaker": ["mining", "tool_hammer", 3, 10, 1, ["titan"], 0.1, "percent"],
	"motherlode": ["mining", "gold", 3, 10, 2, ["titan"], 0.12, "percent"],
	"cornucopia": ["gathering", "super_cornucopia", 1, 9, 1, ["fertile", "abundance", "sage"], 1.0, "flag", SUPER_COST],
	"fortune": ["gathering", "clover", 3, 10, 0, ["cornucopia"], 0.02, "percent"],
	"forager": ["gathering", "berries", 3, 10, 1, ["cornucopia"], 0.12, "percent"],
	"enlightened": ["gathering", "book", 3, 10, 2, ["cornucopia"], 0.08, "percent"],
	"windwalker": ["travel", "super_windwalker", 1, 9, 1, ["bargain", "strider", "storekeeper"], 1.0, "flag", SUPER_COST],
	"haggler": ["travel", "coins", 3, 10, 0, ["windwalker"], 0.06, "percent"],
	"pathfinder": ["travel", "compass", 3, 10, 1, ["windwalker"], 0.12, "percent"],
	"charmer": ["travel", "lasso", 3, 10, 2, ["windwalker"], 0.08, "percent"],
	"beastLord": ["beasts", "super_beastLord", 1, 9, 1, ["herdsman", "soul", "starHunter"], 1.0, "flag", SUPER_COST],
	"herd": ["beasts", "milk", 3, 10, 0, ["beastLord"], 0.1, "percent"],
	"packHunt": ["beasts", "fang", 3, 10, 1, ["beastLord"], 0.1, "percent"],
	"kinship": ["beasts", "heart", 3, 10, 2, ["beastLord"], 0.05, "percent"],
	"landlord": ["farming", "super_landlord", 1, 8, 1, ["deepRoots", "harvestMoon", "seedTrader"], 1.0, "flag", SUPER_COST],
	"richSoil": ["farming", "compost", 3, 9, 0, ["landlord"], 0.12, "percent"],
	"gourmet": ["farming", "dish_stew", 3, 9, 1, ["landlord"], 0.1, "percent"],
	"fairTrade": ["farming", "moneybag", 3, 9, 2, ["landlord"], 0.1, "percent"],
	"champion": ["combat", "super_champion", 1, 8, 1, ["delver", "warlord", "regen"], 1.0, "flag", SUPER_COST],
	"fortress": ["combat", "shield", 3, 9, 0, ["champion"], 0.03, "percent"],
	"executioner": ["combat", "skull", 3, 9, 1, ["champion"], 0.1, "percent"],
	"bloodlust": ["combat", "potion", 3, 9, 2, ["champion"], 0.01, "percent"],
}


static func ids() -> Array:
	return SPECS.keys()


static func exists(id: String) -> bool:
	return SPECS.has(id)


static func branch(id: String) -> String:
	return SPECS[id][0]


static func icon(id: String) -> String:
	return SPECS[id][1]


static func max_rank(id: String) -> int:
	return SPECS[id][2]


static func tier(id: String) -> int:
	return SPECS[id][3]


static func column(id: String) -> int:
	return SPECS[id][4]


static func parents(id: String) -> Array:
	return SPECS[id][5]


static func per_rank(id: String) -> float:
	return SPECS[id][6]


static func unit(id: String) -> String:
	return SPECS[id][7]


## Сколько очков стоит один ранг. У суперталантов больше одного.
static func cost(id: String) -> int:
	var s: Array = SPECS[id]
	return s[8] if s.size() > 8 else 1


## Суперталант: дорогой, открывается, только когда родители прокачаны до максимума,
## и ведёт к следующему ряду ветки.
static func is_super(id: String) -> bool:
	return cost(id) > 1


static func required_level(id: String) -> int:
	return TIER_LEVELS[tier(id)]


static func name_of(id: String) -> String:
	return L.t("talent." + id)


## Текст эффекта на заданном ранге.
static func effect(id: String, rank: int) -> String:
	var value := per_rank(id) * float(rank)
	var key := "talent." + id + ".text"
	match unit(id):
		"percent": return L.t(key, [Fmt.pct(value)])
		"flat": return L.t(key, [int(value)])
	return L.t(key)


## Таланты ветки в порядке TalentID.allCases.
static func in_branch(b: String) -> Array:
	var out: Array = []
	for id in SPECS:
		if SPECS[id][0] == b:
			out.append(id)
	return out


static func branch_title(b: String) -> String:
	return L.t("branch." + b)


static func branch_icon(b: String) -> String:
	return BRANCH_ICONS.get(b, "star")


static func branch_color(b: String) -> Color:
	return BRANCH_COLORS.get(b, Color.WHITE)
