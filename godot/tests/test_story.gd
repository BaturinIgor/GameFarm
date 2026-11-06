extends "res://tests/test_case.gd"
## Сердца земли: главы, страницы, дар, слуги Мглы, пробуждение, осколки, Алтарь и мифическое пробуждение.


func _fill_gift(ch: int) -> void:
	var g := Story.gift(ch)
	Game.save["coins"] = int(Game.save["coins"]) + int(g.get("coins", 0))
	for it in g.get("items", []):
		Game.save["storage"][str(it[0])] = int(Game.save["storage"].get(str(it[0]), 0)) + int(it[1])


func test_chapters_data() -> void:
	eq(Story.count(), 11)
	var seen := {}
	for ch in Story.count():
		var loc := Story.loc(ch)
		check(Locations.SPECS.has(loc), "глава %d: локация %s существует" % [ch + 1, loc])
		check(not seen.has(loc), "у каждой главы своя локация")
		seen[loc] = true
		for it in Story.gift(ch).get("items", []):
			check(str(it[0]) in Res.KINDS, "дар главы %d: известный ресурс %s" % [ch + 1, it[0]])
		check(Story.title(ch) != "heart.ch%d" % (ch + 1), "есть название главы")
		for p in Story.PAGES:
			check(Story.page_text(ch, p) != "heart.ch%d.p%d" % [ch + 1, p + 1], "есть текст страницы")
	eq(Story.ALTAR.size(), Story.ALTAR_COST.size(), "у каждой ступени алтаря есть цена")
	eq(Story.key_for(Story.count() - 1), "star", "финал даёт звёздный ключ")


func test_locked_before_level() -> void:
	set_level(Story.MIN_LEVEL - 1)
	check(not Game.story.chapter_open(), "до уровня раздела глава закрыта")
	for i in Story.PAGE_PITY + 1:
		Game.emit_event("gather", {"kind": "berries", "amount": 1})
	eq(Game.story.pages(), 0, "страницы не падают, пока раздел закрыт")


func test_full_chapter_flow() -> void:
	set_level(Story.MIN_LEVEL)
	Game.save["current"] = Story.loc(0)
	check(Game.story.chapter_open(), "первая глава открыта")
	check(not Game.story.can_awaken(), "сразу будить нельзя")
	# Страницы: гарантия не позже чем через PAGE_PITY добыч
	for i in Story.PAGES * Story.PAGE_PITY:
		Game.emit_event("gather", {"kind": "berries", "amount": 1})
	eq(Game.story.pages(), Story.PAGES, "три страницы найдены")
	# Слуги Мглы
	for i in Story.kills(0) + 3:
		Game.emit_event("kill", {"monster": "slime", "level": 1, "boss": false})
	eq(Game.story.kills(), Story.kills(0), "счётчик не растёт сверх нужного")
	# Дар
	Game.save["coins"] = 0
	Game.save["storage"] = {}
	Game.save["backpack"] = {}
	check(not Game.story.give_gift(), "без ресурсов дар не принести")
	# По частям: сначала только монеты, потом остальное
	Game.save["coins"] = int(Story.gift(0)["coins"])
	check(Game.story.give_gift(), "часть дара принесена")
	check(not Game.story.gift_given(), "дар ещё не весь")
	eq(int(Game.story.gift_left()["coins"]), 0, "монеты зачтены")
	_fill_gift(0)
	check(Game.story.give_gift(), "остаток дара принесён")
	check(Game.story.gift_given(), "дар принесён целиком")
	eq(int(Game.save["coins"]), int(Story.gift(0)["coins"]), "монеты второй раз не списаны")
	check(Game.story.can_awaken())
	var yield_before := Game.stats.yield_all
	var shards := Game.story.shards()
	var out := Game.story.awaken_heart()
	eq(int(out["shards"]), Story.SHARDS_PER_CHAPTER)
	eq(Game.story.shards(), shards + Story.SHARDS_PER_CHAPTER, "осколок за главу")
	eq(int(Game.save["chests"]["keys"].get("silver", 0)) >= 1, true, "серебряный ключ за главу")
	eq(Game.story.chapter(), 1, "следующая глава")
	eq(Game.story.pages(), 0, "страницы новой главы с нуля")
	near(Game.stats.yield_all - yield_before, Story.HEART_YIELD, 0.0001, "+2% добычи за Сердце")
	eq(Game.story.pages_total(), Story.PAGES, "прочитанные страницы считаются")


func test_kills_only_in_chapter_location() -> void:
	set_level(20)
	Game.save["current"] = "hills"
	Game.emit_event("kill", {"monster": "slime", "level": 1, "boss": false})
	eq(Game.story.kills(), 0, "монстры не в той локации не считаются")


func test_altar_raises_caps() -> void:
	set_level(Game.MAX_LEVEL)
	Game.save["shards"] = 100
	eq(Game.stats.cap_yield, 0.0)
	var spent := 0
	for i in Story.ALTAR.size():
		var price := Game.story.altar_price()
		check(Game.story.raise_altar(), "ступень %d поднята" % (i + 1))
		spent += price
	check(not Game.story.raise_altar(), "выше последней ступени нельзя")
	eq(Game.story.shards(), 100 - spent, "осколки списаны по ценам ступеней")
	var caps := Story.altar_caps(Story.ALTAR.size())
	near(Game.stats.cap_yield, float(caps["yield"]))
	near(Game.stats.cap_xp, float(caps["xp"]))
	near(Game.stats.cap_sell, float(caps["sell"]))
	near(Game.stats.cap_animal, float(caps["animal"]))
	# Потолок добычи действительно поднялся
	Game.stats.yield_all = 10.0
	near(Game.stats.yield_multiplier("berries"), Stats.MAX_YIELD + float(caps["yield"]), 0.0001, "новый потолок добычи")


func test_altar_needs_shards() -> void:
	Game.save["shards"] = 0
	check(not Game.story.can_raise_altar())
	check(not Game.story.raise_altar())
	eq(Game.story.altar(), 0)


func test_mythic_awaken_needs_shards() -> void:
	set_level(Game.MAX_LEVEL)
	Game.save["animals"]["chicken"] = Animals.MAX_STARS
	Game.save["awaken"]["chicken"] = Animals.AWAKEN_MAX - 1
	var cost := Game.animals.awaken_cost("chicken")
	check(int(cost.get("shards", 0)) > 0, "мифическое пробуждение просит осколки")
	Game.save["coins"] = int(cost.get("coins", 0))
	for it in cost.get("items", []):
		Game.save["storage"][str(it[0])] = int(it[1])
	Game.save["shards"] = 0
	check(not Game.animals.can_awaken("chicken"), "без осколков нельзя")
	Game.save["shards"] = int(cost["shards"])
	check(Game.animals.can_awaken("chicken"))
	Game.animals.awaken("chicken")
	eq(Game.animals.awaken_level("chicken"), Animals.AWAKEN_MAX)
	eq(Game.story.shards(), 0, "осколки списаны")
	eq(Game.animals.awaken_cost("chicken"), {}, "дальше пробуждать некуда")


func test_mine_floor_gives_shard() -> void:
	Game.save["shards"] = 0
	Game.emit_event("mine", {"floor": Story.MINE_SHARD_EVERY - 1})
	eq(Game.story.shards(), 0)
	Game.emit_event("mine", {"floor": Story.MINE_SHARD_EVERY})
	eq(Game.story.shards(), 1, "осколок на 25-м этаже")


func test_chest_shard_reward() -> void:
	Game.save["shards"] = 0
	var r := {"rarity": "red", "stars": 1, "type": "shard", "kind": "", "n": 1}
	Game.chests.give(r)
	eq(Game.story.shards(), 1, "осколок из сундука")
	check(ChestSystem.reward_text(r) != "", "подпись награды")


func test_save_roundtrip() -> void:
	Game.save["heart"] = {"ch": 3, "pages": 2, "pity": 5, "gift": true, "kills": 4}
	Game.save["shards"] = 7
	Game.save["altar"] = 2
	var copy: Dictionary = JSON.parse_string(JSON.stringify(Game.save))
	for sys in Game.systems:
		sys.defaults(copy)
	eq(int(copy["heart"]["ch"]), 3)
	eq(int(copy["heart"]["pages"]), 2)
	eq(bool(copy["heart"]["gift"]), true)
	eq(int(copy["shards"]), 7)
	eq(int(copy["altar"]), 2)
	# Испорченные значения не ломают загрузку
	var bad := {"heart": {"ch": 99, "pages": -3}, "shards": -5, "altar": 50}
	Game.story.defaults(bad)
	eq(int(bad["heart"]["ch"]), Story.count())
	eq(int(bad["heart"]["pages"]), 0)
	eq(int(bad["shards"]), 0)
	eq(int(bad["altar"]), Story.ALTAR.size())


func test_heart_gives_sparks() -> void:
	set_level(Story.MIN_LEVEL)
	Game.save["current"] = Story.loc(0)
	Game.save["heart"] = {"ch": 0, "pages": Story.PAGES, "pity": 0, "gift": true, "given": {}, "kills": Story.kills(0)}
	Game.save["sparks"] = 0
	check(Game.story.can_awaken())
	var out := Game.story.awaken_heart()
	eq(int(out["sparks"]), Story.sparks_for(0))
	eq(Game.legacy.sparks(), Story.sparks_for(0), "искры наследия за Сердце")


func test_rebirth_perks_refunded() -> void:
	# Перерождения нет: бонусы, которые работали только при нём, возвращаются искрами.
	var s := {"legacy": {"harvest": 2, "capital": 2, "companions": 1}, "sparks": 1}
	Game.legacy.defaults(s)
	eq(int(s["legacy"].get("harvest", 0)), 2, "купленные ранги остаются")
	check(not s["legacy"].has("capital") and not s["legacy"].has("companions"), "старые бонусы убраны")
	eq(int(s["sparks"]), 1 + Legacy.cost("capital", 0) + Legacy.cost("capital", 1) + Legacy.cost("companions", 0), "искры вернулись")
	Game.legacy.defaults(s)
	eq(int(s["sparks"]), 1 + Legacy.cost("capital", 0) + Legacy.cost("capital", 1) + Legacy.cost("companions", 0), "второй раз не возвращаются")
	check(not Game.legacy.has_method("rebirth"), "перерождения больше нет")
