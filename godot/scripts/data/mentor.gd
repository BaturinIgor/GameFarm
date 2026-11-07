class_name Mentor
## Наставник (docs/supabase/alliance_mentor.sql): ученик до 15 уровня выбирает наставника от 25 уровня в альянсе.
## Ступени ученика дают награду обоим, наставник может дарить подарки за кристаллы. Числа как на сервере.

const MENTOR_LEVEL := 25
const APPRENTICE_MAX := 15
const MAX_APPRENTICES := 3
const STEPS := [10, 15, 20, 25, 30]
## Подарок ученику (раз в день): цена в кристаллах и что внутри.
const GIFT_CRYSTALS := 100
const GIFT := {"silver": 1, "copper": 2}


## Награда за ступень: ученику и наставнику.
static func reward(step: int, as_mentor: bool) -> Dictionary:
	return {"coins": (200 if as_mentor else 150) * step, "crystals": 15 if as_mentor else 10}


## Ступени, которые ученик уже прошёл (выше начального уровня) и которые ещё не забраны.
static func ready_steps(start: int, level: int, claimed: Array) -> Array:
	return STEPS.filter(func(s: int) -> bool: return s > start and level >= s and not float(s) in claimed.map(func(c: Variant) -> float: return float(c)))


## Следующая ступень после уровня (0 - все пройдены).
static func next_step(start: int, level: int) -> int:
	for s in STEPS:
		if s > start and s > level:
			return s
	return 0
