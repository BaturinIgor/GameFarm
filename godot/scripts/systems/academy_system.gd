class_name AcademySystem
extends RefCounted
## Исследования академии. В Game.save: academy = {levels: {id: n}, active: id, until}.
## Бонусы: build - время стройки, storage - вместимость склада и амбара, orders - монеты заказов,
## towers - урон башен, squads - время походов отрядов.


func defaults(save: Dictionary) -> void:
	var raw: Variant = save.get("academy", {})
	var a: Dictionary = raw if raw is Dictionary else {}
	var levels := {}
	var src: Variant = a.get("levels", {})
	for id in Academy.IDS:
		levels[id] = clampi(int(src.get(id, 0)) if src is Dictionary else 0, 0, Academy.MAX)
	var active := str(a.get("active", ""))
	save["academy"] = {"levels": levels, "active": active if active in Academy.IDS else "",
		"until": float(a.get("until", 0.0))}


func _a() -> Dictionary:
	return Game.save["academy"]


static func _now() -> float:
	return Time.get_unix_time_from_system()


func level(id: String) -> int:
	return int(_a()["levels"].get(id, 0))


## Множитель бонуса сейчас (1 - нет бонуса).
func mult(id: String) -> float:
	if not Game.save.has("academy"):
		return 1.0
	return Academy.mult_at(id, level(id))


func open() -> bool:
	return Game.estate.level("academy") > 0


## Потолок уровня исследования по уровню академии.
func cap() -> int:
	return mini(Academy.MAX, (Game.estate.level("academy") + 1) / 2)


func active() -> String:
	return str(_a()["active"])


func left() -> float:
	return maxf(0.0, float(_a()["until"]) - _now()) if active() != "" else 0.0


## Почему нельзя начать: "" - можно.
func block(id: String) -> String:
	if not open():
		return "academy.block.closed"
	if active() != "":
		return "academy.block.busy"
	if level(id) >= Academy.MAX:
		return "academy.block.max"
	if level(id) >= cap():
		return "academy.block.cap"
	if not Game.can_afford(Academy.cost(level(id) + 1)):
		return "academy.block.cost"
	return ""


func start(id: String) -> bool:
	if block(id) != "":
		return false
	Game.pay(Academy.cost(level(id) + 1))
	_a()["active"] = id
	_a()["until"] = _now() + Academy.seconds(level(id) + 1)
	Game.mark_dirty()
	Game.save_now()
	return true


func speedup_cost() -> int:
	return Estate.speedup_crystals(left())


func speed_up() -> bool:
	if active() == "" or not Game.shop.spend_crystals(speedup_cost()):
		return false
	_a()["until"] = _now()
	tick()
	return true


## Исследование закончилось: уровень выше. Зовётся из тика усадьбы раз в секунду.
func tick() -> void:
	var id := active()
	if id == "" or float(_a()["until"]) > _now():
		return
	_a()["levels"][id] = mini(Academy.MAX, level(id) + 1)
	_a()["active"] = ""
	_a()["until"] = 0.0
	Game.show_toast("px:" + Academy.icon(id), L.t("academy.done", [Academy.name_of(id), level(id)]))
	Sound.play("levelUp")
	Game.recalc()
	Game.mark_dirty()
	Game.save_now()
