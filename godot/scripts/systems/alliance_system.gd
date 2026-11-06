class_name AllianceSystem
extends RefCounted
## Альянс игрока: данные с сервера (Game.rating.call_rpc -> функции al_* из docs/supabase/alliances.sql),
## вклады в таланты, чат с жалобами и блокировкой. Правила и лимиты проверяет сервер.
## В Game.save: alliance = {id, name, tag, emblem, talents: {талант: очки}} - последняя копия с сервера,
## чтобы бонусы талантов работали и без сети. Пусто - игрок не в альянсе.
## Без сервера (OnlineConfig выключен) раздел не показывается.

## Последний ответ al_me: сам альянс, участники, мои лимиты за день. Пусто - не загружено или не в альянсе.
var data: Dictionary = {}
## Загрузили ли хоть раз (до этого окно показывает "загрузка").
var loaded := false
var busy := false
## Ошибка последнего действия (ключ строки alliance.err.*), показывается в окне.
var error := ""
## Чат: сообщения по порядку и id последнего.
var messages: Array = []
var _last_id := 0
## Результаты поиска и рейтинга.
var found: Array = []
var top: Array = []
var _loaded_at := -100.0
## Снимки экрана: данные подставлены, сеть не трогаем.
var demo := false


func defaults(save: Dictionary) -> void:
	var a: Variant = save.get("alliance", {})
	if not a is Dictionary:
		a = {}
	var talents := {}
	if a.get("talents") is Dictionary:
		for k in a["talents"]:
			if Alliances.TALENTS.has(str(k)):
				talents[str(k)] = maxi(0, int(a["talents"][k]))
	save["alliance"] = {} if int(a.get("id", 0)) <= 0 else {
		"id": int(a["id"]), "name": str(a.get("name", "")), "tag": str(a.get("tag", "")),
		"emblem": int(a.get("emblem", 0)), "talents": talents,
	}
	# В альянсе - сразу обновить данные (лимиты на сегодня и отметку на вкладке)
	if save["alliance"].has("id") and available():
		refresh.call_deferred()


func available() -> bool:
	return OnlineConfig.enabled()


func open() -> bool:
	return available() and Game.level >= Alliances.JOIN_LEVEL


func in_alliance() -> bool:
	return int(Game.save.get("alliance", {}).get("id", 0)) > 0


func role() -> String:
	return str(data.get("role", "member"))


func is_leader() -> bool:
	return role() == "leader"


## Ранг таланта по последней копии (работает и без сети).
func rank(id: String) -> int:
	if not in_alliance():
		return 0
	return Alliances.rank_of(id, int(Game.save["alliance"]["talents"].get(id, 0)))


func bonus(id: String) -> float:
	return Alliances.value(id, rank(id))


func level() -> int:
	return Alliances.level_of(int(data.get("xp", 0)))


func day_used(kind: String) -> int:
	return int(data.get("day", {}).get(kind, 0))


# MARK: Загрузка

func refresh(force := false) -> void:
	if busy or demo or not open():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if not force and loaded and now - _loaded_at < 20.0:
		return
	busy = true
	var res: Variant = await Game.rating.call_rpc("al_me", {})
	busy = false
	if res == null:
		error = "network"
		Game.changed.emit()
		return
	_loaded_at = now
	loaded = true
	error = ""
	_take(res if res is Dictionary else {})


func _take(d: Dictionary) -> void:
	var was := int(data.get("id", 0))
	data = d
	if d.is_empty():
		Game.save["alliance"] = {}
		messages.clear()
		_last_id = 0
	else:
		if was != int(d.get("id", 0)):
			messages.clear()
			_last_id = 0
		var talents := {}
		var raw: Variant = d.get("talents", {})
		if raw is Dictionary:
			for k in raw:
				talents[str(k)] = int(raw[k])
		Game.save["alliance"] = {"id": int(d["id"]), "name": str(d.get("name", "")), "tag": str(d.get("tag", "")),
			"emblem": int(d.get("emblem", 0)), "talents": talents}
	Game.recalc()
	Game.mark_dirty()
	Game.changed.emit()


func search(query: String) -> void:
	if busy or demo:
		return
	busy = true
	var res: Variant = await Game.rating.call_rpc("al_search", {"p_query": query.strip_edges().left(20), "p_level": Game.level})
	busy = false
	found = res if res is Array else []
	error = "" if res != null else "network"
	Game.changed.emit()


func fetch_top() -> void:
	if demo:
		return
	var res: Variant = await Game.rating.call_rpc("al_top", {})
	if res is Array:
		top = res
		Game.changed.emit()


# MARK: Вступление и выход

## Можно ли создать: уровень и цена (кристаллы или монеты).
func can_create(with_coins: bool) -> bool:
	if Game.level < Alliances.CREATE_LEVEL:
		return false
	return int(Game.save["coins"]) >= Alliances.CREATE_COINS if with_coins else Game.shop.crystals() >= Alliances.CREATE_CRYSTALS


func create(name: String, tag: String, emblem: int, about: String, with_coins: bool) -> void:
	if busy or not can_create(with_coins):
		return
	busy = true
	var res: Variant = await Game.rating.call_rpc("al_create", {"p_name": name, "p_tag": tag, "p_emblem": emblem,
		"p_about": about, "p_min_level": Alliances.JOIN_LEVEL, "p_player": Game.rating.player_name(), "p_level": Game.level})
	busy = false
	if res == null:
		_fail()
		return
	# Цена - только после того, как сервер создал альянс
	if with_coins:
		Game.save["coins"] = int(Game.save["coins"]) - Alliances.CREATE_COINS
	else:
		Game.shop.spend_crystals(Alliances.CREATE_CRYSTALS)
	Sound.play("unlock")
	Game.save_now()
	await refresh(true)


func join(id: int) -> void:
	if busy:
		return
	busy = true
	var res: Variant = await Game.rating.call_rpc("al_join", {"p_alliance": id, "p_player": Game.rating.player_name(),
		"p_level": Game.level})
	busy = false
	if res == null:
		_fail()
		return
	Sound.play("unlock")
	await refresh(true)


func leave() -> void:
	if busy:
		return
	busy = true
	var res: Variant = await Game.rating.call_rpc("al_leave", {})
	busy = false
	if res == null:
		_fail()
		return
	_take({})


func kick(user: String) -> void:
	if await _act("al_kick", {"p_user": user}):
		await refresh(true)


func set_role(user: String, r: String) -> void:
	if await _act("al_set_role", {"p_user": user, "p_role": r}):
		await refresh(true)


func edit(about: String, min_level: int, emblem: int) -> void:
	if await _act("al_edit", {"p_about": about, "p_min_level": min_level, "p_emblem": emblem}):
		await refresh(true)


func _act(fn: String, args: Dictionary) -> bool:
	if busy:
		return false
	busy = true
	var res: Variant = await Game.rating.call_rpc(fn, args)
	busy = false
	if res == null:
		_fail()
		return false
	return true


func _fail() -> void:
	var e := Game.rating.last_error
	error = e if e in ["limit", "full", "level too low", "name taken", "tag taken", "bad name", "talent locked",
		"talent maxed", "too fast", "already in alliance", "not allowed"] else "network"
	Game.changed.emit()


# MARK: Вклады

## Цена следующего вклада: {} - бесплатно, {coins: n} или {crystals: n}. Пусто с "none" - лимит на сегодня.
func contribute_cost(kind: String) -> Dictionary:
	match kind:
		"free":
			return {} if day_used("free") < Alliances.FREE_PER_DAY else {"none": true}
		"coins":
			return {"coins": Alliances.coin_cost(Game.level)} if day_used("coins") < Alliances.COINS_PER_DAY else {"none": true}
		"gems":
			return {"crystals": Alliances.gem_cost(day_used("gems"))}
	return {"none": true}


func can_contribute(talent: String, kind: String) -> bool:
	if not in_alliance() or level() < Alliances.talent_level(talent):
		return false
	if int(data.get("talents", {}).get(talent, 0)) >= Alliances.talent_max(talent):
		return false
	var cost := contribute_cost(kind)
	if cost.has("none"):
		return false
	if cost.has("coins") and int(Game.save["coins"]) < int(cost["coins"]):
		return false
	if cost.has("crystals") and Game.shop.crystals() < int(cost["crystals"]):
		return false
	return true


func contribute(talent: String, kind: String) -> void:
	if busy or not can_contribute(talent, kind):
		return
	var cost := contribute_cost(kind)
	busy = true
	var res: Variant = await Game.rating.call_rpc("al_contribute", {"p_talent": talent, "p_kind": kind,
		"p_player": Game.rating.player_name(), "p_level": Game.level})
	busy = false
	if res == null:
		_fail()
		await refresh(true)
		return
	if cost.has("coins"):
		Game.save["coins"] = int(Game.save["coins"]) - int(cost["coins"])
	if cost.has("crystals"):
		Game.shop.spend_crystals(int(cost["crystals"]))
	# Сразу у себя: очки таланта, опыт и лимит; полная копия - при следующей загрузке
	var before := rank(talent)
	data["talents"] = data.get("talents", {})
	data["talents"][talent] = int(res) if (res is float or res is int) else int(data["talents"].get(talent, 0)) + 1
	data["xp"] = int(data.get("xp", 0)) + 1
	data["week_xp"] = int(data.get("week_xp", 0)) + 1
	var day: Dictionary = data.get("day", {})
	day[kind] = int(day.get(kind, 0)) + 1
	data["day"] = day
	Game.save["alliance"]["talents"][talent] = int(data["talents"][talent])
	Game.recalc()
	if rank(talent) > before:
		Game.show_toast("px:" + str(Alliances.TALENTS[talent]["icon"]),
			L.t("alliance.rankUp", [Alliances.talent_name(talent), rank(talent)]))
	Sound.play("pick")
	Game.emit_event("allianceGive", {"kind": kind})
	Game.mark_dirty()
	Game.changed.emit()


# MARK: Чат

func poll_chat() -> void:
	if demo or not in_alliance():
		return
	var res: Variant = await Game.rating.call_rpc("al_messages", {"p_after": _last_id})
	if not res is Array or (res as Array).is_empty():
		return
	for m in res:
		if m is Dictionary and int(m.get("id", 0)) > _last_id:
			messages.append(m)
			_last_id = int(m["id"])
	if messages.size() > 120:
		messages = messages.slice(messages.size() - 120)
	Game.changed.emit()


func say(text: String) -> bool:
	var t := text.strip_edges().left(Alliances.MSG_LEN)
	if t == "" or not in_alliance():
		return false
	var res: Variant = await Game.rating.call_rpc("al_say", {"p_text": t, "p_player": Game.rating.player_name()})
	if res == null:
		_fail()
		return false
	await poll_chat()
	return true


func report(message_id: int, reason: String) -> void:
	await Game.rating.call_rpc("al_report", {"p_message": message_id, "p_reason": reason})
	messages = messages.filter(func(m: Dictionary) -> bool: return int(m.get("id", 0)) != message_id)
	Game.show_toast("px:scroll", L.t("alliance.reported"))
	Game.changed.emit()


func block(user: String) -> void:
	await Game.rating.call_rpc("al_block", {"p_user": user, "p_on": true})
	messages = messages.filter(func(m: Dictionary) -> bool: return str(m.get("user_id", "")) != user)
	Game.show_toast("px:scroll", L.t("alliance.blocked"))
	Game.changed.emit()


## Подпись системного сообщения (вступил, вышел, новый уровень...).
static func system_text(m: Dictionary) -> String:
	var kind := str(m.get("kind", "text"))
	match kind:
		"create": return L.t("alliance.sys.create", [str(m.get("name", "")), str(m.get("body", ""))])
		"join", "leave", "kick": return L.t("alliance.sys." + kind, [str(m.get("name", ""))])
		"level": return L.t("alliance.sys.level", [str(m.get("body", ""))])
	return str(m.get("body", ""))
