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
		levels[id] = clampi(int(src.get(id, 0)) if src is Dictionary else 0, 0, Academy.max_level(id))
	var active := str(a.get("active", ""))
	save["academy"] = {"levels": levels, "active": active if active in Academy.IDS else "",
		"until": float(a.get("until", 0.0))}


func _a() -> Dictionary:
	return Game.save["academy"]


static func _now() -> float:
	return Time.get_unix_time_from_system()


func level(id: String) -> int:
	return int(_a()["levels"].get(id, 0))


## Множитель бонуса сейчас (1 - нет бонуса). Для часов и шанса - сама величина (0 - нет бонуса).
func mult(id: String) -> float:
	if not Game.save.has("academy"):
		return Academy.mult_at(id, 0)
	return Academy.mult_at(id, level(id))


func open() -> bool:
	return Game.estate.level("academy") > 0


## Потолок уровня исследований по уровню академии.
func cap() -> int:
	return mini(Academy.MAX, (Game.estate.level("academy") + 1) / 2)


## Потолок конкретного узла.
func cap_of(id: String) -> int:
	return mini(Academy.max_level(id), cap())


## Узел открыт: ряд по уровню академии и родитель изучен до 2 уровня.
func unlocked(id: String) -> bool:
	if Game.estate.level("academy") < int(Academy.ROW_LEVEL[Academy.row(id)]):
		return false
	var p := Academy.parent(id)
	return p == "" or level(p) >= 2


func active() -> String:
	return str(_a()["active"])


func left() -> float:
	return maxf(0.0, float(_a()["until"]) - _now()) if active() != "" else 0.0


## Почему нельзя начать: "" - можно.
func block(id: String) -> String:
	if not open():
		return "academy.block.closed"
	if not unlocked(id):
		return "academy.block.locked"
	if active() != "":
		return "academy.block.busy"
	if level(id) >= Academy.max_level(id):
		return "academy.block.max"
	if level(id) >= cap_of(id):
		return "academy.block.cap"
	if not Game.can_afford(Academy.cost(id, level(id) + 1)):
		return "academy.block.cost"
	return ""


func start(id: String) -> bool:
	if block(id) != "":
		return false
	Game.pay(Academy.cost(id, level(id) + 1))
	_a()["active"] = id
	_a()["until"] = _now() + Academy.seconds(id, level(id) + 1) * Game.residents.friend_mult("research")
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
	_a()["levels"][id] = mini(Academy.max_level(id), level(id) + 1)
	_a()["active"] = ""
	_a()["until"] = 0.0
	Game.show_toast("px:" + Academy.icon(id), L.t("academy.done", [Academy.name_of(id), level(id)]))
	Sound.play("levelUp")
	Game.recalc()
	Game.mark_dirty()
	Game.save_now()
