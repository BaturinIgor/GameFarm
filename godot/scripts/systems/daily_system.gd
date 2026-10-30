class_name DailySystem
extends RefCounted
## Цели дня: три простые задачи на сегодня за кристаллы (2, 3 и 5). Новые - каждый день.
## В Game.save: daily = {day, goals: [{type, target, progress, crystals, claimed}]}.

const CRYSTALS := [2, 3, 5]


func defaults(save: Dictionary) -> void:
	var raw: Variant = save.get("daily", {})
	var goals: Array = []
	if raw is Dictionary and raw.get("goals") is Array:
		for g in raw["goals"]:
			if g is Dictionary:
				goals.append({"type": str(g.get("type", "deposit")), "target": maxi(1, int(g.get("target", 1))),
					"progress": int(g.get("progress", 0)), "crystals": int(g.get("crystals", 2)),
					"claimed": bool(g.get("claimed", false))})
	save["daily"] = {"day": int(raw.get("day", 0)) if raw is Dictionary else 0, "goals": goals}


func goals() -> Array:
	_ensure()
	return Game.save["daily"]["goals"]


## Сегодняшние цели: если день сменился - новые.
func _ensure() -> void:
	var d: Dictionary = Game.save["daily"]
	var today := ShopSystem.day_index()
	if int(d["day"]) == today and (d["goals"] as Array).size() == 3:
		return
	var lvl := Game.level
	var list: Array = []
	list.append(_goal("deposit", 40 + lvl * 8, 0))
	if Game.estate.orders_open():
		list.append(_goal("order", 2, 1))
	elif lvl >= 4:
		list.append(_goal("kill", 5, 1))
	else:
		list.append(_goal("harvest", 25, 1))
	if Game.estate.level("sawmill") > 0:
		list.append(_goal("produce", 10 + lvl / 2, 2))
	else:
		list.append(_goal("harvest", 30 + lvl * 2, 2))
	Game.save["daily"] = {"day": today, "goals": list}
	Game.mark_dirty()


func _goal(type: String, target: int, i: int) -> Dictionary:
	return {"type": type, "target": target, "progress": 0, "crystals": CRYSTALS[i], "claimed": false}


func on_event(name: String, data: Dictionary) -> void:
	var map := {"deposit": "deposit", "order": "order", "kill": "kill", "harvest": "harvest", "produce": "produce"}
	if not map.has(name):
		return
	var d: Dictionary = Game.save.get("daily", {})
	if int(d.get("day", -1)) != ShopSystem.day_index():
		return
	var n := int(data.get("amount", 1))
	for g in d.get("goals", []):
		if g["type"] == map[name] and int(g["progress"]) < int(g["target"]):
			g["progress"] = mini(int(g["target"]), int(g["progress"]) + maxi(1, n))


func done(g: Dictionary) -> bool:
	return int(g["progress"]) >= int(g["target"])


func claim(i: int) -> void:
	var list := goals()
	if i < 0 or i >= list.size():
		return
	var g: Dictionary = list[i]
	if g["claimed"] or not done(g):
		return
	g["claimed"] = true
	Game.shop.add_crystals(int(g["crystals"]), true)
	Sound.play("treasure")
	Game.save_now()


func claimable() -> int:
	var n := 0
	for g in goals():
		if done(g) and not g["claimed"]:
			n += 1
	return n


static func text(g: Dictionary) -> String:
	return L.t("daily." + str(g["type"]), [Fmt.n(int(g["target"]))])
