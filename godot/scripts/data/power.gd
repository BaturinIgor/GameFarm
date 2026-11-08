class_name Power
## Мощь игрока: одно число, по которому видно, насколько игрок сильный. Складывается из уровня,
## снаряжения, личных талантов, зверей (звёзды, пробуждение, редкий окрас, уровень) и построек усадьбы. Мощь идёт в рейтинг игроков,
## в силу альянса (сумма 30 самых сильных) и в урон по стражу альянса. Сервер (docs/supabase/power.sql)
## принимает мощь не больше MAX.

const PER_LEVEL := 10000
## Уровень даёт ещё LEVEL_SQ * уровень^2: к концу игры мощь растёт быстрее.
const LEVEL_SQ := 100
const PER_GEAR := 2500.0
const PER_TALENT_POINT := 4000
const PER_STAR := 3000
const PER_AWAKEN := 12000
const SHINY := 8000
const PER_ANIMAL_LEVEL := 1000
## Каждый уровень здания усадьбы; башня, стена и лагерь (защита и отряды) - втрое больше.
const PER_BUILDING_LEVEL := 800
const DEFENSE_MULT := 3
const DEFENSE := ["tower", "wall", "camp"]
## Редкие звери (за кристаллы, премиум и гибриды) сильнее в полтора раза.
const RARE_MULT := 1.5
const MAX := 100000000
## Сколько мощи дают +1 к урону по стражу альянса.
const DAMAGE_PER := 10000
## Сколько самых сильных участников дают силу альянса.
const ALLIANCE_TOP := 30
## Как часто отправлять мощь на сервер, если она выросла (секунды).
const SUBMIT_EVERY := 300.0


static func of_level(level: int) -> int:
	var l := maxi(1, level)
	return PER_LEVEL * l + LEVEL_SQ * l * l


static func of_building(id: String, level: int) -> int:
	return PER_BUILDING_LEVEL * maxi(0, level) * (DEFENSE_MULT if id in DEFENSE else 1)


static func of_gear(tier: int) -> int:
	return int(round(Tools.power(tier) * PER_GEAR))


static func of_animal(id: String, stars: int, awaken := 0, shiny := false, level := 1) -> int:
	if stars <= 0:
		return 0
	var base := PER_STAR * stars + PER_AWAKEN * awaken + (SHINY if shiny else 0) + PER_ANIMAL_LEVEL * maxi(0, level - 1)
	var rare := Animals.is_crystal(id) or Animals.is_hybrid(id) or Animals.is_premium(id)
	return int(round(float(base) * (RARE_MULT if rare else 1.0)))


## Мощь по частям: {level, gear, talents, animals, estate}.
static func breakdown() -> Dictionary:
	var gear := 0
	for tool in Tools.UPGRADABLE:
		gear += of_gear(Game.tier(tool))
	var animals := 0
	for id in Game.animals.owned():
		animals += animal(id)
	var estate := 0
	for id in Estate.IDS:
		estate += of_building(id, Game.estate.level(id))
	return {"level": of_level(Game.level), "gear": gear, "talents": PER_TALENT_POINT * Game.talents.points_spent(),
		"animals": animals, "estate": estate}


static func animal(id: String, extra_stars := 0) -> int:
	var a := Game.animals
	return of_animal(id, mini(Animals.MAX_STARS, a.stars(id) + extra_stars), a.awaken_level(id), a.is_shiny(id), a.level(id))


static func total() -> int:
	var sum := 0
	for v in breakdown().values():
		sum += int(v)
	return mini(MAX, sum)


## Какая мощь обычно у игрока уровня level (для «рекомендуемой мощи» подземелий): уровень, снаряжение
## и таланты по уровню, несколько зверей.
static func recommended(level: int) -> int:
	var l := maxi(1, level)
	return int(round((150.0 * float(l) + 2.0 * float(l * l)) / 50.0)) * 5000 + LEVEL_SQ * l * l
