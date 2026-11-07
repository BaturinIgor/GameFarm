class_name Power
## Мощь игрока: одно число, по которому видно, насколько игрок сильный. Складывается из уровня,
## снаряжения, личных талантов и зверей (звёзды, пробуждение, редкий окрас). Мощь идёт в рейтинг игроков,
## в силу альянса (сумма 30 самых сильных) и в урон по стражу альянса. Сервер (docs/supabase/power.sql)
## принимает мощь не больше MAX.

const PER_LEVEL := 100
const PER_GEAR := 25.0
const PER_TALENT_POINT := 40
const PER_STAR := 30
const PER_AWAKEN := 120
const SHINY := 80
## Редкие звери (за кристаллы, премиум и гибриды) сильнее в полтора раза.
const RARE_MULT := 1.5
const MAX := 200000
## Сколько самых сильных участников дают силу альянса.
const ALLIANCE_TOP := 30
## Как часто отправлять мощь на сервер, если она выросла (секунды).
const SUBMIT_EVERY := 300.0


static func of_level(level: int) -> int:
	return PER_LEVEL * maxi(1, level)


static func of_gear(tier: int) -> int:
	return int(round(Tools.power(tier) * PER_GEAR))


static func of_animal(id: String, stars: int, awaken := 0, shiny := false) -> int:
	if stars <= 0:
		return 0
	var base := PER_STAR * stars + PER_AWAKEN * awaken + (SHINY if shiny else 0)
	var rare := Animals.is_crystal(id) or Animals.is_hybrid(id) or Animals.is_premium(id)
	return int(round(float(base) * (RARE_MULT if rare else 1.0)))


## Мощь по частям: {level, gear, talents, animals}.
static func breakdown() -> Dictionary:
	var gear := 0
	for tool in Tools.UPGRADABLE:
		gear += of_gear(Game.tier(tool))
	var animals := 0
	for id in Game.animals.owned():
		animals += animal(id)
	return {"level": of_level(Game.level), "gear": gear, "talents": PER_TALENT_POINT * Game.talents.points_spent(),
		"animals": animals}


static func animal(id: String, extra_stars := 0) -> int:
	var a := Game.animals
	return of_animal(id, mini(Animals.MAX_STARS, a.stars(id) + extra_stars), a.awaken_level(id), a.is_shiny(id))


static func total() -> int:
	var sum := 0
	for v in breakdown().values():
		sum += int(v)
	return mini(MAX, sum)
