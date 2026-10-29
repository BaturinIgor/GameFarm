class_name Locations
## Локации: мир с проходами, сад, экспедиции, ивенты, этажи дома, подземелья.

const IDS := [
	"meadow", "hills", "lake", "swamp", "desert", "snow", "caves", "island", "volcano", "sky",
	"ashPlains", "amberWoods", "fireCanyon", "starMeadows", "frostSpires", "crystalReef",
	"garden",
	"goldMine", "treasureIsland", "luckyMeadow", "crystalCaves", "skyIsles",
	"harvestFest", "slimeNight", "winterTale", "beachParty",
	"homeGround", "homeUpper", "homeBasement", "homeAttic", "homeGreenhouse",
	"dSlime", "dCrypt", "dOrc", "dFrost", "dFire",
]

const SPECS := {
	"meadow": {"level": 1, "kind": "world", "map": Vector2i(1, 0), "ground": Color(0.200, 0.596, 0.294), "path": Color(0.894, 0.651, 0.447), "water": Color(0.2, 0.55, 0.85), "wild": ["mouse"], "dark": false, "weather": "petals", "tint": Color(0, 0, 0, 0), "cloud_shadows": true, "critters": ["🦋", "🐝"], "music": "meadow", "ambience": "birds", "footstep": "footstepGrass", "lava": false},
	"hills": {"level": 4, "kind": "world", "map": Vector2i(0, 0), "ground": Color(0.486, 0.588, 0.235), "path": Color(0.894, 0.651, 0.447), "water": Color(0.2, 0.55, 0.85), "wild": ["goose", "mouse"], "dark": false, "weather": "leaves", "tint": Color(0, 0, 0, 0), "cloud_shadows": true, "critters": ["🦋"], "music": "hills", "ambience": "wind", "footstep": "footstepGrass", "lava": false},
	"lake": {"level": 9, "kind": "world", "map": Vector2i(2, 0), "ground": Color(0.243, 0.537, 0.282), "path": Color(0.894, 0.651, 0.447), "water": Color(0.2, 0.55, 0.85), "wild": ["duck", "swan"], "dark": false, "weather": "pollen", "tint": Color(0, 0, 0, 0), "cloud_shadows": true, "critters": ["🦋", "🐞"], "music": "lake", "ambience": "river", "footstep": "footstepGrass", "lava": false},
	"swamp": {"level": 12, "kind": "world", "map": Vector2i(2, 1), "ground": Color(0.247, 0.533, 0.424), "path": Color(0.353, 0.259, 0.188), "water": Color(0.184, 0.353, 0.251), "wild": ["frog", "duck"], "dark": false, "weather": "fireflies", "tint": Color(0.2, 0.35, 0.25, 0.1), "cloud_shadows": true, "critters": ["🦟", "🐌"], "music": "swamp", "ambience": "river", "footstep": "footstepGrass", "lava": false},
	"desert": {"level": 15, "kind": "world", "map": Vector2i(1, 1), "ground": Color(0.910, 0.706, 0.494), "path": Color(0.784, 0.549, 0.314), "water": Color(0.2, 0.55, 0.85), "wild": ["butterfly", "mouse"], "dark": false, "weather": "sand", "tint": Color(1, 0.6, 0.2, 0.05), "cloud_shadows": true, "critters": ["🦂"], "music": "desert", "ambience": "wind", "footstep": "footstepSand", "lava": false},
	"snow": {"level": 22, "kind": "world", "map": Vector2i(0, 1), "ground": Color(0.933, 0.957, 0.988), "path": Color(0.737, 0.804, 0.878), "water": Color(0.784, 0.902, 0.973), "wild": ["swan", "goose"], "dark": false, "weather": "snow", "tint": Color(0.4, 0.6, 1, 0.05), "cloud_shadows": true, "critters": [], "music": "snow", "ambience": "wind", "footstep": "footstepSnow", "lava": false},
	"caves": {"level": 30, "kind": "world", "map": Vector2i(0, 2), "ground": Color(0.227, 0.188, 0.322), "path": Color(0.298, 0.259, 0.408), "water": Color(0.086, 0.188, 0.369), "wild": ["mouse", "goldenGoose"], "dark": true, "weather": "motes", "tint": Color(0, 0, 0, 0), "cloud_shadows": false, "critters": [], "music": "caves", "ambience": "", "footstep": "footstepStone", "lava": false},
	"island": {"level": 36, "kind": "world", "map": Vector2i(2, 2), "ground": Color(0.894, 0.651, 0.447), "path": Color(0.941, 0.784, 0.588), "water": Color(0.086, 0.706, 0.831), "wild": ["butterfly", "duck"], "dark": false, "weather": "spray", "tint": Color(1, 0.9, 0.5, 0.04), "cloud_shadows": true, "critters": ["🦋", "🐦"], "music": "island", "ambience": "waves", "footstep": "footstepSand", "lava": false},
	"volcano": {"level": 43, "kind": "world", "map": Vector2i(1, 2), "ground": Color(0.298, 0.227, 0.204), "path": Color(0.361, 0.290, 0.267), "water": Color(1.000, 0.478, 0.122), "wild": ["goldenGoose", "goose"], "dark": false, "weather": "embers", "tint": Color(1, 0.25, 0.1, 0.08), "cloud_shadows": true, "critters": [], "music": "volcano", "ambience": "fire", "footstep": "footstepStone", "lava": true},
	"sky": {"level": 50, "kind": "world", "map": Vector2i(1, 3), "ground": Color(0.847, 0.863, 1.000), "path": Color(0.957, 0.910, 0.973), "water": Color(0.373, 0.314, 0.784), "wild": ["goldenGoose", "swan"], "dark": false, "weather": "stars", "tint": Color(1, 0.7, 0.9, 0.05), "cloud_shadows": true, "critters": ["🦋", "🕊️"], "music": "sky", "ambience": "wind", "footstep": "footstepGrass", "lava": false},
	"ashPlains": {"level": 45, "kind": "world", "map": Vector2i(0, 0), "ground": Color(0.353, 0.173, 0.118), "path": Color(0.431, 0.235, 0.173), "water": Color(1.000, 0.478, 0.122), "wild": ["goldenGoose"], "dark": false, "weather": "embers", "tint": Color(1, 0.3, 0.1, 0.08), "cloud_shadows": true, "critters": [], "music": "volcano", "ambience": "fire", "footstep": "footstepStone", "lava": true},
	"amberWoods": {"level": 47, "kind": "world", "map": Vector2i(0, 0), "ground": Color(0.627, 0.353, 0.102), "path": Color(0.722, 0.486, 0.282), "water": Color(0.2, 0.55, 0.85), "wild": ["goose", "goldenGoose"], "dark": false, "weather": "leaves", "tint": Color(1, 0.55, 0.15, 0.06), "cloud_shadows": true, "critters": ["🦋"], "music": "meadow", "ambience": "birds", "footstep": "footstepGrass", "lava": false},
	"fireCanyon": {"level": 49, "kind": "world", "map": Vector2i(0, 0), "ground": Color(0.706, 0.353, 0.204), "path": Color(0.831, 0.478, 0.282), "water": Color(0.2, 0.55, 0.85), "wild": ["goldenGoose"], "dark": false, "weather": "embers", "tint": Color(1, 0.4, 0.2, 0.05), "cloud_shadows": true, "critters": [], "music": "volcano", "ambience": "wind", "footstep": "footstepSand", "lava": false},
	"starMeadows": {"level": 54, "kind": "world", "map": Vector2i(0, 0), "ground": Color(0.243, 0.243, 0.604), "path": Color(0.541, 0.541, 0.941), "water": Color(0.373, 0.314, 0.784), "wild": ["swan", "goldenGoose"], "dark": false, "weather": "stars", "tint": Color(0.6, 0.6, 1, 0.06), "cloud_shadows": true, "critters": ["🦋"], "music": "sky", "ambience": "wind", "footstep": "footstepGrass", "lava": false},
	"frostSpires": {"level": 56, "kind": "world", "map": Vector2i(0, 0), "ground": Color(0.604, 0.667, 0.878), "path": Color(0.816, 0.863, 1.000), "water": Color(0.659, 0.816, 0.925), "wild": ["swan"], "dark": false, "weather": "snow", "tint": Color(0, 0, 0, 0), "cloud_shadows": true, "critters": [], "music": "snow", "ambience": "wind", "footstep": "footstepSnow", "lava": false},
	"crystalReef": {"level": 58, "kind": "world", "map": Vector2i(0, 0), "ground": Color(0.894, 0.651, 0.447), "path": Color(0.941, 0.784, 0.588), "water": Color(0.102, 0.541, 0.706), "wild": ["swan", "duck"], "dark": false, "weather": "spray", "tint": Color(0, 0, 0, 0), "cloud_shadows": true, "critters": ["🐦"], "music": "island", "ambience": "waves", "footstep": "footstepSand", "lava": false},
	"garden": {"level": 1, "kind": "garden", "map": Vector2i(0, 0), "ground": Color(0.200, 0.596, 0.294), "path": Color(0.784, 0.737, 0.682), "water": Color(0.2, 0.55, 0.85), "wild": [], "dark": false, "weather": "petals", "tint": Color(0, 0, 0, 0), "cloud_shadows": true, "critters": ["🦋", "🐝", "🦋"], "music": "garden", "ambience": "birds", "footstep": "footstepStone", "lava": false},
	"goldMine": {"level": 1, "kind": "expedition", "map": Vector2i(0, 0), "ground": Color(0.243, 0.188, 0.125), "path": Color(0.431, 0.345, 0.243), "water": Color(0.165, 0.290, 0.439), "wild": [], "dark": true, "weather": "motes", "tint": Color(0, 0, 0, 0), "cloud_shadows": false, "critters": [], "music": "expedition", "ambience": "", "footstep": "footstepStone", "lava": false},
	"treasureIsland": {"level": 1, "kind": "expedition", "map": Vector2i(0, 0), "ground": Color(0.894, 0.651, 0.447), "path": Color(0.941, 0.784, 0.588), "water": Color(0.086, 0.706, 0.831), "wild": [], "dark": false, "weather": "spray", "tint": Color(0, 0, 0, 0), "cloud_shadows": true, "critters": ["🐦"], "music": "expedition", "ambience": "waves", "footstep": "footstepSand", "lava": false},
	"luckyMeadow": {"level": 1, "kind": "expedition", "map": Vector2i(0, 0), "ground": Color(0.200, 0.596, 0.294), "path": Color(0.894, 0.651, 0.447), "water": Color(0.2, 0.55, 0.85), "wild": [], "dark": false, "weather": "pollen", "tint": Color(0, 0, 0, 0), "cloud_shadows": true, "critters": ["🦋", "🦋", "🐝"], "music": "expedition", "ambience": "birds", "footstep": "footstepGrass", "lava": false},
	"crystalCaves": {"level": 1, "kind": "expedition", "map": Vector2i(0, 0), "ground": Color(0.227, 0.188, 0.322), "path": Color(0.298, 0.259, 0.408), "water": Color(0.086, 0.188, 0.369), "wild": [], "dark": true, "weather": "motes", "tint": Color(0, 0, 0, 0), "cloud_shadows": false, "critters": [], "music": "expedition", "ambience": "", "footstep": "footstepStone", "lava": false},
	"skyIsles": {"level": 1, "kind": "expedition", "map": Vector2i(0, 0), "ground": Color(0.847, 0.863, 1.000), "path": Color(0.957, 0.910, 0.973), "water": Color(0.373, 0.314, 0.784), "wild": [], "dark": false, "weather": "stars", "tint": Color(1, 0.7, 0.9, 0.05), "cloud_shadows": true, "critters": ["🦋", "🕊️"], "music": "expedition", "ambience": "wind", "footstep": "footstepGrass", "lava": false},
	"harvestFest": {"level": 1, "kind": "event", "map": Vector2i(0, 0), "ground": Color(0.522, 0.447, 0.157), "path": Color(0.604, 0.384, 0.220), "water": Color(0.2, 0.55, 0.85), "wild": [], "dark": false, "weather": "leaves", "tint": Color(1, 0.55, 0.15, 0.06), "cloud_shadows": true, "critters": ["🦇", "🦋"], "music": "hills", "ambience": "wind", "footstep": "footstepGrass", "lava": false},
	"slimeNight": {"level": 1, "kind": "event", "map": Vector2i(0, 0), "ground": Color(0.118, 0.227, 0.157), "path": Color(0.235, 0.353, 0.259), "water": Color(0.227, 0.659, 0.227), "wild": [], "dark": true, "weather": "fireflies", "tint": Color(0, 0, 0, 0), "cloud_shadows": false, "critters": [], "music": "caves", "ambience": "", "footstep": "footstepStone", "lava": false},
	"winterTale": {"level": 1, "kind": "event", "map": Vector2i(0, 0), "ground": Color(0.933, 0.957, 0.988), "path": Color(0.737, 0.804, 0.878), "water": Color(0.784, 0.902, 0.973), "wild": [], "dark": false, "weather": "snow", "tint": Color(0.4, 0.6, 1, 0.05), "cloud_shadows": true, "critters": [], "music": "snow", "ambience": "wind", "footstep": "footstepSnow", "lava": false},
	"beachParty": {"level": 1, "kind": "event", "map": Vector2i(0, 0), "ground": Color(0.894, 0.651, 0.447), "path": Color(0.941, 0.784, 0.588), "water": Color(0.086, 0.706, 0.831), "wild": [], "dark": false, "weather": "spray", "tint": Color(0, 0, 0, 0), "cloud_shadows": true, "critters": ["🦀", "🐦"], "music": "island", "ambience": "waves", "footstep": "footstepSand", "lava": false},
	"homeGround": {"level": 1, "kind": "home", "map": Vector2i(0, 0), "ground": Color(0.690, 0.502, 0.314), "path": Color(0.690, 0.502, 0.314), "water": Color(0.2, 0.55, 0.85), "wild": [], "dark": false, "weather": "motes", "tint": Color(0, 0, 0, 0), "cloud_shadows": false, "critters": [], "music": "garden", "ambience": "", "footstep": "footstepStone", "lava": false},
	"homeUpper": {"level": 1, "kind": "home", "map": Vector2i(0, 0), "ground": Color(0.471, 0.353, 0.275), "path": Color(0.471, 0.353, 0.275), "water": Color(0.2, 0.55, 0.85), "wild": [], "dark": false, "weather": "motes", "tint": Color(0, 0, 0, 0), "cloud_shadows": false, "critters": [], "music": "garden", "ambience": "", "footstep": "footstepStone", "lava": false},
	"homeBasement": {"level": 1, "kind": "home", "map": Vector2i(0, 0), "ground": Color(0.353, 0.345, 0.392), "path": Color(0.353, 0.345, 0.392), "water": Color(0.2, 0.55, 0.85), "wild": [], "dark": false, "weather": "motes", "tint": Color(0, 0, 0, 0), "cloud_shadows": false, "critters": [], "music": "garden", "ambience": "", "footstep": "footstepStone", "lava": false},
	"homeAttic": {"level": 1, "kind": "home", "map": Vector2i(0, 0), "ground": Color(0.627, 0.431, 0.235), "path": Color(0.627, 0.431, 0.235), "water": Color(0.2, 0.55, 0.85), "wild": [], "dark": false, "weather": "motes", "tint": Color(0, 0, 0, 0), "cloud_shadows": false, "critters": [], "music": "garden", "ambience": "", "footstep": "footstepStone", "lava": false},
	"homeGreenhouse": {"level": 1, "kind": "home", "map": Vector2i(0, 0), "ground": Color(0.471, 0.588, 0.431), "path": Color(0.471, 0.588, 0.431), "water": Color(0.2, 0.55, 0.85), "wild": [], "dark": false, "weather": "pollen", "tint": Color(0, 0, 0, 0), "cloud_shadows": false, "critters": [], "music": "garden", "ambience": "birds", "footstep": "footstepStone", "lava": false},
	"dSlime": {"level": 1, "kind": "dungeon", "map": Vector2i(0, 0), "ground": Color(0.141, 0.337, 0.227), "path": Color(0.141, 0.337, 0.227), "water": Color(0.227, 0.659, 0.227), "wild": [], "dark": true, "weather": "motes", "tint": Color(0, 0, 0, 0), "cloud_shadows": false, "critters": [], "music": "caves", "ambience": "", "footstep": "footstepStone", "lava": false},
	"dCrypt": {"level": 1, "kind": "dungeon", "map": Vector2i(0, 0), "ground": Color(0.227, 0.204, 0.282), "path": Color(0.227, 0.204, 0.282), "water": Color(0.2, 0.55, 0.85), "wild": [], "dark": true, "weather": "motes", "tint": Color(0, 0, 0, 0), "cloud_shadows": false, "critters": [], "music": "caves", "ambience": "", "footstep": "footstepStone", "lava": false},
	"dOrc": {"level": 1, "kind": "dungeon", "map": Vector2i(0, 0), "ground": Color(0.353, 0.235, 0.125), "path": Color(0.353, 0.235, 0.125), "water": Color(0.2, 0.55, 0.85), "wild": [], "dark": true, "weather": "embers", "tint": Color(0, 0, 0, 0), "cloud_shadows": false, "critters": [], "music": "caves", "ambience": "fire", "footstep": "footstepStone", "lava": false},
	"dFrost": {"level": 1, "kind": "dungeon", "map": Vector2i(0, 0), "ground": Color(0.180, 0.353, 0.541), "path": Color(0.180, 0.353, 0.541), "water": Color(0.2, 0.55, 0.85), "wild": [], "dark": true, "weather": "snow", "tint": Color(0, 0, 0, 0), "cloud_shadows": false, "critters": [], "music": "snow", "ambience": "wind", "footstep": "footstepSnow", "lava": false},
	"dFire": {"level": 1, "kind": "dungeon", "map": Vector2i(0, 0), "ground": Color(0.369, 0.133, 0.063), "path": Color(0.369, 0.133, 0.063), "water": Color(0.2, 0.55, 0.85), "wild": [], "dark": true, "weather": "embers", "tint": Color(0, 0, 0, 0), "cloud_shadows": false, "critters": [], "music": "volcano", "ambience": "fire", "footstep": "footstepStone", "lava": false},
}

const ICONS := {"meadow": "apples", "hills": "stone", "lake": "fish", "swamp": "mushrooms", "desert": "cactus", "snow": "ice", "caves": "crystal", "island": "coconut", "volcano": "obsidian", "sky": "cloud", "ashPlains": "sulfur", "amberWoods": "goldenApple", "fireCanyon": "ruby", "starMeadows": "stardust", "frostSpires": "diamond", "crystalReef": "pearl", "garden": "crown", "goldMine": "gold", "treasureIsland": "chest_gold", "luckyMeadow": "clover", "crystalCaves": "gem", "skyIsles": "stardust", "harvestFest": "pumpkin", "slimeNight": "slime", "winterTale": "chest_gold", "beachParty": "shell", "homeGround": "stairs", "homeUpper": "stairs", "homeBasement": "stairs", "homeAttic": "stairs", "homeGreenhouse": "stairs", "dSlime": "skull", "dCrypt": "skull", "dOrc": "skull", "dFrost": "skull", "dFire": "skull"}

const PLANET := {
	"ashPlains": "ember", "amberWoods": "ember", "fireCanyon": "ember",
	"starMeadows": "azure", "frostSpires": "azure", "crystalReef": "azure",
}


static func spec(id: String) -> Dictionary:
	return SPECS.get(id, SPECS["meadow"])


static func kind(id: String) -> String:
	return spec(id)["kind"]


static func name_of(id: String) -> String:
	return L.t("loc." + id)


static func blurb(id: String) -> String:
	return L.t("loc." + id + ".blurb")


static func planet(id: String) -> String:
	return PLANET.get(id, "home")


static func icon(id: String) -> String:
	return ICONS.get(id, "map")


## Локации родной планеты (карта мира с проходами).
static func world() -> Array:
	return IDS.filter(func(i: String) -> bool: return kind(i) == "world" and planet(i) == "home")
