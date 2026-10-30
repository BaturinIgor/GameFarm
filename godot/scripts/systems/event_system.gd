class_name EventSystem
extends RefCounted
## Ивенты, пропуск, этапы и усиления (порт расширения "Ивенты" из GameState.swift).
## Данные в Game.save: eventKey, eventPoints, eventFree, eventVip, eventBonus, vipKeys, eventSeen, eventDecor,
## eventSkins, eventStage, eventProgress, eventBest, eventBoons, eventChoice.
## Очки дают особые точки праздника (world.gd зовёт points_for_node и add_points) и монстры (событие kill).

## Растёт, когда меняется карта этапа или начинается новый ивент: сцена перестраивает карту ивента.
var map_version := 0


func defaults(save: Dictionary) -> void:
	save["eventKey"] = str(save.get("eventKey", ""))
	save["eventSeen"] = str(save.get("eventSeen", ""))
	for key in ["eventPoints", "eventBonus", "eventProgress", "eventBest"]:
		save[key] = int(save.get(key, 0))
	save["eventStage"] = maxi(1, int(save.get("eventStage", 1)))
	for key in ["eventFree", "eventVip"]:
		var list: Array = []
		for t in save.get(key, []):
			list.append(int(t))
		save[key] = list
	for key in ["vipKeys", "eventSkins"]:
		var names: Array = []
		for k in save.get(key, []):
			names.append(str(k))
		save[key] = names
	var boons := {}
	var raw_boons = save.get("eventBoons", {})
	if raw_boons is Dictionary:
		for b in raw_boons:
			if str(b) in Events.BOONS:
				boons[str(b)] = int(raw_boons[b])
	save["eventBoons"] = boons
	var choice: Array = []
	for b in save.get("eventChoice", []):
		if str(b) in Events.BOONS:
			choice.append(str(b))
	save["eventChoice"] = choice
	# Ивент закончился, пока игра была закрыта: возвращаемся домой.
	var here := str(save.get("current", "meadow"))
	if Locations.kind(here) == "event" and Events.location(Events.current()["event"]) != here:
		save["current"] = "meadow"


# MARK: Состояние

func events_open() -> bool:
	return Game.level >= Events.MIN_LEVEL


## Пропуск куплен на этот ивент или действует MAX.
func has_vip() -> bool:
	return Events.current()["key"] in Game.save.get("vipKeys", []) or Game.shop.max_active()


func event_tier() -> int:
	return Events.tier(int(Game.save.get("eventPoints", 0)))


func in_event() -> bool:
	return Locations.kind(Game.current) == "event"


## Ивент ещё не открывали: на кнопке горит отметка.
func event_is_new() -> bool:
	return events_open() and str(Game.save.get("eventSeen", "")) != Events.current()["key"]


func mark_event_seen() -> void:
	var key: String = Events.current()["key"]
	if str(Game.save.get("eventSeen", "")) == key:
		return
	Game.save["eventSeen"] = key
	Game.mark_dirty()


## Карта ивента открыта (часть isUnlocked для локаций ивентов).
func is_unlocked(location_id: String) -> bool:
	return events_open() and Events.location(Events.current()["event"]) == location_id


## Имя файла карты: у ивентов на каждом этапе своя карта (LocationLayout.resourceName).
func resource_name(location_id: String) -> String:
	if Locations.kind(location_id) != "event":
		return location_id
	var run := Events.current()
	var stage := int(Game.save.get("eventStage", 1)) if str(Game.save.get("eventKey", "")) == run["key"] else 1
	var v := Events.variant(stage, int(run["index"]))
	return "%s_%d" % [location_id, v] if v > 0 else location_id


## Начался новый проход ивента: незабранные награды выдаём сами, очки обнуляем.
func sync_event() -> void:
	var run := Events.current()
	var s := Game.save
	if str(s.get("eventKey", "")) == run["key"]:
		return
	if str(s.get("eventKey", "")) != "":
		_claim_leftovers(str(s["eventKey"]))
	var first := str(s.get("eventKey", "")) == ""
	s["eventKey"] = run["key"]
	s["eventPoints"] = 0
	s["eventFree"] = []
	s["eventVip"] = []
	s["eventBonus"] = 0
	s["eventStage"] = 1
	s["eventProgress"] = 0
	s["eventBest"] = 0
	s["eventBoons"] = {}
	s["eventChoice"] = []
	map_version += 1
	if events_open() and not first:
		Game.show_toast("px:star", L.t("toast.eventStarted", [Events.name_of(run["event"])]))
	Game.mark_dirty()


func _claim_leftovers(key: String) -> void:
	var event: String = key.split("-")[0]
	if not event in Events.IDS:
		return
	var points := int(Game.save.get("eventPoints", 0))
	var tier_n := Events.tier(points)
	if tier_n <= 0:
		return
	var vip: bool = key in Game.save.get("vipKeys", [])
	var any := false
	# Бонусные сундуки после последней ступени тоже не пропадают
	var extra := points - Events.total()
	var chests := extra / Events.BONUS_EVERY - int(Game.save.get("eventBonus", 0)) if extra >= Events.BONUS_EVERY else 0
	if chests > 0:
		Game.save["eventBonus"] = int(Game.save.get("eventBonus", 0)) + chests
		Game.add_coins(Events.bonus_coins(Game.level) * chests)
		for _i in chests:
			_random_card()
		any = true
	for t in range(1, tier_n + 1):
		if not t in Game.save["eventFree"]:
			_grant_event_reward(Events.free_reward(t), event)
			any = true
		if vip and not t in Game.save["eventVip"]:
			_grant_event_reward(Events.vip_reward(t), event)
			any = true
	if any:
		Game.show_toast("px:chest", L.t("toast.eventLeftovers", [Events.name_of(event)]))


# MARK: Пропуск

func can_claim_event(tier_n: int, vip: bool) -> bool:
	if tier_n > event_tier():
		return false
	if vip:
		return has_vip() and not tier_n in Game.save.get("eventVip", [])
	return not tier_n in Game.save.get("eventFree", [])


## Бонусные сундуки после последней ступени.
func event_bonus_ready() -> int:
	var extra := int(Game.save.get("eventPoints", 0)) - Events.total()
	if extra < Events.BONUS_EVERY:
		return 0
	return extra / Events.BONUS_EVERY - int(Game.save.get("eventBonus", 0))


## Сколько наград ждёт (для значка на кнопке).
func event_claimable() -> int:
	if not events_open():
		return 0
	var n := 0
	for t in range(1, Events.TIERS + 1):
		if can_claim_event(t, false):
			n += 1
		if can_claim_event(t, true):
			n += 1
	return n + maxi(0, event_bonus_ready())


func claim_event(tier_n: int, vip: bool) -> void:
	sync_event()
	if not can_claim_event(tier_n, vip):
		return
	var event: String = Events.current()["event"]
	if vip:
		Game.save["eventVip"].append(tier_n)
		_grant_event_reward(Events.vip_reward(tier_n), event)
	else:
		Game.save["eventFree"].append(tier_n)
		_grant_event_reward(Events.free_reward(tier_n), event)
	Sound.play("treasure")
	Game.mark_dirty()
	Game.save_now()


func claim_all_event() -> void:
	sync_event()
	var event: String = Events.current()["event"]
	var any := false
	for t in range(1, Events.TIERS + 1):
		if can_claim_event(t, false):
			Game.save["eventFree"].append(t)
			_grant_event_reward(Events.free_reward(t), event)
			any = true
		if can_claim_event(t, true):
			Game.save["eventVip"].append(t)
			_grant_event_reward(Events.vip_reward(t), event)
			any = true
	if event_bonus_ready() > 0:
		claim_event_bonus()
		any = true
	if not any:
		return
	Sound.play("treasure")
	Game.mark_dirty()
	Game.save_now()


func claim_event_bonus() -> void:
	var n := event_bonus_ready()
	if n <= 0:
		return
	Game.save["eventBonus"] = int(Game.save.get("eventBonus", 0)) + n
	Game.add_coins(Events.bonus_coins(Game.level) * n)
	for _i in n:
		_random_card()
	Game.show_toast("px:chest", L.t("toast.eventBonus", [n]))
	Game.mark_dirty()


func event_reward_coins(base: int) -> int:
	return Events.coins(base, Game.level)


func _grant_event_reward(reward: Dictionary, event: String) -> void:
	var n := int(reward.get("n", 0))
	var s := Game.save
	match str(reward["type"]):
		"coins":
			Game.add_coins(event_reward_coins(n))
		"tickets":
			s["tickets"] = int(s.get("tickets", 0)) + n
		"seeds":
			var seeds: Dictionary = s.get("seeds", {})
			var crop: String = Events.CROP[event]
			seeds[crop] = int(seeds.get(crop, 0)) + n
			s["seeds"] = seeds
		"dish":
			var dishes: Dictionary = s.get("dishes", {})
			var dish: String = Events.DISH[event]
			dishes[dish] = int(dishes.get(dish, 0)) + n
			s["dishes"] = dishes
		"cards":
			for _i in n:
				_random_card()
		"sparks":
			s["sparks"] = int(s.get("sparks", 0)) + n
			s["sparksEarned"] = int(s.get("sparksEarned", 0)) + n
		"maps":
			s["maps"] = int(s.get("maps", 0)) + n
		"decor":
			var decor := Events.decor_of(event)
			var owned: Array = s.get("eventDecor", [])
			if decor in owned:
				Game.add_coins(event_reward_coins(1500))
			else:
				owned.append(decor)
				s["eventDecor"] = owned
				Game.show_toast("px:stairs", L.t("toast.eventDecor", [House.decor_name(decor)]))
		"skin":
			var skin := Events.skin_of(event)
			var skins: Array = s.get("eventSkins", [])
			if skin in skins:
				Game.add_coins(event_reward_coins(3000))
			else:
				skins.append(skin)
				s["eventSkins"] = skins
				Game.show_toast("skin:" + skin, L.t("toast.eventSkin", [L.t("skin." + skin)]))


## Случайная карта коллекции (если коллекция уже есть).
func _random_card() -> void:
	if Game.collection.has_method("random_card"):
		Game.collection.call("random_card")


# MARK: Очки

## Очки ивента за добычу и монстров на карте ивента: идут и в пропуск, и в цель этапа.
## Возвращает, сколько очков начислено с учётом усилений.
func add_event_points(base: int) -> int:
	if base <= 0 or not in_event():
		return 0
	sync_event()
	var n := int(round(float(base) * (1.0 + boon_value("points"))))
	_add_pass_points(n)
	_add_stage_progress(n)
	Game.mark_dirty()
	return n


## Начислить очки ивента; возвращает, сколько начислено (add_event_points).
func add_points(n: int) -> int:
	return add_event_points(n)


func _add_pass_points(n: int) -> void:
	var before := event_tier()
	Game.save["eventPoints"] = int(Game.save.get("eventPoints", 0)) + n
	var after := event_tier()
	if after > before:
		Game.show_toast("px:star", L.t("toast.eventTier", [after]))
		Sound.play("unlock")


## Монстр побеждён на карте ивента: очки или победа над боссом этапа (из noteKill).
func on_event(name: String, data: Dictionary) -> void:
	if name != "kill" or not in_event():
		return
	if bool(data.get("boss", false)):
		event_boss_defeated()
	else:
		add_event_points(event_points_for_monster(str(data.get("monster", "")), false))


# MARK: Этапы ивента

func boon_rank(id: String) -> int:
	return int(Game.save.get("eventBoons", {}).get(id, 0))


## Сила усиления (только на картах ивента).
func boon_value(id: String) -> float:
	return Events.boon_per_rank(id) * float(boon_rank(id)) if in_event() else 0.0


## Сила усиления этапа: ранг * прибавка за ранг (для recalc).
func boon(id: String) -> float:
	return boon_value(id)


## Очки за особую точку с учётом усиления "Урожай" (0, если точка не ивентовая).
func points_for_node(type: String) -> int:
	var base := Events.points_for_node(type)
	return base + int(boon_value("harvest")) if base > 0 else 0


## Очки за монстра с учётом усиления "Охотник".
func event_points_for_monster(kind: String, boss_kill: bool) -> int:
	return Events.BOSS_POINTS if boss_kill else Events.points_for_monster(kind) + int(boon_value("hunter"))


func event_stage() -> int:
	return int(Game.save.get("eventStage", 1))


func event_progress() -> int:
	return int(Game.save.get("eventProgress", 0))


func event_target() -> int:
	return Events.target(event_stage())


func event_boss_stage() -> bool:
	return Events.is_boss_stage(event_stage())


## Сколько нужно для прохождения: на этапе с боссом - ещё и победа над ним.
func event_goal() -> int:
	return event_target() + (Events.BOSS_POINTS if event_boss_stage() else 0)


func event_stage_cleared() -> bool:
	return event_progress() >= event_goal()


## Цель собрана, пора звать босса.
func event_boss_due() -> bool:
	return event_boss_stage() and event_progress() >= event_target() and not event_stage_cleared()


func _add_stage_progress(n: int) -> void:
	if event_stage_cleared():
		return
	# Пока босс жив, прогресс этапа не растёт выше цели.
	var cap := event_target() if event_boss_stage() else event_goal()
	Game.save["eventProgress"] = mini(cap, event_progress() + n)
	if event_stage_cleared():
		_stage_cleared()


## Босс этапа побеждён.
func event_boss_defeated() -> void:
	if not in_event() or not event_boss_stage() or event_stage_cleared():
		return
	_add_pass_points(Events.BOSS_POINTS)
	Game.save["eventProgress"] = event_goal()
	_stage_cleared()
	Game.mark_dirty()


func _stage_cleared() -> void:
	var stage := event_stage()
	Game.save["eventBest"] = maxi(int(Game.save.get("eventBest", 0)), stage)
	_add_pass_points(Events.clear_points(stage))
	Game.add_coins(Events.clear_coins(stage, Game.level))
	if Events.is_boss_stage(stage):
		Game.save["maps"] = int(Game.save.get("maps", 0)) + 1
		Game.show_toast("px:tmap", L.t("toast.map"))
	Game.show_toast("px:portal", L.t("toast.stageCleared", [stage]))
	Sound.play("levelUp")
	Game.mark_dirty()
	Game.save_now()


## Герой вошёл в портал: предлагаем три усиления (или сразу дальше, если всё на максимуме).
func enter_event_portal() -> void:
	if not in_event() or not event_stage_cleared() or not Game.save.get("eventChoice", []).is_empty():
		return
	var open := Events.BOONS.filter(func(b: String) -> bool: return boon_rank(b) < Events.BOON_MAX_RANK)
	if open.is_empty():
		_next_stage()
		return
	open.shuffle()
	Game.save["eventChoice"] = open.slice(0, 3)
	Game.mark_dirty()


func choose_boon(id: String) -> void:
	if not id in Game.save.get("eventChoice", []):
		return
	Game.save["eventBoons"][id] = mini(Events.BOON_MAX_RANK, boon_rank(id) + 1)
	Game.save["eventChoice"] = []
	Sound.play("unlock")
	_next_stage()


func _next_stage() -> void:
	Game.save["eventStage"] = event_stage() + 1
	Game.save["eventProgress"] = 0
	map_version += 1
	Game.recalc()
	Game.show_toast("px:star", L.t("toast.stageStart", [event_stage()]))
	Game.mark_dirty()
	Game.save_now()


## Упал без сил на этапе: теряется четверть набранного прогресса.
func event_faint() -> void:
	if not in_event() or event_stage_cleared():
		return
	var cap := mini(event_progress(), event_target()) if event_boss_stage() else event_progress()
	Game.save["eventProgress"] = cap * 3 / 4
	Game.mark_dirty()


## Купили VIP-пропуск: он действует на текущий ивент (покупку выдаёт этап 6).
func activate_vip() -> void:
	sync_event()
	var key: String = Events.current()["key"]
	var keys: Array = Game.save.get("vipKeys", [])
	if key in keys:
		return
	keys.append(key)
	# Старые ключи не нужны, оставляем последние.
	if keys.size() > 8:
		keys = keys.slice(keys.size() - 8)
	Game.save["vipKeys"] = keys
	Game.recalc()
	Game.mark_dirty()


# MARK: Переходы

## Можно ли сейчас отправиться на карту ивента (в экспедиции и подземелье - нет).
func can_go_to_event() -> bool:
	return events_open() and Game.save.get("expedition") == null and Game.dungeons.run == null


## Отправиться на карту ивента: локация не добавляется в открытые, появляемся у склада.
func go_to_event() -> void:
	if Game.dungeons.run != null:
		return
	sync_event()
	var to := Events.location(Events.current()["event"])
	if not is_unlocked(to) or Game.current == to or Game.save.get("expedition") != null:
		return
	Game.arrival_gate = ""
	Game.save["current"] = to
	Game.recalc()
	Game.mark_dirty()


## С карты ивента домой, на поляну.
func leave_event() -> void:
	if not in_event():
		return
	Game.arrival_gate = ""
	Game.save["current"] = "meadow"
	Game.recalc()
	Game.mark_dirty()
