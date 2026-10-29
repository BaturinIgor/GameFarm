class_name Weapons
## Особое оружие: падает с боссов подземелий, у каждого своё свойство (порт WeaponID из Gear.swift).

const IDS := ["forged", "slimeBlade", "boneSaber", "orcCleaver", "frostBrand", "flameSword", "royalSword"]

## Цвет иконки меча: кованый рисуется как обычный меч своей ступени.
const COLORS := {
	"forged": Color(1, 1, 1),
	"slimeBlade": Color(0.45, 0.95, 0.4),
	"boneSaber": Color(0.95, 0.92, 0.85),
	"orcCleaver": Color(0.6, 0.75, 0.3),
	"frostBrand": Color(0.55, 0.85, 1.0),
	"flameSword": Color(1.0, 0.5, 0.15),
	"royalSword": Color(1.0, 0.82, 0.2),
}

## С какой ступени оружие попадает в руки.
const START_TIER := {
	"forged": 1, "slimeBlade": 3, "boneSaber": 4, "orcCleaver": 5, "frostBrand": 6, "flameSword": 7, "royalSword": 4,
}

## Свойства оружия в бою (GameScene.strikeMonster и recalc):
## poison - шанс, урон в секунду от удара и время; slow - замедление и время; cleave - удар по соседям;
## lifesteal - вампиризм; crit и crit_mult - прибавка к шансу и силе крита (в recalc).
const EFFECTS := {
	"slimeBlade": {"poison_chance": 0.3, "poison_dps": 0.4, "poison_seconds": 3.0},
	"boneSaber": {"crit": 0.1, "crit_mult": 0.2},
	"orcCleaver": {"cleave": 0.6},
	"frostBrand": {"slow": 0.6, "slow_seconds": 2.0},
	"flameSword": {"poison_chance": 1.0, "poison_dps": 0.3, "poison_seconds": 2.0},
	"royalSword": {"lifesteal": 0.05},
}


static func is_valid(id: String) -> bool:
	return id in IDS


static func name_of(id: String) -> String:
	return L.t("weapon." + id)


static func effect_text(id: String) -> String:
	return L.t("weapon.%s.effect" % id)


static func source(id: String) -> String:
	return L.t("weapon.%s.source" % id)


static func color(id: String) -> Color:
	return COLORS.get(id, Color.WHITE)


## Во сколько раз сильнее кованого меча той же ступени.
static func mult(id: String) -> float:
	match id:
		"forged": return 1.0
		"royalSword": return 1.15
	return 1.1


static func start_tier(id: String) -> int:
	return int(START_TIER.get(id, 1))


## Свойство оружия по ключу из EFFECTS (0, если его нет).
static func effect(id: String, key: String) -> float:
	return float(EFFECTS.get(id, {}).get(key, 0.0))


## Цена улучшения особого оружия до ступени tier.
static func upgrade_cost(tier: int) -> Dictionary:
	var t := float(tier)
	var coins := int(300.0 * pow(t, 2.4))
	if tier >= 8:
		return {"coins": coins, "items": [["essence", int(8.0 * t)], ["stardust", tier - 6]]}
	if tier >= 5:
		return {"coins": coins, "items": [["essence", int(5.0 * t)], ["gold", 4 * tier]]}
	return {"coins": coins, "items": [["essence", 3 * tier], ["iron", 10 * tier]]}
