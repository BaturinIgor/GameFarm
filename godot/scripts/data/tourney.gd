class_name Tourney
## Турнир зверей (docs/supabase/tourney.sql): отряд из трёх зверей бьётся с отрядами других игроков.
## Бой - три поединка по порядку, шанс победы в поединке p^1.3 / (p^1.3 + q^1.3), нужно 2 из 3.
## Очки недели (3 за победу, 1 за поражение) двигают по дорожке наград: бесплатной и платной (пропуск турнира
## на неделю за деньги). За место недели - награда в начале следующей. Числа боёв и очков как на сервере.

const MIN_LEVEL := 8
const SQUAD := 3
const FREE_FIGHTS := 5
const BUY_FIGHTS := 5
const MAX_BUYS := 2
const BUY_CRYSTALS := 60
const WIN_POINTS := 3
const LOSS_POINTS := 1
const DUEL_EXP := 1.3

## Дорожка недели: сколько очков нужно на ступень.
const TRACK := [5, 12, 20, 30, 42, 55, 70, 90, 115, 145]


## Шанс победы зверя мощью p над зверем мощью q.
static func duel_chance(p: float, q: float) -> float:
	if p <= 0.0:
		return 0.0
	if q <= 0.0:
		return 1.0
	var a := pow(p, DUEL_EXP)
	return a / (a + pow(q, DUEL_EXP))


## Награда ступени (с 0) дорожки: бесплатная - монеты и медные ключи, платная - кристаллы и ключи получше.
static func tier_reward(tier: int, paid: bool, level: int) -> Dictionary:
	var t := clampi(tier, 0, TRACK.size() - 1)
	if not paid:
		var r := {"coins": (300 + 40 * maxi(1, level)) * (t + 1)}
		if t % 3 == 2:
			r["copper"] = 1 + t / 3
		return r
	var p := {"crystals": 20 + 10 * t}
	if t % 2 == 1:
		p["silver"] = 1
	if t == TRACK.size() - 1:
		p["crystals"] = 300
		p["star"] = 1
	return p


## Награда за место недели (place с 1).
static func place_reward(place: int, level: int) -> Dictionary:
	var c := 0
	if place == 1:
		c = 500
	elif place == 2:
		c = 350
	elif place == 3:
		c = 250
	elif place <= 10:
		c = 150
	elif place <= 50:
		c = 80
	elif place <= 100:
		c = 40
	return {"crystals": c, "coins": (200 + 30 * maxi(1, level)) * (3 if place <= 100 else 1)}


## Сколько ступеней дорожки открыто при очках points.
static func tiers_open(points: int) -> int:
	var n := 0
	for need in TRACK:
		if points >= int(need):
			n += 1
	return n


## Самые сильные звери из owned (id -> мощь), до SQUAD.
static func best_squad(powers: Dictionary) -> Array:
	var ids := powers.keys().filter(func(k: Variant) -> bool: return int(powers[k]) > 0)
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return int(powers[a]) > int(powers[b]))
	return ids.slice(0, SQUAD)
