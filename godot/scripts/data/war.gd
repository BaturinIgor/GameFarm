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
## Живая карта (alliance_war_march.sql): отряды идут 1-3 минуты, до 2 отрядов в пути,
## сбор на замок собирается 5 минут (до 30 участников), победа сбора снимает 2 щита, зверь в гарнизоне - до 500 000 мощи.
const RALLY_SECS := 300
const MAX_MARCHES := 2
const RALLY_MAX := 30
const RALLY_STRIP := 2
const ANIMAL_CAP := 500000


static func tier(node: int) -> int:
	return int(NODES[node][2]) if node >= 0 and node < NODES.size() else 0


## Сколько идёт отряд к точке: ярус 1 - минута, 2 - две, 3 - три.
static func march_secs(t: int) -> int:
	return 60 * clampi(t, 1, 3)


## Уровень клетки для живых боёв (alliance_war_battle.sql): 1 - рядом со своей базой, 2 - между двумя базами,
## 3 и 4 - кольца к центру, 5 - замок. У баз 0.
static func level(node: int) -> int:
	if node == 0:
		return 5
	if is_base(node) or node < 0 or node >= NODES.size():
		return 0
	var t := tier(node)
	if t == 1:
		return 1 if node <= 16 else 2
	return t + 1


## Сила лагеря монстров на ничьей клетке по уровню: слабому лагерь 4-5 уровня почти не по силам.
const CAMP_POWER := [0, 100000, 250000, 500000, 1000000, 3000000]
## Кто стоит в лагере: волны по уровню и вожак в решающей схватке.
const CAMP_MONSTERS := [[], ["slimeGreen", "slimeBlue"], ["slimeRed", "orc", "skeleton"], ["orcRogue", "skelSoldier", "skeletonDark"],
	["orcWarrior", "skelMage", "skelRogue"], ["skelKnight", "orcWarrior", "skelMage"]]
const CAMP_BOSS := ["", "slimeGold", "orcShaman", "skelKnight", "orcWarrior", "skelKnight"]
## Лиги (alliance_war_leagues.sql): 1 - Бронза ... 8 - Легенда. За неделю 1-2 места поднимаются, два последних
## (если в лиге 6+ альянсов) опускаются. Лагеря на клетках и замок сильнее в лиге выше.
const LEAGUES := 8
const LEAGUE_MULT := [1.0, 1.6, 2.5, 4.0, 6.0, 9.0, 13.0, 18.0]
const LEAGUE_COLORS := [Color("b87333"), Color("a8b2bd"), Color("e0b23a"), Color("7fd0d8"), Color("3fbf7f"), Color("4a7fe0"),
	Color("d0455a"), Color("a35ae0")]


static func league_mult(league: int) -> float:
	return float(LEAGUE_MULT[clampi(league, 1, LEAGUES) - 1])


static func league_name(league: int) -> String:
	return L.t("war.league.%d" % clampi(league, 1, LEAGUES))


## Тактика в бою (0..1) добавляет до +25% к силе удара; отступление - поражение без броска.
const TACTIC_MAX := 0.25
## Трофеи: за победу в бою - уровень клетки, каждый трофей +2 000 мощи, не больше 300 трофеев.
const TROPHY_POWER := 2000
const TROPHY_MAX := 300


## Земли альянса кормят ферму: у каждой клетки свой вид добычи. Пока альянс держит клетку, у всех участников
## +2% к добыче этого вида за уровень клетки (не больше +25% на вид), замок - +5% ко всей добыче.
const LAND_KINDS := ["crop", "wood", "stone", "food", "ore", "farm", "gem"]
const LAND_ICONS := {"crop": "wheat", "wood": "wood", "stone": "stone", "food": "berries", "ore": "iron", "farm": "egg", "gem": "ruby", "all": "star"}
const LAND_PER_LEVEL := 0.02
const LAND_CASTLE := 0.05
const LAND_MAX := 0.25


static func land_kind(node: int) -> String:
	if node == 0:
		return "all"
	if is_base(node) or node < 0 or node >= NODES.size():
		return ""
	return str(LAND_KINDS[node % LAND_KINDS.size()])


static func land_value(node: int) -> float:
	return LAND_CASTLE if node == 0 else LAND_PER_LEVEL * level(node)


## Бонус добычи от клеток: {вид: доля}, вид "all" - вся добыча.
static func land_bonus(nodes: Array) -> Dictionary:
	var out := {}
	for n in nodes:
		var k := land_kind(int(n))
		if k == "":
			continue
		out[k] = minf(LAND_MAX, float(out.get(k, 0.0)) + land_value(int(n)))
	return out


static func camp_power(lvl: int) -> int:
	return int(CAMP_POWER[clampi(lvl, 0, 5)])


## Шанс победы в живом бою: как chance, но сила растёт от тактики.
static func battle_chance(power: int, chest: int, garrison: int, tactic: float) -> float:
	var pw := int(round(float(maxi(10000, power)) * (1.0 + TACTIC_MAX * clampf(tactic, 0.0, 1.0))))
	return chance(pw, chest, garrison)


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


## Награда за место; в лиге выше - на четверть больше за каждую ступень.
static func place_reward(place: int, hero_level: int, league := 1) -> Dictionary:
	var i := clampi(place - 1, 0, PLACE_CRYSTALS.size() - 1)
	var k := 1.0 + 0.25 * float(clampi(league, 1, LEAGUES) - 1)
	return {"crystals": int(round(PLACE_CRYSTALS[i] * k)), "coins": int(round(2000.0 * maxi(1, hero_level) / float(maxi(1, place)) * k))}


## Соседи точки.
static func neighbors(node: int) -> Array:
	var out: Array = []
	for l in LINKS:
		if int(l[0]) == node:
			out.append(int(l[1]))
		elif int(l[1]) == node:
			out.append(int(l[0]))
	return out
