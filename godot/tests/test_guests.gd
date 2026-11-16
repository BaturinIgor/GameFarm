extends "res://tests/test_case.gd"
## Звери в гости: бонус хозяину дома, подарок, места.


func test_bonus() -> void:
	var t := 1000.0
	near(Guests.bonus([], t), 0.0)
	near(Guests.bonus([{"stars": 3, "returns": 2000}], t), 0.03)
	near(Guests.bonus([{"stars": 3, "returns": 500}], t), 0.0, 0.0001, "гость уехал")
	var many := []
	for i in 5:
		many.append({"stars": 5, "returns": 2000})
	near(Guests.bonus(many, t), 0.05 * Guests.MAX_HOSTED, 0.0001, "не больше трёх гостей")
	eq(Guests.active_count([{"stars": 1, "returns": 2000}, {"stars": 1, "returns": 10}], t), 1)


func test_reward_grows() -> void:
	check(int(Guests.reward(5, 20)["coins"]) > int(Guests.reward(1, 20)["coins"]))
	check(int(Guests.reward(3, 30)["coins"]) > int(Guests.reward(3, 10)["coins"]))
	eq(int(Guests.reward(3, 10)["copper"]), 1)


func test_slots_and_recalc() -> void:
	fresh({"level": 10, "crystals": 1000, "alliance": {"id": 5, "name": "A", "tag": "A", "emblem": 0, "talents": {}},
		"animals": {"cow": 2}})
	var al := Game.alliance
	eq(al.guest_slots(), 1)
	check(al.can_send_guest("cow"))
	check(not al.can_send_guest("pig"), "нет такого зверя")
	check(al.buy_guest_slot())
	eq(al.guest_slots(), 2)
	eq(Game.shop.crystals(), 1000 - Guests.SLOT_CRYSTALS)
	check(not al.buy_guest_slot(), "второй раз не продаётся")
	var base := Game.stats.yield_all
	Game.save["guestsIn"] = [{"stars": 4, "returns": int(Clock.now()) + 100}]
	Game.recalc()
	near(Game.stats.yield_all - base, 0.04, 0.0001)
