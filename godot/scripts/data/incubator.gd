class_name Incubator
## Инкубатор и Гнездо (документ "Новые механики и сюжет", призыв и скрещивание).
## Яйцо - {r: редкость по шкале сундуков, a: зверь-гибрид или "", s: шанс редкой окраски}.
## Цвет яйца решает, какие звери могут вылупиться и сколько звёзд они получат.
## Гнездо: два своих зверя от 3 звёзд за 8 часов дают яйцо. Пара по рецепту - яйцо гибрида.

const MIN_LEVEL := 6
## Больше яиц не хранится: лишние превращаются в кристаллы.
const MAX_EGGS := 20
const NEST_STARS := 3
const NEST_SECONDS := 8.0 * 3600.0
## Ускорение: кристалл за каждые 10 минут, минимум 1.
const SPEED_MINUTES := 10.0
## Яйцо Древних за кристаллы.
const EGG_PRICE := 80
const EGG_PRICE_RARITY := "purple"

## Редкости яиц (серых нет).
const RARITIES := ["green", "blue", "purple", "gold", "red", "rainbow"]
## Сколько вылупляется: часы.
const HOURS := {"green": 0.5, "blue": 1.0, "purple": 2.0, "gold": 4.0, "red": 8.0, "rainbow": 12.0}
## Сколько звёзд даёт вылупившийся зверь.
const STARS := {"green": 1, "blue": 1, "purple": 1, "gold": 2, "red": 2, "rainbow": 3}
## Шанс редкой окраски у вылупившегося зверя.
const SHINY := {"green": 0.03, "blue": 0.04, "purple": 0.06, "gold": 0.1, "red": 0.15, "rainbow": 1.0}
## Зверь уже на 5 звёздах: вместо звезды кристаллы.
const CRYSTALS := {"green": 3, "blue": 5, "purple": 10, "gold": 20, "red": 40, "rainbow": 80}

## Рецепты: пара родителей (в любом порядке) -> гибрид.
const RECIPES := [
	["chicken", "goldenGoose", "goldenHen"],
	["horse", "swan", "pegasus"],
	["frog", "bee", "honeyToad"],
	["sheep", "unicorn", "cloudSheep"],
]
const HYBRIDS := ["goldenHen", "pegasus", "honeyToad", "cloudSheep"]


static func hours(r: String) -> float:
	return float(HOURS.get(r, 1.0))


static func name_of(r: String) -> String:
	return L.t("egg." + r)


## Гибрид пары или "".
static func hybrid_of(a: String, b: String) -> String:
	for rec in RECIPES:
		if (rec[0] == a and rec[1] == b) or (rec[0] == b and rec[1] == a):
			return str(rec[2])
	return ""


static func recipe_of(hybrid: String) -> Array:
	for rec in RECIPES:
		if rec[2] == hybrid:
			return [str(rec[0]), str(rec[1])]
	return []


## Кто может вылупиться из яйца такой редкости на этом уровне (обычные яйца, не гибриды).
static func pool(r: String, level: int) -> Array:
	var shop: Array = []
	var wild: Array = []
	var crystal: Array = []
	for id in Animals.IDS:
		var s := Animals.spec(id)
		match str(s.get("source", "")):
			"shop":
				if Animals.shop_level(id) <= level:
					shop.append(id)
			"wild":
				wild.append(id)
			"crystal":
				if Animals.crystal_level(id) <= level:
					crystal.append(id)
	match r:
		"green":
			return shop.slice(0, maxi(1, shop.size() / 2)) + ["mouse", "goose", "duck"]
		"blue":
			return shop + wild
		"purple":
			return wild + crystal
		"gold":
			return crystal + HYBRIDS
		_:
			return HYBRIDS + ["moonUnicorn"]


## Случайное яйцо из шахты по глубине.
static func mine_egg(floor_n: int) -> String:
	if floor_n >= 40:
		return "purple"
	return "blue" if floor_n >= 15 else "green"
