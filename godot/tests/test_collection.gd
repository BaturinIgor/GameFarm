extends "res://tests/test_case.gd"
## Коллекции 2.0: уровень коллекционера, награды ключами, зверинец.


func test_collector_points_grow() -> void:
	var c := Game.collection
	var p0 := c.collector_points()
	Game.save["animals"]["chicken"] = 1
	eq(c.collector_points(), p0 + int(CollectionSystem.COLLECTOR_POINTS["animal"]), "новый зверь - очки")
	Game.save["shiny"].append("chicken")
	eq(c.collector_points(), p0 + int(CollectionSystem.COLLECTOR_POINTS["animal"]) + int(CollectionSystem.COLLECTOR_POINTS["shiny"]))


func test_collector_claim_gives_keys_once() -> void:
	var c := Game.collection
	for id in ["chicken", "cow", "horse", "sheep", "bee", "mouse", "goose", "duck", "frog", "swan"]:
		Game.save["animals"][id] = 1
	var lvl := c.collector_level()
	check(lvl >= 2, "десять зверей - несколько уровней")
	eq(c.collector_ready(), lvl)
	var got := c.claim_collector()
	var total := 0
	for k in got:
		total += int(got[k])
	eq(total, lvl, "ключ за каждый уровень")
	eq(Game.chests.keys("copper") + Game.chests.keys("silver") + Game.chests.keys("star"), lvl)
	eq(c.collector_ready(), 0)
	check(c.claim_collector().is_empty(), "второй раз ничего")


func test_collector_reward_schedule() -> void:
	eq(CollectionSystem.collector_reward(1), "copper")
	eq(CollectionSystem.collector_reward(5), "silver")
	eq(CollectionSystem.collector_reward(10), "star")


func test_every_animal_has_source() -> void:
	for id in Animals.IDS:
		check(CollectionPanel.source_text(id) != "", id + ": в зверинце написано, где взять")


func test_claimed_survives_save() -> void:
	Game.save["collectorClaimed"] = 7
	var copy: Dictionary = JSON.parse_string(JSON.stringify(Game.save))
	Game.collection.defaults(copy)
	eq(int(copy["collectorClaimed"]), 7)
