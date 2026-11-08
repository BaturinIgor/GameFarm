class_name AllianceEvents
## События альянса (шаг 2 из 3): страж альянса, задания недели, награды за место в неделе.
## Правила считает сервер (docs/supabase/alliance_events.sql), числа здесь должны совпадать с ним.
## Награды выдаёт игра по ответу сервера (сервер следит, чтобы каждую забирали один раз).

## Удары по стражу в день: бесплатные и за кристаллы.
const FREE_HITS := 3
const EXTRA_HITS := 5
const EXTRA_COST := 10
## Виды заданий и доля одного участника за неделю (как _al_task_share).
const SHARE := {"kill": 120, "produce": 200, "order": 20, "cook": 25, "dungeon": 12, "mine": 15, "treasure": 15, "chest": 10}
const KINDS := ["kill", "produce", "order", "cook", "dungeon", "mine", "treasure", "chest"]
const KIND_ICON := {"kill": "sword", "produce": "hammer", "order": "scroll", "cook": "flame", "dungeon": "door",
	"mine": "stairs", "treasure": "tmap", "chest": "chest"}
## Вклад одного игрока в задание - не больше стольких долей; на награду нужно не меньше 1/10 доли.
const CAP_SHARES := 3
const MIN_SHARE := 0.1
## Стражи по ступеням (по кругу).
const BOSSES := ["orcWarrior", "skelKnight", "slimeGold", "orcShaman", "skeletonDark", "skelMage", "orcRogue", "slimeIce"]
## Как часто отправлять счётчики заданий на сервер (секунды).
const FLUSH_EVERY := 90.0


## Задания недели: 3 вида по номеру недели (как _al_task_kinds).
static func task_kinds(week: int) -> Array:
	return [KINDS[posmod(week, 8)], KINDS[posmod(week + 3, 8)], KINDS[posmod(week + 5, 8)]]


static func task_target(kind: String, members: int) -> int:
	return int(SHARE.get(kind, 0)) * maxi(5, members) / 2


static func boss_hp(tier: int, members: int) -> int:
	return int(round(4000.0 * pow(float(tier), 1.6) * float(maxi(5, members)) / 10.0))


## Урон удара без случайности (сервер добавляет разброс 0.85-1.15).
## Мощь даёт +1 к урону за каждые 100, guard_rank - ранг таланта «Натиск» (+2% за ранг).
static func hit_damage(level: int, power: int, guard_rank: int) -> int:
	var base := 60 + 8 * clampi(level, 1, 200) + clampi(power, 0, Power.MAX) / Power.DAMAGE_PER
	return int(round(float(base) * (1.0 + 0.02 * float(guard_rank))))


static func boss_kind(tier: int) -> String:
	return str(BOSSES[posmod(tier - 1, BOSSES.size())])


# MARK: Награды

## Награда: {crystals, coins, key: copper|silver|star}.
static func boss_reward(tier: int, level: int) -> Dictionary:
	return {"crystals": mini(30, 5 + 3 * tier), "coins": Events.coins(250 * tier, level),
		"key": "star" if tier >= 6 else ("silver" if tier >= 3 else "copper")}


static func task_reward(level: int) -> Dictionary:
	return {"crystals": 15, "coins": Events.coins(600, level), "key": "silver"}


## Места: до какого места какая награда.
const PLACES := [[1, 150, "star"], [3, 100, "star"], [10, 70, "silver"], [50, 40, "silver"], [200, 20, "copper"], [1000000, 10, "copper"]]


static func place_reward(place: int, level: int) -> Dictionary:
	for p in PLACES:
		if place <= int(p[0]):
			return {"crystals": int(p[1]), "coins": Events.coins(int(p[1]) * 20, level), "key": str(p[2])}
	return {}


## Награда с бонусом «Трофеев»: кристаллы и монеты больше на долю bonus.
static func with_bounty(r: Dictionary, bonus: float) -> Dictionary:
	if r.is_empty() or bonus <= 0.0:
		return r
	var out := r.duplicate()
	for k in ["crystals", "coins"]:
		out[k] = int(round(float(r.get(k, 0)) * (1.0 + bonus)))
	return out


static func kind_name(kind: String) -> String:
	return L.t("alliance.task." + kind)
