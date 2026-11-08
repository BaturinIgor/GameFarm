extends "res://tests/test_case.gd"
## Война альянсов: карта, шанс атаки, казна, награды и «Знамя войны».


func test_map() -> void:
	eq(War.NODES.size(), 41, "замок, 8 баз и 32 аванпоста")
	eq(War.tier(0), 4)
	for n in range(1, 9):
		check(War.is_base(n))
		check(War.neighbors(n).size() >= 2, "у базы есть куда идти")
	for n in War.NODES.size():
		var p: Array = War.NODES[n]
		check(int(p[0]) >= 0 and int(p[0]) <= War.SIZE and int(p[1]) >= 0 and int(p[1]) <= War.SIZE, "точка на карте")
	# От каждой базы можно дойти до замка
	for b in range(1, 9):
		var seen := {b: true}
		var queue := [b]
		while not queue.is_empty():
			var x: int = queue.pop_front()
			for m in War.neighbors(x):
				if not seen.has(m) and not War.is_base(m):
					seen[m] = true
					queue.append(m)
		check(seen.has(0), "путь до замка от базы %d" % b)


func test_chance_and_boost() -> void:
	eq(War.boost(0), 0.0)
	eq(War.boost(1000000000), War.BOOST_MAX, "буст не больше 35%")
	eq(War.chance(100, 0, 1000000), War.MIN_CHANCE)
	eq(War.chance(1000000, 0, 1), War.MAX_CHANCE)
	check(War.chance(20000, 2000000, 30000) > War.chance(20000, 0, 30000), "казна поднимает шанс")
	eq(War.attacks(false), 5)
	eq(War.attacks(true), 8)
	check(War.donate_coins(500) <= 100000, "вклад не больше, чем принимает сервер")
	check(War.place_reward(1, 20)["crystals"] > War.place_reward(5, 20)["crystals"])


func test_pass_and_frame() -> void:
	fresh({"level": 20})
	check(not Game.war.has_pass())
	check(not War.PASS_FRAME in Game.alliance.owned_frames())
	Game.war.demo = true
	Game.premium.grant("warBanner", "t1")
	check(Game.war.has_pass())
	check(War.PASS_FRAME in Game.alliance.owned_frames(), "рамка за знамя")
	check(Products.consumable("warBanner"))
	Game.war.demo = false


func test_demo_actions() -> void:
	fresh({"level": 20, "coins": 100000})
	var w := Game.war
	w.demo = true
	w.state = {"league": 1, "slot": 1, "nodes": [[9, 0, 1, 500, true], [10, 2, 1, 500, false], [17, 1, 1, 900, false]],
		"teams": [{"slot": 1, "me": true}, {"slot": 2, "me": false}], "used": 0, "max": 5, "donates": 0, "chest": 0}
	check(w.can_attack(9))
	check(not w.can_attack(10), "далёкая точка")
	check(not w.can_attack(17), "своя точка")
	check(w.can_reinforce(17))
	check(not w.can_attack(1), "базу не атаковать")
	w.donate()
	eq(w.chest(), War.donate_coins(20))
	eq(w.my_place(), 1)
	w.demo = false
	w.state = {}


func test_live_map_demo() -> void:
	fresh({"level": 20, "coins": 100000})
	var w := Game.war
	w.demo = true
	w.live = true
	w.state = {"league": 1, "slot": 1, "nodes": [[9, 1, 1, 500, true], [17, 0, 1, 500, true], [25, 0, 2, 900, true], [33, 0, 2, 900, false],
		[0, 0, 4, 5000, false]], "teams": [{"slot": 1, "me": true}, {"slot": 2, "me": false}], "used": 0, "max": 5, "chest": 0,
		"marches": [], "rallies": []}
	check(w.visible(9), "своя точка видна")
	check(w.visible(17), "соседняя с базой видна")
	check(not w.visible(33), "дальняя - в тумане")
	eq(w.origin(25, 1), 9, "отряд идёт от своей точки")
	eq(War.march_secs(1), 60)
	eq(War.march_secs(3), 180)
	check(w.can_march(17))
	await w.march(17)
	eq(w.my_marches().size(), 1)
	check(not w.can_march(17), "второй отряд к той же точке не идёт")
	await w.march(25)
	check(not w.can_march(9) and w.my_marches().size() == War.MAX_MARCHES, "не больше двух отрядов")
	eq(w.attacks_left(), 3)
	check(w.can_rally(25))
	await w.rally(25)
	check(not w.my_rally().is_empty())
	check(not w.can_rally(17), "один сбор на альянс")
	var r := {"id": 7, "mine": true, "joined": false, "members": 3, "fires": w.now() + 100, "power": 1000}
	check(w.can_join(r))
	await w.join_rally(r)
	check(bool(r["joined"]))
	eq(w.attacks_left(), 1)
	w.demo = false
	w.state = {}
