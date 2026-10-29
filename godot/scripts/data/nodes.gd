class_name Nodes
## Точки добычи: чем добывать, ступень, прочность, опыт, восстановление, что выпадает.
## yields: [ресурс, минимум, максимум, шанс].

const SPECS := {
	"tree": {"tool": "axe", "tier": 1, "hp": 3.0, "xp": 3, "respawn": 8.0, "yields": [["wood", 2, 3, 1.0]], "radius": 18, "blocking": true, "keeps_body": false, "bar": 70, "chip": Color(0.55, 0.36, 0.2)},
	"pine": {"tool": "axe", "tier": 2, "hp": 6.0, "xp": 6, "respawn": 11.0, "yields": [["wood", 4, 5, 1.0]], "radius": 16, "blocking": true, "keeps_body": false, "bar": 74, "chip": Color(0.55, 0.36, 0.2)},
	"palm": {"tool": "axe", "tier": 3, "hp": 10.0, "xp": 9, "respawn": 14.0, "yields": [["wood", 5, 6, 1.0], ["coconut", 1, 2, 0.7]], "radius": 16, "blocking": true, "keeps_body": false, "bar": 76, "chip": Color(0.55, 0.36, 0.2)},
	"snowPine": {"tool": "axe", "tier": 4, "hp": 17.0, "xp": 14, "respawn": 16.0, "yields": [["wood", 8, 10, 1.0]], "radius": 18, "blocking": true, "keeps_body": false, "bar": 78, "chip": Color(1, 1, 1)},
	"glowTree": {"tool": "axe", "tier": 5, "hp": 26.0, "xp": 22, "respawn": 22.0, "yields": [["wood", 12, 15, 1.0], ["crystal", 1, 1, 0.15]], "radius": 20, "blocking": true, "keeps_body": false, "bar": 80, "chip": Color(0.75, 0.55, 1)},
	"bush": {"tool": "hand", "tier": 1, "hp": 2.0, "xp": 1, "respawn": 7.0, "yields": [["berries", 2, 3, 1.0]], "radius": 14, "blocking": false, "keeps_body": false, "bar": 40, "chip": Color(0.35, 0.4, 0.85)},
	"appleTree": {"tool": "hand", "tier": 1, "hp": 3.0, "xp": 2, "respawn": 10.0, "yields": [["apples", 2, 3, 1.0]], "radius": 18, "blocking": true, "keeps_body": true, "bar": 70, "chip": Color(0.9, 0.2, 0.2)},
	"mushroom": {"tool": "hand", "tier": 1, "hp": 1.0, "xp": 2, "respawn": 8.0, "yields": [["mushrooms", 1, 2, 1.0]], "radius": 10, "blocking": false, "keeps_body": false, "bar": 34, "chip": Color(0.85, 0.25, 0.2)},
	"carrot": {"tool": "hand", "tier": 1, "hp": 2.0, "xp": 3, "respawn": 9.0, "yields": [["carrots", 2, 3, 1.0]], "radius": 11, "blocking": false, "keeps_body": false, "bar": 36, "chip": Color(1, 0.55, 0.1)},
	"cactus": {"tool": "axe", "tier": 2, "hp": 5.0, "xp": 7, "respawn": 12.0, "yields": [["cactus", 2, 3, 1.0]], "radius": 14, "blocking": true, "keeps_body": false, "bar": 56, "chip": Color(0.3, 0.68, 0.3)},
	"bamboo": {"tool": "axe", "tier": 2, "hp": 5.0, "xp": 5, "respawn": 10.0, "yields": [["bamboo", 3, 4, 1.0]], "radius": 14, "blocking": true, "keeps_body": false, "bar": 62, "chip": Color(0.3, 0.68, 0.3)},
	"glowShroom": {"tool": "hand", "tier": 1, "hp": 4.0, "xp": 10, "respawn": 14.0, "yields": [["mushrooms", 4, 6, 1.0]], "radius": 12, "blocking": false, "keeps_body": false, "bar": 40, "chip": Color(0.4, 0.95, 1)},
	"rock": {"tool": "pickaxe", "tier": 1, "hp": 4.0, "xp": 3, "respawn": 9.0, "yields": [["stone", 2, 3, 1.0]], "radius": 16, "blocking": true, "keeps_body": false, "bar": 44, "chip": Color(0.6, 0.6, 0.6)},
	"boulder": {"tool": "pickaxe", "tier": 2, "hp": 8.0, "xp": 6, "respawn": 13.0, "yields": [["stone", 5, 7, 1.0], ["coal", 1, 1, 0.3]], "radius": 24, "blocking": true, "keeps_body": false, "bar": 60, "chip": Color(0.6, 0.6, 0.6)},
	"coalOre": {"tool": "pickaxe", "tier": 2, "hp": 7.0, "xp": 6, "respawn": 13.0, "yields": [["coal", 2, 3, 1.0], ["stone", 1, 1, 0.5]], "radius": 20, "blocking": true, "keeps_body": false, "bar": 52, "chip": Color(0.2, 0.2, 0.2)},
	"ironOre": {"tool": "pickaxe", "tier": 3, "hp": 11.0, "xp": 10, "respawn": 16.0, "yields": [["iron", 2, 3, 1.0], ["stone", 1, 1, 0.5]], "radius": 20, "blocking": true, "keeps_body": false, "bar": 52, "chip": Color(0.86, 0.52, 0.32)},
	"goldOre": {"tool": "pickaxe", "tier": 4, "hp": 18.0, "xp": 16, "respawn": 22.0, "yields": [["gold", 2, 3, 1.0]], "radius": 20, "blocking": true, "keeps_body": false, "bar": 52, "chip": Color(1.0, 0.82, 0.18)},
	"iceBlock": {"tool": "pickaxe", "tier": 4, "hp": 15.0, "xp": 14, "respawn": 16.0, "yields": [["ice", 3, 4, 1.0]], "radius": 18, "blocking": true, "keeps_body": false, "bar": 52, "chip": Color(0.55, 0.8, 1)},
	"diamondOre": {"tool": "pickaxe", "tier": 5, "hp": 30.0, "xp": 30, "respawn": 35.0, "yields": [["diamond", 1, 2, 1.0], ["stone", 2, 2, 0.5]], "radius": 20, "blocking": true, "keeps_body": false, "bar": 56, "chip": Color(0.45, 0.9, 1.0)},
	"crystalOre": {"tool": "pickaxe", "tier": 6, "hp": 46.0, "xp": 45, "respawn": 45.0, "yields": [["crystal", 1, 2, 1.0]], "radius": 22, "blocking": true, "keeps_body": false, "bar": 64, "chip": Color(0.72, 0.45, 1.0)},
	"fishSpot": {"tool": "rod", "tier": 1, "hp": 4.0, "xp": 4, "respawn": 10.0, "yields": [["fish", 1, 2, 1.0]], "radius": 14, "blocking": false, "keeps_body": false, "bar": 34, "chip": Color(0.55, 0.8, 1)},
	"oasisFish": {"tool": "rod", "tier": 2, "hp": 7.0, "xp": 8, "respawn": 13.0, "yields": [["fish", 2, 3, 1.0]], "radius": 14, "blocking": false, "keeps_body": false, "bar": 34, "chip": Color(0.55, 0.8, 1)},
	"iceHole": {"tool": "rod", "tier": 3, "hp": 12.0, "xp": 14, "respawn": 16.0, "yields": [["fish", 4, 5, 1.0]], "radius": 16, "blocking": false, "keeps_body": false, "bar": 34, "chip": Color(0.55, 0.8, 1)},
	"willow": {"tool": "axe", "tier": 3, "hp": 9.0, "xp": 9, "respawn": 13.0, "yields": [["wood", 5, 6, 1.0], ["herbs", 1, 2, 0.5]], "radius": 18, "blocking": true, "keeps_body": false, "bar": 76, "chip": Color(0.4, 0.55, 0.3)},
	"herbPatch": {"tool": "hand", "tier": 1, "hp": 3.0, "xp": 5, "respawn": 9.0, "yields": [["herbs", 2, 3, 1.0]], "radius": 12, "blocking": false, "keeps_body": false, "bar": 40, "chip": Color(0.3, 0.68, 0.3)},
	"clayPit": {"tool": "pickaxe", "tier": 2, "hp": 7.0, "xp": 7, "respawn": 12.0, "yields": [["clay", 3, 4, 1.0]], "radius": 18, "blocking": false, "keeps_body": false, "bar": 40, "chip": Color(0.75, 0.45, 0.3)},
	"swampFish": {"tool": "rod", "tier": 2, "hp": 7.0, "xp": 8, "respawn": 12.0, "yields": [["fish", 2, 3, 1.0], ["herbs", 1, 1, 0.3]], "radius": 14, "blocking": false, "keeps_body": false, "bar": 34, "chip": Color(0.55, 0.8, 1)},
	"bananaPalm": {"tool": "axe", "tier": 6, "hp": 40.0, "xp": 34, "respawn": 20.0, "yields": [["wood", 16, 20, 1.0], ["banana", 2, 4, 1.0]], "radius": 18, "blocking": true, "keeps_body": false, "bar": 80, "chip": Color(1, 0.88, 0.3)},
	"pineapple": {"tool": "hand", "tier": 1, "hp": 10.0, "xp": 26, "respawn": 16.0, "yields": [["pineapple", 2, 3, 1.0]], "radius": 14, "blocking": false, "keeps_body": false, "bar": 44, "chip": Color(1, 0.75, 0.2)},
	"shells": {"tool": "hand", "tier": 1, "hp": 6.0, "xp": 20, "respawn": 14.0, "yields": [["shell", 2, 3, 1.0], ["pearl", 1, 1, 0.05]], "radius": 12, "blocking": false, "keeps_body": false, "bar": 34, "chip": Color(1, 0.85, 0.8)},
	"oyster": {"tool": "rod", "tier": 5, "hp": 30.0, "xp": 40, "respawn": 24.0, "yields": [["fish", 6, 8, 1.0], ["pearl", 1, 1, 0.45]], "radius": 14, "blocking": false, "keeps_body": false, "bar": 34, "chip": Color(0.55, 0.8, 1)},
	"coral": {"tool": "pickaxe", "tier": 6, "hp": 50.0, "xp": 44, "respawn": 28.0, "yields": [["coral", 2, 3, 1.0]], "radius": 18, "blocking": true, "keeps_body": false, "bar": 56, "chip": Color(1, 0.45, 0.5)},
	"ashTree": {"tool": "axe", "tier": 7, "hp": 70.0, "xp": 55, "respawn": 26.0, "yields": [["wood", 24, 30, 1.0], ["sulfur", 1, 2, 0.4]], "radius": 20, "blocking": true, "keeps_body": false, "bar": 80, "chip": Color(0.35, 0.35, 0.35)},
	"fireFlower": {"tool": "hand", "tier": 1, "hp": 14.0, "xp": 38, "respawn": 18.0, "yields": [["herbs", 6, 8, 1.0], ["sulfur", 1, 1, 0.25]], "radius": 12, "blocking": false, "keeps_body": false, "bar": 40, "chip": Color(1, 0.45, 0.15)},
	"sulfurVent": {"tool": "pickaxe", "tier": 6, "hp": 55.0, "xp": 48, "respawn": 26.0, "yields": [["sulfur", 2, 3, 1.0]], "radius": 20, "blocking": true, "keeps_body": false, "bar": 56, "chip": Color(0.95, 0.92, 0.25)},
	"obsidianOre": {"tool": "pickaxe", "tier": 7, "hp": 90.0, "xp": 64, "respawn": 32.0, "yields": [["obsidian", 2, 3, 1.0]], "radius": 20, "blocking": true, "keeps_body": false, "bar": 58, "chip": Color(0.3, 0.18, 0.45)},
	"rubyOre": {"tool": "pickaxe", "tier": 7, "hp": 110.0, "xp": 80, "respawn": 45.0, "yields": [["ruby", 1, 1, 1.0], ["obsidian", 1, 1, 0.4]], "radius": 20, "blocking": true, "keeps_body": false, "bar": 58, "chip": Color(0.95, 0.15, 0.3)},
	"lavaFish": {"tool": "rod", "tier": 7, "hp": 80.0, "xp": 60, "respawn": 26.0, "yields": [["fish", 12, 15, 1.0], ["ruby", 1, 1, 0.12]], "radius": 14, "blocking": false, "keeps_body": false, "bar": 34, "chip": Color(1, 0.5, 0.1)},
	"cloudBush": {"tool": "hand", "tier": 1, "hp": 12.0, "xp": 50, "respawn": 20.0, "yields": [["cloud", 2, 3, 1.0]], "radius": 16, "blocking": false, "keeps_body": false, "bar": 50, "chip": Color(1, 1, 1)},
	"goldenTree": {"tool": "hand", "tier": 1, "hp": 16.0, "xp": 60, "respawn": 30.0, "yields": [["goldenApple", 1, 2, 1.0]], "radius": 20, "blocking": true, "keeps_body": true, "bar": 80, "chip": Color(1.0, 0.8, 0.2)},
	"skyTree": {"tool": "axe", "tier": 8, "hp": 140.0, "xp": 90, "respawn": 30.0, "yields": [["wood", 40, 50, 1.0], ["cloud", 1, 2, 0.5]], "radius": 20, "blocking": true, "keeps_body": false, "bar": 84, "chip": Color(0.7, 0.85, 1)},
	"starRock": {"tool": "pickaxe", "tier": 8, "hp": 160.0, "xp": 110, "respawn": 50.0, "yields": [["stardust", 1, 2, 1.0], ["crystal", 1, 1, 0.4]], "radius": 20, "blocking": true, "keeps_body": false, "bar": 60, "chip": Color(1, 0.95, 0.6)},
	"starPond": {"tool": "rod", "tier": 8, "hp": 120.0, "xp": 85, "respawn": 30.0, "yields": [["fish", 18, 22, 1.0], ["stardust", 1, 1, 0.2]], "radius": 14, "blocking": false, "keeps_body": false, "bar": 34, "chip": Color(0.6, 0.6, 1)},
	"beehive": {"tool": "hand", "tier": 1, "hp": 6.0, "xp": 14, "respawn": 30.0, "yields": [["honey", 1, 2, 1.0]], "radius": 14, "blocking": true, "keeps_body": true, "bar": 48, "chip": Color(1, 0.75, 0.2)},
	"grapeVine": {"tool": "hand", "tier": 1, "hp": 6.0, "xp": 10, "respawn": 25.0, "yields": [["berries", 5, 7, 1.0]], "radius": 22, "blocking": false, "keeps_body": false, "bar": 70, "chip": Color(0.55, 0.3, 0.75)},
	"treasureChest": {"tool": "hand", "tier": 1, "hp": 8.0, "xp": 30, "respawn": 600.0, "yields": [["gold", 3, 6, 1.0], ["pearl", 1, 1, 0.35], ["diamond", 1, 1, 0.25], ["shell", 2, 3, 0.5]], "radius": 16, "blocking": false, "keeps_body": false, "bar": 40, "chip": Color(1, 0.85, 0.3)},
	"pumpkinPatch": {"tool": "hand", "tier": 1, "hp": 8.0, "xp": 10, "respawn": 40.0, "yields": [["wheat", 2, 3, 1.0], ["pumpkin", 1, 1, 0.12]], "radius": 16, "blocking": false, "keeps_body": false, "bar": 44, "chip": Color(1, 0.55, 0.1)},
	"giftBox": {"tool": "hand", "tier": 1, "hp": 8.0, "xp": 10, "respawn": 40.0, "yields": [["apples", 2, 3, 1.0], ["gold", 1, 1, 0.2]], "radius": 14, "blocking": false, "keeps_body": false, "bar": 40, "chip": Color(0.9, 0.25, 0.3)},
	"sandCastle": {"tool": "hand", "tier": 1, "hp": 8.0, "xp": 10, "respawn": 40.0, "yields": [["shell", 1, 2, 1.0], ["pearl", 1, 1, 0.06]], "radius": 16, "blocking": false, "keeps_body": false, "bar": 46, "chip": Color(0.95, 0.8, 0.55)},
	"slimeCrystal": {"tool": "pickaxe", "tier": 1, "hp": 9.0, "xp": 12, "respawn": 40.0, "yields": [["slime", 2, 3, 1.0], ["crystal", 1, 1, 0.05]], "radius": 18, "blocking": true, "keeps_body": false, "bar": 58, "chip": Color(0.45, 0.95, 0.4)},
}

## Как точка исчезает после добычи.
const STYLE_FALL := ["tree", "pine", "palm", "snowPine", "glowTree", "willow", "bananaPalm", "ashTree", "skyTree", "bamboo", "cactus"]
const STYLE_CRUMBLE := ["rock", "boulder", "coalOre", "ironOre", "goldOre", "iceBlock", "diamondOre", "crystalOre",
	"coral", "sulfurVent", "obsidianOre", "rubyOre", "starRock", "clayPit", "slimeCrystal", "sandCastle"]
const STYLE_SPLASH := ["fishSpot", "oasisFish", "iceHole", "swampFish", "oyster", "lavaFish", "starPond"]
const STYLE_FADE := ["appleTree", "goldenTree", "beehive", "grapeVine"]


static func spec(type: String) -> Dictionary:
	return SPECS.get(type, SPECS["tree"])


static func name_of(type: String) -> String:
	return L.t("node." + type)


static func main_resource(type: String) -> String:
	return spec(type)["yields"][0][0]


static func style(type: String) -> String:
	if type in STYLE_FALL:
		return "fall"
	if type in STYLE_CRUMBLE:
		return "crumble"
	if type in STYLE_SPLASH:
		return "splash"
	if type in STYLE_FADE:
		return "fade"
	return "pop"
