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
