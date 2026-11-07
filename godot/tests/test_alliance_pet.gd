extends "res://tests/test_case.gd"
## Хранитель альянса: числа совпадают с сервером (docs/supabase/alliance_pet.sql), бонус стадии.


func test_matches_server() -> void:
	# _al_pet_cravings(20764) = wheat, strawberry, cabbage (проверено на локальной базе)
	eq(AlliancePet.cravings(20764), ["wheat", "strawberry", "cabbage"])
	eq(AlliancePet.stage_of(0), 1)
	eq(AlliancePet.stage_of(199), 1)
	eq(AlliancePet.stage_of(200), 2)
	eq(AlliancePet.stage_of(28000), AlliancePet.MAX_STAGE)
	eq(AlliancePet.xp_for(2), 200)
	for item in AlliancePet.EASY + AlliancePet.MID + AlliancePet.RARE:
		check(item in Res.KINDS, "угощение %s - настоящий товар" % item)
	check(AlliancePet.portion(2, 40) > AlliancePet.portion(2, 1), "порция растёт с уровнем")


func test_stage_bonus_applies() -> void:
	fresh()
	var before := Game.stats.yield_all
	Game.save["alliance"] = {"id": 7, "name": "T", "tag": "T", "emblem": 0, "talents": {}, "petStage": 4}
	Game.recalc()
	near(Game.stats.yield_all, before + 0.03, 0.0001, "стадия 4 - +3% к добыче")
	Game.save["alliance"] = {}
	Game.recalc()
	near(Game.stats.yield_all, before, 0.0001)
