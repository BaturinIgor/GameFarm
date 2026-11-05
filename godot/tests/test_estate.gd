extends "res://tests/test_case.gd"
## Усадьба: хранилища, стройка, товары.


func test_capacity_grows_with_level() -> void:
	for store in ["storage", "barn"]:
		var prev := 0
		for n in range(1, Estate.max_level(store) + 1):
			var c := Estate.capacity(store, n)
			check(c > prev, "%s: вместимость на уровне %d не растёт" % [store, n])
			prev = c


func test_build_cost_grows() -> void:
	for id in Estate.IDS:
		var prev := -1.0
		for n in range(1, Estate.max_level(id) + 1):
			var v := Estate.build_value(id, n)
			check(v > prev, "%s: цена уровня %d не растёт" % [id, n])
			check(Estate.build_seconds(id, n) > 0.0, "%s: время стройки %d" % [id, n])
			prev = v


func test_build_cost_items_exist() -> void:
	for id in Estate.IDS:
		for n in range(1, Estate.max_level(id) + 1):
			for it in Estate.build_cost(id, n).get("items", []):
				check(it[0] in Res.KINDS, "%s %d: неизвестный ресурс %s" % [id, n, it[0]])
				check(int(it[1]) > 0, "%s %d: количество %s" % [id, n, it[0]])


func test_recipes_use_known_resources() -> void:
	for good in Estate.GOODS:
		check(Estate.RECIPES.has(good), "у товара %s нет рецепта" % good)
		check(good in Res.KINDS, "товар %s не ресурс" % good)
		check(Estate.per_hour(good, 1) > 0.0, "товар %s не производится" % good)
		for it in Estate.RECIPES.get(good, []):
			check(it[0] in Res.KINDS, "%s: неизвестное сырьё %s" % [good, it[0]])


func test_speedup_price_monotonic() -> void:
	eq(Estate.speedup_crystals(0.0), 0)
	var prev := 0
	for minutes in [1, 15, 60, 240, 480, 1440]:
		var c := Estate.speedup_crystals(minutes * 60.0)
		check(c >= prev, "ускорение на %d мин дешевле более короткого" % minutes)
		prev = c


func test_start_upgrade_pays() -> void:
	set_level(Game.MAX_LEVEL)
	var id := "storage"
	Game.save["coins"] = 100_000_000
	for kind in Res.KINDS:
		Game.save["storage"][kind] = 0
	# Ресурсы для стройки - в обход лимита склада
	var cost: Dictionary = Estate.build_cost(id, Game.estate.level(id) + 1)
	for it in cost.get("items", []):
		Game.save["storage"][it[0]] = int(it[1])
	var lvl := Game.estate.level(id)
	if Game.estate.upgrade_block(id).is_empty():
		check(Game.estate.start_upgrade(id), "стройка началась")
		check(Game.estate.building(id) or Game.estate.level(id) > lvl, "здание строится")
		check(int(Game.save["coins"]) < 100_000_000, "монеты списаны")


## Уровень, на котором нужны доски: главный дом и склад подняты до него.
func _to_planks_level(id: String) -> void:
	set_level(Game.MAX_LEVEL)
	Game.save["estate"]["main"]["level"] = 5
	Game.save["estate"][id]["level"] = 3
	for kind in Res.KINDS:
		Game.save["storage"][kind] = 0


func test_buy_missing_goods_starts_upgrade() -> void:
	_to_planks_level("storage")
	var cost := Estate.build_cost("storage", 4)
	for it in cost["items"]:
		if not Estate.is_good(it[0]):
			Game.save["storage"][it[0]] = int(it[1])
	check(not Game.estate.missing_goods("storage").is_empty(), "доски нужны")
	var price := Game.estate.missing_goods_coins("storage")
	check(price > 0, "цена докупки")
	Game.save["coins"] = int(cost["coins"]) + price
	check(Game.estate.can_buy_missing("storage"), "можно докупить")
	check(Game.estate.buy_missing_and_upgrade("storage"), "докупили и строим")
	check(Game.estate.building("storage"), "стройка идёт")
	eq(Game.save["coins"], 0, "списаны монеты за стройку и товары")
	for it in cost["items"]:
		eq(Game.storage_of(it[0]), 0, "списано " + str(it[0]))


func test_buy_missing_needs_raw_and_coins() -> void:
	_to_planks_level("storage")
	Game.save["coins"] = 1_000_000_000
	# Камня нет: товары за монеты не заменяют сырьё
	check(not Game.estate.can_buy_missing("storage"), "без сырья нельзя")
	var cost := Estate.build_cost("storage", 4)
	for it in cost["items"]:
		if not Estate.is_good(it[0]):
			Game.save["storage"][it[0]] = int(it[1])
	Game.save["coins"] = Game.estate.missing_goods_coins("storage")
	check(not Game.estate.can_buy_missing("storage"), "монет только на товары, на стройку нет")


func test_buy_missing_price_is_a_real_sink() -> void:
	# Докупка дороже, чем продать те же товары: не арбитраж
	for good in Estate.GOODS:
		check(Estate.GOODS_COIN_MULT * Estate.price(good) > Game.sell_price(good) * 2.0, "докупка %s дешевле продажи" % good)
