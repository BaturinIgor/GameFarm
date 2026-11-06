extends "res://tests/test_case.gd"
## Сохранение: запись и чтение, старые и испорченные файлы.


func _write(text: String) -> void:
	var f := FileAccess.open(Game.save_path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_tests_do_not_touch_real_save() -> void:
	check(Game.save_path != Game.SAVE_PATH, "автотесты пишут в отдельный файл")


func test_roundtrip_keeps_progress() -> void:
	set_level(17)
	Game.save["coins"] = 12345
	Game.save["storage"]["wood"] = 77
	Game.save["talents"]["power"] = 3
	Game.shop.add_crystals(42)
	Game.save_now()
	var loaded: Dictionary = Game._load_save()
	eq(loaded["level"], 17)
	eq(loaded["coins"], 12345)
	eq(loaded["storage"]["wood"], 77)
	eq(loaded["talents"]["power"], 3)
	eq(int(loaded["crystals"]), 42)
	eq(typeof(loaded["coins"]), TYPE_INT, "числа после JSON целые")


func test_full_roundtrip_through_defaults() -> void:
	# Сохранение после игры загружается всеми системами без ошибок
	set_level(30)
	Game.save_now()
	var loaded: Dictionary = Game._load_save()
	for sys in Game.systems:
		sys.defaults(loaded)
	Game.save = loaded
	Game.recalc()
	eq(Game.level, 30)


func test_broken_file_starts_fresh() -> void:
	expect_engine_errors()
	_write("{not json")
	var loaded: Dictionary = Game._load_save()
	eq(loaded["level"], 1, "испорченный файл - игра с нуля")


func test_unknown_location_falls_back() -> void:
	_write(JSON.stringify({"economy": Game.ECONOMY, "current": "nowhere", "unlocked": []}))
	var loaded: Dictionary = Game._load_save()
	eq(loaded["current"], "meadow")
	check("meadow" in loaded["unlocked"], "луг всегда открыт")


func test_old_economy_keeps_purchases() -> void:
	_write(JSON.stringify({"economy": 1, "level": 40, "coins": 99999, "crystals": 250, "purchases": ["starter"]}))
	var loaded: Dictionary = Game._load_save()
	Game.economy_reset = false
	eq(loaded["level"], 1, "прогресс старой экономики сброшен")
	eq(int(loaded["crystals"]), 250, "кристаллы сохранены")
	eq(loaded["purchases"], ["starter"], "покупки сохранены")


func test_float_numbers_become_int() -> void:
	_write('{"economy": %d, "level": 5.0, "coins": 100.0, "storage": {"wood": 3.0}}' % Game.ECONOMY)
	var loaded: Dictionary = Game._load_save()
	eq(typeof(loaded["level"]), TYPE_INT)
	eq(typeof(loaded["storage"]["wood"]), TYPE_INT)


func test_old_currencies_absorbed() -> void:
	# Экспедиций больше нет: билеты из старых сохранений и наград становятся фонарями шахты,
	# карты сокровищ - медными ключами.
	Game.save["mine"]["lamps"] = 2
	Game.save["chests"]["keys"]["copper"] = 1
	Game.save["tickets"] = 4
	Game.save["maps"] = 3
	Game.mark_dirty()
	eq(int(Game.save["tickets"]), 0, "билеты обнулены")
	eq(int(Game.save["maps"]), 0, "карты обнулены")
	eq(int(Game.save["mine"]["lamps"]), 6, "билеты стали фонарями")
	eq(int(Game.save["chests"]["keys"]["copper"]), 4, "карты стали медными ключами")
	Game.save["tickets"] = 500
	Game.mark_dirty()
	eq(int(Game.save["mine"]["lamps"]), Mine.LAMPS_HOLD, "запас фонарей ограничен")


func test_old_expedition_save_cleared() -> void:
	var s: Dictionary = JSON.parse_string(JSON.stringify(Game.save))
	s["expedition"] = {"location": "goldMine", "endsAt": 1.0, "returnTo": "meadow"}
	s["current"] = "goldMine"
	for sys in Game.systems:
		sys.defaults(s)
	check(not (s.get("expedition") is Dictionary and not (s["expedition"] as Dictionary).is_empty()), "забег экспедиции стёрт")
	check(str(s["current"]) != "goldMine", "из экспедиции вернулись домой")
	check(not Game.premium.can_start_expedition("goldMine"), "экспедиции не запускаются")


func test_market_lamps_and_keys() -> void:
	Game.save["crystals"] = 1000
	var lamps := Game.mine.lamps()
	check(Game.shop.buy_market("ticket1"))
	eq(Game.mine.lamps(), lamps + 1, "фонарь из лавки")
	var keys := int(Game.save["chests"]["keys"].get("copper", 0))
	check(Game.shop.buy_market("map1"))
	eq(int(Game.save["chests"]["keys"].get("copper", 0)), keys + 1, "медный ключ из лавки")


func test_wild_has_no_ruins() -> void:
	for ring in Wild.RINGS.size():
		for sec in Wild.sectors(ring):
			check(str(sec["kind"]) != "ruins", "в диких землях нет руин с экспедициями")
