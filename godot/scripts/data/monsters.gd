class_name Monsters
## Монстры: слаймы, скелеты и орки (порт MonsterKind, MonsterSheet, MonsterTrait, Bestiary, MonsterStats).
## Живут в дальних частях локаций и в подземельях. Виды и свойства - строки rawValue, как в iOS.

const KINDS := [
	"slimeGreen", "slimeBlue", "slimePurple", "slimeRed", "slimeIce", "slimeGold", "skeleton", "skeletonDark",
	"orc", "orcRogue", "orcShaman", "orcWarrior", "skelSoldier", "skelMage", "skelRogue", "skelKnight",
]

const SPRITES := {
	"slimeGreen": "mo_slime_green", "slimeBlue": "mo_slime_blue", "slimePurple": "mo_slime_purple",
	"slimeRed": "mo_slime_red", "slimeIce": "mo_slime_ice", "slimeGold": "mo_slime_gold",
	"skeleton": "mo_skeleton", "skeletonDark": "mo_skeleton_dark",
	"orc": "mo_orc", "orcRogue": "mo_orc_rogue", "orcShaman": "mo_orc_shaman", "orcWarrior": "mo_orc_warrior",
	"skelSoldier": "mo_skel_soldier", "skelMage": "mo_skel_mage", "skelRogue": "mo_skel_rogue", "skelKnight": "mo_skel_knight",
}

const SLIMES := ["slimeGreen", "slimeBlue", "slimePurple", "slimeRed", "slimeIce", "slimeGold"]
const ORCS := ["orc", "orcRogue", "orcShaman", "orcWarrior"]

## Кадров смерти у орков и новых скелетов.
const DEATH_FRAMES := {"orc": 6, "orcRogue": 6, "orcShaman": 7, "orcWarrior": 9,
	"skelSoldier": 12, "skelMage": 6, "skelRogue": 6, "skelKnight": 8}

const TOUGHNESS := {"skeleton": 1.35, "skeletonDark": 1.35, "orc": 1.5, "orcRogue": 1.1, "orcShaman": 1.0,
	"orcWarrior": 2.0, "skelSoldier": 1.3, "skelMage": 0.9, "skelRogue": 1.0, "skelKnight": 1.9, "slimeGold": 1.6}
const STRENGTH := {"skeleton": 1.3, "skeletonDark": 1.3, "orc": 1.25, "orcRogue": 1.5, "orcShaman": 1.1,
	"orcWarrior": 1.4, "skelSoldier": 1.2, "skelMage": 1.6, "skelRogue": 1.4, "skelKnight": 1.35}
const SPEED := {"skeleton": 78.0, "skeletonDark": 78.0, "orc": 72.0, "orcRogue": 95.0, "skelRogue": 95.0,
	"orcShaman": 60.0, "orcWarrior": 62.0, "skelKnight": 62.0, "skelSoldier": 76.0, "skelMage": 66.0}

## Особые свойства: делают бой разнообразнее, видны значками над монстром.
const TRAITS := ["crit", "dodge", "regen", "slow", "poison", "shield", "enrage", "vampire", "thorns", "swift"]
const TRAIT_ICONS := {"crit": "bolt", "dodge": "eye", "regen": "heart_plus", "slow": "hourglass", "poison": "slime",
	"shield": "shield", "enrage": "skull", "vampire": "heart", "thorns": "sword", "swift": "boots"}

## Монстры каждой локации: вид и сколько логов.
const BESTIARY := {
	"meadow": [["slimeGreen", 3]],
	"hills": [["slimeGreen", 3], ["orc", 1]],
	"lake": [["slimeBlue", 4]],
	"swamp": [["slimePurple", 3], ["skeleton", 2]],
	"desert": [["skeleton", 3], ["skelRogue", 2]],
	"snow": [["slimeIce", 4], ["orcWarrior", 1]],
	"caves": [["skeletonDark", 3], ["slimePurple", 2], ["skelMage", 1]],
	"island": [["slimeBlue", 3], ["slimeGold", 1], ["orcRogue", 1]],
	"volcano": [["slimeRed", 4], ["skeletonDark", 2], ["orcShaman", 1]],
	"sky": [["slimePurple", 3], ["slimeGold", 2], ["skelKnight", 1]],
	"ashPlains": [["slimeRed", 4], ["orcShaman", 2], ["skeletonDark", 2]],
	"amberWoods": [["orc", 3], ["orcRogue", 2], ["orcWarrior", 1]],
	"fireCanyon": [["skelKnight", 2], ["slimeRed", 3], ["orcWarrior", 2]],
	"starMeadows": [["slimePurple", 3], ["slimeGold", 2], ["skelMage", 2]],
	"frostSpires": [["slimeIce", 4], ["skelKnight", 2], ["orcWarrior", 1]],
	"crystalReef": [["slimeBlue", 4], ["orcShaman", 2], ["slimeGold", 1]],
}

static var _icons: Dictionary = {}


static func name_of(kind: String) -> String:
	return L.t("monster." + kind)


static func sprite(kind: String) -> String:
	return SPRITES.get(kind, "mo_slime_green")


static func is_slime(kind: String) -> bool:
	return kind in SLIMES


static func is_orc(kind: String) -> bool:
	return kind in ORCS


static func emoji(kind: String) -> String:
	return "🟢" if is_slime(kind) else ("👹" if is_orc(kind) else "💀")


## Трофей, который с него падает.
static func loot(kind: String) -> String:
	return "slime" if is_slime(kind) else ("tusk" if is_orc(kind) else "bone")


## Как нарезан лист: клетка, колонки и ряды анимаций.
## idle, move, hurt, death - {"row", "frames": [от, до)}; hurt может быть null. bar - высота полоски здоровья.
static func sheet(kind: String) -> Dictionary:
	if is_slime(kind):
		return {"cell": 64.0, "cols": 8, "idle": _anim(0, 0, 4), "move": _anim(1, 0, 8), "hurt": _anim(2, 1, 4),
			"death": _anim(2, 4, 8), "bar": 40.0}
	if kind == "skeleton" or kind == "skeletonDark":
		return {"cell": 32.0, "cols": 6, "idle": _anim(1, 0, 6), "move": _anim(4, 0, 6), "hurt": _anim(8, 0, 4),
			"death": _anim(6, 0, 4), "bar": 56.0}
	return {"cell": 64.0, "cols": 12, "idle": _anim(0, 0, 4), "move": _anim(1, 0, 6), "hurt": null,
		"death": _anim(2, 0, int(DEATH_FRAMES.get(kind, 6))), "bar": 50.0}


static func _anim(row: int, from: int, to: int) -> Dictionary:
	return {"row": row, "frames": [from, to]}


## Насколько крепкий, сильный и быстрый.
static func toughness(kind: String) -> float:
	return float(TOUGHNESS.get(kind, 1.0))


static func strength(kind: String) -> float:
	return float(STRENGTH.get(kind, 1.0))


static func speed(kind: String) -> float:
	return float(SPEED.get(kind, 60.0))


## Портрет для окон (MonsterIcon): первый кадр стойки без прозрачных краёв.
static func icon(kind: String) -> Texture2D:
	if _icons.has(kind):
		return _icons[kind]
	var out: Texture2D = null
	var tex := Sprites.texture(sprite(kind))
	if tex != null:
		var sh := sheet(kind)
		var cell := int(sh["cell"])
		var img := tex.get_image()
		if img != null:
			if img.is_compressed():
				img.decompress()
			var part := img.get_region(Rect2i(0, int(sh["idle"]["row"]) * cell, cell, cell))
			var used := part.get_used_rect()
			if used.size.x > 0 and used.size.y > 0:
				part = part.get_region(used)
			out = ImageTexture.create_from_image(part)
	if out == null:
		out = Sprites.icon("slime" if is_slime(kind) else "skull")
	_icons[kind] = out
	return out


# MARK: Особые свойства

static func trait_name(t: String) -> String:
	return L.t("trait." + t)


static func trait_info(t: String) -> String:
	return L.t("trait." + t + ".info")


## Иконка ic_<имя>.
static func trait_icon(t: String) -> String:
	return TRAIT_ICONS.get(t, "skull")


## Сколько свойств у монстра такого уровня (обычные монстры в мире).
static func roll_traits(level: int) -> Array:
	var chance := 0.45 if level >= 30 else (0.3 if level >= 18 else (0.15 if level >= 10 else 0.0))
	if randf() >= chance:
		return []
	return [TRAITS.pick_random()]


static func pick_traits(n: int) -> Array:
	var all := TRAITS.duplicate()
	all.shuffle()
	return all.slice(0, clampi(n, 0, all.size()))


# MARK: Бестиарий

## Монстры локации: [[вид, сколько логов], ...].
static func in_location(id: String) -> Array:
	return BESTIARY.get(id, [])


## Уровень монстров локации.
static func level_in(id: String) -> int:
	return maxi(2, int(Locations.spec(id)["level"]) + 2)


## Где водится монстр.
static func home_of(kind: String) -> Array:
	return Locations.world().filter(func(id: String) -> bool:
		return in_location(id).any(func(e: Array) -> bool: return e[0] == kind))


## Характеристики монстра на уровне (MonsterStats): hp, damage, speed, xp, coins.
## Особые свойства на числа не влияют, их учитывает MonsterNode.
static func stats(kind: String, level: int, boss := false, _traits: Array = []) -> Dictionary:
	var l := float(level)
	return {
		"hp": 26.0 * pow(1.12, l) * toughness(kind) * (10.0 if boss else 1.0),
		"damage": 4.0 * pow(1.09, l) * strength(kind) * (1.6 if boss else 1.0),
		"speed": speed(kind) * (0.9 if boss else 1.0),
		"xp": int((8.0 + l * 2.5 * toughness(kind)) * (10.0 if boss else 1.0)),
		# x2.5 в новой экономике: бой должен окупаться
		"coins": int((4.0 + l * 1.5) * 2.5 * (6.0 if kind == "slimeGold" else 1.0) * (15.0 if boss else 1.0)),
	}
