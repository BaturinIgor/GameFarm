class_name Alliances
## Альянсы (шаг 1 из 3: альянс, таланты, чат). Правила считает сервер (docs/supabase/alliances.sql),
## числа здесь должны совпадать с ним: игра по ним рисует окно и прикладывает бонусы талантов.
## Шаг 2 - события альянса, шаг 3 - карта битвы альянсов.

## С какого уровня можно вступить и создать свой.
const JOIN_LEVEL := 10
const CREATE_LEVEL := 15
## Цена создания: кристаллы или монеты.
const CREATE_CRYSTALS := 500
const CREATE_COINS := 100000
## Вклады в день: бесплатные и за монеты; за кристаллы - без лимита, цена растёт каждые GEM_STEP.
const FREE_PER_DAY := 20
const COINS_PER_DAY := 20
const GEM_BASE := 5
const GEM_STEP := 5
## Уровни альянса и места.
const MAX_LEVEL := 20
const BASE_CAP := 25
const CAP_PER_LEVEL := 5
const MAX_CAP := 100
## Чат: длина сообщения и как часто обновлять открытый чат (секунды).
const MSG_LEN := 200
const CHAT_POLL := 6.0
const EMBLEMS := ["star", "crown", "sword", "clover", "flame", "moon", "sprout", "gem", "skull", "compass", "key", "trophy",
	"honey", "map", "fist", "heart_plus"]
const EMBLEM_COLORS := [Color("e8b04a"), Color("6fc06a"), Color("5aa8e0"), Color("c27ae0"), Color("e06a5a"), Color("e0d25a"),
	Color("5ad2c8"), Color("e0905a"), Color("9aa0aa"), Color("f07ab0"), Color("8a6ae0"), Color("6a9a4a"), Color("d0a070"),
	Color("4a7ab0"), Color("b04a4a"), Color("70c0f0")]

## Таланты альянса: с какого уровня открыт, иконка, сила за ранг (доля) и множитель цены ранга.
## Каждый вклад - одно очко в выбранный талант и одно очко опыта альянсу.
const TALENTS := {
	"harvest": {"level": 1, "icon": "basket", "per_rank": 0.01, "tier": 1.0},
	"strength": {"level": 1, "icon": "fist", "per_rank": 0.02, "tier": 1.0},
	"garden": {"level": 3, "icon": "sprout", "per_rank": 0.02, "tier": 1.5},
	"beasts": {"level": 3, "icon": "paw", "per_rank": 0.02, "tier": 1.5},
	"workshop": {"level": 6, "icon": "hammer", "per_rank": 0.02, "tier": 2.0},
	"vitality": {"level": 6, "icon": "heart_plus", "per_rank": 0.02, "tier": 2.0},
	"fortune": {"level": 10, "icon": "clover", "per_rank": 0.005, "tier": 3.0},
	"thrift": {"level": 10, "icon": "coin", "per_rank": 0.01, "tier": 3.0},
}
const MAX_RANK := 10
## Очков на ранг r: RANK_BASE * r * tier (сумма до 10 ранга - RANK_BASE * 55 * tier).
const RANK_BASE := 60


# MARK: Уровень

## Опыт до уровня lvl (на 2 уровень - 400).
static func xp_for(lvl: int) -> int:
	return 0 if lvl <= 1 else int(ceil(400.0 * pow(float(lvl - 1), 1.7)))


static func level_of(xp: int) -> int:
	var l := 1
	while l < MAX_LEVEL and xp >= xp_for(l + 1):
		l += 1
	return l


static func cap_of(xp: int) -> int:
	return mini(MAX_CAP, BASE_CAP + CAP_PER_LEVEL * (level_of(xp) - 1))


# MARK: Таланты

static func talent_level(id: String) -> int:
	return int(TALENTS.get(id, {}).get("level", 99))


## Очков от начала до ранга r (как _al_talent_max в SQL для r = 10).
static func points_for(id: String, r: int) -> int:
	var tier := float(TALENTS.get(id, {}).get("tier", 1.0))
	return int(float(RANK_BASE * r * (r + 1) / 2) * tier)


static func talent_max(id: String) -> int:
	return points_for(id, MAX_RANK)


static func rank_of(id: String, points: int) -> int:
	var r := 0
	while r < MAX_RANK and points >= points_for(id, r + 1):
		r += 1
	return r


## Сила таланта на ранге (доля: 0.05 = +5%).
static func value(id: String, rank: int) -> float:
	return float(TALENTS.get(id, {}).get("per_rank", 0.0)) * float(rank)


static func talent_name(id: String) -> String:
	return L.t("alliance.talent." + id)


static func talent_text(id: String, rank: int) -> String:
	return L.t("alliance.talent." + id + ".text", [Fmt.pct(value(id, maxi(1, rank)))])


# MARK: Цены вкладов

## Вклад за монеты дороже с уровнем героя (как монетные награды ивентов).
static func coin_cost(hero_level: int) -> int:
	return Events.coins(150, hero_level)


## Вклад за кристаллы: 5, и каждые 5 вкладов за день цена растёт на 5.
static func gem_cost(done_today: int) -> int:
	return GEM_BASE * (1 + done_today / GEM_STEP)


static func emblem_icon(i: int) -> String:
	return str(EMBLEMS[posmod(i, EMBLEMS.size())])


static func emblem_color(i: int) -> Color:
	return EMBLEM_COLORS[posmod(i, EMBLEM_COLORS.size())]
