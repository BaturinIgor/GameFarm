class_name WarSystem
extends RefCounted
## Карта войны альянсов (Game.rating.call_rpc -> al_war / war_* из docs/supabase/alliance_war.sql).
## Лигу, точки, атаки и очки считает сервер, монеты за победы и награду за место выдаёт игра.
## В Game.save: warPasses - недели со «Знаменем войны», warBanner - знамя покупалось (рамка статуи).

## Последний ответ al_war: league, slot, ends, teams, nodes [[точка, слот владельца, щиты, гарнизон, можно атаковать]],
## chest, boost, used, max, pass, donates, wins, power, log, reward.
var state: Dictionary = {}
var busy := false
## Ошибка последнего действия (ключ строки alliance.err.*).
var error := ""
## Последняя атака (ответ war_attack с номером точки) - показывается на карте.
var last: Dictionary = {}
## Выбранная на карте точка (-1 - ничего).
var selected := -1
## Снимки экрана: данные подставлены, сеть не трогаем.
var demo := false
## Живая карта (war_map): false - на сервере ещё нет alliance_war_march.sql, работаем по-старому.
var live := true
## Разница часов сервера и телефона (секунды), чтобы отряды шли по серверному времени.
var _clock := 0.0


func defaults(save: Dictionary) -> void:
	var passes: Variant = save.get("warPasses", [])
	save["warPasses"] = (passes as Array).map(func(x: Variant) -> int: return int(x)).slice(-8) if passes is Array else []
	save["warBanner"] = bool(save.get("warBanner", false))


func week() -> int:
	return DailySystem.week_index()


func joined() -> bool:
	return state.get("league") != null and int(state.get("league", 0)) > 0


func fetch() -> void:
	if demo or busy or not OnlineConfig.enabled() or not Game.alliance.in_alliance():
		return
	busy = true
	var args := {"p_name": Game.rating.player_name(), "p_level": Game.level}
	var res: Variant = null
	if live:
		res = await Game.rating.call_rpc("war_map", args)
		if res == null and Game.rating.last_error.contains("war_map"):
			live = false
	if not live:
		res = await Game.rating.call_rpc("al_war", args)
	busy = false
	if res is Dictionary:
		state = res
		error = ""
		if state.has("now"):
			_clock = float(state["now"]) - Time.get_unix_time_from_system()
		_take_results()
		# Знамя куплено, а сервер о нём не знает (не было сети) - сообщаем ещё раз
		if has_pass() and not bool(state.get("pass", false)):
			if await Game.rating.call_rpc("war_pass", {}) != null:
				state["pass"] = true
				state["max"] = War.attacks(true)
	else:
		error = "network"
	Game.changed.emit()


# MARK: Точки и команды

func my_slot() -> int:
	return int(state.get("slot", 0))


## Точка карты: {owner (слот, 0 - ничья), shields, garrison, reach}. Базы - за своими слотами.
func node(n: int) -> Dictionary:
	if War.is_base(n):
		return {"owner": n if team(n).size() > 0 else 0, "shields": 0, "garrison": 0, "reach": false}
	for x in state.get("nodes", []):
		if x is Array and x.size() >= 5 and int(x[0]) == n:
			return {"owner": int(x[1]), "shields": int(x[2]), "garrison": int(x[3]), "reach": bool(x[4])}
	return {"owner": 0, "shields": 0, "garrison": 0, "reach": false}


## Альянс лиги по слоту (пусто - слот свободен).
func team(slot: int) -> Dictionary:
	for t in state.get("teams", []):
		if t is Dictionary and int(t.get("slot", 0)) == slot:
			return t
	return {}


## Альянсы лиги по очкам.
func teams() -> Array:
	return state.get("teams", []).filter(func(t: Variant) -> bool: return t is Dictionary)


func my_place() -> int:
	var list := teams()
	for i in list.size():
		if bool(list[i].get("me", false)):
			return i + 1
	return 0


func attacks_left() -> int:
	return maxi(0, int(state.get("max", War.ATTACKS)) - int(state.get("used", 0)))


func donates_left() -> int:
	return maxi(0, War.DONATES_PER_DAY - int(state.get("donates", 0)))


func chest() -> int:
	return int(state.get("chest", 0))


func power() -> int:
	return maxi(int(state.get("power", 0)), Power.total())


func chance(n: int) -> float:
	return War.chance(power(), chest(), int(node(n).get("garrison", 0)))


func can_attack(n: int) -> bool:
	var d := node(n)
	return joined() and not War.is_base(n) and int(d["owner"]) != my_slot() and bool(d["reach"]) and attacks_left() > 0


func can_reinforce(n: int) -> bool:
	var d := node(n)
	return joined() and not War.is_base(n) and int(d["owner"]) == my_slot() and my_slot() > 0 \
		and int(d["shields"]) < War.max_shields(War.tier(n)) and attacks_left() > 0


# MARK: Действия

func attack(n: int, reinforce := false) -> void:
	if busy or (not can_reinforce(n) if reinforce else not can_attack(n)):
		return
	if demo:
		last = {"node": n, "won": true, "captured": not reinforce, "reinforced": reinforce, "chance": chance(n)}
		Game.changed.emit()
		return
	busy = true
	var res: Variant = await Game.rating.call_rpc("war_attack", {"p_node": n, "p_reinforce": reinforce, "p_name": Game.rating.player_name()})
	busy = false
	if not res is Dictionary:
		_fail()
		await fetch()
		return
	last = res.duplicate()
	last["node"] = n
	if bool(res.get("won", false)) and not bool(res.get("reinforced", false)):
		var coins := War.win_coins(Game.level, bool(res.get("captured", false)))
		Game.add_coins(coins)
		last["coins"] = coins
		Sound.play("purchase")
	elif bool(res.get("reinforced", false)):
		Sound.play("purchase")
	else:
		Sound.play("error")
	Game.mark_dirty()
	await fetch()


## Вложить монеты в казну войны: буст атаки всего альянса.
func donate() -> void:
	var coins := War.donate_coins(Game.level)
	if busy or donates_left() <= 0 or not joined():
		return
	if int(Game.save["coins"]) < coins:
		Game.show_toast("px:coin", L.t("war.noCoins"))
		return
	if demo:
		state["chest"] = chest() + coins
		state["donates"] = int(state.get("donates", 0)) + 1
		Game.changed.emit()
		return
	busy = true
	var res: Variant = await Game.rating.call_rpc("war_donate", {"p_coins": coins})
	busy = false
	if res == null:
		_fail()
		return
	Game.save["coins"] = int(Game.save["coins"]) - coins
	Sound.play("purchase")
	Game.show_toast("px:coin", L.t("war.donated", [Fmt.n(coins)]))
	Game.mark_dirty()
	await fetch()


## Награда за место альянса в прошлой неделе: {week, place, teams} или пусто.
func reward() -> Dictionary:
	var r: Variant = state.get("reward")
	return r if r is Dictionary else {}


func claim() -> void:
	if busy or reward().is_empty():
		return
	busy = true
	var res: Variant = await Game.rating.call_rpc("war_claim", {})
	busy = false
	if not res is Dictionary:
		_fail()
		await fetch()
		return
	var place := int(res.get("place", 8))
	var r := War.place_reward(place, Game.level)
	Game.add_coins(int(r["coins"]))
	Game.shop.add_crystals(int(r["crystals"]))
	Sound.play("purchase")
	Game.show_toast("px:trophy", L.t("war.claimed", [place, Fmt.n(int(r["coins"])), int(r["crystals"])]))
	Game.mark_dirty()
	await fetch()


# MARK: Живая карта: отряды, сборы, гарнизоны

func now() -> float:
	return Time.get_unix_time_from_system() + _clock


## Отряды в пути: [{id, name, node, kind, slot, from, at, me, animal}].
func marches() -> Array:
	return (state.get("marches", []) as Array).filter(func(x: Variant) -> bool: return x is Dictionary)


func my_marches() -> Array:
	return marches().filter(func(m: Dictionary) -> bool: return bool(m.get("me", false)))


## Сборы: [{id, node, leader, slot, fires, power, members, mine, joined}].
func rallies() -> Array:
	return (state.get("rallies", []) as Array).filter(func(x: Variant) -> bool: return x is Dictionary)


func my_rally() -> Dictionary:
	for r in rallies():
		if bool(r.get("mine", false)):
			return r
	return {}


## Зверь в гарнизоне точки: [зверь, кто оставил] или пусто.
func guard(n: int) -> Array:
	for g in state.get("guards", []):
		if g is Array and g.size() >= 3 and int(g[0]) == n and g[1] != null:
			return [str(g[1]), str(g[2])]
	return []


## Видно ли точку (туман войны): свои, соседние со своими, базы и замок.
func visible(n: int) -> bool:
	if War.is_base(n) or n == 0 or not joined():
		return true
	var mine := my_slot()
	if int(node(n)["owner"]) == mine:
		return true
	for m in War.neighbors(n):
		if m == mine or (not War.is_base(m) and int(node(m)["owner"]) == mine):
			return true
	return false


## Откуда идёт отряд к точке: соседняя точка или база этого альянса.
func origin(n: int, slot: int) -> int:
	for m in War.neighbors(n):
		if m == slot or (not War.is_base(m) and int(node(m)["owner"]) == slot):
			return m
	return slot


func can_march(n: int) -> bool:
	return can_attack(n) and War.tier(n) != 4 and my_marches().size() < War.MAX_MARCHES \
		and not marches().any(func(m: Dictionary) -> bool: return bool(m.get("me", false)) and int(m.get("node", -1)) == n)


func can_rally(n: int) -> bool:
	return can_attack(n) and my_rally().is_empty() and live


func can_join(r: Dictionary) -> bool:
	return bool(r.get("mine", false)) and not bool(r.get("joined", false)) and attacks_left() > 0 \
		and int(r.get("members", 0)) < War.RALLY_MAX and float(r.get("fires", 0)) > now()


func can_guard(n: int) -> bool:
	var d := node(n)
	return joined() and live and not War.is_base(n) and int(d["owner"]) == my_slot() and my_slot() > 0 \
		and attacks_left() > 0 and my_marches().size() < War.MAX_MARCHES


## Отправить отряд (атака или укрепление со зверем). Без живой карты на сервере - мгновенная атака, как раньше.
func march(n: int, reinforce := false, animal := "") -> void:
	if busy:
		return
	if not live:
		await attack(n, reinforce)
		return
	if not (can_guard(n) if reinforce else can_march(n)):
		return
	var ap := mini(War.ANIMAL_CAP, Power.animal(animal)) if animal != "" else 0
	if demo:
		var t := now()
		var list: Array = state.get("marches", [])
		list.append({"id": 900 + list.size(), "name": Game.rating.player_name(), "node": n, "kind": "reinforce" if reinforce else "attack",
			"slot": my_slot(), "from": t, "at": t + War.march_secs(War.tier(n)), "me": true, "animal": animal if animal != "" else null})
		state["marches"] = list
		state["used"] = int(state.get("used", 0)) + 1
		Game.changed.emit()
		return
	busy = true
	var res: Variant = await Game.rating.call_rpc("war_march", {"p_node": n, "p_reinforce": reinforce, "p_name": Game.rating.player_name(),
		"p_animal": animal if animal != "" else null, "p_animal_power": ap})
	busy = false
	if not res is Dictionary:
		_fail()
		await fetch()
		return
	Sound.play("purchase")
	Game.show_toast("px:swords", L.t("war.marching", [Fmt.seconds(float(res.get("secs", 60)))]))
	await fetch()


func rally(n: int) -> void:
	if busy or not can_rally(n):
		return
	if demo:
		var list: Array = state.get("rallies", [])
		list.append({"id": 50, "node": n, "leader": Game.rating.player_name(), "slot": my_slot(), "fires": now() + War.RALLY_SECS,
			"power": power(), "members": 1, "mine": true, "joined": true})
		state["rallies"] = list
		state["used"] = int(state.get("used", 0)) + 1
		Game.changed.emit()
		return
	busy = true
	var res: Variant = await Game.rating.call_rpc("war_rally", {"p_node": n, "p_name": Game.rating.player_name()})
	busy = false
	if not res is Dictionary:
		_fail()
		await fetch()
		return
	Sound.play("purchase")
	Game.show_toast("px:swords", L.t("war.rallyStarted"))
	await fetch()


func join_rally(r: Dictionary) -> void:
	if busy or not can_join(r):
		return
	if demo:
		r["joined"] = true
		r["members"] = int(r.get("members", 0)) + 1
		r["power"] = int(r.get("power", 0)) + power()
		state["used"] = int(state.get("used", 0)) + 1
		Game.changed.emit()
		return
	busy = true
	var res: Variant = await Game.rating.call_rpc("war_rally_join", {"p_rally": int(r.get("id", 0)), "p_name": Game.rating.player_name()})
	busy = false
	if not res is Dictionary:
		_fail()
		await fetch()
		return
	Sound.play("purchase")
	await fetch()


## Исходы моих дошедших отрядов: монеты за победы и тост - один раз на отряд (номера помним в сохранении).
func _take_results() -> void:
	var seen: Array = Game.save.get("warSeen", [])
	var changed := false
	for r in state.get("results", []):
		if not r is Dictionary or int(r.get("id", 0)) in seen:
			continue
		seen.append(int(r.get("id", 0)))
		changed = true
		var res := str(r.get("result", ""))
		var n := int(r.get("node", 0))
		last = {"node": n, "won": res in ["win", "capture", "reinforce"], "captured": res == "capture", "reinforced": res == "reinforce"}
		if res == "win" or res == "capture":
			var coins := War.win_coins(Game.level, res == "capture")
			Game.add_coins(coins)
			last["coins"] = coins
			Sound.play("purchase")
		Game.show_toast("px:swords", L.t("war.result." + res, [_short_name(n)]))
	if changed:
		Game.save["warSeen"] = seen.slice(-40)
		Game.mark_dirty()


static func _short_name(n: int) -> String:
	if n == 0:
		return L.t("war.castle")
	return L.t("war.post", [n - War.TEAMS])


func _fail() -> void:
	var e := Game.rating.last_error
	error = e if e in ["limit", "not allowed", "already claimed", "bad lot", "busy", "full"] else "network"
	Game.changed.emit()


# MARK: Знамя войны

func has_pass() -> bool:
	return week() in Game.save.get("warPasses", [])


## Покупка «Знамени войны» (PremiumSystem.grant): +3 атаки в день на эту неделю и рамка статуи навсегда.
func activate_pass() -> void:
	var passes: Array = Game.save.get("warPasses", [])
	if not week() in passes:
		passes.append(week())
	Game.save["warPasses"] = passes.slice(-8)
	Game.save["warBanner"] = true
	Game.mark_dirty()
	if not demo and OnlineConfig.enabled() and Game.alliance.in_alliance():
		if await Game.rating.call_rpc("war_pass", {}) != null:
			state["pass"] = true
			state["max"] = War.attacks(true)
	Game.changed.emit()


## Что ждёт игрока (для отметки на вкладке событий): атаки и награда.
func ready_count() -> int:
	if not joined() and reward().is_empty():
		return 0
	return (1 if attacks_left() > 0 and joined() else 0) + (0 if reward().is_empty() else 1)
