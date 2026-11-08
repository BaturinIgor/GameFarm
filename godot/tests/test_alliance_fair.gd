extends "res://tests/test_case.gd"
## Ярмарка альянса: цены лота, прилавки и возврат товара.


func test_prices() -> void:
	eq(AllianceFair.base("iron", 10), 60)
	eq(AllianceFair.min_price("iron", 10), 30)
	eq(AllianceFair.max_price("iron", 10), 180)
	eq(AllianceFair.default_price("iron", 10), 90)
	eq(AllianceFair.clamp_price("iron", 10, 5), 30)
	eq(AllianceFair.clamp_price("iron", 10, 9999), 180)
	check(AllianceFair.min_price("wood", 1) >= 1, "цена не меньше монеты")
	check(not AllianceFair.valid_kind("unknownStuff"))


func test_slots_and_return() -> void:
	fresh({"level": 20, "alliance": {"id": 5, "name": "A", "tag": "A", "emblem": 0, "talents": {}}, "crystals": 1000})
	var al := Game.alliance
	al.fair = {"lots": [], "top": [], "mine": [{"id": 1, "kind": "iron", "qty": 5, "price": 50, "buyer": null, "old": false}]}
	eq(al.fair_slots(), 1)
	check(not al.can_list_lot(), "единственный прилавок занят")
	check(al.buy_fair_slot())
	eq(al.fair_slots(), 2)
	check(al.can_list_lot())
	check(not al.buy_fair_slot(), "второй раз не покупается")
	var before := Game.storage_of("iron")
	al._return_items([{"kind": "iron", "qty": 7}, {"kind": "bogus", "qty": 3}])
	eq(Game.storage_of("iron"), before + 7)
	al.fair = {}


func test_sql_matches() -> void:
	var path := ProjectSettings.globalize_path("res://").path_join("../docs/supabase/alliance_fair.sql")
	var sql := FileAccess.get_file_as_string(path)
	check(sql.contains("p_qty > %d" % AllianceFair.MAX_QTY), "предел количества как в игре")
	check(sql.contains("least(greatest(p_slots, 1), %d)" % AllianceFair.MAX_SLOTS))
