extends "res://tests/test_case.gd"
## Гонка к Сердцу долины: флажки, забег, ворота, торговец, осколки, места, награды и темп прохождения.


func _run(seat := 0, now := 1000.0) -> RaceRun:
	return RaceRun.create(seat, now, 12345 + seat, "Me")


func test_flags_spend_and_restore() -> void:
	fresh({"level": Race.MIN_LEVEL})
	var r := Game.race
	eq(r.flags(), Race.FLAGS_MAX, "полный запас флажков")
	check(r.start(7) != null, "гонка началась")
	eq(r.flags(), Race.FLAGS_MAX - 1, "флажок потрачен")
	check(not r.can_start(), "вторую гонку не начать, пока идёт первая")
	Clock.offset = Race.FLAG_EVERY + 5
	eq(r.flags(), Race.FLAGS_MAX, "флажок вернулся за час")


func test_locked_below_level() -> void:
	fresh({"level": Race.MIN_LEVEL - 1})
	check(not Game.race.can_start(), "до нужного уровня гонка закрыта")
	check(Game.race.start() == null, "старт не проходит")


func test_layout_same_for_all_seats() -> void:
	# У всех мест одинаковые расстояния от лагеря до ворот и Сердца
	var base := Race.camp_pos(0).distance_to(Race.gate_pos(0, 0))
	var heart := Race.camp_pos(0).distance_to(Race.heart_center())
	for s in Race.SEATS:
		near(Race.camp_pos(s).distance_to(Race.gate_pos(s, 0)), base, 0.5, "до ворот 1, место %d" % s)
		near(Race.camp_pos(s).distance_to(Race.heart_center()), heart, 0.5, "до Сердца, место %d" % s)
		eq(Race.cell_at(Race.camp_pos(s)), Race.CORNERS[s]["cell"], "лагерь в своём углу")
		for sp in Race.spots(s):
			var p: Vector2 = sp["pos"]
			check(Rect2(0, 0, Race.SIZE, Race.SIZE).has_point(p), "точка %s на карте" % sp["id"])
			check(p.distance_to(Race.heart_center()) > Race.HEART_R + 40.0, "точка %s не в Сердце" % sp["id"])
		# Ворота 1 и 2 на границе своих клеток
		for g in 2:
			var cells := Race.gate_cells(s, g)
			near(Race.gate_pos(s, g).distance_to(Race.cell_center(cells[0])), Race.TILE / 2.0, 0.5, "ворота %d на краю" % g)


func test_gather_sell_and_upgrade() -> void:
	var run := _run()
	run.d["bag"]["wood"] = 30
	var got := run.sell("wood", 30, 1000.0)
	check(got < 30 * int(Race.PRICES["wood"]), "цена падает при продаже подряд")
	check(got >= int(30 * Race.PRICES["wood"] * 0.8), "но не сильно на 30 единицах")
	check(run.price("wood", 1000.0) < float(Race.PRICES["wood"]), "сразу после продажи дешевле")
	near(run.price("wood", 1000.0 + 600.0), float(Race.PRICES["wood"]), 0.001, "за 10 минут цена вернулась")
	run.d["coins"] = Race.TOOL_PRICE[1]
	check(run.upgrade(), "инструмент 2")
	eq(run.tool(), 2, "ступень выросла")
	eq(run.coins(), 0, "монеты списаны")
	check(not run.upgrade(), "на 3 не хватает")


func test_sell_spare_keeps_gate_items() -> void:
	var run := _run(1)
	var food: String = Race.FOOD[run.biome]
	run.d["bag"] = {"wood": 40, food: 10, "stone": 22}
	run.sell_spare(1000.0)
	eq(run.have("wood"), 22, "дерево для ворот осталось")
	eq(run.have(food), 10, "еды меньше нужного - не продаётся")
	eq(run.have("stone"), 22, "камень для ворот остался")
	check(run.coins() > 0, "лишнее продано")


func test_gates_in_order_and_ways() -> void:
	var run := _run(2)
	check(not run.can_open(1, "coins"), "ворота 2 раньше первых не открыть")
	run.d["coins"] = 1000
	check(run.open_gate(0, "coins"), "ворота 1 за монеты")
	eq(run.coins(), 1000 - int(Race.GATES[0]["coins"]), "монеты списаны")
	run.d["bag"] = {"coal": 28, "iron": 28}
	check(run.open_gate(1, "items"), "ворота 2 за ресурсы")
	eq(run.have("coal"), 0, "уголь ушёл")
	var xp := int(run.d["xp"])
	check(run.open_gate(2, "guard"), "ворота 3 после победы над стражем")
	eq(int(run.d["xp"]), xp + int(Race.GUARDS[2]["xp"]), "опыт за стража")
	check(not run.can_finish(), "без осколков в Сердце не войти")


func test_shards_and_finish() -> void:
	var run := _run()
	check(not run.take_vein(0), "жила 1 требует инструмент 2")
	run.d["tool"] = 3
	check(run.take_vein(0) and run.take_vein(1), "обе жилы")
	check(not run.give_elder(), "старцу нечего отдать")
	run.d["bag"] = {"gold": 12, "diamond": 6}
	check(run.give_elder(), "осколок старца")
	eq(run.shards(), 3, "три осколка")
	for i in 3:
		run.d["gates"][i] = true
	check(run.finish(1000.0 + 500.0), "дошёл до центра")
	near(float(run.d["finish"]), 500.0, 0.01, "время финиша")
	check(run.decided(1000.0 + 501.0), "итог известен сразу")
	check(not run.finish(1000.0 + 600.0), "второй раз не финишировать")


func test_no_finish_after_time() -> void:
	var run := _run()
	run.d["tool"] = 3
	run.d["shards"] = [true, true, true]
	run.d["gates"] = [true, true, true]
	check(not run.finish(1000.0 + Race.DURATION + 1), "после конца времени финиша нет")
	check(run.decided(1000.0 + Race.DURATION), "время вышло - итог известен")


func test_places_finish_and_progress() -> void:
	var run := _run()
	for b in run.d["bots"]:
		b["pace"] = 600.0
	run.d["bots"][0]["pace"] = 400.0
	run.d["bots"][2]["pace"] = 2000.0
	# Финиш на 500-й секунде: впереди один странник
	run.d["tool"] = 3
	run.d["shards"] = [true, true, true]
	run.d["gates"] = [true, true, true]
	check(run.finish(1000.0 + 500.0), "финиш")
	eq(run.place(1000.0 + 900.0), 2, "второе место: один дошёл раньше")
	# Не дошёл: место по этапам
	var slow := _run()
	for b in slow.d["bots"]:
		b["pace"] = 5000.0
	slow.d["gates"] = [true, true, false]
	eq(slow.place(1000.0 + Race.DURATION), 1, "странники отстали по этапам")


func test_catch_up_bonus() -> void:
	var run := _run()
	for b in run.d["bots"]:
		b["pace"] = 100.0
	eq(run.behind(1000.0 + 200.0), 3, "лидер прошёл трое ворот")
	var total := 0
	for i in 200:
		total += run.gather("wood", 2, 1000.0 + 200.0)
	between(float(total) / 200.0, 2.0 * 1.45 - 0.15, 2.0 * 1.45 + 0.15, "+45% добычи при отставании на 3 ворот")


func test_guards_need_level() -> void:
	# Страж ворот побеждается на своём уровне и не побеждается уровнем ниже
	for i in Race.GUARDS.size():
		var g: Dictionary = Race.GUARDS[i]
		var need := int(Race.GATES[i]["guard"])
		check(_duel(need, g), "страж %d на уровне %d" % [i + 1, need])
		check(not _duel(need - 1, g), "страж %d сильнее уровня %d" % [i + 1, need - 1])


## Бой героя уровня lv со стражем: побеждает ли герой.
func _duel(lv: int, g: Dictionary) -> bool:
	var hero := float(Race.HERO_HP[lv - 1])
	var t := float(g["hp"]) / (float(Race.HERO_HIT[lv - 1]) / Race.HIT_EVERY)
	return float(g["dps"]) * t < hero


func test_claim_rewards_and_stats() -> void:
	fresh({"level": Race.MIN_LEVEL})
	var r := Game.race
	var run := r.start(3)
	run.d["tool"] = 3
	run.d["shards"] = [true, true, true]
	run.d["gates"] = [true, true, true]
	for b in run.d["bots"]:
		b["pace"] = 900.0
	check(r.claim().is_empty(), "пока гонка идёт, итога нет")
	run.finish(Clock.now() + 10.0)
	var crystals := Game.shop.crystals()
	var got := r.claim()
	eq(int(got["place"]), 1, "первое место")
	eq(r.trophies(), Race.TROPHIES[0], "трофеи")
	eq(int(r.places()[0]), 1, "статистика первых мест")
	eq(Game.shop.crystals(), crystals + Race.CRYSTALS[0], "кристаллы")
	eq(Game.chests.keys("silver"), 1, "серебряный ключ")
	check(not r.active(), "забег закрыт")
	check(not Game.save.has("raceRun"), "и убран из сохранения")


func test_save_roundtrip() -> void:
	fresh({"level": Race.MIN_LEVEL})
	var run := Game.race.start(5)
	run.d["bag"]["wood"] = 7
	Game.race.touch()
	var text := JSON.stringify(Game.save)
	var data: Dictionary = JSON.parse_string(text)
	Game.save = data
	Game.race.defaults(Game.save)
	check(Game.race.active(), "забег восстановлен")
	eq(Game.race.run().have("wood"), 7, "сумка на месте")
	eq(Game.race.run().seat, run.seat, "место на месте")


func test_league_reward_once() -> void:
	fresh({"level": Race.MIN_LEVEL})
	Game.save["raceStats"]["trophies"] = int(Race.LEAGUES[1]["from"]) - 3
	var run := Game.race.start(1)
	run.d["start"] = Clock.now() - Race.DURATION - 1
	for b in run.d["bots"]:
		b["pace"] = 100.0
	var got := Game.race.claim()
	eq(int(got["place"]), 4, "последнее место")
	eq(int(got["league"]), 1, "новая лига")
	eq(int(got["league_crystals"]), int(Race.LEAGUES[1]["crystals"]), "награда лиги")


## Темп: хороший игрок доходит до центра за 8-12 минут, странники укладываются в 15 минут кроме медленного.
func test_pace_of_good_player() -> void:
	var t := _simulate(0)
	between(t, 8.0 * 60.0, 12.0 * 60.0, "хороший игрок доходит за 8-12 минут (%d с)" % int(t))
	check(Race.BOT_PACES[0] < Race.DURATION and Race.BOT_PACES[1] < Race.DURATION, "быстрый и средний странник успевают")


## Прохождение по простой модели: подойти к точке ~2,5 с, удар раз в HIT_EVERY, торговец и ворота по 6 с.
func _simulate(seat: int) -> float:
	var run := RaceRun.create(seat, 0.0, 1, "Sim")
	run.d["bots"] = []
	var st := {"t": 0.0}
	var walk := 3.0
	var mine := func(node: String, kind: String) -> void:
		var n: Dictionary = Race.NODES[node]
		st["t"] += walk + float(run.hits_for(node)) * Race.HIT_EVERY
		run.gather(kind, (int(n["min"]) + int(n["max"])) / 2 + ((int(n["min"]) + int(n["max"])) % 2), st["t"])
		run.add_xp(int(n["xp"]))
	var defs: Array = Race.CORNER_NODES[run.biome]
	var gate0 := Race.gate_items(seat, 0)
	# Угол: ресурсы ворот и монеты на инструмент 2
	var i := 0
	while not run.has_items(gate0) or run.coins() + _spare_value(run, gate0, st["t"]) < Race.TOOL_PRICE[1]:
		var d: Array = defs[i % 3]
		mine.call("corner", d[1])
		i += 1
	st["t"] += 6.0
	run.sell_spare(st["t"])
	run.upgrade()
	st["t"] += 8.0 + float(int(ceil(Race.VEINS[0]["hp"] / run.power()))) * Race.HIT_EVERY
	run.take_vein(0)
	check(run.open_gate(0, "items"), "модель: ворота 1")
	st["t"] += 15.0
	# Перешеек: уголь и железо на ворота и инструмент 3
	var gate1 := Race.gate_items(seat, 1)
	i = 0
	while not run.has_items(gate1) or run.coins() + _spare_value(run, gate1, st["t"]) < Race.TOOL_PRICE[2]:
		mine.call("coal" if i % 2 == 0 else "iron", "coal" if i % 2 == 0 else "iron")
		i += 1
	st["t"] += 6.0
	run.sell_spare(st["t"])
	run.upgrade()
	st["t"] += 8.0 + float(int(ceil(Race.VEINS[1]["hp"] / run.power()))) * Race.HIT_EVERY
	run.take_vein(1)
	check(run.open_gate(1, "items"), "модель: ворота 2")
	st["t"] += 15.0
	# Ядро: старец и кристаллы
	var gate2 := Race.gate_items(seat, 2)
	i = 0
	while not run.has_items(Race.ELDER) and not run.shards() == 3:
		mine.call("gold" if i % 2 == 0 else "diamond", "gold" if i % 2 == 0 else "diamond")
		i += 1
	st["t"] += 6.0
	run.give_elder()
	while not run.has_items(gate2):
		mine.call("crystal", "crystal")
	check(run.open_gate(2, "items"), "модель: ворота 3")
	st["t"] += 10.0
	return st["t"]


func _spare_value(run: RaceRun, keep: Array, now: float) -> int:
	var total := 0
	for kind in run.d["bag"]:
		var spare := run.have(kind)
		for it in keep:
			if it[0] == kind:
				spare -= int(it[1])
		if spare > 0:
			total += int(float(spare) * run.price(kind, now) * 0.9)
	return total


func test_clock() -> void:
	eq(Race.clock(0.0), "0:00")
	eq(Race.clock(65.2), "1:06")
	eq(Race.clock(900.0), "15:00")
