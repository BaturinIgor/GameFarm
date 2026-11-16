extends "res://tests/test_case.gd"
## Погода альянса: когда идёт, дождь ускоряет грядки, солнце даёт бонус.


func test_active_and_pending() -> void:
	var w := {"kind": "rain", "starts": 1000, "ends": 1000 + AllianceWeather.DURATION}
	eq(AllianceWeather.active(w, 999.0), "")
	check(AllianceWeather.pending(w, 999.0))
	eq(AllianceWeather.active(w, 1000.0), "rain")
	eq(AllianceWeather.active(w, 4599.0), "rain")
	eq(AllianceWeather.active(w, 4600.0), "", "час прошёл")
	eq(AllianceWeather.active({"kind": "snow", "starts": 0, "ends": 99999}, 10.0), "", "неизвестная погода")


func test_rain_overlap() -> void:
	var w := {"kind": "rain", "starts": 1000, "ends": 4600}
	eq(AllianceWeather.rain_overlap(w, 0.0, 500.0), 0.0)
	eq(AllianceWeather.rain_overlap(w, 0.0, 2000.0), 1000.0)
	eq(AllianceWeather.rain_overlap(w, 2000.0, 9000.0), 2600.0)
	eq(AllianceWeather.rain_overlap({"kind": "sun", "starts": 1000, "ends": 4600}, 0.0, 9000.0), 0.0, "солнце не поливает")


func test_rain_speeds_beds() -> void:
	fresh({"level": 10})
	var crop: String = Farming.CROP_IDS[0]
	var t := Clock.now()
	var bed := {"crop": crop, "plantedAt": t - 30.0, "boost": 0.0, "watered": false, "speed": 1.0}
	Game.save["beds"] = [bed]
	var ready := Farming.ready_at(Game.garden.bed(0))
	var w := {"kind": "rain", "starts": t - 20.0, "ends": t + 3000.0}
	Game.garden.apply_rain(w, t - 200.0, t)
	near(Farming.ready_at(Game.garden.bed(0)), ready - 20.0, 0.01, "20 секунд дождя - на 20 секунд раньше")


func test_rain_not_before_planting() -> void:
	var t := 10000.0
	var bed := {"crop": Farming.CROP_IDS[0], "plantedAt": t - 30.0, "boost": 0.0, "speed": 1.0}
	var w := {"kind": "rain", "starts": int(t - 600.0), "ends": int(t + 3000.0)}
	near(AllianceWeather.rain_boost(bed, w, t - 600.0, t), 30.0, 0.01, "только с посадки")


func test_sun_bonus() -> void:
	fresh({"level": 10, "alliance": {"id": 5, "name": "A", "tag": "A", "emblem": 0, "talents": {}}})
	var base := Game.stats.yield_all
	var t := int(Clock.now())
	Game.save["allianceWeather"] = {"kind": "sun", "starts": t - 10, "ends": t + 100}
	Game.recalc()
	near(Game.stats.yield_all - base, AllianceWeather.SUN_YIELD, 0.001)
	Game.save["allianceWeather"] = {}
	Game.recalc()
	near(Game.stats.yield_all, base, 0.001)
