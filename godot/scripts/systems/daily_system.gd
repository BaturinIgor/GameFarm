class_name DailySystem
extends RefCounted
## Цели дня и цели недели за кристаллы.
## День: до пяти целей (добыча и склад всегда, остальные - из того, что уже открыто), за каждую 1-4 кристалла,
## за все цели дня - сундук: ещё кристаллы и монеты. Неделя (с понедельника): четыре большие цели и сундук недели.
## Цели растут с уровнем: на 18 уровне день - это около 370 ударов по ресурсам и 390 ресурсов на склад.
## В Game.save: daily = {day, v, goals: [{type, target, progress, crystals, claimed}], bonus},
## weekly = {week, v, goals, bonus}.

const VERSION := 2
const DAY_CRYSTALS := [1, 2, 2, 3, 4]
const DAY_BONUS := 3
const WEEK_CRYSTALS := [5, 5, 5, 10]
const WEEK_BONUS := 15
## Какие события что считают (у продажи и склада - количество, у остального - по одному).
const EVENTS := ["deposit", "order", "kill", "harvest", "produce", "sell", "quest", "daily", "dungeon", "raid", "crop"]


func defaults(save: Dictionary) -> void:
	save["daily"] = _read(save.get("daily", {}), "day")
	save["weekly"] = _read(save.get("weekly", {}), "week")


func _read(raw: Variant, key: String) -> Dictionary:
	var d: Dictionary = raw if raw is Dictionary else {}
	var goals: Array = []
	if d.get("goals") is Array:
		for g in d["goals"]:
			if g is Dictionary:
				goals.append({"type": str(g.get("type", "deposit")), "target": maxi(1, int(g.get("target", 1))),
					"progress": int(g.get("progress", 0)), "crystals": int(g.get("crystals", 2)),
					"claimed": bool(g.get("claimed", false))})
	return {key: int(d.get(key, -1)), "v": int(d.get("v", 1)), "goals": goals, "bonus": bool(d.get("bonus", false))}


# MARK: Время

## Номер недели с понедельника (день 0 по Unix - четверг).
static func week_index() -> int:
	return int(floor(float(ShopSystem.day_index() + 3) / 7.0))


## Секунд до новых целей недели (полночь понедельника).
static func week_left() -> float:
	var next_start := (week_index() + 1) * 7 - 3
	return float(next_start - ShopSystem.day_index() - 1) * 86400.0 + ShopSystem.next_day_in()


# MARK: Цели

func goals() -> Array:
	_ensure_day()
	return Game.save["daily"]["goals"]


func week_goals() -> Array:
	_ensure_week()
	return Game.save["weekly"]["goals"]


## Что уже открыто у игрока (кроме добычи и склада, они есть всегда).
func _extras() -> Array:
	var lvl := Game.level
	var out: Array = ["sell", "quest"]
	if lvl >= 4:
		out.append("kill")
	if Game.estate.level("sawmill") > 0:
		out.append("produce")
	if Game.estate.orders_open():
		out.append("order")
	if lvl >= 8:
		out.append("dungeon")
	return out


## Сколько нужно сделать за день.
static func day_target(type: String, lvl: int) -> int:
	var l := float(lvl)
	match type:
		"harvest": return 150 + lvl * 12
		"deposit": return 120 + lvl * 15
		"sell": return maxi(200, int(round(pow(l, 1.5) * 60.0 / 50.0)) * 50)
		"quest": return mini(6, 3 + lvl / 10)
		"kill": return 12 + lvl
		"produce": return 15 + lvl
		"order": return 3
		"dungeon": return 2
	return 10


func _ensure_day() -> void:
	var d: Dictionary = Game.save["daily"]
	var today := ShopSystem.day_index()
	if int(d["day"]) == today and int(d.get("v", 1)) == VERSION and not (d["goals"] as Array).is_empty():
		return
	var lvl := Game.level
	var types: Array = ["harvest", "deposit"]
	var extra := _extras()
	extra.shuffle()
	for t in extra:
		if types.size() < DAY_CRYSTALS.size():
			types.append(t)
	var list: Array = []
	# Награды по порядку: последние цели самые дорогие
	var first := DAY_CRYSTALS.size() - types.size()
	for i in types.size():
		list.append(_goal(types[i], day_target(types[i], lvl), DAY_CRYSTALS[first + i]))
	Game.save["daily"] = {"day": today, "v": VERSION, "goals": list, "bonus": false}
	Game.mark_dirty()


func _ensure_week() -> void:
	var w: Dictionary = Game.save["weekly"]
	var week := week_index()
	if int(w["week"]) == week and int(w.get("v", 1)) == VERSION and not (w["goals"] as Array).is_empty():
		return
	var lvl := Game.level
	var list: Array = []
	list.append(_goal("harvest", 1200 + lvl * 60, WEEK_CRYSTALS[0]))
	list.append(_goal("daily", 20, WEEK_CRYSTALS[1]))
	list.append(_goal("quest", 15 + lvl / 2, WEEK_CRYSTALS[2]))
	var big: Array = []
	if lvl >= 4:
		big.append(["kill", 60 + lvl * 4])
	if Game.estate.level("sawmill") > 0:
		big.append(["produce", 100 + lvl * 6])
	if lvl >= 8:
		big.append(["dungeon", 8])
	if big.is_empty():
		big.append(["deposit", 900 + lvl * 80])
	var pick: Array = big.pick_random()
	list.append(_goal(str(pick[0]), int(pick[1]), WEEK_CRYSTALS[3]))
	Game.save["weekly"] = {"week": week, "v": VERSION, "goals": list, "bonus": false}
	Game.mark_dirty()


func _goal(type: String, target: int, crystals: int) -> Dictionary:
	return {"type": type, "target": target, "progress": 0, "crystals": crystals, "claimed": false}


func on_event(name: String, data: Dictionary) -> void:
	if not name in EVENTS:
		return
	if name == "raid" and not bool(data.get("win", false)):
		return
	var n := maxi(1, int(data.get("amount", 1)))
	var d: Dictionary = Game.save.get("daily", {})
	if int(d.get("day", -1)) == ShopSystem.day_index():
		_count(d.get("goals", []), name, n)
	var w: Dictionary = Game.save.get("weekly", {})
	if int(w.get("week", -1)) == week_index():
		_count(w.get("goals", []), name, n)


func _count(list: Array, type: String, n: int) -> void:
	for g in list:
		if g["type"] == type and int(g["progress"]) < int(g["target"]):
			g["progress"] = mini(int(g["target"]), int(g["progress"]) + n)


func done(g: Dictionary) -> bool:
	return int(g["progress"]) >= int(g["target"])


## Забрать цель дня (week = true - цель недели).
func claim(i: int, week := false) -> void:
	var list := week_goals() if week else goals()
	if i < 0 or i >= list.size():
		return
	var g: Dictionary = list[i]
	if g["claimed"] or not done(g):
		return
	g["claimed"] = true
	Game.shop.add_crystals(int(g["crystals"]), true)
	Sound.play("treasure")
	if not week:
		Game.emit_event("daily", {})
	Game.save_now()


# MARK: Сундук за все цели

func all_claimed(week := false) -> bool:
	for g in (week_goals() if week else goals()):
		if not g["claimed"]:
			return false
	return true


func bonus_taken(week := false) -> bool:
	return bool(Game.save["weekly" if week else "daily"].get("bonus", false))


func bonus_ready(week := false) -> bool:
	return all_claimed(week) and not bonus_taken(week)


func bonus_crystals(week := false) -> int:
	return WEEK_BONUS if week else DAY_BONUS


func bonus_coins(week := false) -> int:
	var lvl := Game.level
	var day := 100 + lvl * lvl * 4
	return day * 5 if week else day


func take_bonus(week := false) -> void:
	if not bonus_ready(week):
		return
	Game.save["weekly" if week else "daily"]["bonus"] = true
	Game.shop.add_crystals(bonus_crystals(week), true)
	Game.add_coins(bonus_coins(week))
	Sound.play("treasure")
	Game.save_now()


func claimable() -> int:
	var n := 0
	for g in goals():
		if done(g) and not g["claimed"]:
			n += 1
	for g in week_goals():
		if done(g) and not g["claimed"]:
			n += 1
	n += (1 if bonus_ready() else 0) + (1 if bonus_ready(true) else 0)
	return n


static func text(g: Dictionary) -> String:
	return L.t("daily." + str(g["type"]), [Fmt.n(int(g["target"]))])
