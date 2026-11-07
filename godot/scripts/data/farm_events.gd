class_name FarmEvents
## Фарм-ивенты на основных локациях. Идут по 3 дня без перерыва, одновременно с праздником (Events).
## Три вида:
##   hunt   - на всех основных локациях появляются ивентовые монстры (особый цвет), очки за каждого;
##   gather - очки за каждую точку ресурса, добытую героем нужным инструментом;
##   task   - очки за дела по всей игре (ACTIONS: событие игры -> очки), например цеха усадьбы или клады.
## Награды - лестница из MILESTONES ступеней. Вся лестница рассчитана примерно на GOAL_HOURS часов
## игры за 3 дня (5-6 часов в день). Скорость набора очков (RATE) - оценка, её уточняют прогоны ботами.
## Проход фарм-ивента - словарь {event, index, start, end, key}, как у Events.run.
## Награда ступени - {type, n}: coins, planks, crystals, tickets, cards, sparks.

const IDS := ["slimeRush", "lumberjack", "workshopMarathon", "boneNight", "stoneFever", "treasureHunt",
	"bigCatch", "berryHarvest", "gardenFair"]
## До 1.1 по кругу шли только эти шесть. Старый порядок держим до NEW_FROM, чтобы ивент не сменился посреди прохода.
const OLD_IDS := ["slimeRush", "lumberjack", "boneNight", "stoneFever", "bigCatch", "berryHarvest"]
## Проход, с которого идёт новый круг (1 декабря 2026).
const NEW_FROM := 12
const DURATION := 3 * 86400

const KIND := {
	"slimeRush": "hunt", "boneNight": "hunt",
	"lumberjack": "gather", "stoneFever": "gather", "bigCatch": "gather", "berryHarvest": "gather",
	"workshopMarathon": "task", "treasureHunt": "task", "gardenFair": "task",
}
## Очки task-ивентов: событие игры -> очки. У produce и crop - за каждую штуку (amount), у остального - за раз.
const ACTIONS := {
	"workshopMarathon": {"produce": 1, "cook": 6, "order": 20},
	"treasureHunt": {"treasure": 25, "chest": 15, "guardian": 40, "mine": 4, "dungeon": 10},
	"gardenFair": {"plant": 1, "crop": 1, "trade": 10},
}
const PER_AMOUNT := ["produce", "crop"]
## Инструмент точек, которые дают очки в gather-ивентах.
const TOOL := {"lumberjack": "axe", "stoneFever": "pickaxe", "bigCatch": "rod", "berryHarvest": "hand"}
## Ивентовый монстр hunt-ивентов: вид, цвет (только у ивентовых), сколько логов на локации.
const MONSTER := {"slimeRush": "slimeGreen", "boneNight": "skeleton"}
const TINT := {"slimeRush": Color("ff7ad9"), "boneNight": Color("7fe0ff")}
const DENS := 4
const ICON := {"slimeRush": "slime", "boneNight": "skull", "lumberjack": "wood", "stoneFever": "stone",
	"bigCatch": "fish", "berryHarvest": "apples", "workshopMarathon": "hammer", "treasureHunt": "tmap",
	"gardenFair": "sprout"}
const COLORS := {
	"slimeRush": [Color("ff9ae3"), Color("a8327f")],
	"boneNight": [Color("9fe8ff"), Color("2f4f86")],
	"lumberjack": [Color("c9e07a"), Color("4f7a2a")],
	"stoneFever": [Color("d6d0c4"), Color("5f5a52")],
	"bigCatch": [Color("8fe0ff"), Color("1f6fa0")],
	"berryHarvest": [Color("ffb0a0"), Color("b0404a")],
	"workshopMarathon": [Color("ffd08a"), Color("8a4a1f")],
	"treasureHunt": [Color("ffe27a"), Color("6a4a9a")],
	"gardenFair": [Color("b8f08a"), Color("2f7a4a")],
}

## Очки: за ивентового монстра и за точку ресурса.
const KILL_POINTS := 3
const SPOT_POINTS := 1
## Оценка скорости: очков в час активной игры (hunt - около 90 монстров, gather - около 500 точек).
## task - оценка по обычной игре: дела идут между делом, лестница короче.
const RATE := {"hunt": 270, "gather": 500, "task": 120}
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


## Сколько очков даёт событие игры в task-ивенте (0 - не считается).
static func action_points(event: String, action: String, data: Dictionary) -> int:
	var per := int(ACTIONS.get(event, {}).get(action, 0))
	if per <= 0:
		return 0
	if action == "raid" and not bool(data.get("win", false)):
		return 0
	return per * maxi(1, int(data.get("amount", 1))) if action in PER_AMOUNT else per


static func icon(event: String) -> String:
	return str(ICON.get(event, "star"))


# MARK: Расписание

static func run(index: int) -> Dictionary:
	var event: String = OLD_IDS[posmod(index, OLD_IDS.size())] if index < NEW_FROM else IDS[posmod(index - NEW_FROM, IDS.size())]
	var start := float(Events.EPOCH) + float(index) * DURATION
	return {"event": event, "index": index, "start": start, "end": start + DURATION, "key": "farm-%s-%d" % [event, index]}


static func index_at(t: float) -> int:
	return floori((t - float(Events.EPOCH)) / DURATION)


static func current() -> Dictionary:
	return run(index_at(Clock.now()))


static func upcoming(count := 2) -> Array:
	var now := index_at(Clock.now())
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
