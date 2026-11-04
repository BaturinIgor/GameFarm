class_name FarmEventSystem
extends RefCounted
## Фарм-ивенты на основных локациях (данные в data/farm_events.gd). Идут одновременно с праздником.
## В Game.save: farmKey, farmPoints, farmClaimed (ступени), farmSeen, farmBest (лучший результат по ивенту).
## Очки: ивентовые монстры (MonstersFeature зовёт on_farm_kill) и точки ресурсов (World зовёт on_spot).


func defaults(save: Dictionary) -> void:
	save["farmKey"] = str(save.get("farmKey", ""))
	save["farmSeen"] = str(save.get("farmSeen", ""))
	save["farmPoints"] = int(save.get("farmPoints", 0))
	var claimed: Array = []
	for t in save.get("farmClaimed", []):
		claimed.append(int(t))
	save["farmClaimed"] = claimed
	var best = save.get("farmBest", {})
	save["farmBest"] = best if best is Dictionary else {}


func is_open() -> bool:
	return Game.events.events_open()


func current() -> Dictionary:
	return FarmEvents.current()


func event_id() -> String:
	return str(FarmEvents.current()["event"])


func points() -> int:
	sync()
	return int(Game.save.get("farmPoints", 0))


func step() -> int:
	return FarmEvents.step_of(event_id(), points())


func is_new() -> bool:
	return is_open() and str(Game.save.get("farmSeen", "")) != str(FarmEvents.current()["key"])


func mark_seen() -> void:
	var key := str(FarmEvents.current()["key"])
	if str(Game.save.get("farmSeen", "")) == key:
		return
	Game.save["farmSeen"] = key
	Game.mark_dirty()


## Начался новый фарм-ивент: незабранные награды прошлого выдаём сами, очки обнуляем.
func sync() -> void:
	var run := FarmEvents.current()
	var s := Game.save
	if str(s.get("farmKey", "")) == run["key"]:
		return
	var old := str(s.get("farmKey", ""))
	if old != "":
		_claim_leftovers(old)
	s["farmKey"] = run["key"]
	s["farmPoints"] = 0
	s["farmClaimed"] = []
	if is_open() and old != "":
		Game.show_toast("px:" + FarmEvents.icon(run["event"]), L.t("toast.farmStarted", [FarmEvents.name_of(run["event"])]))
	Game.mark_dirty()


func _claim_leftovers(key: String) -> void:
	var parts := key.split("-")
	if parts.size() < 2 or not parts[1] in FarmEvents.IDS:
		return
	var event := parts[1]
	var reached := FarmEvents.step_of(event, int(Game.save.get("farmPoints", 0)))
	var any := false
	for t in range(1, reached + 1):
		if not t in Game.save.get("farmClaimed", []):
			_grant(FarmEvents.reward(t))
			any = true
	if any:
		Game.show_toast("px:chest", L.t("toast.eventLeftovers", [FarmEvents.name_of(event)]))


# MARK: Очки

func add(n: int) -> void:
	if n <= 0 or not is_open():
		return
	sync()
	var event := event_id()
	var before := step()
	Game.save["farmPoints"] = int(Game.save["farmPoints"]) + n
	var best: Dictionary = Game.save["farmBest"]
	best[event] = maxi(int(best.get(event, 0)), int(Game.save["farmPoints"]))
	var after := step()
	if after > before:
		Game.show_toast("px:" + FarmEvents.icon(event), L.t("toast.farmStep", [after, FarmEvents.MILESTONES]))
		Sound.play("unlock")
	Game.mark_dirty()


## Сейчас охота: на основных локациях есть ивентовые монстры этого вида.
func hunt_monster() -> String:
	if not is_open():
		return ""
	var event := event_id()
	return str(FarmEvents.MONSTER.get(event, "")) if FarmEvents.kind(event) == "hunt" else ""


## Какой hunt-ивент идёт ("" - сейчас не охота).
func hunt_monster_event() -> String:
	return event_id() if hunt_monster() != "" else ""


func on_farm_kill() -> int:
	if hunt_monster() == "":
		return 0
	add(FarmEvents.KILL_POINTS)
	return FarmEvents.KILL_POINTS


## Герой добыл точку ресурса на основной локации.
func on_spot(tool: String) -> int:
	if not is_open():
		return 0
	var event := event_id()
	if FarmEvents.kind(event) != "gather" or str(FarmEvents.TOOL.get(event, "")) != tool:
		return 0
	add(FarmEvents.SPOT_POINTS)
	return FarmEvents.SPOT_POINTS


# MARK: Награды

func can_claim(t: int) -> bool:
	return is_open() and t >= 1 and t <= step() and not t in Game.save.get("farmClaimed", [])


func claimable() -> int:
	if not is_open():
		return 0
	var n := 0
	for t in range(1, step() + 1):
		if can_claim(t):
			n += 1
	return n


func claim(t: int) -> void:
	sync()
	if not can_claim(t):
		return
	Game.save["farmClaimed"].append(t)
	_grant(FarmEvents.reward(t))
	Sound.play("treasure")
	Game.mark_dirty()
	Game.save_now()


func claim_all() -> void:
	sync()
	var any := false
	for t in range(1, step() + 1):
		if can_claim(t):
			Game.save["farmClaimed"].append(t)
			_grant(FarmEvents.reward(t))
			any = true
	if not any:
		return
	Sound.play("treasure")
	Game.mark_dirty()
	Game.save_now()


func _grant(reward: Dictionary) -> void:
	var n := FarmEvents.scaled(reward, Game.level)
	var s := Game.save
	match str(reward["type"]):
		"coins":
			Game.add_coins(n)
		"planks":
			# Награда не пропадает, даже если склад полон
			s["storage"]["planks"] = int(s["storage"].get("planks", 0)) + n
		"crystals":
			Game.shop.add_crystals(n)
		"tickets":
			s["tickets"] = int(s.get("tickets", 0)) + n
		"cards":
			for _i in n:
				Game.collection.random_card()
		"sparks":
			s["sparks"] = int(s.get("sparks", 0)) + n
			s["sparksEarned"] = int(s.get("sparksEarned", 0)) + n
