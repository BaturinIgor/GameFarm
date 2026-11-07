class_name Story
## Сюжет «Сердца земли»: глава на каждую большую локацию. В главе три шага: найти 3 страницы дневника Древних
## (падают при добыче в этой локации), принести дар Сердцу (монеты и плоды этой локации) и прогнать слуг Мглы (победить монстров там же).
## Разбуженное Сердце даёт Осколок Древних, ключ и +2% к добыче. Осколки тратятся на Алтарь Древних
## (поднимает потолки бонусов) и мифическое пробуждение зверей.

const CHAPTERS := [
	{"loc": "meadow", "gift": {"coins": 300, "items": [["berries", 20], ["apples", 20]]}},
	{"loc": "hills", "gift": {"coins": 800, "items": [["carrots", 30], ["coal", 20]]}},
	{"loc": "lake", "gift": {"coins": 1500, "items": [["fish", 30], ["bamboo", 30]]}},
	{"loc": "swamp", "gift": {"coins": 2500, "items": [["herbs", 30], ["clay", 30]]}},
	{"loc": "desert", "gift": {"coins": 4000, "items": [["cactus", 40], ["coconut", 15]]}},
	{"loc": "snow", "gift": {"coins": 7000, "items": [["ice", 40], ["diamond", 5]]}},
	{"loc": "caves", "gift": {"coins": 12000, "items": [["mushrooms", 60], ["crystal", 10]]}},
	{"loc": "island", "gift": {"coins": 18000, "items": [["pineapple", 30], ["coral", 15]]}},
	{"loc": "volcano", "gift": {"coins": 26000, "items": [["obsidian", 20], ["ruby", 5]]}},
	{"loc": "sky", "gift": {"coins": 35000, "items": [["cloud", 30], ["goldenApple", 20]]}},
	# Дальние планеты (1.1): главы перед финалом
	{"loc": "ashPlains", "gift": {"coins": 38000, "items": [["obsidian", 30], ["emberstone", 6]]}},
	{"loc": "amberWoods", "gift": {"coins": 42000, "items": [["goldenApple", 30], ["resin", 8]]}},
	{"loc": "fireCanyon", "gift": {"coins": 46000, "items": [["ruby", 10], ["phoenixFeather", 6]]}},
	{"loc": "starMeadows", "gift": {"coins": 52000, "items": [["stardust", 10], ["starlight", 8]]}},
	{"loc": "frostSpires", "gift": {"coins": 56000, "items": [["diamond", 20], ["frostglass", 8]]}},
	{"loc": "crystalReef", "gift": {"coins": 60000, "items": [["coral", 30], ["azurite", 8]]}},
]

## Версия списка глав: в 1.1 перед финалом добавлены 5 глав дальних планет (см. StorySystem.defaults).
const VERSION := 2
## Сколько глав вставлено перед финалом и с какой главы старые сохранения сдвигаются.
const INSERTED_AT := 10
const INSERTED := 5

## С какого уровня открыт раздел.
const MIN_LEVEL := 3

const PAGES := 3
## Шанс страницы за одну добычу в локации главы и гарантия: не позже чем через PAGE_PITY добыч.
const PAGE_CHANCE := 0.04
const PAGE_PITY := 30
## Сколько слуг Мглы прогнать: растёт с главой.
const KILLS_BASE := 6
const KILLS_STEP := 2
## Награда за главу: осколки и ключ (финал - больше).
const SHARDS_PER_CHAPTER := 1
const FINAL_SHARDS := 3
## Бонус к добыче за каждое разбуженное Сердце.
const HEART_YIELD := 0.02

## Осколок с любой добычи: редкая находка (очень редко).
const SHARD_CHANCE := 0.0001
## Шахта: осколок каждые 100 этажей.
const MINE_SHARD_EVERY := 100

## Алтарь Древних: каждый уровень поднимает один потолок. Цена - осколки.
const ALTAR := [
	["yield", 0.1], ["xp", 0.1], ["animal", 0.2], ["sell", 0.1], ["yield", 0.1],
	["xp", 0.1], ["animal", 0.2], ["sell", 0.1], ["yield", 0.2], ["xp", 0.2],
]
const ALTAR_COST := [1, 1, 2, 2, 3, 3, 4, 4, 5, 5]
const ALTAR_ICON := {"yield": "bag", "xp": "book", "animal": "paw", "sell": "coins"}

## Цвет значка осколка (значок искры, перекрашенный).
const SHARD_TINT := Color(0.62, 0.85, 1.0)

## Мифическое пробуждение зверя: столько осколков сверх обычной цены.
const MYTHIC_SHARDS := 2


static func count() -> int:
	return CHAPTERS.size()


static func loc(ch: int) -> String:
	return str(CHAPTERS[clampi(ch, 0, CHAPTERS.size() - 1)]["loc"])


static func gift(ch: int) -> Dictionary:
	return CHAPTERS[clampi(ch, 0, CHAPTERS.size() - 1)]["gift"]


static func kills(ch: int) -> int:
	return KILLS_BASE + KILLS_STEP * ch


## Искры наследия за пробуждённое Сердце (вместо перерождения): 4, 6, 8 ... 24.
const SPARKS_BASE := 4
const SPARKS_STEP := 2


static func sparks_for(ch: int) -> int:
	return SPARKS_BASE + SPARKS_STEP * ch


static func shards_for(ch: int) -> int:
	return FINAL_SHARDS if ch == CHAPTERS.size() - 1 else SHARDS_PER_CHAPTER


static func key_for(ch: int) -> String:
	return "star" if ch == CHAPTERS.size() - 1 else "silver"


static func title(ch: int) -> String:
	return L.t("heart.ch%d" % (ch + 1))


static func page_text(ch: int, page: int) -> String:
	return L.t("heart.ch%d.p%d" % [ch + 1, page + 1])


## Сколько добавляет к потолкам алтарь уровня lvl: {yield, xp, animal, sell}.
static func altar_caps(lvl: int) -> Dictionary:
	var out := {"yield": 0.0, "xp": 0.0, "animal": 0.0, "sell": 0.0}
	for i in mini(lvl, ALTAR.size()):
		out[ALTAR[i][0]] = float(out[ALTAR[i][0]]) + float(ALTAR[i][1])
	return out
