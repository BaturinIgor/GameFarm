extends "res://tests/test_case.gd"
## Задания и цели дня: события двигают прогресс, награду можно забрать один раз.


func test_quests_exist() -> void:
	Game.quests.ensure_quests()
	check(Game.quests.current_quests().size() > 0, "у нового игрока есть задания")


func test_gather_event_progresses_quest() -> void:
	Game.quests.ensure_quests()
	for q in Game.quests.current_quests():
		if str(q.get("type", "")) == "gather":
			var kind := str(q.get("resource", ""))
			var before := int(q.get("progress", 0))
			Game.add_to_backpack(kind, 1)
			check(int(q.get("progress", 0)) > before, "сбор двигает задание на " + kind)
			return


func test_claim_quest_once() -> void:
	Game.quests.ensure_quests()
	var q: Dictionary = Game.quests.current_quests()[0]
	q["progress"] = int(q.get("target", 1))
	var id := str(q["id"])
	var coins := int(Game.save["coins"])
	Game.quests.claim_quest(id)
	check(int(Game.save["coins"]) > coins or Game.level > 1, "награда за задание")
	var after := int(Game.save["coins"])
	Game.quests.claim_quest(id)
	eq(Game.save["coins"], after, "повторно награду не дают")


func test_daily_goal_claim_once() -> void:
	var goals: Array = Game.daily.goals()
	check(goals.size() > 0, "есть цели дня")
	var g: Dictionary = goals[0]
	g["progress"] = int(g.get("target", 1))
	check(Game.daily.done(g), "цель выполнена")
	var c := Game.shop.crystals()
	Game.daily.claim(0)
	check(Game.shop.crystals() > c, "кристаллы за цель")
	var after := Game.shop.crystals()
	Game.daily.claim(0)
	eq(Game.shop.crystals(), after, "повторно не дают")
