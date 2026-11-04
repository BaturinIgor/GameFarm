extends "res://tests/test_case.gd"
## Поздняя игра: всё прокачано до конца. Потолки характеристик держатся, подсчёты не падают.


func _max_out() -> void:
	set_level(Game.MAX_LEVEL)
	Game.save["coins"] = 1_000_000_000
	Game.save["bonusTalentPoints"] = 10_000
	for id in Talents.ids():
		Game.save["talents"][id] = Talents.max_rank(id)
	for tool in Tools.UPGRADABLE:
		Game.save["tools"][tool] = Tools.MAX_TIER
	for id in Animals.IDS:
		Game.save["animals"][id] = Animals.MAX_STARS
		Game.save["awaken"][id] = 3
	Game.save["active"] = Animals.IDS.slice(0, Game.animals.max_active())
	for kind in Res.KINDS:
		Game.save["storage"][kind] = 500
	Game.recalc()


func test_stat_caps_hold() -> void:
	_max_out()
	var s := Game.stats
	check(s.speed <= Stats.BASE_SPEED * Stats.MAX_SPEED_MULT + 0.01, "скорость выше потолка: %s" % s.speed)
	check(s.xp_mult <= Stats.MAX_XP + 0.0001, "опыт выше потолка: %s" % s.xp_mult)
	check(s.sell_mult <= Stats.MAX_SELL + 0.0001, "продажа выше потолка: %s" % s.sell_mult)
	check(s.respawn_mult >= Stats.MIN_RESPAWN - 0.0001, "респаун быстрее потолка: %s" % s.respawn_mult)
	check(s.crit_chance <= 0.75 + 0.0001, "крит выше 75%%: %s" % s.crit_chance)
	check(s.capacity > 0, "рюкзак")
	for p in s.producers:
		check(float(p["interval"]) > 0.0, "интервал производителя")


func test_hp_and_defense_sane() -> void:
	_max_out()
	check(Game.workshop.max_hp() > 0.0, "здоровье героя")
	between(Game.workshop.dodge_chance(), 0.0, 0.9, "уклонение")
	check(Game.workshop.defense() < 1.0, "защита не делает неуязвимым")


func test_counters_dont_crash() -> void:
	_max_out()
	Game.workshop.upgradable_count()
	Game.animals.upgradable_count()
	Game.quests.claimable_count()
	Game.daily.claimable()
	Game.world_map.openable_gates()
	Game.estate.ready_count()
	Game.estate.tick()
	Game.shop.current_offers()
	check(Game.talents.points_free() >= 0)


func test_talent_tree_fits_max_level() -> void:
	# Сведения для баланса: сколько очков нужно на всё дерево и сколько даёт 60 уровень
	var need := 0
	for id in Talents.ids():
		need += Talents.max_rank(id) * Talents.cost(id)
	var have := Game.talent_points_at(Game.MAX_LEVEL)
	print("       talents: на всё дерево %d очков, к %d уровню - %d без бонусов" % [need, Game.MAX_LEVEL, have])
	check(need > 0)
