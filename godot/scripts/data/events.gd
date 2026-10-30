class_name Events
## Ивенты (порт Events.swift): каждую неделю новый праздник со своей картой, очками и пропуском наград.
## Проход ивента (EventRun) - словарь {event, index, start, end, key}, даты - unix-секунды.
## Награда пропуска - словарь {type, n}: coins, tickets, seeds, dish, cards, sparks, maps, decor, skin.

const IDS := ["harvestFest", "slimeNight", "winterTale", "beachParty"]

## Пиксельная иконка ивента.
const ICON := {"harvestFest": "pumpkin", "slimeNight": "slime", "winterTale": "chest_gold", "beachParty": "shell"}
## Особая точка добычи на карте ивента.
const NODE := {"harvestFest": "pumpkinPatch", "slimeNight": "slimeCrystal", "winterTale": "giftBox", "beachParty": "sandCastle"}
## Спрайт-превью особой точки.
const PREVIEW := {"harvestFest": "crop_pumpkin_3", "slimeNight": "crystal_slime", "winterTale": "gift_red", "beachParty": "sandcastle"}
## Семена и блюдо в наградах пропуска.
const CROP := {"harvestFest": "pumpkin", "slimeNight": "grapes", "winterTale": "cabbage", "beachParty": "strawberry"}
const DISH := {"harvestFest": "pumpkinSoup", "slimeNight": "popcorn", "winterTale": "stew", "beachParty": "juice"}
const DECOR := {"harvestFest": "jackLantern", "slimeNight": "slimeLamp", "winterTale": "snowman", "beachParty": "sandcastle"}
const SKIN := {"harvestFest": "autumn", "slimeNight": "slimeKing", "winterTale": "frost", "beachParty": "surfer"}
## Цвета баннера: верх и низ.
const COLORS := {
	"harvestFest": [Color("ffb04a"), Color("b8531a")],
	"slimeNight": [Color("8be36a"), Color("2e6b3a")],
	"winterTale": [Color("9fd8ff"), Color("3f72c8")],
	"beachParty": [Color("ffe08a"), Color("2fa8c8")],
}

## С какого уровня открыты ивенты.
const MIN_LEVEL := 5
const DURATION := 7 * 86400
## Отсчёт недель: понедельник, 26 октября 2026 (UTC).
const EPOCH := 1792972800


static func name_of(event: String) -> String:
	return L.t("event." + event)


static func blurb(event: String) -> String:
	return L.t("event." + event + ".blurb")


## Карта ивента (у каждого праздника своя локация с тем же id).
static func location(event: String) -> String:
	return event


## Какой ивент на этой карте ("" - не карта ивента).
static func event_of_location(location_id: String) -> String:
	return location_id if location_id in IDS else ""


static func decor_of(event: String) -> String:
	return str(DECOR.get(event, ""))


static func skin_of(event: String) -> String:
	return str(SKIN.get(event, ""))


# MARK: Расписание

static func run(index: int) -> Dictionary:
	var n := IDS.size()
	var event: String = IDS[((index % n) + n) % n]
	var start := float(EPOCH) + float(index) * DURATION
	return {"event": event, "index": index, "start": start, "end": start + DURATION, "key": "%s-%d" % [event, index]}


static func index_at(t: float) -> int:
	return floori((t - float(EPOCH)) / DURATION)


static func current() -> Dictionary:
	return run(index_at(Time.get_unix_time_from_system()))


## Ближайшие ивенты после текущего.
static func upcoming(count := 3) -> Array:
	var now := index_at(Time.get_unix_time_from_system())
	var out: Array = []
	for i in range(1, count + 1):
		out.append(run(now + i))
	return out


# MARK: Очки

## Очки за добычу на карте ивента: их дают только особые точки праздника.
static func points_for_node(type: String) -> int:
	return 1 if type in ["pumpkinPatch", "giftBox", "sandCastle", "slimeCrystal"] else 0


static func points_for_monster(kind: String) -> int:
	return 5 if kind == "slimeGold" else 2


## Очки за босса этапа.
const BOSS_POINTS := 15


# MARK: Этапы

## Сколько разных карт у ивента: этапы идут по кругу через все.
const VARIANTS := 5


## Какая карта на этапе. С каждой неделей порядок сдвигается.
static func variant(stage: int, run_index: int) -> int:
	return posmod((stage - 1) + run_index, VARIANTS)


## Цель этапа: столько очков нужно набрать на этой карте, чтобы открылся портал.
static func target(stage: int) -> int:
	return 30 + 6 * (stage - 1)


## Каждый пятый этап охраняет босс: без победы над ним портал не откроется.
static func is_boss_stage(stage: int) -> bool:
	return stage % 5 == 0


## Награда за этап: очки пропуска и монеты.
static func clear_points(stage: int) -> int:
	return 30 + 5 * stage + (40 if is_boss_stage(stage) else 0)


static func clear_coins(stage: int, level: int) -> int:
	return coins(60 + 15 * stage, level)


## Монстры становятся сильнее с каждым этапом.
static func monster_level(player_level: int, stage: int) -> int:
	return maxi(2, player_level / 2 + 1) + (stage - 1) * 2 / 3


static func monster_count(base: int, stage: int) -> int:
	return base + (stage - 1) / 3


## Сколько особых свойств у монстра на этапе.
static func traits(stage: int) -> int:
	var r := randf()
	if stage < 4:
		return 0
	if stage < 8:
		return 1 if r < 0.35 else 0
	if stage < 13:
		return 2 if r < 0.25 else 1
	return 2 if r < 0.5 else 1


static func boss_traits(stage: int) -> int:
	return mini(4, 1 + stage / 5)


## Босс этапа у каждого праздника.
static func boss(event: String) -> String:
	match event:
		"harvestFest": return "skelKnight"
		"slimeNight": return "slimeGold"
		"winterTale": return "slimeIce"
		_: return "orcWarrior"


## Монстры на картах ивентов: [[вид, сколько логов], ...].
static func monsters(event: String) -> Array:
	match event:
		"harvestFest": return [["slimeGreen", 3], ["skeleton", 2]]
		"slimeNight": return [["slimeGreen", 4], ["slimeBlue", 2], ["slimePurple", 2], ["slimeGold", 1]]
		"winterTale": return [["slimeIce", 4]]
		_: return [["slimeBlue", 3], ["slimeGold", 1]]


# MARK: Пропуск

const TIERS := 20
## После последней ступени каждые столько очков дают бонусный сундук.
const BONUS_EVERY := 300


## Сколько очков нужно на ступень (с единицы).
static func cost(tier_n: int) -> int:
	return 60 + 10 * tier_n


## Сколько всего очков нужно, чтобы открыть ступень.
static func threshold(tier_n: int) -> int:
	var sum := 0
	for t in range(1, tier_n + 1):
		sum += cost(t)
	return sum


static func total() -> int:
	return threshold(TIERS)


## Сколько ступеней открыто при таких очках.
static func tier(points: int) -> int:
	var t := 0
	while t < TIERS and points >= threshold(t + 1):
		t += 1
	return t


static func free_reward(tier_n: int) -> Dictionary:
	match tier_n:
		1: return {"type": "coins", "n": 200}
		2: return {"type": "seeds", "n": 4}
		3: return {"type": "cards", "n": 1}
		4: return {"type": "coins", "n": 350}
		5: return {"type": "tickets", "n": 1}
		6: return {"type": "dish", "n": 1}
		7: return {"type": "coins", "n": 500}
		8: return {"type": "cards", "n": 1}
		9: return {"type": "seeds", "n": 6}
		10: return {"type": "decor", "n": 1}
		11: return {"type": "coins", "n": 700}
		12: return {"type": "maps", "n": 1}
		13: return {"type": "tickets", "n": 1}
		14: return {"type": "cards", "n": 2}
		15: return {"type": "sparks", "n": 1}
		16: return {"type": "coins", "n": 1000}
		17: return {"type": "tickets", "n": 2}
		18: return {"type": "dish", "n": 2}
		19: return {"type": "cards", "n": 2}
		_: return {"type": "coins", "n": 2000}


static func vip_reward(tier_n: int) -> Dictionary:
	match tier_n:
		1: return {"type": "coins", "n": 500}
		2: return {"type": "tickets", "n": 1}
		3: return {"type": "cards", "n": 2}
		4: return {"type": "dish", "n": 2}
		5: return {"type": "sparks", "n": 1}
		6: return {"type": "coins", "n": 900}
		7: return {"type": "tickets", "n": 2}
		8: return {"type": "seeds", "n": 10}
		9: return {"type": "maps", "n": 1}
		10: return {"type": "sparks", "n": 2}
		11: return {"type": "coins", "n": 1500}
		12: return {"type": "dish", "n": 3}
		13: return {"type": "tickets", "n": 2}
		14: return {"type": "cards", "n": 3}
		15: return {"type": "sparks", "n": 2}
		16: return {"type": "coins", "n": 2500}
		17: return {"type": "tickets", "n": 3}
		18: return {"type": "maps", "n": 2}
		19: return {"type": "sparks", "n": 3}
		# Последняя платная ступень: образ и час бесконечной энергии
		_: return {"type": "skin", "n": 1, "energy": 60}


## Монеты в наградах растут с уровнем.
static func coins(base: int, level: int) -> int:
	return int(round(float(base) * (1.0 + float(level) * 0.12)))


## Бонусный сундук после всех ступеней.
static func bonus_coins(level: int) -> int:
	return coins(600, level)


# MARK: Усиления этапов

## После каждого этапа игрок выбирает одно из трёх. Действуют только на картах ивента
## и сбрасываются с новым ивентом.
const BOONS := ["points", "damage", "vitality", "swift", "harvest", "hunter", "regen", "lucky", "regrowth"]
const BOON_MAX_RANK := 3
const BOON_PER_RANK := {
	"points": 0.2, "damage": 0.15, "vitality": 0.15, "swift": 0.08, "harvest": 1.0, "hunter": 2.0,
	"regen": 0.01, "lucky": 0.06, "regrowth": 0.2,
}
const BOON_ICON := {
	"points": "star", "damage": "fist", "vitality": "heart", "swift": "boots", "harvest": "basket", "hunter": "sword",
	"regen": "heart_plus", "lucky": "clover", "regrowth": "sprout",
}


static func boon_name(boon: String) -> String:
	return L.t("boon." + boon)


static func boon_per_rank(boon: String) -> float:
	return float(BOON_PER_RANK.get(boon, 0.0))


static func boon_icon(boon: String) -> String:
	return str(BOON_ICON.get(boon, "star"))


## Описание с силой на этом ранге.
static func boon_text(boon: String, rank: int) -> String:
	var value := boon_per_rank(boon) * float(maxi(1, rank))
	if boon == "harvest" or boon == "hunter":
		return L.t("boon." + boon + ".text", [int(value)])
	return L.t("boon." + boon + ".text", [Fmt.pct(value)])
