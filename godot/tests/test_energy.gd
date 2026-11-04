extends "res://tests/test_case.gd"
## Энергия: трата на удары, лимиты еды, покупка.


func test_full_at_start() -> void:
	near(Game.energy.value(), Game.energy.max_value(), 0.01)


func test_spend_reduces() -> void:
	var before := Game.energy.value()
	check(Game.energy.try_spend(10.0))
	near(Game.energy.value(), before - 10.0, 0.05, "энергия тратится на удар")


func test_runs_out() -> void:
	Game.save["energy"]["value"] = 0.5
	Game.save["energy"]["at"] = Time.get_unix_time_from_system()
	check(not Game.energy.try_spend(1.0), "без энергии удар не проходит")


func test_regenerates_over_time() -> void:
	Game.save["energy"]["value"] = 0.0
	Game.save["energy"]["at"] = Time.get_unix_time_from_system() - Game.energy.regen_seconds() * 10.0
	near(Game.energy.value(), 10.0, 0.2, "восстановление за 10 интервалов")


func test_regen_stops_at_max() -> void:
	Game.save["energy"]["value"] = 0.0
	Game.save["energy"]["at"] = Time.get_unix_time_from_system() - 1e7
	near(Game.energy.value(), Game.energy.max_value(), 0.01)


func test_food_daily_limit() -> void:
	Game.save["energy"]["value"] = 0.0
	Game.save["energy"]["at"] = Time.get_unix_time_from_system()
	var got := 0
	for i in 50:
		got += Game.energy.add_food(100)
	eq(got, EnergySystem.FOOD_PER_DAY, "еда за день даёт не больше лимита")
	eq(Game.energy.food_left(), 0)


func test_overflow_cap() -> void:
	Game.energy.add(1e6)
	check(Game.energy.value() <= Game.energy.max_value() * EnergySystem.OVERFLOW + 0.01, "запас сверх лимита ограничен")


func test_buy_needs_crystals_and_grows_price() -> void:
	Game.save["crystals"] = 0
	check(not Game.energy.buy(), "без кристаллов не купить")
	Game.shop.add_crystals(1000)
	var p1 := Game.energy.buy_price()
	check(Game.energy.buy())
	check(Game.energy.buy_price() > p1, "вторая покупка за день дороже")
	eq(Game.shop.crystals(), 1000 - p1)
