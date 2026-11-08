extends "res://tests/test_case.gd"
## Наставник: ступени ученика и награды.


func test_ready_steps() -> void:
	eq(Mentor.ready_steps(9, 16, []), [10, 15])
	eq(Mentor.ready_steps(9, 16, [10.0]), [15], "забранная ступень не повторяется")
	eq(Mentor.ready_steps(12, 16, []), [15], "ступени ниже начального уровня не считаются")
	eq(Mentor.ready_steps(5, 9, []), [])


func test_next_step() -> void:
	eq(Mentor.next_step(9, 9), 10)
	eq(Mentor.next_step(12, 16), 20)
	eq(Mentor.next_step(9, 30), 0)


func test_rewards() -> void:
	check(int(Mentor.reward(20, true)["coins"]) > int(Mentor.reward(20, false)["coins"]), "наставнику больше монет")
	check(int(Mentor.reward(30, false)["coins"]) > int(Mentor.reward(10, false)["coins"]))


func test_pick_rules() -> void:
	fresh({"level": 12, "alliance": {"id": 5, "name": "A", "tag": "A", "emblem": 0, "talents": {}}})
	var al := Game.alliance
	al.mentor = {"mentor": null, "apprentices": []}
	check(al.can_pick_mentor({"level": 30}))
	check(not al.can_pick_mentor({"level": 20}), "наставник от 25 уровня")
	check(not al.can_pick_mentor({"level": 30, "me": true}))
	al.mentor = {"mentor": {"name": "X", "start": 9, "claimed": []}, "apprentices": []}
	check(not al.can_pick_mentor({"level": 30}), "уже есть наставник")
	eq(al.mentor_count(), 1, "ступень 10 готова")
	al.mentor = {}
