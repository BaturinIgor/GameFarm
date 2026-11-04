extends "res://tests/test_case.gd"
## Звери: лавка, звёзды, спутники, добыча без игры.


func _buyable() -> String:
	for id in Animals.IDS:
		if Animals.shop_level(id) >= 0 and Animals.shop_base_price(id) > 0:
			return id
	return ""


func test_buy_from_shop() -> void:
	var id := _buyable()
	check(id != "", "в лавке есть звери")
	set_level(maxi(1, Animals.shop_level(id)))
	var price := Game.animals.shop_price(id)
	Game.save["coins"] = price
	check(Game.animals.buy(id), "покупка " + id)
	eq(Game.animals.stars(id), 1)
	eq(Game.save["coins"], 0, "монеты списаны")
	check(Game.animals.is_active(id), "новый зверь идёт с героем")
	check(Game.animals.shop_price(id) > price, "следующая звезда дороже")


func test_buy_blocked_by_level_and_coins() -> void:
	var id := _buyable()
	Game.save["coins"] = 10_000_000
	if Animals.shop_level(id) > 1:
		check(not Game.animals.buy(id), "уровень мал")
	set_level(Game.MAX_LEVEL)
	Game.save["coins"] = 0
	check(not Game.animals.buy(id), "монет нет")


func test_stars_capped() -> void:
	var id := _buyable()
	Game.animals.add_star(id, Animals.MAX_STARS + 10)
	eq(Game.animals.stars(id), Animals.MAX_STARS)
	set_level(Game.MAX_LEVEL)
	Game.save["coins"] = 100_000_000
	check(not Game.animals.buy(id), "на максимуме звёзд не покупается")


func test_active_limit() -> void:
	for id in Animals.IDS:
		Game.save["animals"][id] = 1
	Game.save["active"] = []
	var added := 0
	for id in Animals.IDS:
		if Game.animals.toggle_active(id):
			added += 1
	eq(added, Game.animals.max_active(), "с собой не больше лимита")
	eq(Game.animals.active().size(), Game.animals.max_active())


func test_animal_power_capped() -> void:
	set_level(Game.MAX_LEVEL)
	for id in Animals.IDS:
		Game.save["animals"][id] = Animals.MAX_STARS
		Game.save["awaken"][id] = 3
	Game.save["active"] = Animals.IDS.slice(0, Game.animals.max_active())
	Game.recalc()
	for p in Game.stats.producers:
		check(float(p["interval"]) > 0.0, "интервал производителя > 0")


func test_load_drops_unknown_and_duplicates() -> void:
	fresh({"animals": {"chicken": 9, "unknownBeast": 2}, "active": ["chicken", "chicken", "unknownBeast"]})
	eq(Game.animals.stars("chicken"), Animals.MAX_STARS, "звёзды режутся до максимума")
	check(not Game.save["animals"].has("unknownBeast"), "неизвестный зверь отброшен")
	eq(Game.save["active"], ["chicken"], "без повторов и неизвестных")


func test_offline_production_respects_storage() -> void:
	var producer := ""
	for id in Animals.IDS:
		if Animals.is_producer(id):
			producer = id
			break
	check(producer != "", "есть зверь-производитель")
	Game.save["animals"][producer] = Animals.MAX_STARS
	Game.save["active"] = [producer]
	Game.recalc()
	Game.save["lastSeen"] = Time.get_unix_time_from_system() - 30 * 24 * 3600
	var report := Game.animals.apply_offline()
	check(not report.is_empty(), "производитель принёс добычу")
	check(float(report.get("duration", 0.0)) <= Game.stats.offline_hours * 3600.0 + 1.0, "время без игры ограничено")
	for store in ["storage", "barn"]:
		check(Game.estate.stored(store) <= Game.estate.capacity(store), "хранилище %s не переполнено" % store)


func test_offline_short_absence_gives_nothing() -> void:
	Game.save["lastSeen"] = Time.get_unix_time_from_system() - 30
	eq(Game.animals.apply_offline(), {})


func test_offline_clock_moved_back() -> void:
	Game.save["lastSeen"] = Time.get_unix_time_from_system() + 3600
	eq(Game.animals.apply_offline(), {}, "часы назад не дают добычи")
