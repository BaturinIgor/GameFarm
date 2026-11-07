class_name AlliancePet
## Хранитель альянса: общий зверь, которого кормит весь альянс (docs/supabase/alliance_pet.sql).
## Числа совпадают с сервером: стадии, угощения дня, порции. Продукты за порцию списывает игра.

## Виды Хранителя (выбирает глава, пока его не кормили).
const KINDS := ["phoenixChick", "pegasus", "moonUnicorn", "goldenGoose"]
## Опыт до стадий 2..10 (как _al_pet_stage).
const STAGES := [200, 700, 1600, 3000, 5000, 8000, 12500, 19000, 28000]
const MAX_STAGE := 10
## Порций в день на участника.
const PORTIONS := 10
## Угощения: простые, средние, редкие (как _al_pet_cravings), и сколько штук в порции на 1 уровне героя.
const EASY := ["wheat", "carrots", "egg", "milk"]
const MID := ["tomato", "potato", "strawberry", "wool"]
const RARE := ["corn", "cabbage", "honey", "eggplant"]
const BASE_AMOUNT := [10, 6, 4]
## Бонус всем участникам за каждую стадию после первой: к добыче и к опыту.
const STAGE_BONUS := 0.01


static func stage_of(xp: int) -> int:
	var s := 1
	for t in STAGES:
		if xp >= int(t):
			s += 1
	return s


## Опыт от начала до стадии (1 - 0).
static func xp_for(stage: int) -> int:
	return 0 if stage <= 1 else int(STAGES[mini(stage, MAX_STAGE) - 2])


static func cravings(day: int) -> Array:
	return [EASY[posmod(day, 4)], MID[posmod(day / 2, 4)], RARE[posmod(day / 3, 4)]]


## Продуктов в одной порции: растёт с уровнем героя, чтобы всем было ощутимо.
static func portion(slot: int, hero_level: int) -> int:
	return int(round(float(BASE_AMOUNT[clampi(slot, 0, 2)]) * (1.0 + float(maxi(1, hero_level) - 1) / 15.0)))


## Опыт Хранителю за порцию: простое 1, среднее 2, редкое 3.
static func xp_per_portion(slot: int) -> int:
	return clampi(slot, 0, 2) + 1


static func bonus(stage: int) -> float:
	return STAGE_BONUS * float(clampi(stage, 1, MAX_STAGE) - 1)


## Размер Хранителя на карточке по стадии.
static func size_for(stage: int) -> float:
	return 44.0 + 4.0 * float(clampi(stage, 1, MAX_STAGE))
