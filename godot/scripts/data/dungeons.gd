class_name Dungeons
## Подземелья: в каждом 10 этажей с волнами монстров, на 5 и 10 этаже - босс (порт DungeonID, ComingDungeon,
## Dungeon и Potion из Dungeons.swift). Идентификаторы - строки rawValue, как в iOS.

const IDS := ["slimeCaves", "boneCrypt", "orcCamp", "frostHollow", "fireDepths"]
## Подземелья, которые появятся позже: только анонс.
const COMING := ["sunkenTemple", "starMaze"]

const FLOORS := 10

## Карта подземелья.
const LOCATION := {"slimeCaves": "dSlime", "boneCrypt": "dCrypt", "orcCamp": "dOrc", "frostHollow": "dFrost",
	"fireDepths": "dFire"}
## С какого уровня героя открыто.
const LEVEL := {"slimeCaves": 8, "boneCrypt": 15, "orcCamp": 22, "frostHollow": 30, "fireDepths": 40}
## Уровень монстров на первом этаже.
const BASE_LEVEL := {"slimeCaves": 6, "boneCrypt": 13, "orcCamp": 20, "frostHollow": 28, "fireDepths": 37}
const MOBS := {
	"slimeCaves": ["slimeGreen", "slimeBlue", "slimePurple"],
	"boneCrypt": ["skeleton", "skelSoldier", "skelRogue", "skelMage"],
	"orcCamp": ["orc", "orcRogue", "orcShaman"],
	"frostHollow": ["slimeIce", "skeletonDark", "skelKnight"],
	"fireDepths": ["slimeRed", "orcWarrior", "skelMage", "skeletonDark"],
}
const BOSS := {"slimeCaves": "slimeGold", "boneCrypt": "skelKnight", "orcCamp": "orcWarrior", "frostHollow": "slimeIce",
	"fireDepths": "slimeRed"}
## Окраска босса (у слизняка своя).
const BOSS_TINT := {"boneCrypt": Color(0.55, 0.4, 0.9), "orcCamp": Color(0.9, 0.3, 0.2), "frostHollow": Color(0.4, 0.7, 1),
	"fireDepths": Color(1, 0.35, 0.05)}
## Оружие босса.
const WEAPON := {"slimeCaves": "slimeBlade", "boneCrypt": "boneSaber", "orcCamp": "orcCleaver", "frostHollow": "frostBrand",
	"fireDepths": "flameSword"}
## Цвета карточки: верх и низ.
const COLORS := {
	"slimeCaves": [Color("6fd15a"), Color("1f5a3a")],
	"boneCrypt": [Color("b8b0c8"), Color("3a3450")],
	"orcCamp": [Color("c89a5a"), Color("5a3a1e")],
	"frostHollow": [Color("a8dcff"), Color("2a4a8a")],
	"fireDepths": [Color("ff9a4a"), Color("7a1a0e")],
}

## Зелье лечения: восстанавливает 40% здоровья. Продаёт стражник, падает в подземельях.
const POTION_HEAL := 0.4
const POTION_COOLDOWN := 4.0


static func name_of(id: String) -> String:
	return L.t("dungeon." + id)


static func blurb(id: String) -> String:
	return L.t("dungeon." + id + ".blurb")


static func boss_name(id: String) -> String:
	return L.t("dungeon." + id + ".boss")


static func location(id: String) -> String:
	return LOCATION.get(id, "dSlime")


## Подземелье этой карты ("" - не подземелье).
static func of_location(loc: String) -> String:
	for id in IDS:
		if LOCATION[id] == loc:
			return id
	return ""


static func level(id: String) -> int:
	return int(LEVEL.get(id, 1))


static func base_level(id: String) -> int:
	return int(BASE_LEVEL.get(id, 1))


static func mobs(id: String) -> Array:
	return MOBS.get(id, [])


static func boss(id: String) -> String:
	return BOSS.get(id, "slimeGold")


## Окраска босса или null.
static func boss_tint(id: String) -> Variant:
	return BOSS_TINT.get(id, null)


static func weapon(id: String) -> String:
	return WEAPON.get(id, "forged")


static func colors(id: String) -> Array:
	return COLORS.get(id, COLORS["slimeCaves"])


static func coming_name(id: String) -> String:
	return L.t("dungeon.soon." + id)


static func coming_blurb(id: String) -> String:
	return L.t("dungeon.soon." + id + ".blurb")


# MARK: Этажи

static func is_boss_floor(floor_n: int) -> bool:
	return floor_n == 5 or floor_n == 10


static func waves(floor_n: int) -> int:
	return 2 if floor_n <= 3 else (3 if floor_n <= 7 else 4)


static func monsters_per_wave(floor_n: int) -> int:
	return mini(7, 3 + floor_n / 2)


static func monster_level(id: String, floor_n: int) -> int:
	return base_level(id) + int(round(float(floor_n - 1) * 1.5))


## Сколько особых свойств у обычного монстра на этаже.
static func traits(floor_n: int) -> int:
	var r := randf()
	if floor_n <= 3:
		return 1 if r < 0.15 else 0
	if floor_n <= 6:
		return 1 if r < 0.5 else 0
	return 2 if r < 0.3 else 1


static func boss_traits(floor_n: int) -> int:
	return 3 if floor_n >= 10 else 2


## Награда за этаж: монеты и эссенция. Первое прохождение - втрое больше и зелья.
static func coins(id: String, floor_n: int, first: bool) -> int:
	var base := float(60 + base_level(id) * 12) * (1.0 + float(floor_n) * 0.35) * (2.0 if is_boss_floor(floor_n) else 1.0)
	return int(base * (3.0 if first else 1.0))


static func essence(id: String, floor_n: int, first: bool) -> int:
	var tier := maxi(0, IDS.find(id))
	var base := 1 + tier + floor_n / 3 + (3 + tier if is_boss_floor(floor_n) else 0)
	return base * (3 if first else 1)


## Шанс, что босс отдаст оружие (на 10 этаже при первом прохождении - всегда).
static func weapon_chance(floor_n: int, first: bool) -> float:
	if floor_n == 10 and first:
		return 1.0
	if floor_n == 10:
		return 0.2
	return 0.15 if floor_n == 5 else 0.0


## Цена зелья (Potion.price).
static func potion_price(hero_level: int) -> int:
	return 40 + hero_level * 6
