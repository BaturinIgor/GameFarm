class_name FarmEvents
## Фарм-ивенты на основных локациях. Идут по 3 дня без перерыва, одновременно с праздником (Events).
## Два вида:
##   hunt   - на всех основных локациях появляются ивентовые монстры (особый цвет), очки за каждого;
##   gather - очки за каждую точку ресурса, добытую героем нужным инструментом.
## Награды - лестница из MILESTONES ступеней. Вся лестница рассчитана примерно на GOAL_HOURS часов
## игры за 3 дня (5-6 часов в день). Скорость набора очков (RATE) - оценка, её уточняют прогоны ботами.
## Проход фарм-ивента - словарь {event, index, start, end, key}, как у Events.run.
## Награда ступени - {type, n}: coins, planks, crystals, tickets, cards, sparks.

const IDS := ["slimeRush", "lumberjack", "boneNight", "stoneFever", "bigCatch", "berryHarvest"]
const DURATION := 3 * 86400

const KIND := {
	"slimeRush": "hunt", "boneNight": "hunt",
	"lumberjack": "gather", "stoneFever": "gather", "bigCatch": "gather", "berryHarvest": "gather",
}
## Инструмент точек, которые дают очки в gather-ивентах.
const TOOL := {"lumberjack": "axe", "stoneFever": "pickaxe", "bigCatch": "rod", "berryHarvest": "hand"}
## Ивентовый монстр hunt-ивентов: вид, цвет (только у ивентовых), сколько логов на локации.
const MONSTER := {"slimeRush": "slimeGreen", "boneNight": "skeleton"}
const TINT := {"slimeRush": Color("ff7ad9"), "boneNight": Color("7fe0ff")}
const DENS := 4
const ICON := {"slimeRush": "slime", "boneNight": "skull", "lumberjack": "wood", "stoneFever": "stone",
	"bigCatch": "fish", "berryHarvest": "apples"}
const COLORS := {
	"slimeRush": [Color("ff9ae3"), Color("a8327f")],
	"boneNight": [Color("9fe8ff"), Color("2f4f86")],
	"lumberjack": [Color("c9e07a"), Color("4f7a2a")],
	"stoneFever": [Color("d6d0c4"), Color("5f5a52")],
	"bigCatch": [Color("8fe0ff"), Color("1f6fa0")],
	"berryHarvest": [Color("ffb0a0"), Color("b0404a")],
}

## Очки: за ивентового монстра и за точку ресурса.
const KILL_POINTS := 3
const SPOT_POINTS := 1
## Оценка скорости: очков в час активной игры (hunt - около 90 монстров, gather - около 500 точек).
const RATE := {"hunt": 270, "gather": 500}
## Рыбалка медленнее: точек меньше, клёв дольше.
const RATE_OF := {"bigCatch": 300}
const GOAL_HOURS := 15
const MILESTONES := 15
## Ивентовые монстры на уровень сильнее обычных на локации.
const LEVEL_BONUS := 1


static func name_of(event: String) -> String:
	return L.t("farm." + event)


static func blurb(event: String) -> String:
	return L.t("farm." + event + ".blurb")


static func kind(event: String) -> String:
	return str(KIND.get(event, "gather"))


static func icon(event: String) -> String:
	return str(ICON.get(event, "star"))


# MARK: Расписание

static func run(index: int) -> Dictionary:
	var n := IDS.size()
	var event: String = IDS[posmod(index, n)]
	var start := float(Events.EPOCH) + float(index) * DURATION
	return {"event": event, "index": index, "start": start, "end": start + DURATION, "key": "farm-%s-%d" % [event, index]}


static func index_at(t: float) -> int:
	return floori((t - float(Events.EPOCH)) / DURATION)


static func current() -> Dictionary:
	return run(index_at(Time.get_unix_time_from_system()))


static func upcoming(count := 2) -> Array:
	var now := index_at(Time.get_unix_time_from_system())
	var out: Array = []
	for i in range(1, count + 1):
		out.append(run(now + i))
	return out


# MARK: Лестница наград

## Сколько очков на всю лестницу.
static func total(event: String) -> int:
	return int(RATE_OF.get(event, RATE[kind(event)])) * GOAL_HOURS


## Сколько очков нужно, чтобы открыть ступень (с единицы). Первые ступени быстрые, последние долгие.
static func threshold(event: String, step: int) -> int:
	if step <= 0:
		return 0
	var f := pow(float(mini(step, MILESTONES)) / float(MILESTONES), 1.4)
	return int(round(float(total(event)) * f / 10.0)) * 10


static func step_of(event: String, points: int) -> int:
	var s := 0
	while s < MILESTONES and points >= threshold(event, s + 1):
		s += 1
	return s


## Награда ступени. Доски - главная награда: их долго делать, а нужны они на все улучшения.
static func reward(step: int) -> Dictionary:
	match step:
		1: return {"type": "coins", "n": 300}
		2: return {"type": "planks", "n": 10}
		3: return {"type": "cards", "n": 1}
		4: return {"type": "planks", "n": 15}
		5: return {"type": "crystals", "n": 10}
		6: return {"type": "coins", "n": 800}
		7: return {"type": "planks", "n": 25}
		8: return {"type": "tickets", "n": 2}
		9: return {"type": "planks", "n": 35}
		10: return {"type": "crystals", "n": 20}
		11: return {"type": "cards", "n": 3}
		12: return {"type": "planks", "n": 50}
		13: return {"type": "sparks", "n": 2}
		14: return {"type": "planks", "n": 70}
		_: return {"type": "crystals", "n": 50}


## Количество досок и монет растёт с уровнем героя.
static func scaled(reward: Dictionary, level: int) -> int:
	var n := int(reward.get("n", 0))
	match str(reward["type"]):
		"coins":
			return Events.coins(n, level)
		"planks":
			return int(round(float(n) * (1.0 + float(level) * 0.05)))
	return n
