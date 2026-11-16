extends "res://tests/test_case.gd"
## Турнир зверей: шансы поединков, отряд, дорожка наград и пропуск.


func test_duel_chance() -> void:
	check(absf(Tourney.duel_chance(100, 100) - 0.5) < 0.001, "равные звери - пополам")
	check(Tourney.duel_chance(200, 100) > 0.65, "вдвое сильнее - заметно чаще")
	eq(Tourney.duel_chance(0, 50), 0.0)
	eq(Tourney.duel_chance(50, 0), 1.0)


func test_tiers_and_rewards() -> void:
	eq(Tourney.tiers_open(0), 0)
	eq(Tourney.tiers_open(12), 2)
	eq(Tourney.tiers_open(10000), Tourney.TRACK.size())
	var last := Tourney.tier_reward(Tourney.TRACK.size() - 1, true, 20)
	eq(int(last["crystals"]), 300)
	eq(int(last["star"]), 1)
	check(int(Tourney.tier_reward(5, false, 30)["coins"]) > int(Tourney.tier_reward(5, false, 10)["coins"]))
	check(int(Tourney.place_reward(1, 10)["crystals"]) > int(Tourney.place_reward(5, 10)["crystals"]))
	eq(int(Tourney.place_reward(500, 10)["crystals"]), 0, "вне сотни - только монеты")


func test_squad() -> void:
	fresh({"level": 20, "animals": {"cow": 3, "chicken": 1, "pig": 2, "sheep": 1}})
	var t := Game.tourney
	var sq := t.squad()
	eq(sq.size(), 3)
	eq(sq[0], "cow", "без выбора - самые сильные")
	t.set_slot(2, "sheep")
	eq(t.squad()[2], "sheep")
	t.set_slot(0, "sheep")
	eq(t.squad()[0], "sheep", "зверь из отряда меняется местами")
	eq(t.squad()[2], "cow")
	t.set_slot(1, "unicornX")
	check(not "unicornX" in t.squad(), "чужого зверя нельзя")


func test_track_and_pass() -> void:
	fresh({"level": 20, "animals": {"cow": 3}})
	var t := Game.tourney
	t.state = {"week": DailySystem.week_index(), "points": 13, "fights_left": 0, "buys_left": 2}
	eq(t.ready_count(), 2, "две бесплатные ступени")
	check(not t.can_claim_tier(0, true), "платная без пропуска закрыта")
	var coins := int(Game.save["coins"])
	t.claim_tier(0, false)
	check(int(Game.save["coins"]) > coins)
	check(not t.can_claim_tier(0, false), "второй раз не выдаётся")
	Game.premium.grant("tourneyPass", "t1")
	check(t.has_pass())
	var gems := Game.shop.crystals()
	t.claim_tier(1, true)
	eq(Game.shop.crystals(), gems + int(Tourney.tier_reward(1, true, 20)["crystals"]))
	# Новая неделя - дорожка и пропуск с нуля
	t.state["week"] = DailySystem.week_index() + 1
	check(not t.has_pass())
	check(not t.tier_claimed(0, false))
	t.state = {}


func test_sql_matches() -> void:
	var path := ProjectSettings.globalize_path("res://").path_join("../docs/supabase/tourney.sql")
	var sql := FileAccess.get_file_as_string(path)
	check(sql.contains("select %d $$;" % Tourney.FREE_FIGHTS), "бесплатные бои как в игре")
	check(sql.contains("_tn_max_buys() returns int language sql immutable as $$ select %d" % Tourney.MAX_BUYS))
	check(sql.contains("power(ap, %s)" % str(Tourney.DUEL_EXP)), "шанс поединка как в игре")
