extends "res://tests/test_case.gd"
## Альянсы: числа совпадают с сервером (docs/supabase/alliances.sql), бонусы талантов, цены вкладов.


func test_levels_and_caps() -> void:
	eq(Alliances.level_of(0), 1)
	eq(Alliances.level_of(699), 1)
	eq(Alliances.level_of(700), 2, "на 2 уровень - 700 опыта, как _al_level")
	eq(Alliances.level_of(214000), 29, "проверено на локальной базе")
	eq(Alliances.level_of(10_000_000), Alliances.MAX_LEVEL)
	eq(Alliances.cap_of({}), 25, "альянс начинает с 25 мест")
	eq(Alliances.cap_of({"seats": Alliances.points_for("seats", 4)}), 45)
	eq(Alliances.cap_of({"seats": Alliances.talent_max("seats")}), 100, "все ранги «Мест» - 100 мест")


func test_talent_ranks() -> void:
	eq(Alliances.TALENTS.size(), 24)
	eq(Alliances.talent_max("harvest"), 4800, "как _al_talent_max: 40 * 120")
	eq(Alliances.talent_max("seats"), 9600)
	eq(Alliances.talent_max("rest"), 14400)
	var total := 0
	for id in Alliances.TALENTS:
		total += Alliances.talent_max(id)
	eq(total, 220800, "всё дерево, как на сервере")
	eq(Alliances.rank_of("harvest", 39), 0)
	eq(Alliances.rank_of("harvest", 40), 1)
	eq(Alliances.rank_of("harvest", 4800), Alliances.MAX_RANK)
	for lvl in Alliances.ROWS:
		eq(Alliances.row(lvl).size(), 6, "в ряду %d шесть талантов" % lvl)
	for id in Alliances.TALENTS:
		check(L.t("alliance.talent." + id) != "alliance.talent." + id, "есть название таланта %s" % id)
		check(L.t("alliance.talent." + id + ".text").contains("{0}"), "в описании %s есть {0}" % id)
		check(not Alliances.talent_text(id, 15).contains("{0}"), "описание %s подставляется" % id)


func test_costs() -> void:
	eq(Alliances.gem_cost(0), 5)
	eq(Alliances.gem_cost(4), 5)
	eq(Alliances.gem_cost(5), 10, "каждые 5 вкладов дороже")
	eq(Alliances.gem_cost(12), 15)
	check(Alliances.coin_cost(40) > Alliances.coin_cost(10), "за монеты дороже с уровнем")


func test_talent_bonus_applies() -> void:
	var before := Game.stats.yield_all
	Game.save["alliance"] = {"id": 7, "name": "T", "tag": "T", "emblem": 0, "talents": {"harvest": 4800, "strength": 40}}
	Game.recalc()
	near(Game.stats.yield_all, before + 0.15, 0.0001, "15 рангов урожая - +15% добычи")
	eq(Game.alliance.rank("strength"), 1)
	# Вышел из альянса - бонусов нет
	Game.save["alliance"] = {}
	Game.recalc()
	near(Game.stats.yield_all, before, 0.0001)


func test_save_cleanup() -> void:
	fresh({"alliance": {"id": 3, "talents": {"harvest": 10, "bogus": 5}}})
	eq(Game.save["alliance"]["talents"].has("bogus"), false, "неизвестные таланты убраны")
	fresh({"alliance": "garbage"})
	eq(Game.save["alliance"], {})
	check(not Game.alliance.in_alliance())


func test_hidden_switch() -> void:
	Alliances.enabled = false
	var spec := Nav.group_spec("world")
	check(not "alliance" in spec[3], "без альянсов во вкладке «Мир» нет раздела альянса")
	check(not Game.alliance.available(), "альянс недоступен")
	check(not Game.alliance.open(), "окно альянса закрыто")
	Alliances.enabled = true
	check("alliance" in Nav.group_spec("world")[3])
