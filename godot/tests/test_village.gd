extends "res://tests/test_case.gd"
## Деревня альянса: уровни построек, украшения домика и набор за деньги.


func test_numbers() -> void:
	eq(Village.need(1), 200000)
	check(Village.need(10) > Village.need(9))
	eq(Village.bonus(3), 0.03)
	eq(Village.bonus(99), Village.BONUS_PER_LEVEL * Village.MAX_LEVEL)
	check(Village.donate_coins(500) <= 100000, "вклад не больше, чем принимает сервер")


func test_decos() -> void:
	fresh({"level": 20, "alliance": {"id": 5, "name": "A", "tag": "A", "emblem": 0, "talents": {}}, "crystals": 1000})
	var al := Game.alliance
	al.demo = true
	check(not al.buy_deco("goldStatue"), "украшение из набора за кристаллы не купить")
	check(al.buy_deco("fountain"))
	eq(Game.shop.crystals(), 1000 - Village.deco_price("fountain"))
	eq(al.shown_decos(), ["fountain"], "купленное сразу у домика")
	al.buy_deco("lantern")
	al.buy_deco("bench")
	al.buy_deco("flowers")
	eq(al.shown_decos().size(), Village.SHOWN, "у домика не больше трёх")
	al.toggle_deco("flowers")
	check(not "flowers" in al.shown_decos())
	al.demo = false


func test_pack_and_frame() -> void:
	fresh({"level": 20, "alliance": {"id": 5, "name": "A", "tag": "A", "emblem": 0, "talents": {}}})
	var al := Game.alliance
	al.demo = true
	check(not al.pick_frame("royal"), "королевскую рамку не купить")
	var gems := Game.shop.crystals()
	Game.premium.grant("villagePack", "")
	check("goldStatue" in al.owned_decos())
	check("royal" in al.owned_frames())
	eq(Game.shop.crystals(), gems + Village.PACK_CRYSTALS)
	check(al.pick_frame("royal"))
	al.demo = false


func test_bonus_in_stats() -> void:
	fresh({"level": 20, "alliance": {"id": 5, "name": "A", "tag": "A", "emblem": 0, "talents": {}}})
	var base := Game.stats.yield_all
	Game.save["villageLevels"] = {"mill": 5, "tower": 0, "well": 0}
	Game.recalc()
	check(absf(Game.stats.yield_all - base - 0.05) < 0.0001, "мельница даёт к добыче")
