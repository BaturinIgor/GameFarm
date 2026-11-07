class_name Village
## Деревня альянса (docs/supabase/alliance_village.sql): домики участников с украшениями, визиты к друзьям
## (полить грядки, оставить подарок) и общие постройки, которые растут от монет участников. Числа как на сервере.

const BUILDINGS := ["mill", "tower", "well"]
const ICONS := {"mill": "basket", "tower": "sword", "well": "watering_can"}
const MAX_LEVEL := 10
## Бонус постройки за уровень: мельница - к добыче, башня - к опыту, колодец - к скорости роста грядок.
const BONUS_PER_LEVEL := 0.01
const DONATES_PER_DAY := 5
const WATERS_PER_DAY := 5
## Полив друга: хозяину столько секунд роста всех грядок, гостю монеты.
const WATER_GROW := 600.0
const GIFT_CRYSTALS := 30
## Украшения домика: за кристаллы или из набора «Праздник в деревне» (за деньги). Показывается до 3.
const SHOWN := 3
const DECOS := {
	"flowers": {"icon": "sprout", "crystals": 60},
	"fence": {"icon": "wood", "crystals": 80},
	"lantern": {"icon": "flame", "crystals": 120},
	"bench": {"icon": "planks", "crystals": 150},
	"fountain": {"icon": "watering_can", "crystals": 250},
	"windmill": {"icon": "clover", "crystals": 300},
	# Набор за деньги
	"goldStatue": {"icon": "crown", "pack": true},
	"rainbowArch": {"icon": "rainbow", "pack": true},
	"starLantern": {"icon": "spark", "pack": true},
}
const DECO_ORDER := ["flowers", "fence", "lantern", "bench", "fountain", "windmill", "goldStatue", "rainbowArch", "starLantern"]
## Набор «Праздник в деревне»: три украшения, королевская рамка статуи и кристаллы.
const PACK_CRYSTALS := 300
const PACK_FRAME := "royal"


## Сколько монет нужно на уровень level постройки.
static func need(level: int) -> int:
	return int(round(200000.0 * pow(float(maxi(1, level)), 1.5)))


## Вклад в постройку за раз: растёт с уровнем героя.
static func donate_coins(hero_level: int) -> int:
	return mini(100000, 500 * maxi(1, hero_level))


static func water_coins(hero_level: int) -> int:
	return 50 + 10 * maxi(1, hero_level)


static func bonus(level: int) -> float:
	return BONUS_PER_LEVEL * clampi(level, 0, MAX_LEVEL)


static func valid_deco(id: String) -> bool:
	return DECOS.has(id)


static func deco_price(id: String) -> int:
	return int(DECOS.get(id, {}).get("crystals", 0))


static func in_pack(id: String) -> bool:
	return bool(DECOS.get(id, {}).get("pack", false))
