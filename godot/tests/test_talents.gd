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
