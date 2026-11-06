extends "res://tests/test_case.gd"
## Альянсы: числа совпадают с сервером (docs/supabase/alliances.sql), бонусы талантов, цены вкладов.


func test_levels_and_caps() -> void:
	eq(Alliances.level_of(0), 1)
	eq(Alliances.level_of(399), 1)
	eq(Alliances.level_of(400), 2, "на 2 уровень - 400 опыта, как _al_level")
	eq(Alliances.cap_of(0), 25)
	eq(Alliances.cap_of(Alliances.xp_for(16)), 100, "100 мест на 16 уровне")
	eq(Alliances.level_of(10_000_000), Alliances.MAX_LEVEL)


func test_talent_ranks() -> void:
	eq(Alliances.talent_max("harvest"), 3300, "как _al_talent_max: 60 * 55")
	eq(Alliances.talent_max("garden"), 4950)
	eq(Alliances.talent_max("workshop"), 6600)
	eq(Alliances.talent_max("fortune"), 9900)
	eq(Alliances.rank_of("harvest", 59), 0)
	eq(Alliances.rank_of("harvest", 60), 1)
	eq(Alliances.rank_of("harvest", 3300), Alliances.MAX_RANK)
	for id in Alliances.TALENTS:
		check(L.t("alliance.talent." + id) != "alliance.talent." + id, "есть название таланта %s" % id)


func test_costs() -> void:
	eq(Alliances.gem_cost(0), 5)
	eq(Alliances.gem_cost(4), 5)
	eq(Alliances.gem_cost(5), 10, "каждые 5 вкладов дороже")
	eq(Alliances.gem_cost(12), 15)
	check(Alliances.coin_cost(40) > Alliances.coin_cost(10), "за монеты дороже с уровнем")


func test_talent_bonus_applies() -> void:
	var before := Game.stats.yield_all
	Game.save["alliance"] = {"id": 7, "name": "T", "tag": "T", "emblem": 0, "talents": {"harvest": 3300, "strength": 60}}
	Game.recalc()
	near(Game.stats.yield_all, before + 0.10, 0.0001, "10 рангов урожая - +10% добычи")
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
