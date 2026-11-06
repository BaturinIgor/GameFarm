extends "res://tests/test_case.gd"
## Дерево талантов: очки, требования, изучение и сброс.


func test_points_by_level() -> void:
	eq(Game.talent_points_at(1), 1)
	eq(Game.talent_points_at(10), 11)
	eq(Game.talent_points_at(60), 66)


func test_learn_root_talent() -> void:
	eq(Game.talents.points_free(), 1)
	check(Game.talents.learn("power"), "корневой талант изучается")
	eq(Game.talents.rank("power"), 1)
	eq(Game.talents.points_free(), 0)
	eq(Game.talents.block_reason("power"), "points", "второй ранг без очков")


func test_learn_requires_parents_and_level() -> void:
	set_level(10)
	eq(Game.talents.block_reason("lumberjack"), "parents", "без родителя")
	Game.talents.learn("power")
	check(Game.talents.learn("lumberjack"), "после родителя изучается")
	set_level(1)
	Game.save["bonusTalentPoints"] = 50
	eq(Game.talents.block_reason("quickHands"), "level", "мал уровень")


func test_super_talent_needs_maxed_parents() -> void:
	for id in Talents.ids():
		if not Talents.is_super(id) or Talents.parents(id).is_empty():
			continue
		set_level(Game.MAX_LEVEL)
		Game.save["bonusTalentPoints"] = 1000
		for p in Talents.parents(id):
			Game.save["talents"][p] = 1
		if Talents.max_rank(Talents.parents(id)[0]) > 1:
			eq(Game.talents.block_reason(id), "parents", "суперталант %s при неполных родителях" % id)
		for p in Talents.parents(id):
			Game.save["talents"][p] = Talents.max_rank(p)
		check(Game.talents.block_reason(id) in ["", "parents"], "суперталант %s" % id)
		return


func test_cannot_exceed_max_rank() -> void:
	set_level(Game.MAX_LEVEL)
	Game.save["bonusTalentPoints"] = 1000
	for i in Talents.max_rank("power") + 3:
		Game.talents.learn("power")
	eq(Game.talents.rank("power"), Talents.max_rank("power"))
	eq(Game.talents.block_reason("power"), "maxed")


func test_reset_returns_points_and_costs_coins() -> void:
	set_level(5)
	Game.talents.learn("power")
	Game.talents.learn("power")
	var free_before := Game.talents.points_free()
	Game.save["coins"] = Game.talents.respec_cost()
	check(Game.talents.reset_talents(), "сброс")
	eq(Game.save["coins"], 0, "сброс стоит монет")
	eq(Game.talents.points_free(), free_before + 2, "очки вернулись")
	check(not Game.talents.can_reset(), "второй сброс без вложенных очков")


func test_unknown_talents_dropped_on_load() -> void:
	fresh({"talents": {"power": 2, "removedTalent": 3}})
	eq(Game.save["talents"], {"power": 2})


func test_estate_branch_replaces_academy() -> void:
	# Бывшая академия - ветка талантов "Усадьба": бонусы считаются от рангов талантов.
	check("estate" in Talents.BRANCHES)
	eq(Game.academy.mult("build"), 1.0, "без талантов бонуса нет")
	eq(Game.academy.mult("stockpile"), 0.0)
	Game.save["talents"]["estBuild"] = 2
	Game.save["talents"]["estStorage"] = 3
	Game.save["talents"]["estStockpile"] = 2
	Game.save["talents"]["estThrift"] = 1
	near(Game.academy.mult("build"), 1.0 - 2.0 * Talents.per_rank("estBuild"), 0.0001, "стройка быстрее")
	near(Game.academy.mult("storage"), 1.0 + 3.0 * Talents.per_rank("estStorage"), 0.0001, "склад больше")
	near(Game.academy.mult("stockpile"), 2.0, 0.0001, "часы запаса")
	near(Game.academy.mult("thrift"), Talents.per_rank("estThrift"), 0.0001, "шанс сберечь энергию")
	for id in Academy.TALENT:
		check(Talents.exists(str(Academy.TALENT[id])), "талант для %s есть" % id)
		check(Talents.name_of(str(Academy.TALENT[id])) != "talent." + str(Academy.TALENT[id]), "есть название")
	check(not ("academy" in Estate.IDS), "здания академии больше нет")


func test_academy_save_migrated() -> void:
	var s := {"talents": {"power": 1, "estStorage": 4}, "bonusTalentPoints": 2,
		"academy": {"levels": {"build": 3, "storage": 2, "stamina": 10, "thrift": 1}, "active": "orders", "until": 5.0}}
	Game.academy.defaults(s)
	check(not s.has("academy"), "старые исследования убраны")
	eq(int(s["talents"]["estBuild"]), 2, "уровень 3 -> ранг 2")
	eq(int(s["talents"]["estStorage"]), 4, "уже изученный ранг выше не трогаем")
	eq(int(s["talents"]["estStamina"]), Talents.max_rank("estStamina"), "не выше потолка")
	eq(int(s["talents"]["estThrift"]), 1)
	eq(int(s["bonusTalentPoints"]), 2 + 2 + 5 + 1, "за перенесённые ранги - бесплатные очки")
	Game.academy.defaults(s)
	eq(int(s["bonusTalentPoints"]), 10, "второй раз не переносится")


func test_estate_house_gives_points() -> void:
	var before := Game.talents.points_total()
	var lvl := Game.estate.level("main")
	Game.save["estate"]["main"]["level"] = lvl + 3
	eq(Game.talents.points_total(), before + 3, "очко за каждый уровень главного дома")
