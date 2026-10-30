class_name Raids
## Набеги на усадьбу (документ "Новая экономика"): раз в 8 часов волна монстров идёт к складу.
## Победа - монеты и кристаллы, поражение - небольшая часть незащищённого склада и щит на 12 часов.

const EVERY := 8.0 * 3600.0
## Первый набег после открытия - через час, чтобы игрок увидел его в тот же день.
const FIRST := 3600.0
const WARN := 300.0
const POSTPONE := 3600.0
const SHIELD := 12.0 * 3600.0
## С какого уровня главного дома идут набеги.
const MAIN_LEVEL := 4
## Поражение: 10% незащищённой части. Защищено 50% + 2% за уровень склада.
const LOSS := 0.10
const PROTECT_BASE := 0.5
const PROTECT_PER_LEVEL := 0.02
## Сколько секунд монстр стоит у склада, прежде чем унести добычу и уйти.
const STEAL_TIME := 2.0
const STEAL_RADIUS := 56.0
## Зона частокола вокруг склада.
const WALL_RADIUS := 220.0

## Кто приходит: по уровню главного дома (берётся последняя подходящая строка).
const WAVES := [
	[4, ["slimeGreen", "orc"]],
	[6, ["slimeBlue", "orc", "skeleton"]],
	[8, ["slimePurple", "skeleton", "orcRogue"]],
	[11, ["skeletonDark", "orcShaman", "skelRogue"]],
	[14, ["skelSoldier", "orcWarrior", "skelMage"]],
	[17, ["skelKnight", "orcWarrior", "slimeRed"]],
]


## Сколько монстров в волне.
static func wave_size(main: int) -> int:
	return clampi(main + 2, 5, 14)


static func wave_level() -> int:
	return maxi(1, Game.level - 1)


static func wave_kinds(main: int) -> Array:
	var kinds: Array = WAVES[0][1]
	for row in WAVES:
		if main >= int(row[0]):
			kinds = row[1]
	return kinds


## Монстры волны по порядку.
static func wave(main: int) -> Array:
	var kinds := wave_kinds(main)
	var out: Array = []
	for i in wave_size(main):
		out.append(kinds[i % kinds.size()])
	return out


## Башни: сколько стоит у склада, урон выстрела, дальность, пауза между выстрелами.
static func tower_count(n: int) -> int:
	return 0 if n <= 0 else mini(4, 1 + n / 5)


static func tower_damage(n: int) -> float:
	return 26.0 * pow(1.12, 6.0 + 2.0 * float(n)) * 0.35


static func tower_range(n: int) -> float:
	return 230.0 + 6.0 * float(n)


const TOWER_RATE := 1.2


## Частокол: во сколько раз медленнее монстры у склада (0.75 - на четверть).
static func wall_slow(n: int) -> float:
	return 1.0 if n <= 0 else maxf(0.45, 0.75 - 0.015 * float(n - 1))


## Какая доля склада защищена.
static func protected_share(storage_level: int) -> float:
	return minf(1.0, PROTECT_BASE + PROTECT_PER_LEVEL * float(storage_level))
