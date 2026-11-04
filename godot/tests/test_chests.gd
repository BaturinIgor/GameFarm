extends "res://tests/test_case.gd"
## Сундуки: шансы, ключи, гарантия, награды.


func test_odds_sum_to_100() -> void:
	for chest in Chests.IDS:
		var total := 0.0
		for r in Chests.RARITIES:
			total += float(Chests.spec(chest)["odds"].get(r, 0.0))
		near(total, 100.0, 0.001, "шансы сундука " + chest)
		check(str(Chests.spec(chest)["pity_rarity"]) in Chests.RARITIES, chest + ": гарантия - известная редкость")
		check(Chests.key_of(chest) in Chests.KEYS, chest + ": известный ключ")


func test_roll_respects_floor() -> void:
	for i in 300:
		var r := Chests.roll_rarity("wood", "blue")
		check(Chests.rarity_index(r) >= Chests.rarity_index("blue"), "гарантия не ниже синей, выпало " + r)
		between(Chests.roll_stars(), 1, 3, "звёзды 1-3")


func test_open_spends_keys() -> void:
	Game.chests.add_keys("copper", 3, false)
	eq(Game.chests.open("wood", 2).size(), 2, "открыто два")
	eq(Game.chests.keys("copper"), 1)
	eq(Game.chests.open("wood", 10).size(), 1, "открывается столько, сколько ключей")
	eq(Game.chests.keys("copper"), 0)
	check(Game.chests.open("wood").is_empty(), "без ключа не открывается")


func test_pity_guarantee() -> void:
	var need := int(Chests.spec("ancient")["pity"])
	Game.save["chests"]["pity"]["ancient"] = need - 1
	Game.chests.add_keys("star", 1, false)
	var got: Array = Game.chests.open("ancient")
	check(Chests.rarity_index(str(got[0]["rarity"])) >= Chests.rarity_index("red"), "на гарантии красный или выше")
	eq(Game.chests.pity_left("ancient"), need, "счётчик гарантии сброшен")


func test_buy_key_for_crystals() -> void:
	var price := Game.chests.key_price("silver")
	Game.save["crystals"] = price - 1
	check(not Game.chests.buy_key("silver"), "кристаллов мало")
	Game.save["crystals"] = price
	check(Game.chests.buy_key("silver"), "ключ куплен")
	eq(Game.chests.keys("silver"), 1)
	eq(Game.shop.crystals(), 0)


func test_rewards_are_positive() -> void:
	set_level(30)
	for r in Chests.RARITIES:
		for s in [1, 2, 3]:
			for i in 10:
				var rw := ChestSystem.make_reward(r, s, Game.level)
				check(int(rw["n"]) > 0, "%s %d*: награда %s пустая" % [r, s, rw["type"]])
				check(str(rw["type"]) in Chests.POOLS[r], "тип из пула")
				check(ChestSystem.reward_text(rw) != "", "есть подпись")
