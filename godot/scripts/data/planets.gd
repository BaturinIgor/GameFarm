class_name Planets
## Содержимое дальних планет: свой ресурс в каждой локации, страж локации (босс раз в день), и сводка
## «что ждёт на планете» для карты. Сами локации - в Locations, монстры - в Monsters.BESTIARY.

## Ресурс, который есть только в этой локации, и точка добычи, откуда он падает (Nodes.SPECS).
const RESOURCE := {
	"ashPlains": "emberstone", "amberWoods": "resin", "fireCanyon": "phoenixFeather",
	"starMeadows": "starlight", "frostSpires": "frostglass", "crystalReef": "azurite",
}
const NODE := {
	"ashPlains": "emberVein", "amberWoods": "sunTree", "fireCanyon": "phoenixNest",
	"starMeadows": "starBloom", "frostSpires": "frostCrystal", "crystalReef": "reefGeode",
}

## Страж локации: вид монстра, цвет и сколько монстров уровней сверху. Появляется в дальней части
## локации, пока его не победили сегодня. Награда за первую победу за день - REWARD.
const GUARDIAN := {
	"ashPlains": {"kind": "slimeRed", "tint": Color(1.0, 0.45, 0.2), "plus": 3},
	"amberWoods": {"kind": "orcWarrior", "tint": Color(1.0, 0.75, 0.3), "plus": 3},
	"fireCanyon": {"kind": "skelKnight", "tint": Color(1.0, 0.35, 0.25), "plus": 4},
	"starMeadows": {"kind": "skelMage", "tint": Color(0.75, 0.7, 1.0), "plus": 3},
	"frostSpires": {"kind": "slimeIce", "tint": Color(0.65, 0.9, 1.0), "plus": 3},
	"crystalReef": {"kind": "orcShaman", "tint": Color(0.45, 0.75, 1.0), "plus": 4},
}

## Награда стража за день: ресурс локации, ключ и (редко) Осколок Древних.
const REWARD_RES := 12
const REWARD_KEY := "silver"
const REWARD_SHARD_CHANCE := 0.1


static func of_planet(p: String) -> Array:
	return WorldGraph.planet_locations(p)


static func resource_of(loc: String) -> String:
	return str(RESOURCE.get(loc, ""))


static func guardian(loc: String) -> Dictionary:
	return GUARDIAN.get(loc, {})


static func guardian_name(loc: String) -> String:
	return L.t("guardian." + loc)


## Что ждёт на планете: локации с уровнями, свои ресурсы, дикие звери, монстры и стражи.
static func preview(p: String) -> Dictionary:
	var locs: Array = of_planet(p)
	var res: Array = []
	var animals: Array = []
	var monsters: Array = []
	var guardians: Array = []
	for loc in locs:
		if RESOURCE.has(loc):
			res.append(RESOURCE[loc])
		for a in Animals.IDS:
			var spec: Dictionary = Animals.spec(a)
			if str(spec.get("source", "")) == "wild" and str(spec.get("location", "")) == loc and not a in animals:
				animals.append(a)
		for e in Monsters.in_location(loc):
			if not e[0] in monsters:
				monsters.append(e[0])
		if GUARDIAN.has(loc):
			guardians.append(loc)
	return {"locations": locs, "resources": res, "animals": animals, "monsters": monsters, "guardians": guardians}
