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
## Рейтинг альянсов по силе и игроков по мощи.
var strength_top: Array = []
var power_top: Array = []
## Мощь участников моего альянса: id -> мощь.
var powers: Dictionary = {}
## Хранитель альянса (ответ al_pet): kind, xp, stage, day, cravings, fed, total, ends, top.
var pet: Dictionary = {}
## Летопись (ответ al_chronicle): страницы недель, зал славы, неделя основания. Пусто - не загружено.
var chronicle: Dictionary = {}
var _loaded_at := -100.0
## События альянса на эту неделю (ответ al_events): страж, задания, место. Пусто - не загружено.
var ev: Dictionary = {}
var _flushed_at := -1000.0
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
		"petStage": clampi(int(a.get("petStage", 1)), 1, AlliancePet.MAX_STAGE),
	}
	save["allianceSeen"] = bool(save.get("allianceSeen", false))
	# Купленные рамки статуи (украшение за кристаллы)
	var frames: Variant = save.get("statueFrames", [])
	save["statueFrames"] = (frames as Array).filter(func(f: Variant) -> bool: return Chronicle.valid(str(f))) \
		if frames is Array else []
	save["statueFrame"] = str(save.get("statueFrame", "stone"))
	# Погода альянса: последняя известная и до какого момента дождь уже полил грядки
	var w: Variant = save.get("allianceWeather", {})
	save["allianceWeather"] = {"kind": str(w.get("kind", "")), "starts": int(w.get("starts", 0)),
		"ends": int(w.get("ends", 0))} if w is Dictionary and save["alliance"].has("id") else {}
	save["weatherApplied"] = float(save.get("weatherApplied", 0.0))
	_weather_was = ""
	# Звери, которые гостят у меня (для бонуса без сети), и купленное второе место для отправки
	var hosted: Variant = save.get("guestsIn", [])
	save["guestsIn"] = (hosted as Array).filter(func(x: Variant) -> bool: return x is Dictionary).map(
		func(x: Dictionary) -> Dictionary: return {"stars": int(x.get("stars", 1)), "returns": int(x.get("returns", 0))}) \
		if hosted is Array and save["alliance"].has("id") else []
	save["guestSlot"] = bool(save.get("guestSlot", false))
	_hosted_was = -1
	if _ticker == null:
		_start_ticker.call_deferred()
	# Счётчики для заданий альянса, ещё не отправленные на сервер
	var pend: Variant = save.get("alliancePending", {})
	save["alliancePending"] = pend if pend is Dictionary and save["alliance"].has("id") else {}
	# В альянсе - сразу обновить данные (лимиты на сегодня и отметку на вкладке)
	if save["alliance"].has("id") and available():
		refresh.call_deferred()


func available() -> bool:
	return OnlineConfig.enabled()


func open() -> bool:
	return available() and Game.level >= Alliances.JOIN_LEVEL


## Открывал ли игрок окно альянса. До этого вкладка "Мир" и плашка на главном экране зовут посмотреть.
func seen() -> bool:
	return bool(Game.save.get("allianceSeen", false))


func mark_seen() -> void:
	if not seen():
		Game.save["allianceSeen"] = true
		Game.mark_dirty()
		Game.changed.emit()


## Бесплатные вклады, оставшиеся на сегодня (0 - не в альянсе или ещё не загрузили).
func free_left() -> int:
	if not in_alliance() or not loaded:
		return 0
	return maxi(0, Alliances.FREE_PER_DAY - day_used("free"))


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
	if in_alliance():
		await fetch_powers()
		await fetch_pet()
		await fetch_weather()
		await fetch_guests()
		await fetch_mentor()
		await refresh_events()


func _take(d: Dictionary) -> void:
	var was := int(data.get("id", 0))
	data = d
	if d.is_empty():
		Game.save["alliance"] = {}
		Game.save["alliancePending"] = {}
		Game.save["allianceWeather"] = {}
		Game.save["guestsIn"] = []
		guests = {}
		mentor = {}
		pet = {}
		ev = {}
		weather = {}
		chronicle = {}
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
		var stage := int(Game.save.get("alliance", {}).get("petStage", 1)) if was == int(d.get("id", 0)) else 1
		Game.save["alliance"] = {"id": int(d["id"]), "name": str(d.get("name", "")), "tag": str(d.get("tag", "")),
			"emblem": int(d.get("emblem", 0)), "talents": talents, "petStage": stage}
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


# MARK: Хранитель альянса

func fetch_pet() -> void:
	if demo or not in_alliance():
		return
	var res: Variant = await Game.rating.call_rpc("al_pet", {})
	if res is Dictionary:
		pet = res
		_set_pet_stage(int(res.get("stage", 1)))
		Game.changed.emit()


func fetch_chronicle() -> void:
	if demo or not in_alliance():
		return
	var res: Variant = await Game.rating.call_rpc("al_chronicle", {})
	if res is Dictionary:
		chronicle = res
		# Рамка на сервере теряется при переходе в другой альянс: ставим выбранную снова
		if str(res.get("frame", "stone")) != statue_frame():
			Game.rating.call_rpc("al_statue_frame", {"p_frame": statue_frame()})
		Game.changed.emit()


# MARK: Статуи

func statue_frame() -> String:
	var f := str(Game.save.get("statueFrame", "stone"))
	return f if f in owned_frames() else "stone"


func owned_frames() -> Array:
	return ["stone"] + Game.save.get("statueFrames", []).filter(func(f: Variant) -> bool: return Chronicle.valid(str(f)))


## Купить рамку за кристаллы (или выбрать уже купленную) и поставить её на статую.
func pick_frame(frame: String) -> bool:
	if not Chronicle.valid(frame):
		return false
	if not frame in owned_frames():
		if not Game.shop.spend_crystals(Chronicle.price(frame)):
			return false
		if not Game.save.has("statueFrames"):
			Game.save["statueFrames"] = []
		Game.save["statueFrames"].append(frame)
	Game.save["statueFrame"] = frame
	Game.mark_dirty()
	if demo:
		chronicle["frame"] = frame
	elif in_alliance():
		Game.rating.call_rpc("al_statue_frame", {"p_frame": frame})
		for x in chronicle.get("statues", []):
			if bool(x.get("me", false)):
				x["frame"] = frame
	Game.changed.emit()
	return true


# MARK: Погода

## Ответ al_weather: kind, starts, ends, caller, free_left, paid_left. Пусто - не загружено.
var weather: Dictionary = {}
var _ticker: Timer
var _weather_was := ""


func _start_ticker() -> void:
	if _ticker != null:
		return
	_ticker = Timer.new()
	_ticker.wait_time = 5.0
	_ticker.autostart = true
	_ticker.timeout.connect(weather_tick)
	Game.add_child(_ticker)


func fetch_weather() -> void:
	if demo or not in_alliance():
		return
	var res: Variant = await Game.rating.call_rpc("al_weather", {})
	if res is Dictionary:
		_take_weather(res)


func _take_weather(res: Dictionary) -> void:
	weather = res
	var w := {"kind": str(res.get("kind", "")), "starts": int(res.get("starts", 0)), "ends": int(res.get("ends", 0))}
	if w != Game.save.get("allianceWeather", {}):
		Game.save["allianceWeather"] = w
		Game.mark_dirty()
	weather_tick()
	Game.changed.emit()


## Погода, которая идёт сейчас ("" - никакая).
func weather_now() -> String:
	if not in_alliance():
		return ""
	return AllianceWeather.active(Game.save.get("allianceWeather", {}), Clock.now())


## Каждые 5 секунд: дождь поливает грядки, начало и конец погоды пересчитывают бонусы.
func weather_tick() -> void:
	var w: Dictionary = Game.save.get("allianceWeather", {})
	var t := Clock.now()
	if in_alliance() and str(w.get("kind", "")) == "rain":
		var from := float(Game.save.get("weatherApplied", 0.0))
		if from < t:
			Game.garden.apply_rain(w, maxf(from, float(w.get("starts", 0))), t)
	Game.save["weatherApplied"] = t
	# Гость уехал - бонус пересчитать
	var hosted := Guests.active_count(Game.save.get("guestsIn", []), t)
	if hosted != _hosted_was:
		_hosted_was = hosted
		Game.recalc()
	var now_kind := weather_now()
	if now_kind != _weather_was:
		var started := now_kind != "" and _weather_was == ""
		_weather_was = now_kind
		Game.recalc()
		Game.changed.emit()
		if started:
			Game.show_toast("px:" + str(AllianceWeather.ICONS[now_kind]), L.t("weather.started." + now_kind, [Fmt.pct(AllianceWeather.SUN_YIELD)]))


func can_call_weather(paid: bool) -> bool:
	if not in_alliance() or weather.is_empty():
		return false
	if AllianceWeather.active(weather, Clock.now()) != "" or AllianceWeather.pending(weather, Clock.now()):
		return false
	if paid:
		return int(weather.get("paid_left", 0)) > 0
	return role() in ["leader", "officer"] and int(weather.get("free_left", 0)) > 0


## Позвать погоду: kind rain/sun, delay из AllianceWeather.DELAYS, paid - за кристаллы (списываются после успеха).
func call_weather(kind: String, delay: int, paid: bool) -> void:
	if busy or not kind in AllianceWeather.KINDS or not delay in AllianceWeather.DELAYS or not can_call_weather(paid):
		return
	if paid and Game.shop.crystals() < AllianceWeather.PAID_CRYSTALS:
		return
	busy = true
	var res: Variant = await Game.rating.call_rpc("al_weather_call", {"p_kind": kind, "p_delay": delay, "p_paid": paid})
	busy = false
	if not res is Dictionary:
		_fail()
		await fetch_weather()
		return
	if paid:
		Game.shop.spend_crystals(AllianceWeather.PAID_CRYSTALS)
	Sound.play("levelUp")
	_take_weather(res)
	poll_chat()


# MARK: Звери в гости

## Ответ al_guests: out (мои звери в гостях), in (гости у меня), friends. Пусто - не загружено.
var guests: Dictionary = {}
var _hosted_was := -1


func fetch_guests() -> void:
	if demo or not in_alliance():
		return
	var res: Variant = await Game.rating.call_rpc("al_guests", {})
	if res is Dictionary:
		_take_guests(res)


func _take_guests(res: Dictionary) -> void:
	guests = res
	var hosted: Array = []
	for x in res.get("in", []):
		hosted.append({"stars": int(x.get("stars", 1)), "returns": int(x.get("returns", 0))})
	Game.save["guestsIn"] = hosted
	_hosted_was = -1
	weather_tick()
	Game.mark_dirty()
	Game.changed.emit()


func guest_bonus() -> float:
	return Guests.bonus(Game.save.get("guestsIn", []), Clock.now()) if in_alliance() else 0.0


func guest_slots() -> int:
	return Guests.BASE_SLOTS + (1 if bool(Game.save.get("guestSlot", false)) else 0)


func guests_away() -> Array:
	return guests.get("out", [])


## Можно ли сейчас отправить этого зверя (место свободно, зверь дома).
func can_send_guest(animal: String) -> bool:
	if not in_alliance() or Game.animals.stars(animal) <= 0:
		return false
	var away := guests_away()
	return away.size() < guest_slots() and away.filter(func(x: Dictionary) -> bool: return str(x.get("animal", "")) == animal).is_empty()


func send_guest(host_id: String, animal: String) -> void:
	if busy or not can_send_guest(animal):
		return
	busy = true
	var res: Variant = await Game.rating.call_rpc("al_guest_send", {"p_host": host_id, "p_animal": animal,
		"p_stars": Game.animals.stars(animal), "p_slots": guest_slots()})
	busy = false
	if not res is Dictionary:
		_fail()
		return
	Sound.play("purchase")
	_take_guests(res)
	poll_chat()


## Зверь вернулся из гостей: подарок.
func claim_guest(id: int) -> void:
	if busy:
		return
	busy = true
	var res: Variant = await Game.rating.call_rpc("al_guest_claim", {"p_id": id})
	busy = false
	if not res is Dictionary:
		_fail()
		await fetch_guests()
		return
	var r := Guests.reward(int(res.get("stars", 1)), Game.level)
	Game.add_coins(int(r["coins"]))
	Game.chests.add_keys("copper", int(r["copper"]))
	Game.show_toast("px:paw", L.t("guests.back", [Animals.name_of(str(res.get("animal", ""))), Fmt.n(int(r["coins"]))]))
	await fetch_guests()


func buy_guest_slot() -> bool:
	if bool(Game.save.get("guestSlot", false)) or not Game.shop.spend_crystals(Guests.SLOT_CRYSTALS):
		return false
	Game.save["guestSlot"] = true
	Game.mark_dirty()
	Game.changed.emit()
	return true


# MARK: Наставник

## Ответ al_mentor: mentor (мой наставник или null), apprentices (мои ученики). Пусто - не загружено.
var mentor: Dictionary = {}


func fetch_mentor() -> void:
	if demo or not in_alliance():
		return
	var res: Variant = await Game.rating.call_rpc("al_mentor", {"p_level": Game.level})
	if res is Dictionary:
		mentor = res
		var m: Variant = res.get("mentor")
		if m is Dictionary and int(m.get("gifts", 0)) > 0:
			await _take_mentor_gifts()
		Game.changed.emit()


func my_mentor() -> Dictionary:
	var m: Variant = mentor.get("mentor")
	return m if m is Dictionary else {}


func apprentices() -> Array:
	return mentor.get("apprentices", [])


## Можно ли мне взять этого участника наставником.
func can_pick_mentor(m: Dictionary) -> bool:
	return in_alliance() and not mentor.is_empty() and my_mentor().is_empty() and Game.level <= Mentor.APPRENTICE_MAX \
		and int(m.get("level", 1)) >= Mentor.MENTOR_LEVEL and not bool(m.get("me", false))


## Сколько наград наставничества можно забрать (для отметки).
func mentor_count() -> int:
	var n := 0
	var me := my_mentor()
	if not me.is_empty():
		n += Mentor.ready_steps(int(me.get("start", 1)), Game.level, me.get("claimed", [])).size()
	for a in apprentices():
		n += Mentor.ready_steps(int(a.get("start", 1)), int(a.get("level", 1)), a.get("claimed", [])).size()
	return n


func pick_mentor(id: String) -> void:
	if busy:
		return
	busy = true
	var res: Variant = await Game.rating.call_rpc("al_mentor_pick", {"p_mentor": id, "p_level": Game.level})
	busy = false
	if not res is Dictionary:
		_fail()
		return
	mentor = res
	Sound.play("levelUp")
	poll_chat()
	Game.changed.emit()


## Забрать награду за ступень ученика (ученик - свою, наставник - за ученика).
func claim_mentor(apprentice_id: String, step: int) -> void:
	if busy:
		return
	busy = true
	var res: Variant = await Game.rating.call_rpc("al_mentor_claim", {"p_apprentice": apprentice_id, "p_step": step})
	busy = false
	if not res is Dictionary:
		_fail()
		await fetch_mentor()
		return
	var r := Mentor.reward(step, str(res.get("role", "")) == "mentor")
	Game.add_coins(int(r["coins"]))
	Game.shop.add_crystals(int(r["crystals"]))
	Game.show_toast("px:star", L.t("mentor.claimed", [Fmt.n(int(r["coins"])), int(r["crystals"])]))
	await fetch_mentor()


func gift_apprentice(id: String) -> void:
	if busy or Game.shop.crystals() < Mentor.GIFT_CRYSTALS:
		return
	busy = true
	var res: Variant = await Game.rating.call_rpc("al_mentor_gift", {"p_apprentice": id})
	busy = false
	if res == null:
		_fail()
		return
	Game.shop.spend_crystals(Mentor.GIFT_CRYSTALS)
	Sound.play("purchase")
	Game.show_toast("px:chest", L.t("mentor.giftSent"))
	await fetch_mentor()


func _take_mentor_gifts() -> void:
	var n: Variant = await Game.rating.call_rpc("al_mentor_gifts_take", {})
	if n is float or n is int:
		var count := int(n)
		if count > 0:
			for k in Mentor.GIFT:
				Game.chests.add_keys(k, int(Mentor.GIFT[k]) * count, false)
			Game.show_toast("px:chest", L.t("mentor.giftGot", [str(my_mentor().get("name", "")), count]))


func leave_mentor() -> void:
	if busy:
		return
	busy = true
	await Game.rating.call_rpc("al_mentor_leave", {})
	busy = false
	await fetch_mentor()


func pet_stage() -> int:
	return int(Game.save.get("alliance", {}).get("petStage", 1)) if in_alliance() else 1


func _set_pet_stage(stage: int) -> void:
	if not in_alliance() or stage == pet_stage():
		return
	Game.save["alliance"]["petStage"] = clampi(stage, 1, AlliancePet.MAX_STAGE)
	Game.recalc()
	Game.mark_dirty()


func pet_fed() -> int:
	return int(pet.get("fed", 0))


## Цена порции угощения slot (0 простое, 1 среднее, 2 редкое).
func pet_cost(slot: int) -> Dictionary:
	var items: Array = pet.get("cravings", [])
	if slot >= items.size():
		return {}
	return {"items": [[str(items[slot]), AlliancePet.portion(slot, Game.level)]]}


func can_feed_pet(slot: int) -> bool:
	var cost := pet_cost(slot)
	return not busy and not cost.is_empty() and pet_fed() < AlliancePet.PORTIONS and Game.can_afford(cost)


## Порция Хранителю: сервер считает опыт, продукты списываются после успеха.
func feed_pet(slot: int) -> void:
	if not can_feed_pet(slot):
		return
	var cost := pet_cost(slot)
	busy = true
	var res: Variant = await Game.rating.call_rpc("al_pet_feed", {"p_slot": slot, "p_count": 1})
	busy = false
	if not res is Dictionary:
		_fail()
		await fetch_pet()
		return
	Game.pay(cost)
	pet["xp"] = int(res.get("xp", 0))
	pet["stage"] = int(res.get("stage", 1))
	pet["fed"] = int(res.get("fed", 0))
	pet["total"] = int(pet.get("total", 0)) + int(res.get("gain", 0))
	var grew := int(res.get("stage", 1)) > pet_stage()
	_set_pet_stage(int(res.get("stage", 1)))
	Sound.play("levelUp" if grew else "coin")
	Game.show_toast("an:" + str(pet.get("kind", "phoenixChick")), L.t("alliance.pet.fed", [int(res.get("gain", 0))]))
	Game.emit_event("allianceFeed", {})
	Game.mark_dirty()
	Game.changed.emit()


func choose_pet(kind: String) -> void:
	if busy or not kind in AlliancePet.KINDS:
		return
	busy = true
	var res: Variant = await Game.rating.call_rpc("al_pet_kind", {"p_kind": kind})
	busy = false
	if res == null:
		_fail()
	await fetch_pet()


func fetch_powers() -> void:
	var res: Variant = await Game.rating.call_rpc("al_member_powers", {})
	if res is Array:
		powers.clear()
		for x in res:
			if x is Dictionary:
				powers[str(x.get("id", ""))] = int(x.get("power", 0))
		Game.changed.emit()


## Сила моего альянса: сумма мощи 30 самых сильных (как _al_strength).
func strength() -> int:
	var list: Array = powers.values()
	list.sort()
	list.reverse()
	var sum := 0
	for i in mini(Power.ALLIANCE_TOP, list.size()):
		sum += int(list[i])
	return sum


func fetch_strength_top() -> void:
	if demo:
		return
	var res: Variant = await Game.rating.call_rpc("al_strength_top", {})
	if res is Array:
		strength_top = res
		Game.changed.emit()


func fetch_power_top() -> void:
	if demo:
		return
	var res: Variant = await Game.rating.call_rpc("power_top", {})
	if res is Array:
		power_top = res
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
		"talent maxed", "too fast", "already in alliance", "not allowed", "pet fed", "weather busy", "guest away", "host full", "has mentor", "level too high"] else "network"
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


# MARK: События альянса

func refresh_events() -> void:
	if demo or not in_alliance():
		return
	await flush_progress(true)
	var res: Variant = await Game.rating.call_rpc("al_events", {})
	if res is Dictionary:
		ev = res
		Game.changed.emit()


## Бесплатных ударов в день: 3 и +1 за каждые 5 рангов «Боевого клича» (как _al_free_hits).
func free_hits() -> int:
	return int(ev.get("free_hits", AllianceEvents.FREE_HITS + rank("warcry") / 5))


func hits_left() -> int:
	return maxi(0, free_hits() - int(ev.get("hits", free_hits())))


func extra_left() -> int:
	return maxi(0, AllianceEvents.EXTRA_HITS - int(ev.get("extra", AllianceEvents.EXTRA_HITS)))


func can_attack(extra: bool) -> bool:
	if ev.is_empty() or busy:
		return false
	if extra:
		return hits_left() == 0 and extra_left() > 0 and Game.shop.crystals() >= AllianceEvents.EXTRA_COST
	return hits_left() > 0


## Удар по стражу. Урон считает сервер, кристаллы за доп. удар - после успеха.
func attack(extra: bool) -> void:
	if not can_attack(extra):
		return
	busy = true
	var res: Variant = await Game.rating.call_rpc("al_ev_attack", {"p_level": Game.level, "p_extra": extra})
	busy = false
	if not res is Dictionary:
		_fail()
		await refresh_events()
		return
	if extra:
		Game.shop.spend_crystals(AllianceEvents.EXTRA_COST)
	var dmg := int(res.get("damage", 0))
	var used := "extra" if extra else "hits"
	ev[used] = int(ev.get(used, 0)) + 1
	ev["damage"] = int(ev.get("damage", 0)) + dmg
	ev["hp"] = maxi(0, int(ev.get("hp", 0)) - dmg)
	Sound.play("crit" if not bool(res.get("killed", false)) else "levelUp")
	Game.show_toast("px:swords", L.t("alliance.ev.hit", [Fmt.n(dmg)]))
	Game.emit_event("allianceHit", {})
	Game.mark_dirty()
	Game.changed.emit()
	if bool(res.get("killed", false)):
		await refresh_events()


## Что можно забрать: [[what, ref], ...].
func claimable() -> Array:
	var out: Array = []
	if ev.is_empty():
		return out
	for t in ev.get("unclaimed", []):
		out.append(["boss", int(t)])
	var tasks: Array = ev.get("tasks", [])
	for i in tasks.size():
		if task_ready(tasks[i]):
			out.append(["task", i])
	if ev.get("last_place") != null and not bool(ev.get("last_claimed", true)):
		out.append(["place", 0])
	return out


func task_ready(t: Dictionary) -> bool:
	return not bool(t.get("claimed", false)) and int(t.get("progress", 0)) >= int(t.get("target", 1)) \
		and float(t.get("mine", 0)) >= float(t.get("share", 1)) * AllianceEvents.MIN_SHARE


## Награда с бонусом таланта «Трофеи» (кристаллы и монеты).
func reward_for(what: String, ref: int) -> Dictionary:
	var r := {}
	match what:
		"boss": r = AllianceEvents.boss_reward(ref, Game.level)
		"task": r = AllianceEvents.task_reward(Game.level)
		"place": r = AllianceEvents.place_reward(int(ev.get("last_place", 1000000)), Game.level)
	return AllianceEvents.with_bounty(r, bonus("bounty"))


func claim(what: String, ref: int) -> void:
	if busy:
		return
	busy = true
	var res: Variant = await Game.rating.call_rpc("al_ev_claim", {"p_what": what, "p_ref": ref})
	busy = false
	if not res is Dictionary:
		_fail()
		await refresh_events()
		return
	var r: Dictionary
	match str(res.get("what", "")):
		"boss": r = AllianceEvents.boss_reward(int(res.get("tier", 1)), Game.level)
		"task": r = AllianceEvents.task_reward(Game.level)
		"place": r = AllianceEvents.place_reward(int(res.get("place", 1000000)), Game.level)
	RewardsPopup.track(func() -> void: _give(r))
	Sound.play("treasure")
	Game.save_now()
	await refresh_events()


func _give(r: Dictionary) -> void:
	if int(r.get("crystals", 0)) > 0:
		Game.shop.add_crystals(int(r["crystals"]))
	if int(r.get("coins", 0)) > 0:
		Game.add_coins(int(r["coins"]))
	if str(r.get("key", "")) != "":
		Game.chests.add_keys(str(r["key"]), 1, false)


## Сколько отметить на вкладке: удары и награды.
func events_count() -> int:
	if ev.is_empty():
		return 0
	return hits_left() + claimable().size()


## Счётчики заданий: копим в сохранении и отправляем пачкой.
func on_event(name: String, data: Dictionary) -> void:
	if not AllianceEvents.SHARE.has(name) or not in_alliance() or not available():
		return
	var pend: Dictionary = Game.save.get("alliancePending", {})
	pend[name] = int(pend.get(name, 0)) + maxi(1, int(data.get("amount", 1)))
	Game.save["alliancePending"] = pend
	flush_progress()


func flush_progress(force := false) -> void:
	var pend: Dictionary = Game.save.get("alliancePending", {})
	if demo or pend.is_empty() or not in_alliance():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if not force and now - _flushed_at < AllianceEvents.FLUSH_EVERY:
		return
	_flushed_at = now
	var sent := pend.duplicate()
	Game.save["alliancePending"] = {}
	var res: Variant = await Game.rating.call_rpc("al_ev_progress", {"p_counts": sent})
	if res == null and Game.rating.last_error == "network":
		# Не дошло - вернуть в очередь
		var back: Dictionary = Game.save.get("alliancePending", {})
		for k in sent:
			back[k] = int(back.get(k, 0)) + int(sent[k])
		Game.save["alliancePending"] = back
	Game.mark_dirty()


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
		"boss": return L.t("alliance.sys.boss", [str(m.get("body", ""))])
		"task": return L.t("alliance.sys.task", [AllianceEvents.kind_name(str(m.get("body", "")))])
		"pet": return L.t("alliance.sys.pet", [str(m.get("body", ""))])
		"guest":
			var g := str(m.get("body", "")).split(":")
			if g.size() == 2:
				return L.t("alliance.sys.guest", [str(m.get("name", "")), Animals.name_of(g[0]), g[1]])
		"mentor": return L.t("alliance.sys.mentor", [str(m.get("name", "")), str(m.get("body", ""))])
		"weather":
			var parts := str(m.get("body", "")).split(":")
			if parts.size() == 2 and parts[0] in AllianceWeather.KINDS:
				return L.t("alliance.sys.weather." + parts[0], [str(m.get("name", "")), Fmt.clock(int(parts[1]))])
	return str(m.get("body", ""))
