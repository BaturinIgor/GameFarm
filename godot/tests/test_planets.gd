extends "res://tests/test_case.gd"
## Дальние планеты: свои ресурсы и точки добычи, стражи локаций, карточка «Что ждёт», перенос глав сюжета.


func test_planet_data() -> void:
	for loc in Planets.RESOURCE:
		var res := Planets.resource_of(loc)
		check(Locations.SPECS.has(loc), "локация %s существует" % loc)
		check(res in Res.KINDS, "ресурс %s известен" % res)
		check(Nodes.SPECS.has(Planets.NODE[loc]), "точка добычи %s есть" % Planets.NODE[loc])
		check(L.t("res." + res) != "res." + res, "у ресурса %s есть название" % res)
		check(Planets.guardian_name(loc) != "guardian." + loc, "у стража %s есть имя" % loc)
		var g := Planets.guardian(loc)
		check(str(g["kind"]) in Monsters.KINDS, "вид стража %s известен" % loc)
	eq(Planets.guardian("meadow"), {}, "на лугу стража нет")


func test_preview_lists_planet_content() -> void:
	for p in ["ember", "azure"]:
		var pv := Planets.preview(p)
		check(pv["locations"].size() >= 3, "на планете %s есть локации" % p)
		eq(pv["resources"].size(), pv["locations"].size(), "у каждой локации %s свой ресурс" % p)
		eq(pv["guardians"].size(), pv["locations"].size(), "у каждой локации %s свой страж" % p)
		check(pv["animals"].size() >= 1, "на планете %s есть дикие звери" % p)
		check(pv["monsters"].size() >= 1, "на планете %s есть монстры" % p)


func test_guardian_once_a_day() -> void:
	var loc := "ashPlains"
	check(not Game.world_map.guardian_done(loc), "страж ждёт")
	var keys := int(Game.save["chests"]["keys"].get(Planets.REWARD_KEY, 0))
	Game.world_map.guardian_defeated(loc)
	check(Game.world_map.guardian_done(loc), "страж побеждён сегодня")
	eq(int(Game.save["storage"].get(Planets.resource_of(loc), 0)), Planets.REWARD_RES, "ресурс локации получен")
	eq(int(Game.save["chests"]["keys"].get(Planets.REWARD_KEY, 0)), keys + 1, "ключ получен")
	Game.world_map.guardian_defeated(loc)
	eq(int(Game.save["storage"].get(Planets.resource_of(loc), 0)), Planets.REWARD_RES, "второй раз за день награды нет")
	Clock.offset = 86400.0
	check(not Game.world_map.guardian_done(loc), "на следующий день страж снова ждёт")


func test_story_migration_keeps_finale() -> void:
	# Старое сохранение: финал был 11-й главой (индекс 10)
	fresh({"heart": {"ch": 10, "pages": 2, "gift": false}})
	eq(int(Game.save["heart"]["ch"]), 10 + Story.INSERTED, "игрок остаётся на финале")
	eq(Story.loc(int(Game.save["heart"]["ch"])), "crystalReef", "финал - Хрустальный риф")
	eq(int(Game.save["heart"]["pages"]), 2, "найденные страницы сохранены")
	fresh({"heart": {"ch": 11}})
	eq(int(Game.save["heart"]["ch"]), Story.count(), "пройденный сюжет остаётся пройденным")
	fresh({"heart": {"ch": 4}})
	eq(int(Game.save["heart"]["ch"]), 4, "ранние главы не сдвигаются")
	# Новое сохранение не сдвигается повторно
	var again := {"heart": Game.save["heart"].duplicate()}
	again["heart"]["ch"] = 12
	fresh(again)
	eq(int(Game.save["heart"]["ch"]), 12, "сохранение версии 2 не сдвигается")


func test_task_farm_events() -> void:
	# Старый круг не меняется до NEW_FROM, новый - со всеми видами
	for i in FarmEvents.NEW_FROM:
		eq(FarmEvents.run(i)["event"], FarmEvents.OLD_IDS[i % FarmEvents.OLD_IDS.size()], "проход %d как в 1.0" % i)
	var seen := {}
	for i in FarmEvents.IDS.size():
		seen[FarmEvents.run(FarmEvents.NEW_FROM + i)["event"]] = true
	eq(seen.size(), FarmEvents.IDS.size(), "в новом круге все ивенты")
	for e in FarmEvents.ACTIONS:
		eq(FarmEvents.kind(e), "task")
		check(L.t("farm." + e) != "farm." + e, "есть название %s" % e)
		for a in FarmEvents.ACTIONS[e]:
			check(L.t("farm.act." + a) != "farm.act." + a, "есть текст очков за %s" % a)
	eq(FarmEvents.action_points("workshopMarathon", "produce", {"amount": 7}), 7, "товары - за штуку")
	eq(FarmEvents.action_points("workshopMarathon", "order", {}), 20)
	eq(FarmEvents.action_points("workshopMarathon", "kill", {}), 0, "чужие дела не считаются")


func test_task_event_counts_actions() -> void:
	set_level(Events.MIN_LEVEL + 5)
	# Найти проход марафона мастерских и встать в его середину
	var idx := FarmEvents.NEW_FROM
	while FarmEvents.run(idx)["event"] != "workshopMarathon":
		idx += 1
	Clock.offset = float(FarmEvents.run(idx)["start"]) + 3600.0 - Time.get_unix_time_from_system()
	check(Game.farm.is_open(), "ивенты открыты")
	Game.farm.sync()
	var before := Game.farm.points()
	Game.emit_event("produce", {"kind": "planks", "amount": 5})
	Game.emit_event("order", {"cart": 0})
	Game.emit_event("kill", {"monster": "slime", "level": 1, "boss": false})
	eq(Game.farm.points(), before + 25, "очки за товары и заказ")


func test_week_has_six_goals() -> void:
	set_level(20)
	Game.save["weekly"] = {"week": -1, "v": 1, "goals": [], "bonus": false}
	var goals := Game.daily.week_goals()
	eq(goals.size(), DailySystem.WEEK_CRYSTALS.size(), "шесть целей недели")
	var types := {}
	for g in goals:
		types[g["type"]] = true
		check(L.t("daily." + str(g["type"]), [1]) != "daily." + str(g["type"]), "есть текст цели %s" % g["type"])
	eq(types.size(), goals.size(), "цели не повторяются")
	# Новичок: всё равно шесть целей
	fresh()
	set_level(1)
	eq(Game.daily.week_goals().size(), DailySystem.WEEK_CRYSTALS.size(), "у новичка тоже шесть")
	for t in ["cook", "chest", "hatch", "mine", "guardian", "treasure", "order"]:
		check(L.t("daily." + t, [1]) != "daily." + t, "есть текст цели %s" % t)
