extends "res://tests/test_case.gd"
## Мощь игрока: части, звери, предел.


func test_parts() -> void:
	eq(Power.of_level(20), 240000)
	eq(Power.of_gear(1), 2500)
	eq(Power.of_gear(10), 105000)
	eq(Power.of_animal("chicken", 0), 0, "не приручен - нет силы")
	eq(Power.of_animal("chicken", 5), 15000)
	eq(Power.of_animal("chicken", 5, 4, true), 15000 + 48000 + 8000)
	check(Power.of_animal("moonUnicorn", 3) > Power.of_animal("cow", 3), "редкий зверь сильнее")


func test_total_grows_with_animals() -> void:
	fresh({"level": 10, "animals": {"chicken": 1}})
	var parts := Power.breakdown()
	var sum := 0
	for v in parts.values():
		sum += int(v)
	eq(Power.total(), sum, "мощь - сумма частей")
	var before := Power.total()
	Game.animals.add_star("chicken", 1)
	eq(Power.total() - before, Power.PER_STAR, "звезда добавляет мощь")
	eq(AllianceEvents.hit_damage(10, Power.total(), 0), 60 + 80 + Power.total() / Power.DAMAGE_PER)


func test_recommended() -> void:
	var prev := 0
	for l in range(1, 61):
		var r := Power.recommended(l)
		check(r >= prev, "рекомендуемая мощь не падает с уровнем")
		eq(r % 100, 0, "круглое число")
		prev = r


func test_animal_levels() -> void:
	fresh({"animals": {"chicken": 1}, "coins": 1000000})
	var a := Game.animals
	eq(a.level("chicken"), 1)
	eq(a.level_cap("chicken"), 6, "6 уровней за звезду")
	var cost := a.feed_cost("chicken")
	eq(cost["items"][0][0], "wheat", "первые уровни - пшеница")
	eq(a.can_feed("chicken"), false, "без корма нельзя")
	Game.save["storage"]["wheat"] = 1000
	Game.save["storage"]["carrots"] = 1000
	var p0 := Power.animal("chicken")
	var b0 := a.boost("chicken")
	for i in 10:
		a.feed("chicken")
	eq(a.level("chicken"), 6, "дальше 6 уровня не кормится без второй звезды")
	near(a.boost("chicken"), b0 * 1.05, 0.0001, "+1% за уровень")
	eq(Power.animal("chicken") - p0, 5 * Power.PER_ANIMAL_LEVEL)
	check(int(Game.save["storage"]["wheat"]) < 1000, "корм списан")
	fresh({"animalLevels": {"chicken": 99, "bogus": 3}, "animals": {"chicken": 5}})
	eq(Game.save["animalLevels"], {"chicken": 30}, "уровни в сохранении чистятся")
	for l in range(1, Animals.MAX_LEVEL):
		check(Farming.CROPS.values().any(func(c: Dictionary) -> bool: return c["produce"] == Animals.feed_cost(l)["items"][0][0]), "корм уровня %d - урожай" % l)


func test_estate_power() -> void:
	fresh()
	var p0 := Power.total()
	eq(Power.of_building("mill", 5), 5 * Power.PER_BUILDING_LEVEL)
	eq(Power.of_building("tower", 5), 5 * Power.PER_BUILDING_LEVEL * Power.DEFENSE_MULT, "башня втрое сильнее")
	Game.save["estate"]["tower"]["level"] = int(Game.save["estate"]["tower"]["level"]) + 2
	eq(Power.total() - p0, 2 * Power.PER_BUILDING_LEVEL * Power.DEFENSE_MULT, "уровни башни идут в мощь")
	eq(int(Power.breakdown()["estate"]) > 0, true, "усадьба в разбивке")
