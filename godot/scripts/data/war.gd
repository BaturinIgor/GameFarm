class_name War
## Карта войны альянсов (docs/supabase/alliance_war.sql): недельная лига до 8 альянсов на карте 120x120.
## В центре замок, базы альянсов по краям, между ними 32 аванпоста. Числа как на сервере.

const SIZE := 120
const TEAMS := 8
## Точки: [x, y, ярус]. Ярус 0 - база альянса (точки 1..8 - базы слотов 1..8), 1-3 - аванпосты, 4 - замок (точка 0).
const NODES := [[60, 60, 4], [60, 6, 0], [98, 22, 0], [114, 60, 0], [98, 98, 0], [60, 114, 0], [22, 98, 0], [6, 60, 0], [22, 22, 0], [60, 20, 1], [88, 32, 1], [100, 60, 1], [88, 88, 1], [60, 100, 1], [32, 88, 1], [20, 60, 1], [32, 32, 1], [78, 18, 1], [102, 42, 1], [102, 78, 1], [78, 102, 1], [42, 102, 1], [18, 78, 1], [18, 42, 1], [42, 18, 1], [71, 33, 2], [87, 49, 2], [87, 71, 2], [71, 87, 2], [49, 87, 2], [33, 71, 2], [33, 49, 2], [49, 33, 2], [60, 45, 3], [71, 49, 3], [75, 60, 3], [71, 71, 3], [60, 75, 3], [49, 71, 3], [45, 60, 3], [49, 49, 3]]
const LINKS := [[0, 33], [0, 34], [0, 35], [0, 36], [0, 37], [0, 38], [0, 39], [0, 40], [1, 9], [1, 17], [1, 24], [2, 10], [2, 17], [2, 18], [3, 11], [3, 18], [3, 19], [4, 12], [4, 19], [4, 20], [5, 13], [5, 20], [5, 21], [6, 14], [6, 21], [6, 22], [7, 15], [7, 22], [7, 23], [8, 16], [8, 23], [8, 24], [9, 17], [9, 24], [9, 25], [9, 32], [10, 17], [10, 18], [10, 25], [10, 26], [11, 18], [11, 19], [11, 26], [11, 27], [12, 19], [12, 20], [12, 27], [12, 28], [13, 20], [13, 21], [13, 28], [13, 29], [14, 21], [14, 22], [14, 29], [14, 30], [15, 22], [15, 23], [15, 30], [15, 31], [16, 23], [16, 24], [16, 31], [16, 32], [17, 25], [18, 26], [19, 27], [20, 28], [21, 29], [22, 30], [23, 31], [24, 32], [25, 33], [25, 34], [26, 34], [26, 35], [27, 35], [27, 36], [28, 36], [28, 37], [29, 37], [29, 38], [30, 38], [30, 39], [31, 39], [31, 40], [32, 33], [32, 40]]
const ATTACKS := 5
const PASS_ATTACKS := 3
const DONATES_PER_DAY := 3
const BOOST_MAX := 0.35
## +1% к силе атаки за каждые 100 000 монет в казне.
const BOOST_COINS := 10000000.0
const MIN_CHANCE := 0.1
const MAX_CHANCE := 0.9
## Цвета альянсов по слоту (0 - ничья точка).
const COLORS := [Color("cfc4ae"), Color("e0503a"), Color("3a8ee0"), Color("4cbf4a"), Color("f0b62a"),
	Color("a35ae0"), Color("2ac0c0"), Color("f07ab0"), Color("8a6a4a")]
## Кристаллы за место альянса в лиге.
const PLACE_CRYSTALS := [300, 200, 150, 100, 60, 60, 60, 60]
## Рамка статуи за «Знамя войны».
const PASS_FRAME := "war"


static func tier(node: int) -> int:
	return int(NODES[node][2]) if node >= 0 and node < NODES.size() else 0


static func is_base(node: int) -> bool:
	return node >= 1 and node <= TEAMS


## Очков в час за точку.
static func rate(t: int) -> int:
	return [0, 10, 20, 30, 100][clampi(t, 0, 4)]


static func max_shields(t: int) -> int:
	return 6 if t == 4 else 3


static func attacks(with_pass: bool) -> int:
	return ATTACKS + (PASS_ATTACKS if with_pass else 0)


static func boost(chest: int) -> float:
	return minf(BOOST_MAX, maxf(0.0, float(chest) / BOOST_COINS))


## Шанс победы: моя мощь с бустом казны против гарнизона точки.
static func chance(power: int, chest: int, garrison: int) -> float:
	var a := float(maxi(10000, power)) * (1.0 + boost(chest))
	return clampf(a / (a + float(maxi(1, garrison))), MIN_CHANCE, MAX_CHANCE)


## Вклад в казну за раз (как в постройки деревни).
static func donate_coins(hero_level: int) -> int:
	return Village.donate_coins(hero_level)


## Монеты за победу в атаке (захват - втрое).
static func win_coins(hero_level: int, captured: bool) -> int:
	return (100 + 20 * maxi(1, hero_level)) * (3 if captured else 1)


static func place_reward(place: int, hero_level: int) -> Dictionary:
	var i := clampi(place - 1, 0, PLACE_CRYSTALS.size() - 1)
	return {"crystals": PLACE_CRYSTALS[i], "coins": int(round(2000.0 * maxi(1, hero_level) / float(maxi(1, place))))}


## Соседи точки.
static func neighbors(node: int) -> Array:
	var out: Array = []
	for l in LINKS:
		if int(l[0]) == node:
			out.append(int(l[1]))
		elif int(l[1]) == node:
			out.append(int(l[0]))
	return out
