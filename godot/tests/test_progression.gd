extends "res://tests/test_case.gd"
## Уровень, опыт и награды за уровень.


func test_new_player() -> void:
	eq(Game.level, 1, "уровень нового игрока")
	eq(Game.save["coins"], 30, "монеты нового игрока")
	eq(Game.save["current"], "meadow", "стартовая локация")
	eq(Game.stats.capacity, Game.capacity_at(1), "рюкзак нового игрока")


func test_xp_curve_grows() -> void:
	eq(Game.xp_to_next(1), 25, "опыт до 2 уровня")
	for lvl in range(1, Game.MAX_LEVEL):
		if not check(Game.xp_to_next(lvl + 1) > Game.xp_to_next(lvl), "опыт до уровня %d не растёт" % (lvl + 1)):
			return


func test_gain_xp_levels_up_and_pays() -> void:
	var levels: Array = []
	var cb := func(from: int, to: int) -> void: levels.append([from, to])
	Game.level_up.connect(cb)
	var coins := int(Game.save["coins"])
	Game.gain_xp(Game.xp_to_next(1))
	Game.level_up.disconnect(cb)
	eq(Game.level, 2, "уровень после опыта")
	eq(Game.save["xp"], 0, "остаток опыта")
	eq(levels, [[1, 2]], "сигнал level_up")
	check(int(Game.save["coins"]) >= coins + Game.level_coin_reward(1), "награда монетами за уровень")
	eq(Game.save["bestLevel"], 2, "лучший уровень")


func test_gain_xp_several_levels_at_once() -> void:
	var need := Game.xp_to_next(1) + Game.xp_to_next(2) + Game.xp_to_next(3)
	Game.gain_xp(need + 5)
	eq(Game.level, 4)
	eq(Game.save["xp"], 5, "остаток опыта")


func test_xp_multiplier_applies() -> void:
	Game.stats.xp_mult = 2.0
	Game.gain_xp(10)
	eq(Game.save["xp"], 20)


func test_max_level_stops_xp() -> void:
	set_level(Game.MAX_LEVEL)
	Game.gain_xp(1_000_000)
	eq(Game.level, Game.MAX_LEVEL, "уровень не выше максимума")
	check(int(Game.save["xp"]) < Game.mastery_xp(), "остаток опыта меньше очка мастерства")
	check(Game.level_progress >= 0.0 and Game.level_progress < 1.0, "полоска показывает мастерство")


## После последнего уровня опыт превращается в очки мастерства, а они - в очки талантов.
func test_max_level_xp_gives_mastery() -> void:
	set_level(Game.MAX_LEVEL)
	var talents := Game.talents.points_total()
	Game.gain_xp(Game.mastery_xp() * 3)
	eq(Game.mastery_points(), 3, "очки мастерства")
	eq(Game.save["xp"], 0, "остаток опыта")
	eq(Game.talents.points_total(), talents + 3, "мастерство добавляет очки талантов")


func test_zero_or_negative_xp_ignored() -> void:
	Game.gain_xp(0)
	Game.gain_xp(-50)
	eq(Game.save["xp"], 0)
	eq(Game.level, 1)


func test_level_up_restores_half_energy() -> void:
	Game.save["energy"]["value"] = 10.0
	Game.gain_xp(Game.xp_to_next(1))
	var mx := Game.energy.max_value()
	check(absf(Game.energy.value() - minf(mx, 10.0 + mx * EnergySystem.LEVEL_UP_SHARE)) < 0.01, "после нового уровня - половина запаса сверху")


func test_level_up_never_lowers_energy() -> void:
	var mx := Game.energy.max_value()
	Game.save["energy"]["value"] = mx * 1.5
	Game.gain_xp(Game.xp_to_next(1))
	check(Game.energy.value() >= mx * 1.5 - 0.01, "переполнение энергии не срезается")
