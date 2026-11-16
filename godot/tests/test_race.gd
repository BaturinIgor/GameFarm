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
	eq(run.behind(1000.0 + 250.0), 3, "лидер прошёл трое ворот")
	eq(run.beacon_left(1000.0 + 250.0), 0.0, "маяк лидера уже погас")
	var total := 0
	for i in 200:
		total += run.gather("wood", 2, 1000.0 + 250.0)
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


func test_bots_same_for_every_seat() -> void:
	# Странник на месте 3 одинаков у игроков с мест 0 и 1 одной комнаты
	var a := RaceRun.create(0, 0.0, 777, "A")
	var b := RaceRun.create(1, 0.0, 777, "B")
	var found := 0
	for x in a.d["bots"]:
		for y in b.d["bots"]:
			if int(x["seat"]) == int(y["seat"]):
				eq(str(x["name"]), str(y["name"]), "имя странника совпадает")
				near(float(x["pace"]), float(y["pace"]), 0.001, "темп странника совпадает")
				found += 1
	eq(found, 2, "общие места - 2 и 3")


func test_mark_times() -> void:
	var run := _run(0, 1000.0)
	run.d["gates"][0] = true
	run.mark(1003.0)
	eq(run.d["times"], [10.0], "этап раньше 10 с записан как 10 с")
	run.d["shards"][0] = true
	run.d["gates"][1] = true
	run.mark(1200.0)
	eq(run.d["times"], [10.0, 200.0, 200.0], "два этапа за раз - одно время")
	run.mark(1300.0)
	eq(run.d["times"].size(), 3, "без новых этапов ничего не добавилось")


func _human(run: RaceRun, seat: int, times: Array, age: float, done: bool, now: float) -> void:
	run.apply_humans([{"seat": seat, "name": "Masha", "skin": "", "times": times, "age": age, "done": done}], now)


func test_human_rival_replaces_bot() -> void:
	var run := _run(0, 0.0)
	var seat := int(run.d["bots"][0]["seat"])
	check(run.apply_humans([{"seat": seat, "name": "Masha", "skin": "", "times": [30, 90], "age": 100, "done": false}], 100.0),
		"живой соперник встал на место странника")
	var b: Dictionary = run.d["bots"][0]
	eq(str(b["name"]), "Masha", "имя живого")
	eq(RaceRun.bot_steps(b, 60.0), 1, "к 60 с у живого один этап")
	eq(RaceRun.bot_steps(b, 100.0), 2, "к 100 с - два")
	eq(RaceRun.bot_gates(b, 100.0), 1, "ворота живого по этапам")
	between(RaceRun.bot_fraction(b, 100.0), float(Race.BOT_STEPS[1]), float(Race.BOT_STEPS[2]), "живой на поле между этапами")
	var rows := run.standings(100.0)
	for r in rows:
		if str(r["name"]) == "Masha":
			check(not bool(r["bot"]), "в таблице живой не странник")


func test_result_waits_for_humans() -> void:
	var run := _run(0, 0.0)
	run.d["room"] = 5
	var seat := int(run.d["bots"][0]["seat"])
	for i in 3:
		run.d["gates"][i] = true
		run.d["shards"][i] = true
	check(run.finish(500.0), "дошёл за 500 с")
	# Соперник вошёл на 30 с позже: его гонке 470 с, он ещё может прийти быстрее
	_human(run, seat, [40, 100, 160, 220, 280, 340], 470.0, false, 500.0)
	check(run.ended(500.0), "мой путь окончен")
	check(not run.decided(500.0), "итог ждёт соперника")
	check(not run.decided(520.0), "через 20 с его гонке 490 с - ещё ждём")
	check(run.decided(531.0), "его гонке больше 500 с - обогнать уже не может")
	eq(run.place(531.0), 1, "я первый среди дошедших к 500 с")
	_human(run, seat, [40, 100, 160, 220, 280, 340, 480], 490.0, true, 520.0)
	check(run.decided(520.0), "соперник дошёл - итог известен")
	eq(run.place(520.0) > 1, true, "соперник дошёл быстрее (480 с) - я ниже")


func test_result_without_network() -> void:
	var run := _run(0, 0.0)
	run.d["room"] = 5
	_human(run, int(run.d["bots"][0]["seat"]), [40], 0.0, false, 10.0)
	# Соперник вошёл на 10 с позже меня, связи больше нет
	check(not run.decided(float(Race.DURATION) + 1.0), "сразу после конца ждём соперника")
	check(run.decided(float(Race.DURATION + Race.RESULT_WAIT)), "без связи итог через RESULT_WAIT")


func test_save_keeps_online_fields() -> void:
	var run := _run(0, 0.0)
	run.d["room"] = 9
	run.d["times"] = [12.5, 40.0]
	_human(run, int(run.d["bots"][1]["seat"]), [20, 50], 60.0, false, 60.0)
	var back := RaceRun.from_save(JSON.parse_string(JSON.stringify(run.d)))
	eq(back.room(), 9, "комната сохранилась")
	eq(back.d["times"], [12.5, 40.0], "свои этапы сохранились")
	eq(RaceRun.bot_steps(back.d["bots"][1], 60.0), 2, "ход живого сохранился")


func test_beacon_speeds_up_gathering() -> void:
	var run := _run(0, 0.0)
	for b in run.d["bots"]:
		b["pace"] = 2000.0
	run.d["bots"][1]["pace"] = 400.0
	near(run.beacon_at(), 400.0, 0.001, "маяк зажёг первый дошедший")
	eq(run.beacon_left(399.0), 0.0, "до его финиша маяка нет")
	near(run.beacon_left(450.0), Race.BEACON_TIME - 50.0, 0.001, "после - горит BEACON_TIME")
	eq(run.beacon_left(400.0 + Race.BEACON_TIME + 1.0), 0.0, "и гаснет")
	run.d["gates"] = [true, true, true]
	var total := 0
	for i in 200:
		total += run.gather("wood", 2, 450.0)
	between(float(total) / 200.0, 2.0 * (1.0 + Race.BEACON_BOOST) - 0.15, 2.0 * (1.0 + Race.BEACON_BOOST) + 0.15, "добыча быстрее под маяком")
	check(not run.lit_beacon(), "я его не зажигал")
	run.d["shards"] = [true, true, true]
	check(run.finish(300.0), "я дошёл раньше всех")
	check(run.lit_beacon(), "значит, маяк мой")
	eq(run.beacon_left(450.0), 0.0, "дошедшему ускорение не нужно")


func test_cheer_the_one_behind() -> void:
	var run := _run(0, 0.0)
	for b in run.d["bots"]:
		b["pace"] = 5000.0
	check(not run.can_cheer(10.0), "никто не отстаёт - некого подбодрить")
	run.d["gates"] = [true, false, false]
	eq(run.cheer_kind(), "", "сумка пуста - нечем")
	run.d["bag"] = {"wood": 12, "stone": 3}
	check(run.can_cheer(10.0), "теперь можно")
	var c := run.cheer(10.0)
	check(not c.is_empty(), "подбодрил")
	eq(str(c["kind"]), "wood", "делюсь тем, чего больше")
	eq(run.have("wood"), 12 - Race.CHEER_COST, "ресурсы ушли")
	eq(run.cheers(), 1, "очко дружбы")
	run.d["bag"]["wood"] = 100
	run.cheer(10.0)
	run.cheer(10.0)
	check(run.cheer(10.0).is_empty(), "не больше CHEER_MAX за гонку")
	eq(run.cheers(), Race.CHEER_MAX, "очков дружбы - CHEER_MAX")


func test_gifts_arrive_once() -> void:
	var run := _run(2, 0.0)
	var food := str(Race.FOOD[run.biome])
	eq(run.receive_gifts(2), 2, "два подарка")
	eq(run.have(food), 2 * Race.CHEER_COST, "еда своего угла в сумке")
	eq(run.receive_gifts(2), 0, "повторно не кладём")
	eq(run.receive_gifts(3), 1, "новый - один")


func test_friend_trophies_on_claim() -> void:
	fresh({"level": Race.MIN_LEVEL})
	var r := Game.race
	var run := r.start(3)
	run.d["cheers"] = 2
	Clock.offset = Race.DURATION + Race.RESULT_WAIT + 5
	var got := r.claim()
	eq(int(got["friend"]), 2, "очки дружбы в итоге")
	eq(r.trophies(), int(Race.TROPHIES[int(got["place"]) - 1]) + 2, "по трофею за каждое")


func test_ad_flags_per_day() -> void:
	fresh({"level": Race.MIN_LEVEL})
	var r := Game.race
	Game.save["raceFlags"]["n"] = 0
	for i in Race.AD_FLAGS:
		r.ad_flag()
	eq(r.ad_flags_left(), 0, "за рекламу - не больше AD_FLAGS в день")
	r.ad_flag()
	eq(int(Game.save["raceFlags"]["n"]), Race.AD_FLAGS, "лишний ролик флажка не даёт")
	Clock.offset = 86400 + 5
	eq(r.ad_flags_left(), Race.AD_FLAGS, "назавтра снова можно")


func test_rating_prizes() -> void:
	eq(Race.day_prize(1), Race.DAY_PRIZES[0], "1 место дня")
	eq(Race.day_prize(10), Race.DAY_PRIZES[3], "10 место дня")
	eq(Race.day_prize(11), 0, "11 место дня без награды")
	eq(Race.month_prize(2), Race.MONTH_PRIZES[1], "2 место месяца")
	eq(Race.month_prize(100), Race.MONTH_PRIZES[4], "100 место месяца")
	eq(Race.month_prize(101), 0, "101 - без награды")
	eq(Race.month_title(3), "champion", "титул чемпиона")
	eq(Race.month_title(42), "top100", "титул топ-100")
	eq(Race.month_label(2026 * 12 + 10), "11.2026", "месяц сервера")
	eq(Race.day_label(20772), "15.11", "день сервера")
	fresh({"level": Race.MIN_LEVEL})
	var crystals := Game.shop.crystals()
	Game.race.grant_prize({"period": "month", "key": 2026 * 12 + 10, "place": 5})
	eq(Game.shop.crystals(), crystals + Race.month_prize(5), "кристаллы за месяц")
	eq(Race.month_title(int(Game.race.best_title()["p"])), "medalist", "титул сохранён")


func test_game_center_race() -> void:
	fresh({"level": Race.MIN_LEVEL})
	check(not GCenter.earned("race.win_1"), "без побед достижения нет")
	Game.save["raceStats"]["places"][0] = 1
	check(GCenter.earned("race.win_1"), "первая победа")
	check("race.win_1" in GCenter.pending_achievements(), "уйдёт в Game Center")
	Game.save["raceStats"]["trophies"] = 800
	check(GCenter.earned("race.league_3"), "золотая лига")
	eq(GCenter.score("race_trophies"), 800, "таблица трофеев")


func test_bots_faster_in_high_league() -> void:
	var low := RaceRun.create(0, 0.0, 777, "Me", 0)
	var high := RaceRun.create(0, 0.0, 777, "Me", 5)
	for i in low.d["bots"].size():
		near(float(high.d["bots"][i]["pace"]), float(low.d["bots"][i]["pace"]) * float(Race.LEAGUE_PACE[5]), 0.01,
			"в Алмазной лиге странник быстрее")


func test_ad_doubles_reward() -> void:
	fresh({"level": Race.MIN_LEVEL})
	var r := Game.race
	var run := r.start(3)
	run.d["shards"] = [true, true, true]
	run.d["gates"] = [true, true, true]
	for b in run.d["bots"]:
		b["pace"] = 900.0
	run.finish(Clock.now() + 10.0)
	var crystals := Game.shop.crystals()
	var got := r.claim(true)
	eq(int(got["place"]), 1, "первое место")
	eq(Game.shop.crystals(), crystals + 2 * Race.CRYSTALS[0], "кристаллы вдвое")
	eq(Game.chests.keys("silver"), 2, "и ключа два")
	eq(r.trophies(), Race.TROPHIES[0], "трофеи не удваиваются")


func test_racer_kit() -> void:
	fresh({"level": Race.MIN_LEVEL})
	check(not Game.race.has_kit(), "без покупки наряда нет")
	Game.premium.grant("racerKit")
	check(Game.race.has_kit(), "куплен")
	check(not Products.consumable("racerKit"), "покупается один раз")
