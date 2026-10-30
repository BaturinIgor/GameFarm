class_name ResidentSystem
extends RefCounted
## Жители и их истории. В Game.save: residents = {id: {arrived, chapter (пройдено глав), taken, base}}.
## base - счётчик побед над нужным монстром в момент, когда задание взято.

## Состояния жителя: away - ещё не переехал, locked - глава ждёт уровня героя, new - можно взять задание,
## active - задание взято, ready - можно сдать, done - история пройдена.


func defaults(save: Dictionary) -> void:
	var raw: Variant = save.get("residents", {})
	var clean := {}
	for id in Residents.IDS:
		var r: Dictionary = raw.get(id, {}) if raw is Dictionary and raw.get(id) is Dictionary else {}
		clean[id] = {"arrived": bool(r.get("arrived", false)),
			"chapter": clampi(int(r.get("chapter", 0)), 0, Residents.chapters(id).size()),
			"taken": bool(r.get("taken", false)), "base": int(r.get("base", 0)),
			"friend": int(r.get("friend", 0)), "giftDay": int(r.get("giftDay", -1)), "gifts": int(r.get("gifts", 0))}
	save["residents"] = clean
	# Старые сохранения: кто уже должен жить в деревне - живёт, без оповещений
	var est: Variant = save.get("estate", {})
	var main := 1
	if est is Dictionary and est.get("main") is Dictionary:
		main = int(est["main"].get("level", 1))
	for id in Residents.IDS:
		if main >= Residents.main_level(id):
			clean[id]["arrived"] = true


func _r(id: String) -> Dictionary:
	return Game.save["residents"][id]


func arrived(id: String) -> bool:
	return bool(_r(id)["arrived"])


func arrived_list() -> Array:
	return Residents.IDS.filter(func(id: String) -> bool: return arrived(id))


## Сколько глав пройдено.
func chapter(id: String) -> int:
	return int(_r(id)["chapter"])


func finished(id: String) -> bool:
	return chapter(id) >= Residents.chapters(id).size()


## Текущая глава (пусто, если история пройдена).
func current(id: String) -> Dictionary:
	if finished(id):
		return {}
	return Residents.chapters(id)[chapter(id)]


func state(id: String) -> String:
	if not arrived(id):
		return "away"
	if finished(id):
		return "done"
	if not bool(_r(id)["taken"]):
		return "new" if Game.level >= int(current(id)["level"]) else "locked"
	return "ready" if task_done(id) else "active"


## Прогресс задания: [сколько есть, сколько нужно]. Для give - по самому отстающему ресурсу.
func progress(id: String) -> Array:
	var task: Dictionary = current(id).get("task", {})
	match str(task.get("type", "")):
		"kill":
			var n := Game.combat.kills_of(task["kind"]) - int(_r(id)["base"])
			return [clampi(n, 0, int(task["n"])), int(task["n"])]
		"build":
			return [mini(Game.estate.level(task["id"]), int(task["n"])), int(task["n"])]
		"visit":
			return [1 if Game.world_map.is_unlocked(task["loc"]) else 0, 1]
		"give":
			var have := 0
			var need := 0
			for it in task["items"]:
				have += mini(Game.amount(it[0]), int(it[1]))
				need += int(it[1])
			return [have, need]
	return [0, 1]


func task_done(id: String) -> bool:
	var p := progress(id)
	return int(p[0]) >= int(p[1])


func take(id: String) -> void:
	if state(id) != "new":
		return
	var r := _r(id)
	r["taken"] = true
	var task: Dictionary = current(id)["task"]
	r["base"] = Game.combat.kills_of(task["kind"]) if task["type"] == "kill" else 0
	Game.emit_event("story_take", {"id": id})
	Game.mark_dirty()


## Сдать главу: ресурсы списываются, награда выдаётся. Возвращает награду (пусто - сдать нельзя).
func hand_in(id: String) -> Dictionary:
	if state(id) != "ready":
		return {}
	var n := chapter(id)
	var task: Dictionary = current(id)["task"]
	if task["type"] == "give":
		Game.pay({"items": task["items"]})
	var reward := Residents.reward(id, n)
	Game.add_coins(int(reward["coins"]))
	Game.gain_xp(int(reward["xp"]))
	Game.shop.add_crystals(int(reward["crystals"]))
	var r := _r(id)
	r["chapter"] = n + 1
	r["taken"] = false
	r["base"] = 0
	Sound.play("coinBig")
	Game.emit_event("story", {"id": id, "chapter": n + 1})
	Game.mark_dirty()
	Game.save_now()
	return reward


## Сколько жителей ждут: новое задание или можно сдать (значок на кнопке заданий).
func attention_count() -> int:
	var n := 0
	for id in Residents.IDS:
		var s := state(id)
		if s == "new" or s == "ready":
			n += 1
	return n


# MARK: Дружба

func friend_points(id: String) -> int:
	return int(_r(id)["friend"])


func friend_level(id: String) -> int:
	return Residents.friend_level(friend_points(id))


func gifts_left(id: String) -> int:
	var r := _r(id)
	if int(r["giftDay"]) != ShopSystem.day_index():
		return Residents.GIFTS_PER_DAY
	return maxi(0, Residents.GIFTS_PER_DAY - int(r["gifts"]))


## Подарить один товар со склада. Возвращает полученные очки (0 - нельзя).
func give(id: String, good: String) -> int:
	if not arrived(id) or gifts_left(id) <= 0 or Game.storage_of(good) <= 0:
		return 0
	var r := _r(id)
	var today := ShopSystem.day_index()
	if int(r["giftDay"]) != today:
		r["giftDay"] = today
		r["gifts"] = 0
	r["gifts"] = int(r["gifts"]) + 1
	Game.save["storage"][good] = Game.storage_of(good) - 1
	var before := friend_level(id)
	var pts := Residents.gift_points(id, good)
	r["friend"] = int(r["friend"]) + pts
	if friend_level(id) > before:
		Game.show_toast("px:heart", L.t("friend.levelUp", [Residents.name_of(id), friend_level(id)]))
		Sound.play("levelUp")
		Game.recalc()
	Game.mark_dirty()
	return pts


## Бонус дружбы по виду: множитель (1 - нет бонуса). Каждый житель усиливает своё.
func friend_mult(bonus: String) -> float:
	var m := 1.0
	if not Game.save.has("residents"):
		return m
	for id in Residents.FRIEND:
		var f: Dictionary = Residents.FRIEND[id]
		if str(f["bonus"]) == bonus and arrived(id):
			m += float(f["step"]) * float(friend_level(id))
	return m


## Кто переедет следующим (для подсказки в списке).
func next_away() -> String:
	for id in Residents.IDS:
		if not arrived(id):
			return id
	return ""


func on_event(name: String, data: Dictionary) -> void:
	if name != "build" or str(data.get("id", "")) != "main":
		return
	var main := int(data.get("level", 1))
	for id in Residents.IDS:
		if not arrived(id) and main >= Residents.main_level(id):
			_r(id)["arrived"] = true
			Game.show_toast("px:" + Residents.icon(id), L.t("resident.arrived", [Residents.name_of(id)]))
			Game.mark_dirty()
