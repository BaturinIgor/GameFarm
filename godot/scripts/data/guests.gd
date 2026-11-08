class_name Guests
## Звери в гости (docs/supabase/alliance_guests.sql): свой зверь гостит сутки у друга из альянса.
## Пока гостит - хозяину дома бонус к добыче, когда вернётся - хозяину зверя подарок. Числа как на сервере.

const DURATION := 86400
const BASE_SLOTS := 1
const MAX_SLOTS := 2
## Второе место для отправки - за кристаллы, навсегда.
const SLOT_CRYSTALS := 250
## Сколько гостей один дом принимает сразу.
const MAX_HOSTED := 3
## Бонус к добыче хозяину дома: за каждую звезду гостя.
const BONUS_PER_STAR := 0.01


## Подарок за вернувшегося зверя: монеты по звёздам и медный ключ.
static func reward(stars: int, level: int) -> Dictionary:
	return {"coins": (100 + 20 * level) * clampi(stars, 1, Animals.MAX_STARS), "copper": 1}


## Бонус к добыче от гостей, которые сейчас у меня: [{stars, returns}].
static func bonus(hosted: Array, t: float) -> float:
	var sum := 0.0
	for x in hosted.slice(0, MAX_HOSTED):
		if x is Dictionary and float(x.get("returns", 0)) > t:
			sum += BONUS_PER_STAR * clampi(int(x.get("stars", 1)), 1, Animals.MAX_STARS)
	return sum


static func active_count(hosted: Array, t: float) -> int:
	return hosted.filter(func(x: Variant) -> bool: return x is Dictionary and float(x.get("returns", 0)) > t).size()
