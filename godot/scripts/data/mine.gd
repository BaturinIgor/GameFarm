class_name Mine
## Шахта Глубин: мини-игра со взрывами (документ "Новые механики и сюжет").
## Поле 7x9 из блоков руды. Касание группы из 2+ одинаковых соседних блоков взрывает её, сверху падают новые.
## Группа из 5+ оставляет динамит, из 7+ - бур, из 9+ - гранату Древних. Цель этажа - разбить все камни
## (их бьют взрывы рядом) за ограниченное число ударов. Каждые 10 этажей меняется порода.
## Вход стоит фонарь: их 5, один восстанавливается за 30 минут.

const W := 7
const H := 9
const MIN_LEVEL := 5

const LAMPS_MAX := 5
const LAMP_SECONDS := 1800.0
## Полный запас фонарей за кристаллы.
const LAMPS_PRICE := 30
## Ещё ударов, когда они кончились: за кристаллы (цена растёт с каждой покупкой за этаж) или за ролик (раз за этаж).
const EXTRA_MOVES := 5
const EXTRA_PRICE := 10
const EXTRA_STEP := 10

## Из скольких блоков группа оставляет особый блок.
const TNT_AT := 5
const DRILL_AT := 7
const ORB_AT := 9

## Сколько блоков руды дают 1 единицу на склад.
const BLOCKS_PER_UNIT := 4

## Порода по глубине: каждые 10 этажей. ores - 5 видов руды (на первых 20 этажах в игре 4 из них),
## bg и rock - цвета фона шахты и камней, tint - оттенок блоков.
const LAYERS := [
	{"id": "earth", "ores": ["stone", "coal", "clay", "iron", "copper"],
		"bg": Color("3b2a1e"), "rock": Color("6d5d50"), "tint": Color("8a6a4a")},
	{"id": "stone", "ores": ["stone", "coal", "iron", "gold", "clay"],
		"bg": Color("2a2a33"), "rock": Color("6b6b78"), "tint": Color("70707e")},
	{"id": "ice", "ores": ["ice", "iron", "gold", "diamond", "stone"],
		"bg": Color("1d3346"), "rock": Color("8aa7bd"), "tint": Color("5d88a8")},
	{"id": "crystal", "ores": ["crystal", "diamond", "amethyst", "gold", "emerald"],
		"bg": Color("261a3d"), "rock": Color("6e5a8f"), "tint": Color("6d4f9e")},
	{"id": "lava", "ores": ["obsidian", "sulfur", "ruby", "gold", "coal"],
		"bg": Color("3a1410"), "rock": Color("6a4a44"), "tint": Color("9a3a26")},
]
## Цвет блока по номеру руды: пять хорошо различимых цветов, значок руды - поверх.
const ORE_COLORS := [Color("e0564f"), Color("4f9de0"), Color("6cc24a"), Color("f2c33c"), Color("b07ae0")]


static func layer(floor_n: int) -> Dictionary:
	return LAYERS[(maxi(1, floor_n) - 1) / 10 % LAYERS.size()]


static func layer_name(floor_n: int) -> String:
	return L.t("mine.layer." + str(layer(floor_n)["id"]))


## Сколько видов руды на этаже: 4, с 21-го этажа - 5.
static func colors(floor_n: int) -> int:
	return 4 if floor_n <= 20 else 5


static func ore_of(floor_n: int, c: int) -> String:
	var ores: Array = layer(floor_n)["ores"]
	return str(ores[clampi(c, 0, ores.size() - 1)])


## Камней на этаже.
static func rocks(floor_n: int) -> int:
	return mini(4 + floor_n / 2, 16)


## Прочность камня: на первых этажах 1, глубже - до 3.
static func rock_hp(floor_n: int, rng: RandomNumberGenerator) -> int:
	if floor_n < 8:
		return 1
	var top := 2 if floor_n < 25 else 3
	return rng.randi_range(1, top) if rng.randf() < 0.6 else 1


## Ударов на этаж.
static func moves(floor_n: int) -> int:
	return 18 + (4 if floor_n <= 10 else 0) + mini(6, floor_n / 15)


## Монеты за этаж.
static func coins(floor_n: int, level: int) -> int:
	return int(round(Chests.base_value(level) * (0.5 + 0.02 * float(floor_n)) / 10.0)) * 10


## Ключ за этаж ("" - без ключа): каждые 25 - звёздный, каждые 10 - серебряный, каждые 5 - медный.
static func key_for(floor_n: int) -> String:
	if floor_n % 25 == 0:
		return "star"
	if floor_n % 10 == 0:
		return "silver"
	if floor_n % 5 == 0:
		return "copper"
	return ""


## Сколько руды можно унести из шахты за день (единиц на склад).
static func daily_ore(level: int) -> int:
	return 150 + level * 10
