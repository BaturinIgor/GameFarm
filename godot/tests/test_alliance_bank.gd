extends "res://tests/test_case.gd"
## Банк альянса: вклады в банк и медали, ранги и постройки за банк (только глава и офицеры), магазин за медали.


func _setup(role: String) -> AllianceSystem:
	fresh({"level": 20, "coins": 1000000})
	var al := Game.alliance
	al.demo = true
	al.busy = false
	al.data = {"id": 7, "name": "T", "tag": "T", "emblem": 0, "xp": 100000, "talents": {}, "role": role, "day": {}}
	Game.save["alliance"] = {"id": 7, "name": "T", "tag": "T", "emblem": 0, "talents": {}}
	al.bank = {"bank": 0, "medals": 0, "buildings": {}, "buys": {}, "log": []}
	return al


func _teardown(al: AllianceSystem) -> void:
	al.demo = false
	al.bank = {}
	al.data = {}
	Game.save["alliance"] = {}


func test_numbers_match_server() -> void:
	eq(Alliances.BUILD_COSTS, [600, 1500, 3000, 5000, 8000], "как _al_build_cost")
	eq(int(Alliances.SHOP["keyCopper"]["price"]), 20, "как _al_shop_price")
	eq(int(Alliances.SHOP["keyStar"]["limit"]), 1, "как _al_shop_limit")
	eq(Alliances.medals_for("gems", 0), 3)
	eq(Alliances.medals_for("free", 5), 2, "Сокровищница 5 ур. - +50%")
	eq(Alliances.rank_cost("harvest", 0), Alliances.points_for("harvest", 1))
	eq(Alliances.rank_cost("harvest", Alliances.talent_max("harvest")), 0, "максимум - больше не купить")


func test_give_fills_bank_and_medals() -> void:
	var al := _setup("member")
	Game.shop.add_crystals(100)
	al.give("free")
	al.give("gems")
	eq(al.bank_points(), 2)
	eq(al.medals(), 4)
	eq(al.day_used("free"), 1)
	_teardown(al)


func test_spend_only_leader() -> void:
	var al := _setup("member")
	al.bank["bank"] = 10000
	al.bank_talent("harvest")
	eq(int(al.data["talents"].get("harvest", 0)), 0, "участник не тратит банк")
	al.data["role"] = "officer"
	al.bank_talent("harvest")
	eq(al.rank("harvest"), 1, "офицер купил ранг")
	eq(al.bank_points(), 10000 - Alliances.points_for("harvest", 1))
	al.bank_build("granary")
	eq(al.building("granary"), 1)
	eq(al.bank_points(), 10000 - Alliances.points_for("harvest", 1) - Alliances.build_cost(1))
	eq((al.bank["log"] as Array).size(), 2, "траты в журнале")
	_teardown(al)


func test_granary_and_barracks() -> void:
	var al := _setup("leader")
	var base := Game.stats.yield_multiplier("wheat")
	al.bank["bank"] = 100000
	al.bank_build("granary")
	near(Game.stats.yield_multiplier("wheat") - base, Alliances.build_bonus("granary", 1), 0.0001, "амбар - ко всей добыче")
	var p0 := Game.war.attack_power()
	al.bank_build("barracks")
	check(Game.war.attack_power() > p0, "казарма усиливает удар")
	for i in 10:
		al.bank_build("walls")
	eq(al.building("walls"), Alliances.BUILD_MAX, "не выше предела")
	_teardown(al)
	Game.recalc()


func test_shop() -> void:
	var al := _setup("member")
	al.bank["medals"] = 1000
	var keys := Game.chests.keys("copper")
	for i in 10:
		al.shop_buy("keyCopper")
	eq(al.shop_bought("keyCopper"), int(Alliances.SHOP["keyCopper"]["limit"]), "лимит в неделю")
	eq(al.medals(), 1000 - 20 * int(Alliances.SHOP["keyCopper"]["limit"]))
	eq(Game.chests.keys("copper"), keys + int(Alliances.SHOP["keyCopper"]["limit"]), "ключи выданы")
	al.bank["medals"] = 10
	check(not al.can_shop("keySilver"), "медалей мало")
	_teardown(al)
