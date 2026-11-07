class_name TourneySystem
extends RefCounted
## Турнир зверей: отряд, бои, дорожка наград недели и пропуск турнира (Game.rating.call_rpc -> tn_* из
## docs/supabase/tourney.sql). Бои и места считает сервер, награды выдаёт игра.
## В Game.save: squad - id зверей отряда по порядку, tourneyPasses - недели с купленным пропуском,
## tourneyTrack - {week, free: [ступени], paid: [ступени]} - что уже забрано на дорожке этой недели.

## Последний ответ tn_state: week, rating, squad, fights_left, buys_left, points, wins, log, top, last.
var state: Dictionary = {}
var busy := false
## Ошибка последнего действия (ключ строки tourney.err.*).
var error := ""
## Последний бой (ответ tn_fight) - показывается в окне, пока не закроют.
var last_fight: Dictionary = {}
## Снимки экрана: данные подставлены, сеть не трогаем.
var demo := false


func defaults(save: Dictionary) -> void:
	var sq: Variant = save.get("squad", [])
	save["squad"] = (sq as Array).map(func(x: Variant) -> String: return str(x)).slice(0, Tourney.SQUAD) if sq is Array else []
	var passes: Variant = save.get("tourneyPasses", [])
	save["tourneyPasses"] = (passes as Array).map(func(x: Variant) -> int: return int(x)).slice(-8) if passes is Array else []
	var tr: Variant = save.get("tourneyTrack", {})
	if not tr is Dictionary:
		tr = {}
	save["tourneyTrack"] = {"week": int(tr.get("week", 0)),
		"free": _ints(tr.get("free", [])), "paid": _ints(tr.get("paid", []))}


static func _ints(a: Variant) -> Array:
	if not a is Array:
		return []
	var out: Array = []
	for x in a:
		var n := int(x)
		if n >= 0 and n < Tourney.TRACK.size() and not n in out:
			out.append(n)
	return out


func open() -> bool:
	return Game.level >= Tourney.MIN_LEVEL


func online() -> bool:
	return OnlineConfig.enabled() or demo


func week() -> int:
	return int(state.get("week", DailySystem.week_index()))


# MARK: Отряд

## Отряд: свои звери по порядку. Пусто или звери пропали - самые сильные.
func squad() -> Array:
	var owned := Game.animals.owned()
	var list: Array = Game.save.get("squad", []).filter(func(id: Variant) -> bool: return str(id) in owned and Power.animal(str(id)) > 0)
	if list.is_empty():
		var powers := {}
		for id in owned:
			powers[id] = Power.animal(id)
		list = Tourney.best_squad(powers)
	return list.slice(0, Tourney.SQUAD)


## Поставить зверя в ячейку отряда (если он уже в отряде - меняются местами).
func set_slot(slot: int, id: String) -> void:
	var list := squad()
	if slot < 0 or slot >= Tourney.SQUAD or not id in Game.animals.owned():
		return
	var at := list.find(id)
	if slot < list.size():
		if at >= 0:
			list[at] = list[slot]
		list[slot] = id
	elif at < 0:
		list.append(id)
	Game.save["squad"] = list
	Game.mark_dirty()
	Game.changed.emit()


func squad_power() -> int:
	var sum := 0
	for id in squad():
		sum += Power.animal(str(id))
	return sum


func _payload() -> Array:
	return squad().map(func(id: Variant) -> Dictionary: return {"id": str(id), "p": Power.animal(str(id))})


func _args() -> Dictionary:
	return {"p_squad": _payload(), "p_name": Game.rating.player_name(), "p_level": Game.level}


# MARK: Сервер

func fetch() -> void:
	if demo or busy or not OnlineConfig.enabled():
		return
	busy = true
	var res: Variant = await Game.rating.call_rpc("tn_state", _args())
	busy = false
	if res is Dictionary:
		state = res
		error = ""
		_roll_track()
	else:
		error = "network"
	Game.changed.emit()


func fights_left() -> int:
	return int(state.get("fights_left", 0))


func buys_left() -> int:
	return int(state.get("buys_left", 0))


func points() -> int:
	return int(state.get("points", 0))


func fight() -> void:
	if busy or fights_left() <= 0 or squad().is_empty():
		return
	busy = true
	var res: Variant = await Game.rating.call_rpc("tn_fight", _args())
	busy = false
	if not res is Dictionary:
		_fail()
		return
	last_fight = res
	Sound.play("purchase" if bool(res.get("won", false)) else "error")
	await fetch()


func buy_fights() -> void:
	if busy or buys_left() <= 0:
		return
	if Game.shop.crystals() < Tourney.BUY_CRYSTALS:
		Game.show_toast("px:gem", L.t("crystals.notEnough", [Fmt.n(Tourney.BUY_CRYSTALS - Game.shop.crystals())]))
		return
	busy = true
	var res: Variant = await Game.rating.call_rpc("tn_buy", {})
	busy = false
	if res == null:
		_fail()
		return
	Game.shop.spend_crystals(Tourney.BUY_CRYSTALS)
	Sound.play("purchase")
	Game.mark_dirty()
	await fetch()


## Прошлая неделя: {week, place, points, claimed} или пусто.
func last_week() -> Dictionary:
	var l: Variant = state.get("last")
	return l if l is Dictionary else {}


func can_claim_week() -> bool:
	var l := last_week()
	return not l.is_empty() and not bool(l.get("claimed", true))


func claim_week() -> void:
	if busy or not can_claim_week():
		return
	busy = true
	var res: Variant = await Game.rating.call_rpc("tn_claim", {})
	busy = false
	if not res is Dictionary:
		_fail()
		await fetch()
		return
	var r := Tourney.place_reward(int(res.get("place", 999)), Game.level)
	Game.add_coins(int(r["coins"]))
	Game.shop.add_crystals(int(r["crystals"]))
	Game.show_toast("px:trophy", L.t("tourney.weekClaimed", [int(res.get("place", 0)), Fmt.n(int(r["coins"])), int(r["crystals"])]))
	Game.mark_dirty()
	await fetch()


func _fail() -> void:
	var e := Game.rating.last_error
	error = {"no fights": "noFights", "no squad": "noSquad", "limit": "limit", "already claimed": "claimed"}.get(e, "network")
	Game.changed.emit()


# MARK: Дорожка и пропуск

func has_pass() -> bool:
	return week() in Game.save.get("tourneyPasses", []) or Game.shop.max_active()


## Покупка пропуска (PremiumSystem.grant): платная дорожка этой недели.
func activate_pass() -> void:
	var passes: Array = Game.save.get("tourneyPasses", [])
	if not week() in passes:
		passes.append(week())
	Game.save["tourneyPasses"] = passes.slice(-8)
	Game.mark_dirty()
	Game.changed.emit()


func _track() -> Dictionary:
	_roll_track()
	return Game.save["tourneyTrack"]


## Новая неделя - дорожка с нуля.
func _roll_track() -> void:
	var t: Dictionary = Game.save.get("tourneyTrack", {})
	if int(t.get("week", 0)) != week():
		Game.save["tourneyTrack"] = {"week": week(), "free": [], "paid": []}


func tier_claimed(tier: int, paid: bool) -> bool:
	return tier in _track()["paid" if paid else "free"]


func can_claim_tier(tier: int, paid: bool) -> bool:
	return tier < Tourney.tiers_open(points()) and not tier_claimed(tier, paid) and (not paid or has_pass())


func claim_tier(tier: int, paid: bool) -> void:
	if not can_claim_tier(tier, paid):
		return
	var r := Tourney.tier_reward(tier, paid, Game.level)
	Game.add_coins(int(r.get("coins", 0)))
	Game.shop.add_crystals(int(r.get("crystals", 0)))
	for k in Chests.KEYS:
		if r.has(k):
			Game.chests.add_keys(k, int(r[k]), false)
	_track()["paid" if paid else "free"].append(tier)
	Sound.play("purchase")
	Game.show_toast("px:chest_gold", L.t("tourney.tierClaimed", [tier + 1]))
	Game.mark_dirty()
	Game.changed.emit()


## Что можно забрать (для отметки на вкладке).
func ready_count() -> int:
	if not open() or state.is_empty():
		return 0
	var n := 1 if can_claim_week() else 0
	for i in Tourney.tiers_open(points()):
		if can_claim_tier(i, false):
			n += 1
		if can_claim_tier(i, true):
			n += 1
	return n
