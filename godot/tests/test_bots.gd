extends "res://tests/test_case.gd"
## Бот-игрок (tests/sim) на трёх игровых днях: правила работают в ускоренном времени, игрок растёт.
## Полный прогон ботов - вручную: -- --simulate или Actions -> Bots.


func test_bot_three_days() -> void:
	var bot: RefCounted = load("res://tests/sim/bot.gd").new({"name": "smoke", "days": 3, "sessions": 3, "minutes": 10.0})
	var rep: Dictionary = bot.call("run")
	Clock.offset = 0.0
	var last: Dictionary = rep["days"][-1]
	check(int(last["level"]) >= 5, "за 3 дня бот дорос до 5 уровня, а не %s" % last["level"])
	check(float(rep["played_hours"]) > 1.0, "бот играл")
	check(int(last["estate"]["main"]) >= 2, "главный дом строится")


func test_clock_offset_moves_rules_time() -> void:
	var before := Clock.now()
	Clock.offset = 3600.0
	near(Clock.now() - before, 3600.0, 2.0)
	Clock.offset = 0.0
