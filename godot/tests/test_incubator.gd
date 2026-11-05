extends "res://tests/test_case.gd"
## Инкубатор и Гнездо: яйца, таймер, вылупление, гибриды, наследование окраски.


func test_pools_not_empty() -> void:
	for lvl in [Incubator.MIN_LEVEL, 20, 60]:
		for r in Incubator.RARITIES:
			var pool := Incubator.pool(r, lvl)
			check(not pool.is_empty(), "из яйца %s на уровне %d кто-то вылупляется" % [r, lvl])
			for id in pool:
				check(str(id) in Animals.IDS, "%s - известный зверь" % id)
				check(not Animals.is_premium(str(id)), "платный зверь %s не вылупляется" % id)


func test_tables_cover_rarities() -> void:
	for r in Incubator.RARITIES:
		check(Incubator.HOURS.has(r) and Incubator.STARS.has(r) and Incubator.SHINY.has(r) and Incubator.CRYSTALS.has(r),
			"у редкости %s заданы все таблицы" % r)
		check(r in Chests.RARITIES, r + " - редкость сундуков")
	for i in Incubator.RARITIES.size() - 1:
		var a: String = Incubator.RARITIES[i]
		var b: String = Incubator.RARITIES[i + 1]
		check(Incubator.hours(a) <= Incubator.hours(b), "редкое яйцо высиживается не быстрее обычного")


func test_hybrids_are_animals() -> void:
	for h in Incubator.HYBRIDS:
		check(h in Animals.IDS, h + " в списке зверей")
		check(Animals.is_hybrid(h), h + " - гибрид")
		eq(Animals.from(h), h, "гибрид не теряется при загрузке")
		check(not Animals.effects(h).is_empty(), h + ": есть эффекты")
		for e in Animals.effects(h):
			if e.get("type") == "produce":
				check(str(e["kind"]) in Res.KINDS, "%s даёт известный ресурс" % h)
		var rec := Incubator.recipe_of(h)
		eq(rec.size(), 2, h + ": два родителя")
		for p in rec:
			check(p in Animals.IDS and not Animals.is_hybrid(p), "родитель %s - обычный зверь" % p)
		eq(Incubator.hybrid_of(rec[0], rec[1]), h)
		eq(Incubator.hybrid_of(rec[1], rec[0]), h, "порядок родителей не важен")
		check(L.t("animal." + h) != "animal." + h, h + ": есть имя")
	eq(Incubator.hybrid_of("chicken", "cow"), "")


func test_hybrid_survives_save() -> void:
	set_level(20)
	Game.animals.add_star("pegasus", 2)
	Game.animals.mark_shiny("pegasus")
	var copy: Dictionary = JSON.parse_string(JSON.stringify(Game.save))
	for sys in Game.systems:
		sys.defaults(copy)
	eq(int(copy["animals"].get("pegasus", 0)), 2, "звёзды гибрида сохраняются")
	check("pegasus" in copy["shiny"], "окраска гибрида сохраняется")


func test_add_egg_and_cap() -> void:
	set_level(Incubator.MIN_LEVEL)
	Game.save["crystals"] = 0
	for i in Incubator.MAX_EGGS:
		Game.incubator.add_egg("green", "", 0.0, false)
	eq(Game.incubator.eggs().size(), Incubator.MAX_EGGS)
	Game.incubator.add_egg("blue", "", 0.0, false)
	eq(Game.incubator.eggs().size(), Incubator.MAX_EGGS, "запас не растёт сверх предела")
	eq(int(Game.save["crystals"]), int(Incubator.CRYSTALS["blue"]), "лишнее яйцо - кристаллы")
	Game.incubator.add_egg("nonsense", "", 0.0, false)
	eq(Game.incubator.eggs().size(), Incubator.MAX_EGGS, "неизвестная редкость не добавляется")


func test_incubate_timer_and_hatch() -> void:
	set_level(Incubator.MIN_LEVEL - 1)
	Game.incubator.add_egg("blue", "", 0.0, false)
	check(not Game.incubator.incubate(0), "до уровня инкубатор закрыт")
	set_level(Incubator.MIN_LEVEL)
	check(Game.incubator.incubate(0), "яйцо в инкубаторе")
	check(Game.incubator.eggs().is_empty(), "яйцо ушло из запаса")
	check(Game.incubator.busy() and not Game.incubator.ready())
	near(Game.incubator.time_left(), Incubator.hours("blue") * 3600.0, 2.0, "таймер по редкости")
	check(Game.incubator.hatch().is_empty(), "раньше времени не вылупляется")
	Game.incubator.add_egg("green", "", 0.0, false)
	check(not Game.incubator.incubate(0), "второе яйцо не помещается")
	Clock.offset = Incubator.hours("blue") * 3600.0 + 1.0
	check(Game.incubator.ready(), "время вышло")
	var out := Game.incubator.hatch()
	check(not out.is_empty(), "вылупился")
	check(Game.animals.stars(str(out["animal"])) > 0, "зверь появился у игрока")
	check(not Game.incubator.busy(), "инкубатор свободен")


func test_speed_up_costs_crystals() -> void:
	set_level(Incubator.MIN_LEVEL)
	Game.incubator.add_egg("red", "", 0.0, false)
	Game.incubator.incubate(0)
	var price := IncubatorSystem.speed_price(Game.incubator.time_left())
	eq(price, int(ceil(Incubator.hours("red") * 60.0 / Incubator.SPEED_MINUTES)), "кристалл за каждые 10 минут")
	Game.save["crystals"] = price - 1
	check(not Game.incubator.speed_up(), "без кристаллов не ускорить")
	Game.save["crystals"] = price
	check(Game.incubator.speed_up())
	eq(int(Game.save["crystals"]), 0)
	check(Game.incubator.ready())
	eq(IncubatorSystem.speed_price(30.0), 1, "минимум один кристалл")


func test_roll_gives_stars_and_shiny() -> void:
	var rainbow := IncubatorSystem.roll({"r": "rainbow", "a": "", "s": 0.0}, 60)
	check(bool(rainbow["shiny"]), "радужное яйцо - всегда редкая окраска")
	eq(int(rainbow["stars"]), 3)
	var hybrid := IncubatorSystem.roll({"r": "gold", "a": "honeyToad", "s": 0.0}, 10)
	eq(str(hybrid["animal"]), "honeyToad", "из яйца гибрида - гибрид")
	var shiny := 0
	for i in 400:
		if bool(IncubatorSystem.roll({"r": "green", "a": "", "s": 0.5}, 10)["shiny"]):
			shiny += 1
	between(shiny, 140, 260, "унаследованный шанс 50%")


func test_give_at_max_stars_gives_crystals() -> void:
	Game.save["crystals"] = 0
	Game.save["animals"]["chicken"] = Animals.MAX_STARS
	var out := {"animal": "chicken", "stars": 1, "shiny": false, "rarity": "gold", "new": false, "crystals": 0}
	Game.incubator.give(out)
	eq(Game.animals.stars("chicken"), Animals.MAX_STARS)
	eq(int(out["crystals"]), int(Incubator.CRYSTALS["gold"]), "вместо звезды кристаллы")
	eq(int(Game.save["crystals"]), int(Incubator.CRYSTALS["gold"]))


func test_nest_egg_inheritance() -> void:
	var plain := IncubatorSystem.nest_egg("chicken", "cow", false, false)
	eq(str(plain["r"]), "blue")
	eq(str(plain["a"]), "")
	near(float(plain["s"]), 0.0)
	var one := IncubatorSystem.nest_egg("horse", "swan", true, false)
	eq(str(one["r"]), "gold", "пара по рецепту - золотое яйцо")
	eq(str(one["a"]), "pegasus")
	near(float(one["s"]), 0.25, 0.0001, "один редкий родитель")
	near(float(IncubatorSystem.nest_egg("frog", "bee", true, true)["s"]), 0.5, 0.0001, "оба редкие")


func test_breed_flow() -> void:
	set_level(20)
	check(not Game.incubator.can_breed("horse", "swan"), "без зверей нельзя")
	Game.save["animals"]["horse"] = 3
	Game.save["animals"]["swan"] = 2
	check(not Game.incubator.can_breed("horse", "swan"), "нужно от трёх звёзд")
	Game.save["animals"]["swan"] = 3
	check(not Game.incubator.can_breed("horse", "horse"), "зверя нельзя скрестить с собой")
	check(Game.incubator.breed("horse", "swan"))
	check(not Game.incubator.breed("horse", "swan"), "гнездо занято")
	check(Game.incubator.collect_nest().is_empty(), "яйцо ещё не готово")
	Clock.offset = Incubator.NEST_SECONDS + 1.0
	check(Game.incubator.nest_ready())
	eq(Game.incubator.ready_count(), 1, "отметка на вкладке")
	var egg := Game.incubator.collect_nest()
	eq(str(egg["a"]), "pegasus")
	eq(Game.incubator.eggs().size(), 1, "яйцо в запасе")
	check(not Game.incubator.nesting(), "гнездо свободно")
	check(Game.animals.stars("horse") == 3 and Game.animals.stars("swan") == 3, "родители остаются у игрока")


func test_mine_gives_eggs() -> void:
	set_level(20)
	Game.incubator.on_event("mine", {"floor": 2})
	eq(Game.incubator.eggs().size(), 0)
	Game.incubator.on_event("mine", {"floor": 3})
	eq(Game.incubator.eggs().size(), 1, "каждый третий этаж - яйцо")
	eq(Incubator.mine_egg(3), "green")
	eq(Incubator.mine_egg(15), "blue")
	eq(Incubator.mine_egg(45), "purple")


func test_bad_save_is_cleaned() -> void:
	var save := {"incubator": {"eggs": [{"r": "gold", "a": "pegasus", "s": 5.0}, {"r": "xxx"}, 7, {"r": "blue", "a": "dragon"}],
		"slot": {"egg": {"r": "nope"}, "until": 1.0}, "nest": {"a": "chicken", "b": "dragon", "until": 0}, "found": ["pegasus", "pegasus", "x"]}}
	Game.incubator.defaults(save)
	var inc: Dictionary = save["incubator"]
	eq(inc["eggs"].size(), 2, "плохие яйца отброшены")
	near(float(inc["eggs"][0]["s"]), 1.0, 0.0001, "шанс в пределах")
	eq(str(inc["eggs"][1]["a"]), "", "неизвестный гибрид сброшен")
	check(inc["slot"].is_empty())
	check(inc["nest"].is_empty())
	eq(inc["found"], ["pegasus"])


func test_chest_egg_reward() -> void:
	set_level(20)
	var r := {"type": "egg", "kind": "purple", "n": 1, "rarity": "purple", "stars": 1}
	Game.chests.give(r)
	eq(Game.incubator.eggs().size(), 1, "яйцо из сундука")
	eq(ChestSystem.reward_icon(r), "egg:purple")
