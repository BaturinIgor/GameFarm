class_name Legacy
## Перерождение и наследие (порт Rebirth и LegacyPerk из Legacy.swift).
## Игрок начинает заново и получает искры, а за искры покупает вечные бонусы наследия.

## С этого уровня перерождение даёт искры.
const MIN_LEVEL := 15

const PERKS := ["harvest", "wisdom", "merchant", "pack", "boots", "growth", "talent", "tools", "capital",
	"fighter", "vigor", "luck", "gardener", "chef", "companions"]

## Пиксельная иконка бонуса (ic_<имя>).
const ICON := {
	"harvest": "basket", "wisdom": "book", "merchant": "coins", "pack": "bag", "boots": "boots",
	"growth": "hourglass", "talent": "star", "tools": "hammer", "capital": "chest_gold", "fighter": "sword",
	"vigor": "heart", "luck": "clover", "gardener": "sprout", "chef": "dish_stew", "companions": "paw",
}

## Прибавка за один ранг.
const PER_RANK := {
	"harvest": 0.05, "wisdom": 0.06, "merchant": 0.05, "pack": 4.0, "boots": 0.03, "growth": 0.05,
	"talent": 1.0, "tools": 1.0, "capital": 300.0, "fighter": 0.05, "vigor": 0.05, "luck": 0.01,
	"gardener": 0.04, "chef": 0.1, "companions": 1.0,
}

## Бонусы, которые показываются процентами.
const PERCENT := ["harvest", "wisdom", "merchant", "boots", "growth", "fighter", "vigor", "luck", "gardener", "chef"]


## Искры за текущий забег: растут с уровнем, плюс немного за достижения и открытые проходы.
static func sparks(level: int, achievements: int, gates: int) -> int:
	if level < MIN_LEVEL:
		return 0
	var base := pow(float(level - 10), 1.5) / 2.0
	return int(floor(base)) + achievements / 2 + gates


static func name_of(perk: String) -> String:
	return L.t("legacy." + perk)


static func icon(perk: String) -> String:
	return str(ICON.get(perk, "spark"))


static func max_rank(perk: String) -> int:
	match perk:
		"tools", "companions": return 3
		"talent", "chef": return 5
	return 10


static func per_rank(perk: String) -> float:
	return float(PER_RANK.get(perk, 0.0))


## Цена следующего ранга в искрах.
static func cost(perk: String, rank: int) -> int:
	match perk:
		"tools": return 12 * (rank + 1)
		"companions": return 10 + 10 * rank
		"talent": return 8 + 6 * rank
	return 3 + 2 * rank


## Текст бонуса для заданного числа рангов.
static func effect(perk: String, ranks: int) -> String:
	var v := per_rank(perk) * float(ranks)
	if perk in PERCENT:
		return L.t("legacy.%s.effect" % perk, [Fmt.pct(v)])
	if perk == "capital":
		return L.t("legacy.%s.effect" % perk, [Fmt.n(int(v))])
	return L.t("legacy.%s.effect" % perk, [int(v)])
