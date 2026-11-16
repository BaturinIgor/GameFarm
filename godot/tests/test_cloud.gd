extends "res://tests/test_case.gd"
## Сохранение в iCloud и уведомления: правила без плагинов (сами плагины есть только на iPhone).


func test_pack_roundtrip() -> void:
	set_level(25)
	Game.save["coins"] = 9876
	var back: Variant = Cloud.unpack(Cloud.pack(Game.save))
	check(back is Dictionary, "копия читается")
	eq(int(back["level"]), 25)
	eq(int(back["coins"]), 9876)
	check(Cloud.pack(Game.save).size() < Cloud.MAX_BYTES, "копия помещается в iCloud")
	eq(Cloud.unpack(PackedByteArray()), null, "пустая копия - ничего")


func test_offer_only_for_other_device() -> void:
	var local := {"level": 10, "xp": 5, "lastSeen": 1000}
	eq(Cloud.should_offer({}, local, "A"), false, "в iCloud пусто")
	eq(Cloud.should_offer({"level": 20, "xp": 0, "at": 2000, "device": "A"}, local, "A"), false, "своя копия")
	eq(Cloud.should_offer({"level": 20, "xp": 0, "at": 500, "device": "B"}, local, "A"), true, "там уровень выше")
	eq(Cloud.should_offer({"level": 5, "xp": 0, "at": 500, "device": "B"}, local, "A"), false, "там старее и ниже")
	eq(Cloud.should_offer({"level": 5, "xp": 0, "at": 2000, "device": "B"}, local, "A"), true, "там новее")
	eq(Cloud.should_offer({"level": 10, "xp": 5, "at": 2000, "device": "B"}, local, "A"), false, "та же игра")
	eq(Cloud.should_offer({"level": 10, "xp": 9, "at": 2000, "device": "B"}, local, "A"), true, "тот же уровень, новее")


func test_declined_copy_is_not_offered_again() -> void:
	var local := {"level": 1, "xp": 0, "lastSeen": 1000, "settings": {"cloudDeclined": 3000}}
	eq(Cloud.should_offer({"level": 30, "xp": 0, "at": 3000, "device": "B"}, local, "A"), false, "отказ от этой копии")
	eq(Cloud.should_offer({"level": 31, "xp": 0, "at": 4000, "device": "B"}, local, "A"), true, "новая копия - снова спросить")


func test_meta_has_progress() -> void:
	set_level(12)
	var m := Cloud.make_meta(Game.save, "dev")
	eq(m["level"], 12)
	eq(m["device"], "dev")
	check(int(m["at"]) > 0, "время копии")


func test_night_moves_to_morning() -> void:
	var day := 20000.0 * 86400.0
	# UTC (bias 0): 23:30 -> 9:00 следующего дня, 3:00 -> 9:00 того же дня, 15:00 не меняется
	eq(Notify.quiet_with_bias(day + 23.5 * 3600.0, 0.0), day + 86400.0 + 9.0 * 3600.0)
	eq(Notify.quiet_with_bias(day + 3.0 * 3600.0, 0.0), day + 9.0 * 3600.0)
	eq(Notify.quiet_with_bias(day + 15.0 * 3600.0, 0.0), day + 15.0 * 3600.0)
	# Москва (+3 ч): 20:00 UTC = 23:00 местного -> 9:00 местного = 6:00 UTC следующего дня
	eq(Notify.quiet_with_bias(day + 20.0 * 3600.0, 3.0 * 3600.0), day + 86400.0 + 6.0 * 3600.0)


func test_plan_has_comeback_and_no_near_pings() -> void:
	var now := Clock.now()
	var plan := Notify.plan(now)
	var ids: Array = plan.map(func(n: Dictionary) -> String: return n["id"])
	check("comeback0" in ids and "comeback1" in ids, "напоминание вернуться")
	for n in plan:
		check(float(n["at"]) - now >= Notify.MIN_DELAY, "не раньше чем через 10 минут: " + str(n["id"]))
		check(str(n["text"]) != "", "есть текст: " + str(n["id"]))


func test_plan_reminds_about_ripe_garden() -> void:
	set_level(20)
	var now := Clock.now()
	Game.garden.plant(0, "")
	var b := Game.garden.bed(0)
	if Farming.is_empty(b):
		return
	var ids: Array = Notify.plan(now).map(func(n: Dictionary) -> String: return n["id"])
	if Farming.ready_at(b) - now >= Notify.MIN_DELAY:
		check("garden" in ids, "урожай созреет - напомнить")
