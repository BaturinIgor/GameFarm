class_name FairSystem
extends RefCounted
## Ярмарка выходного дня: в субботу и воскресенье жители скупают товары усадьбы вдвое дороже цены
## и доплачивают кристаллами. Каждый день 4 лота, одинаковые у всех (по номеру дня). В Game.save: fair = {day, sold}.

const LOTS := 4
const PAY := 2.0


func defaults(save: Dictionary) -> void:
	var raw: Variant = save.get("fair", {})
	var f: Dictionary = raw if raw is Dictionary else {}
	save["fair"] = {"day": int(f.get("day", -1)), "sold": f.get("sold", []) if f.get("sold") is Array else []}


func _f() -> Dictionary:
	var f: Dictionary = Game.save["fair"]
	if int(f["day"]) != ShopSystem.day_index():
		f["day"] = ShopSystem.day_index()
		f["sold"] = []
	return f


## Суббота или воскресенье по местному времени.
static func weekend() -> bool:
	var wd := int(Time.get_datetime_dict_from_system()["weekday"])
	return wd == 0 or wd == 6


## Какие товары могут быть на ярмарке: из построенных зданий.
func _goods() -> Array:
	var out: Array = []
	for id in Estate.IDS:
		if Estate.produces(id) and Game.estate.level(id) > 0:
			out.append_array(Estate.recipes(id))
	return out


## Лоты сегодня: [{good, n, coins, crystals, from}].
func lots() -> Array:
	var goods := _goods()
	if goods.is_empty():
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("fair|%d" % ShopSystem.day_index())
	var people: Array = Game.residents.arrived_list()
	var out: Array = []
	for i in LOTS:
		var g: String = goods[rng.randi() % goods.size()]
		var value := (80.0 + 40.0 * float(Game.level)) * rng.randf_range(0.8, 1.3)
		var n := clampi(int(round(value / float(Estate.price(g)))), 2, 40)
		out.append({"good": g, "n": n, "coins": int(round(float(Estate.price(g) * n) * PAY)),
			"crystals": 1 + rng.randi() % 3, "from": people[rng.randi() % people.size()] if not people.is_empty() else ""})
	return out


func sold(i: int) -> bool:
	return i in _f()["sold"]


func can_sell(i: int) -> bool:
	var list := lots()
	return weekend() and i >= 0 and i < list.size() and not sold(i) and Game.storage_of(list[i]["good"]) >= int(list[i]["n"])


func sell(i: int) -> bool:
	if not can_sell(i):
		return false
	var lot: Dictionary = lots()[i]
	Game.save["storage"][lot["good"]] = Game.storage_of(lot["good"]) - int(lot["n"])
	Game.add_coins(int(lot["coins"]))
	Game.shop.add_crystals(int(lot["crystals"]), true)
	_f()["sold"].append(i)
	Sound.play("coinBig")
	Game.emit_event("fair", {"good": lot["good"]})
	Game.mark_dirty()
	Game.save_now()
	return true


func ready_count() -> int:
	if not weekend():
		return 0
	var n := 0
	for i in lots().size():
		if can_sell(i):
			n += 1
	return n
