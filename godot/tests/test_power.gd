extends "res://tests/test_case.gd"
## Мощь игрока: части, звери, предел.


func test_parts() -> void:
	eq(Power.of_level(20), 2000)
	eq(Power.of_gear(1), 25)
	eq(Power.of_gear(10), 1050)
	eq(Power.of_animal("chicken", 0), 0, "не приручен - нет силы")
	eq(Power.of_animal("chicken", 5), 150)
	eq(Power.of_animal("chicken", 5, 4, true), 150 + 480 + 80)
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
	eq(AllianceEvents.hit_damage(10, Power.total(), 0), 60 + 80 + Power.total() / 100)
