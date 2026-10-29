class_name Cards
## Карты и созвездия (порт CardID, ConstellationID и Cards из Collection.swift).
## Каждое созвездие собирается из пяти карт. Полное созвездие даёт вечный бонус и образ героя.

const CONSTELLATIONS := ["harvest", "forest", "depths", "sea", "beasts", "monsters", "sky", "garden", "dungeon", "birds"]

## Карты созвездий по порядку (в этом порядке звёзды соединяются линией).
const SETS := {
	"harvest": ["wheat", "carrot", "pumpkin", "sunflower", "grapes"],
	"forest": ["log", "apple", "mushroom", "berry", "honey"],
	"depths": ["stone", "coal", "iron", "gold", "diamond"],
	"sea": ["fish", "shell", "coral", "pearl", "coconut"],
	"beasts": ["cow", "sheep", "pig", "chicken", "horse"],
	"monsters": ["slimeGreen", "slimeBlue", "slimeRed", "slimeIce", "skeleton"],
	"sky": ["cloud", "feather", "crystal", "ruby", "stardust"],
	"garden": ["tomato", "potato", "strawberry", "corn", "chili"],
	"dungeon": ["orc", "orcShaman", "skelKnight", "skelMage", "essence"],
	"birds": ["duck", "goose", "swan", "goldenGoose", "egg"],
}

const IDS := [
	"wheat", "carrot", "pumpkin", "sunflower", "grapes",
	"log", "apple", "mushroom", "berry", "honey",
	"stone", "coal", "iron", "gold", "diamond",
	"fish", "shell", "coral", "pearl", "coconut",
	"cow", "sheep", "pig", "chicken", "horse",
	"slimeGreen", "slimeBlue", "slimeRed", "slimeIce", "skeleton",
	"cloud", "feather", "crystal", "ruby", "stardust",
	"tomato", "potato", "strawberry", "corn", "chili",
	"orc", "orcShaman", "skelKnight", "skelMage", "essence",
	"duck", "goose", "swan", "goldenGoose", "egg",
]

## Ресурс, при добыче которого может выпасть карта.
const RESOURCE := {
	"wheat": "wheat", "carrot": "carrots", "pumpkin": "pumpkin", "sunflower": "sunflower", "grapes": "grapes",
	"log": "wood", "apple": "apples", "mushroom": "mushrooms", "berry": "berries", "honey": "honey",
	"stone": "stone", "coal": "coal", "iron": "iron", "gold": "gold", "diamond": "diamond",
	"fish": "fish", "shell": "shell", "coral": "coral", "pearl": "pearl", "coconut": "coconut",
	"cloud": "cloud", "feather": "feather", "crystal": "crystal", "ruby": "ruby", "stardust": "stardust",
	"tomato": "tomato", "potato": "potato", "strawberry": "strawberry", "corn": "corn", "chili": "chili",
	"essence": "essence", "egg": "egg",
}

## Карты с картинкой зверя и монстра (CardArt).
const ANIMAL := {
	"cow": "cow", "sheep": "sheep", "pig": "pig", "chicken": "chicken", "horse": "horse",
	"duck": "duck", "goose": "goose", "swan": "swan", "goldenGoose": "goldenGoose",
}
const MONSTER := {
	"slimeGreen": "slimeGreen", "slimeBlue": "slimeBlue", "slimeRed": "slimeRed", "slimeIce": "slimeIce",
	"skeleton": "skeleton", "orc": "orc", "orcShaman": "orcShaman", "skelKnight": "skelKnight", "skelMage": "skelMage",
}

## Какая карта может выпасть с монстра.
const FROM_MONSTER := {
	"slimeGreen": "slimeGreen", "slimeBlue": "slimeBlue", "slimeRed": "slimeRed", "slimeIce": "slimeIce",
	"skeleton": "skeleton", "skeletonDark": "skeleton",
	"orc": "orc", "orcRogue": "orc", "orcWarrior": "orc",
	"orcShaman": "orcShaman",
	"skelKnight": "skelKnight", "skelSoldier": "skelKnight",
	"skelMage": "skelMage", "skelRogue": "skelMage",
}

## Какая карта может выпасть при приручении зверя.
const FROM_ANIMAL := {
	"cow": "cow", "sheep": "sheep", "pig": "pig", "chicken": "chicken", "rooster": "chicken", "horse": "horse",
	"duck": "duck", "duckHat": "duck", "goose": "goose", "swan": "swan", "goldenGoose": "goldenGoose",
}

## Награда за полное созвездие.
const SKIN := {
	"harvest": "harvester", "forest": "ranger", "depths": "miner", "sea": "sailor", "beasts": "shepherd",
	"monsters": "hunter", "sky": "stargazer", "garden": "cultivator", "dungeon": "duelist", "birds": "falconer",
}

## Где звёзды на небе (0...1, y сверху вниз), рисуются линией по порядку карт.
const SHAPES := {
	"harvest": [[0.1, 0.7], [0.3, 0.35], [0.5, 0.55], [0.7, 0.25], [0.9, 0.6]],
	"forest": [[0.5, 0.1], [0.3, 0.4], [0.7, 0.4], [0.2, 0.8], [0.8, 0.8]],
	"depths": [[0.15, 0.2], [0.35, 0.75], [0.5, 0.3], [0.65, 0.75], [0.85, 0.2]],
	"sea": [[0.1, 0.5], [0.3, 0.25], [0.5, 0.6], [0.7, 0.3], [0.9, 0.55]],
	"beasts": [[0.2, 0.3], [0.45, 0.2], [0.6, 0.5], [0.4, 0.8], [0.85, 0.65]],
	"monsters": [[0.5, 0.15], [0.2, 0.45], [0.35, 0.85], [0.65, 0.85], [0.8, 0.45]],
	"sky": [[0.1, 0.8], [0.3, 0.5], [0.5, 0.15], [0.7, 0.5], [0.9, 0.8]],
	"garden": [[0.12, 0.3], [0.3, 0.7], [0.5, 0.35], [0.7, 0.7], [0.88, 0.3]],
	"dungeon": [[0.2, 0.2], [0.5, 0.15], [0.8, 0.2], [0.65, 0.8], [0.35, 0.8]],
	"birds": [[0.1, 0.6], [0.3, 0.3], [0.5, 0.5], [0.7, 0.3], [0.9, 0.6]],
}

## Сколько карт нужно для звезды: 1, 3, 6, 10, 15.
const THRESHOLDS := [1, 3, 6, 10, 15]


static func is_valid(card: String) -> bool:
	return card in IDS


static func constellation_of(card: String) -> String:
	for c in SETS:
		if card in SETS[c]:
			return c
	return ""


static func cards_of(c: String) -> Array:
	return SETS.get(c, [])


static func constellation_name(c: String) -> String:
	return L.t("const." + c)


static func name_of(card: String) -> String:
	if ANIMAL.has(card):
		return Animals.name_of(ANIMAL[card])
	if MONSTER.has(card):
		return Monsters.name_of(MONSTER[card])
	return Res.name_of(RESOURCE.get(card, "wood"))


## Картинка карты: ["res", вид], ["animal", зверь] или ["monster", монстр].
static func art(card: String) -> Array:
	if ANIMAL.has(card):
		return ["animal", ANIMAL[card]]
	if MONSTER.has(card):
		return ["monster", MONSTER[card]]
	return ["res", RESOURCE.get(card, "wood")]


## Карта для ресурса ("" - такой нет).
static func for_resource(kind: String) -> String:
	for card in IDS:
		if RESOURCE.get(card, "") == kind:
			return card
	return ""


static func for_monster(kind: String) -> String:
	return FROM_MONSTER.get(kind, "")


static func for_animal(id: String) -> String:
	return FROM_ANIMAL.get(id, "")


static func stars(count: int) -> int:
	var n := 0
	for t in THRESHOLDS:
		if count >= t:
			n += 1
	return n


## Сколько копий нужно для следующей звезды (-1 - звёзд больше нет).
static func next(count: int) -> int:
	for t in THRESHOLDS:
		if count < t:
			return t
	return -1


## Бонус: 5% за полное созвездие и ещё 2% за каждую звезду самой слабой карты сверх первой.
static func bonus(min_stars: int) -> float:
	if min_stars <= 0:
		return 0.0
	return 0.05 + 0.02 * float(min_stars - 1)


static func bonus_text(c: String, value: float) -> String:
	return L.t("const.%s.bonus" % c, [Fmt.pct(value)])
