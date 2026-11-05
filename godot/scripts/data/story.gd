class_name Story
## Сюжет «Сердца земли»: глава на каждую большую локацию. В главе три шага: найти 3 страницы дневника Древних
## (падают при добыче в этой локации), принести дар Сердцу и прогнать слуг Мглы (победить монстров там же).
## Разбуженное Сердце даёт Осколок Древних, ключ и +2% к добыче. Осколки тратятся на Алтарь Древних
## (поднимает потолки бонусов) и мифическое пробуждение зверей.

const CHAPTERS := [
	{"loc": "meadow", "gift": {"coins": 300, "items": [["berries", 20], ["apples", 20]]}},
	{"loc": "hills", "gift": {"coins": 800, "items": [["carrots", 30], ["coal", 20], ["planks", 10]]}},
	{"loc": "lake", "gift": {"coins": 1500, "items": [["fish", 40], ["bamboo", 30], ["planks", 20]]}},
	{"loc": "swamp", "gift": {"coins": 2500, "items": [["herbs", 40], ["clay", 40], ["brick", 10]]}},
	{"loc": "desert", "gift": {"coins": 4000, "items": [["cactus", 40], ["coconut", 30], ["brick", 20]]}},
	{"loc": "snow", "gift": {"coins": 7000, "items": [["ice", 50], ["diamond", 5], ["iron_bar", 10]]}},
	{"loc": "caves", "gift": {"coins": 12000, "items": [["crystal", 20], ["diamond", 10], ["iron_bar", 20]]}},
	{"loc": "island", "gift": {"coins": 18000, "items": [["pearl", 15], ["coral", 30], ["lime", 20]]}},
	{"loc": "volcano", "gift": {"coins": 26000, "items": [["ruby", 10], ["obsidian", 30], ["gold_bar", 10]]}},
	{"loc": "sky", "gift": {"coins": 35000, "items": [["stardust", 15], ["cloud", 40], ["gold_bar", 20]]}},
	{"loc": "crystalReef", "gift": {"coins": 50000, "items": [["coral", 60], ["pearl", 30], ["gold_bar", 30]]}},
]

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

## Осколок с любой добычи: редкая находка (примерно раз в 2-3 часа игры).
const SHARD_CHANCE := 0.0004
## Шахта: осколок каждые 25 этажей.
const MINE_SHARD_EVERY := 25

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
