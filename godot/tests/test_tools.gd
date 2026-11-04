extends "res://tests/test_case.gd"
## Мастерская: ступени инструментов.


func test_upgrade_pays_and_raises_tier() -> void:
	set_level(Tools.required_level("axe", 2))
	var cost := Game.workshop.next_cost("axe")
	Game.save["coins"] = int(cost["coins"]) + 7
	for it in cost["items"]:
		Game.save["storage"][it[0]] = int(it[1])
	eq(Game.workshop.upgrade_block("axe"), "")
	check(Game.workshop.upgrade("axe"))
	eq(Game.tier("axe"), 2)
	eq(Game.save["coins"], 7, "монеты списаны")
	for it in cost["items"]:
		eq(Game.amount(it[0]), 0, "списан ресурс " + str(it[0]))


func test_upgrade_blocked_without_resources() -> void:
	set_level(Game.MAX_LEVEL)
	Game.save["coins"] = 0
	eq(Game.workshop.upgrade_block("axe"), "cost")
	check(not Game.workshop.upgrade("axe"))
	eq(Game.tier("axe"), 1)


func test_upgrade_blocked_by_level() -> void:
	Game.save["coins"] = 1_000_000
	var next := 2
	while next <= Tools.MAX_TIER and Tools.required_level("pickaxe", next) <= 1:
		next += 1
	Game.save["tools"]["pickaxe"] = next - 1
	eq(Game.workshop.upgrade_block("pickaxe"), "level")


func test_max_tier() -> void:
	Game.save["tools"]["axe"] = Tools.MAX_TIER
	eq(Game.workshop.upgrade_block("axe"), "max")
	eq(Game.workshop.next_cost("axe"), {})


func test_every_tier_has_cost_and_rising_level() -> void:
	for tool in Tools.UPGRADABLE:
		var prev := 0
		for t in range(2, Tools.MAX_TIER + 1):
			var c := Tools.cost(tool, t)
			check(int(c["coins"]) > 0 or not (c["items"] as Array).is_empty(), "%s ступень %d бесплатная" % [tool, t])
			var lvl := Tools.required_level(tool, t)
			check(lvl >= prev, "%s: уровень ступени %d меньше предыдущей" % [tool, t])
			check(lvl <= Game.MAX_LEVEL, "%s: ступень %d недостижима" % [tool, t])
			prev = lvl
