extends "res://tests/test_case.gd"
## Летопись и статуи: рамки за кристаллы, номер недели.


func test_frames_match_server() -> void:
	var sql := FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../docs/supabase/alliance_chronicle.sql"))
	if sql == "":
		return
	for id in Chronicle.ORDER:
		check(Chronicle.FRAMES.has(id))
		check("'%s'" % id in sql, "рамка %s есть на сервере" % id)
	eq(Chronicle.price("stone"), 0, "камень бесплатно")


func test_week_number() -> void:
	eq(Chronicle.week_number(100, 100), 1)
	eq(Chronicle.week_number(105, 100), 6)
	eq(Chronicle.week_number(90, 100), 1, "не меньше первой")


func test_buy_frame() -> void:
	fresh({"crystals": 400})
	var al := Game.alliance
	eq(al.statue_frame(), "stone")
	check(al.pick_frame("gold"), "хватило кристаллов")
	eq(Game.shop.crystals(), 400 - Chronicle.price("gold"))
	eq(al.statue_frame(), "gold")
	check(not al.pick_frame("flame"), "не хватает кристаллов")
	eq(al.statue_frame(), "gold")
	check(al.pick_frame("stone"))
	check(al.pick_frame("gold"), "купленная рамка снова бесплатно")
	eq(Game.shop.crystals(), 400 - Chronicle.price("gold"))
	check(not al.pick_frame("rainbow"), "нет такой рамки")


func test_save_sanitized() -> void:
	fresh({"statueFrames": ["gold", "hack", 5], "statueFrame": "flame"})
	eq(Game.save["statueFrames"], ["gold"])
	eq(Game.alliance.statue_frame(), "stone", "не купленная рамка не ставится")
