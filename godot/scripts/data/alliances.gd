class_name Alliances
## Альянсы (шаг 1 из 3: альянс, таланты, чат). Правила считает сервер (docs/supabase/alliances.sql),
## числа здесь должны совпадать с ним: игра по ним рисует окно и прикладывает бонусы талантов.
## Шаг 2 - события альянса, шаг 3 - карта битвы альянсов.

## С какого уровня можно вступить и создать свой.
const JOIN_LEVEL := 5
const CREATE_LEVEL := 15
## Цена создания: кристаллы или монеты.
const CREATE_CRYSTALS := 500
const CREATE_COINS := 100000
## Вклады в день: бесплатные и за монеты; за кристаллы - без лимита, цена растёт каждые GEM_STEP.
const FREE_PER_DAY := 20
const COINS_PER_DAY := 20
const GEM_BASE := 5
const GEM_STEP := 5
## Уровни альянса и места: альянс начинает с 25 мест, талант «Места» даёт +5 за ранг, до 100.
const MAX_LEVEL := 30
const BASE_CAP := 25
const MAX_CAP := 100
## Чат: длина сообщения и как часто обновлять открытый чат (секунды).
const MSG_LEN := 200
const CHAT_POLL := 6.0
const EMBLEMS := ["star", "crown", "sword", "clover", "flame", "moon", "sprout", "gem", "skull", "compass", "key", "trophy",
	"honey", "map", "fist", "heart_plus"]
const EMBLEM_COLORS := [Color("e8b04a"), Color("6fc06a"), Color("5aa8e0"), Color("c27ae0"), Color("e06a5a"), Color("e0d25a"),
	Color("5ad2c8"), Color("e0905a"), Color("9aa0aa"), Color("f07ab0"), Color("8a6ae0"), Color("6a9a4a"), Color("d0a070"),
	Color("4a7ab0"), Color("b04a4a"), Color("70c0f0")]

## Таланты альянса: 4 ряда по 6, ряд открывается на уровне альянса 1, 5, 12, 20 и дороже в 1, 1.5, 2, 3 раза.
## level - с какого уровня открыт, per_rank - сила за ранг, tier - множитель цены, unit - как писать силу
## (pct - проценты, flat - число, hours - часы, hit - удары). Каждый вклад - очко в талант и очко опыта альянсу.
const TALENTS := {
	"harvest": {"level": 1, "icon": "basket", "per_rank": 0.01, "tier": 1.0, "unit": "pct"},
	"strength": {"level": 1, "icon": "fist", "per_rank": 0.015, "tier": 1.0, "unit": "pct"},
	"garden": {"level": 1, "icon": "sprout", "per_rank": 0.015, "tier": 1.0, "unit": "pct"},
	"beasts": {"level": 1, "icon": "paw", "per_rank": 0.015, "tier": 1.0, "unit": "pct"},
	"seats": {"level": 1, "icon": "crown", "per_rank": 5.0, "tier": 2.0, "unit": "flat"},
	"guard": {"level": 1, "icon": "sword", "per_rank": 0.02, "tier": 1.0, "unit": "pct"},
	"workshop": {"level": 5, "icon": "hammer", "per_rank": 0.012, "tier": 1.5, "unit": "pct"},
	"vitality": {"level": 5, "icon": "heart_plus", "per_rank": 0.015, "tier": 1.5, "unit": "pct"},
	"swift": {"level": 5, "icon": "boots", "per_rank": 0.01, "tier": 1.5, "unit": "pct"},
	"scholar": {"level": 5, "icon": "book", "per_rank": 0.01, "tier": 1.5, "unit": "pct"},
	"merchant": {"level": 5, "icon": "coin", "per_rank": 0.01, "tier": 1.5, "unit": "pct"},
	"warcry": {"level": 5, "icon": "flame", "per_rank": 0.2, "tier": 1.5, "unit": "hit"},
	"fortune": {"level": 12, "icon": "clover", "per_rank": 0.004, "tier": 2.0, "unit": "pct"},
	"thrift": {"level": 12, "icon": "tag", "per_rank": 0.008, "tier": 2.0, "unit": "pct"},
	"tamer": {"level": 12, "icon": "lasso", "per_rank": 0.015, "tier": 2.0, "unit": "pct"},
	"crit": {"level": 12, "icon": "target", "per_rank": 0.003, "tier": 2.0, "unit": "pct"},
	"bounty": {"level": 12, "icon": "chest", "per_rank": 0.03, "tier": 2.0, "unit": "pct"},
	"gold": {"level": 12, "icon": "goldenApple", "per_rank": 0.01, "tier": 2.0, "unit": "pct"},
	"rest": {"level": 20, "icon": "moon", "per_rank": 0.2, "tier": 3.0, "unit": "hours"},
	"gems": {"level": 20, "icon": "gem", "per_rank": 0.001, "tier": 3.0, "unit": "pct"},
	"helpers": {"level": 20, "icon": "heart", "per_rank": 0.015, "tier": 3.0, "unit": "pct"},
	"regrow": {"level": 20, "icon": "wheat", "per_rank": 0.006, "tier": 3.0, "unit": "pct"},
	"packs": {"level": 20, "icon": "bag", "per_rank": 3.0, "tier": 3.0, "unit": "flat"},
	"ranch": {"level": 20, "icon": "sunflower", "per_rank": 0.004, "tier": 3.0, "unit": "pct"},
}
## Ряды талантов: уровни, с которых они открываются.
const ROWS := [1, 5, 12, 20]
const MAX_RANK := 15
## Очков от начала до ранга r: RANK_BASE * r(r+1)/2 * tier (до 15 ранга - RANK_BASE * 120 * tier).
const RANK_BASE := 40


# MARK: Уровень

## Опыт до уровня lvl (на 2 уровень - 700, как _al_level).
static func xp_for(lvl: int) -> int:
	return 0 if lvl <= 1 else int(ceil(700.0 * pow(float(lvl - 1), 1.7)))


static func level_of(xp: int) -> int:
	var l := 1
	while l < MAX_LEVEL and xp >= xp_for(l + 1):
		l += 1
	return l


## Мест в альянсе по очкам талантов (как _al_cap).
static func cap_of(talents: Dictionary) -> int:
	return mini(MAX_CAP, BASE_CAP + int(value("seats", rank_of("seats", int(talents.get("seats", 0))))))


# MARK: Таланты

static func talent_level(id: String) -> int:
	return int(TALENTS.get(id, {}).get("level", 99))


## Очков от начала до ранга r (как _al_talent_points).
static func points_for(id: String, r: int) -> int:
	var tier := float(TALENTS.get(id, {}).get("tier", 1.0))
	return int(floor(float(RANK_BASE * r * (r + 1) / 2) * tier))


## Таланты ряда (в порядке объявления).
static func row(open_level: int) -> Array:
	return TALENTS.keys().filter(func(id: String) -> bool: return talent_level(id) == open_level)


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
	var v := value(id, maxi(1, rank))
	var shown := ""
	match str(TALENTS.get(id, {}).get("unit", "pct")):
		"flat": shown = str(int(round(v)))
		"hours": shown = "%.1f" % v
		"hit": shown = str(int(floor(v)))
		_: shown = Fmt.pct(v)
	return L.t("alliance.talent." + id + ".text", [shown])


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
