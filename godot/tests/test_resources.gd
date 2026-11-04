extends "res://tests/test_case.gd"
## Рюкзак, склад, продажа и оплата.


func test_backpack_respects_capacity() -> void:
	var cap := Game.stats.capacity
	eq(Game.add_to_backpack("wood", cap + 50), cap, "в рюкзак влезает только вместимость")
	eq(Game.backpack_free, 0)
	eq(Game.add_to_backpack("stone", 1), 0, "в полный рюкзак ничего не кладётся")
	eq(Game.save["gathered"]["wood"], cap, "собранное считается по положенному")


func test_backpack_ignores_non_positive() -> void:
	eq(Game.add_to_backpack("wood", 0), 0)
	eq(Game.add_to_backpack("wood", -5), 0)
	eq(Game.backpack_count, 0)


func test_deposit_moves_backpack_to_storage() -> void:
	Game.add_to_backpack("wood", 10)
	Game.add_to_backpack("apples", 4)
	eq(Game.deposit_backpack(), 14)
	eq(Game.storage_of("wood"), 10)
	eq(Game.storage_of("apples"), 4)
	eq(Game.backpack_count, 0, "рюкзак пуст после сдачи")


func test_storage_limit_keeps_rest_in_backpack() -> void:
	var room := Game.estate.storage_room("wood")
	Game.save["storage"]["stone"] = room - 3
	Game.add_to_backpack("wood", 10)
	eq(Game.deposit_backpack(), 3, "сдаётся только свободное место")
	eq(int(Game.save["backpack"].get("wood", 0)), 7, "лишнее остаётся в рюкзаке")
	eq(Game.estate.storage_room("wood"), 0)


func test_storage_and_barn_are_separate() -> void:
	# Урожай и еда - в амбаре, дерево и камень - на складе
	eq(Estate.store_of("wood"), "storage")
	eq(Estate.store_of("wheat"), "barn")
	var room := Game.estate.storage_room("wood")
	Game.save["storage"]["wood"] = room
	eq(Game.estate.storage_room("stone"), 0, "склад полон")
	check(Game.estate.storage_room("wheat") > 0, "амбар не зависит от склада")


func test_add_to_storage_caps() -> void:
	var room := Game.estate.storage_room("stone")
	eq(Game.add_to_storage("stone", room + 100), room)
	eq(Game.add_to_storage("stone", 5), 0, "в полный склад ничего не кладётся")


func test_sell_pays_and_removes() -> void:
	Game.save["storage"]["wood"] = 10
	var coins := int(Game.save["coins"])
	var price := Game.sell_price("wood")
	check(price >= 1, "цена продажи не меньше 1")
	eq(Game.sell("wood", 4), 4 * price)
	eq(Game.storage_of("wood"), 6)
	eq(Game.save["coins"], coins + 4 * price)


func test_sell_more_than_have() -> void:
	Game.save["storage"]["wood"] = 3
	eq(Game.sell("wood", 1000), 3 * Game.sell_price("wood"), "продаётся только то, что есть")
	eq(Game.storage_of("wood"), 0)
	eq(Game.sell("wood", 1), 0, "нечего продавать")


func test_can_afford_and_pay_storage_first() -> void:
	Game.save["coins"] = 100
	Game.save["storage"]["wood"] = 5
	Game.save["backpack"]["wood"] = 10
	var cost := {"coins": 60, "items": [["wood", 8]]}
	check(Game.can_afford(cost))
	Game.pay(cost)
	eq(Game.save["coins"], 40)
	eq(Game.storage_of("wood"), 0, "сначала списывается склад")
	eq(int(Game.save["backpack"]["wood"]), 7, "остальное из рюкзака")
	check(not Game.can_afford({"coins": 41}), "монет не хватает")
	check(not Game.can_afford({"items": [["wood", 8]]}), "дерева не хватает")


func test_discount_never_zero() -> void:
	Game.stats.discount = 0.01
	var d := Game.discounted({"coins": 10, "items": [["wood", 3]]})
	check(int(d["items"][0][1]) >= 1, "скидка не делает предмет бесплатным")
