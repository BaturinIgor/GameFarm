extends "res://tests/test_case.gd"
## Обучение: шаги по событиям, награды, пропуск для старых сохранений, знакомство с разделами.


func test_new_player_starts_at_first_step() -> void:
	fresh()
	check(Game.guide.active(), "новичок проходит обучение")
	eq(Game.guide.index(), 0)
	eq(str(Game.guide.current()["id"]), "wood")


func test_veteran_skips() -> void:
	var save := Game.default_save()
	save["level"] = Guide.SKIP_LEVEL
	save.erase("guideStep")
	Game.save = save
	Game.guide.defaults(save)
	check(not Game.guide.active(), "прокачанное сохранение без обучения")


func test_steps_by_events() -> void:
	fresh()
	var coins := int(Game.save["coins"])
	Game.emit_event("gather", {"kind": "stone", "amount": 3})
	eq(Game.guide.progress(), 0, "камень не считается за дерево")
	Game.emit_event("gather", {"kind": "wood", "amount": 3})
	eq(Game.guide.progress(), 3)
	Game.emit_event("deposit", {"amount": 3})
	eq(Game.guide.index(), 0, "сдача на склад раньше своего шага не считается")
	Game.emit_event("gather", {"kind": "wood", "amount": 2})
	eq(Game.guide.index(), 1, "5 дерева - шаг пройден")
	eq(int(Game.save["coins"]) - coins, int(Guide.STEPS[0]["coins"]))
	eq(Game.guide.progress(), 0, "счётчик сброшен")


func test_finish_gives_crystals() -> void:
	fresh()
	var crystals := Game.shop.crystals()
	for s in Guide.STEPS:
		var data := {"kind": s.get("kind", ""), "amount": int(s["target"])}
		Game.emit_event(str(s["event"]), data)
	check(not Game.guide.active(), "все шаги пройдены")
	eq(Game.shop.crystals() - crystals, Guide.FINAL_CRYSTALS)
	eq(Game.guide.badge("storage"), 0, "после обучения отметок нет")


func test_badge_points_to_section() -> void:
	fresh({"guideStep": 4, "guideCount": 0})
	eq(Game.guide.badge("storage"), 1, "шаг продажи ведёт на склад")
	eq(Game.guide.badge("quests"), 0)


func test_intro_once() -> void:
	fresh()
	check(Game.guide.should_intro("mine"))
	check(not Game.guide.should_intro("storage"), "у склада нет знакомства")
	Game.guide.mark_intro("mine")
	check(not Game.guide.should_intro("mine"), "второй раз не показываем")


func test_texts_exist() -> void:
	for i in Guide.STEPS.size():
		var id := str(Guide.STEPS[i]["id"])
		for key in ["guide." + id, "guide." + id + ".hint"]:
			check(L.t(key) != key, "есть строка " + key)
	for sub in Guide.INTROS:
		check(Nav.SUBS.has(sub), "раздел %s есть в навигации" % sub)
		for n in int(Guide.INTROS[sub]["slides"]):
			var key := "intro.%s.%d" % [sub, n + 1]
			check(L.t(key) != key, "есть строка " + key)
