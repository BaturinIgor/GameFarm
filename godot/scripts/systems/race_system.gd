class_name RaceSystem
extends RefCounted
## Гонка к Сердцу долины: флажки (попытки), идущий забег, трофеи, лиги и статистика мест.
## В Game.save: raceRun - идущий забег (RaceRun.d) или нет ключа; raceFlags = {n, at} - флажки и когда
## пересчитаны; raceStats = {trophies, places [4], races, best (с), league (лучшая лига, за которую дана награда)};
## racePending - итоги, ещё не отправленные на сервер [{room, place, times}]; raceAds = {day, n} - флажки за рекламу
## сегодня; raceTitles - титулы за месяц [{m (номер месяца), p (место)}].
## Сервер (docs/supabase/race.sql через Game.rating.call_rpc): race_join - место в комнате на 4, race_sync - свой
## ход и ход живых соперников, race_result - итог для рейтинга, race_top - рейтинг дня и месяца, race_cheer и
## race_emote - уютные действия, race_prizes и race_prize_claim - награды за места в рейтинге.
## Без сети гонка идёт со странниками. Правила забега - RaceRun, данные - Race.

var _run: RaceRun
## Идёт запрос к серверу (вход в комнату или ход соперников).
var busy := false
var _sync_busy := false
## Растёт, когда на поле появился живой соперник (поле обновляет имена и облик).
var rev := 0
## Рейтинги: {"day": ответ race_top, "month": ...}.
var top := {}
var top_error := false
## Снимки экрана: данные подставлены, сеть не трогаем.
var demo := false
## Незабранные награды за рейтинг: [{period, key, place, points}] (с сервера).
var prizes: Array = []
## Меня подбодрили: растёт с каждым новым подарком (поле показывает), gift_count - сколько подарков пришло.
var gift_rev := 0
var gift_count := 0
var _emote_at := -100.0


func defaults(save: Dictionary) -> void:
	var f: Variant = save.get("raceFlags", {})
	var flags: Dictionary = f if f is Dictionary else {}
	save["raceFlags"] = {"n": clampi(int(flags.get("n", Race.FLAGS_MAX)), 0, Race.FLAGS_MAX + 99),
		"at": float(flags.get("at", Clock.now()))}
	var st: Variant = save.get("raceStats", {})
	var stats: Dictionary = st if st is Dictionary else {}
	var places: Array = []
	var raw_places: Array = stats.get("places", []) if stats.get("places") is Array else []
	for i in Race.SEATS:
		places.append(int(raw_places[i]) if i < raw_places.size() else 0)
	save["raceStats"] = {"trophies": maxi(0, int(stats.get("trophies", 0))), "places": places,
		"races": maxi(0, int(stats.get("races", 0))), "best": float(stats.get("best", 0.0)),
		"league": int(stats.get("league", 0))}
	var ads: Variant = save.get("raceAds", {})
	save["raceAds"] = {"day": int((ads as Dictionary).get("day", 0)), "n": int((ads as Dictionary).get("n", 0))} if ads is Dictionary else {"day": 0, "n": 0}
	var titles: Array = []
	for x in save.get("raceTitles", []) if save.get("raceTitles") is Array else []:
		if x is Dictionary and Race.month_title(int(x.get("p", 0))) != "":
			titles.append({"m": int(x["m"]), "p": int(x["p"])})
	save["raceTitles"] = titles
	var pend: Variant = save.get("racePending", [])
	save["racePending"] = (pend as Array).filter(func(p: Variant) -> bool: return p is Dictionary and int(p.get("room", 0)) > 0).slice(-20) if pend is Array else []
	_run = RaceRun.from_save(save.get("raceRun"))
	if _run == null:
		save.erase("raceRun")


func _s() -> Dictionary:
	return Game.save["raceStats"]


func open() -> bool:
	return Game.level >= Race.MIN_LEVEL


# MARK: Флажки

## Флажки к этому моменту (восстановленные добавляются в сохранение).
func flags() -> int:
	var f: Dictionary = Game.save["raceFlags"]
	var n := int(f["n"])
	var now := Clock.now()
	if n >= Race.FLAGS_MAX:
		f["at"] = now
		return n
	var steps := int(floor((now - float(f["at"])) / float(Race.FLAG_EVERY)))
	if steps > 0:
		n = mini(Race.FLAGS_MAX, n + steps)
		f["n"] = n
		f["at"] = now if n >= Race.FLAGS_MAX else float(f["at"]) + float(steps * Race.FLAG_EVERY)
	return n


## Через сколько секунд следующий флажок (0 - полный запас).
func flag_left() -> float:
	if flags() >= Race.FLAGS_MAX:
		return 0.0
	return maxf(0.0, float(Game.save["raceFlags"]["at"]) + float(Race.FLAG_EVERY) - Clock.now())


func add_flags(n: int) -> void:
	flags()
	Game.save["raceFlags"]["n"] = int(Game.save["raceFlags"]["n"]) + n
	Game.mark_dirty()


func _ads() -> Dictionary:
	var a: Dictionary = Game.save["raceAds"]
	if int(a["day"]) != ShopSystem.day_index():
		a["day"] = ShopSystem.day_index()
		a["n"] = 0
	return a


## Сколько флажков за рекламу ещё можно взять сегодня.
func ad_flags_left() -> int:
	return maxi(0, Race.AD_FLAGS - int(_ads()["n"]))


## Флажок за досмотренный ролик (Ads.show_rewarded).
func ad_flag() -> void:
	if ad_flags_left() <= 0:
		return
	_ads()["n"] = int(_ads()["n"]) + 1
	add_flags(1)
	Game.show_toast("px:bolt", L.t("race.adFlagGot"))


# MARK: Забег

func run() -> RaceRun:
	return _run


## Идёт забег, итог которого ещё не забран.
func active() -> bool:
	return _run != null


func can_start() -> bool:
	return open() and _run == null and flags() > 0


## Новый забег: флажок, место (угол) и странники. Возвращает забег или null.
func start(seed_value := -1, seat := -1, room := 0) -> RaceRun:
	if not can_start():
		return null
	var f: Dictionary = Game.save["raceFlags"]
	if int(f["n"]) >= Race.FLAGS_MAX:
		f["at"] = Clock.now()
	f["n"] = int(f["n"]) - 1
	var s := seed_value if seed_value >= 0 else randi()
	_run = RaceRun.create(seat if seat >= 0 else s % Race.SEATS, Clock.now(), s, Game.rating.player_name())
	_run.d["room"] = room
	Game.save["raceRun"] = _run.d
	Game.mark_dirty()
	Game.save_now()
	return _run


## Старт с живыми соперниками: место в комнате на сервере, без сети - со странниками.
func start_online() -> RaceRun:
	if not can_start() or busy:
		return null
	if demo or not OnlineConfig.enabled():
		return start()
	busy = true
	Game.changed.emit()
	var res: Variant = await Game.rating.call_rpc("race_join",
		{"p_name": Game.rating.player_name(), "p_skin": Skins.current(), "p_league": league()})
	busy = false
	if not can_start():
		return null
	if res is Dictionary and int(res.get("room", 0)) > 0:
		return start(int(res["seed"]), clampi(int(res.get("seat", 0)), 0, Race.SEATS - 1), int(res["room"]))
	return start()


## Свой ход на сервер, ход живых соперников с сервера.
func sync() -> void:
	if _run == null or _run.room() == 0 or _sync_busy or demo:
		return
	_sync_busy = true
	var room := _run.room()
	_run.mark(Clock.now())
	var res: Variant = await Game.rating.call_rpc("race_sync", {"p_room": room, "p_times": _run.d["times"]})
	_sync_busy = false
	if _run == null or _run.room() != room or not res is Dictionary:
		return
	if _run.apply_humans(res.get("seats", []), Clock.now()):
		rev += 1
	var fresh := _run.receive_gifts(int(res.get("gifts", 0)))
	if fresh > 0:
		gift_count = fresh
		gift_rev += 1
	touch()


## Подбодрить отстающего (RaceRun.cheer); живому сопернику подарок уходит через сервер. Ответ как у RaceRun.cheer.
func cheer() -> Dictionary:
	if _run == null:
		return {}
	var c := _run.cheer(Clock.now())
	if c.is_empty():
		return c
	touch()
	if bool(c["human"]) and _run.room() > 0 and not demo:
		Game.rating.call_rpc("race_cheer", {"p_room": _run.room(), "p_seat": int(c["seat"])})
	return c


func can_emote() -> bool:
	return _run != null and Clock.now() - _emote_at >= Race.EMOTE_EVERY


## Смайлик над своим бегуном (видят живые соперники).
func emote(id: String) -> bool:
	if not id in Race.EMOTES or not can_emote():
		return false
	_emote_at = Clock.now()
	if _run.room() > 0 and not demo:
		Game.rating.call_rpc("race_emote", {"p_room": _run.room(), "p_emote": id})
	return true


## Награда за место: {trophies, crystals, key, league (новая лига или -1), league_crystals}.
static func reward_for(place: int) -> Dictionary:
	var i := clampi(place - 1, 0, Race.SEATS - 1)
	return {"trophies": int(Race.TROPHIES[i]), "crystals": int(Race.CRYSTALS[i]), "key": str(Race.KEYS[i])}


## Забрать итог (когда он известен): трофеи, кристаллы, ключ, статистика. Возвращает награду с местом
## ({} - итога ещё нет).
func claim() -> Dictionary:
	if _run == null or not _run.decided(Clock.now()):
		return {}
	var place := _run.place(Clock.now())
	var r := reward_for(place)
	r["place"] = place
	# Очки дружбы («Подбодрить») - по трофею сверху
	r["friend"] = _run.cheers()
	r["trophies"] = int(r["trophies"]) + int(r["friend"])
	r["beacon"] = _run.lit_beacon()
	var s := _s()
	var before := Race.league_of(int(s["trophies"]))
	s["trophies"] = int(s["trophies"]) + int(r["trophies"])
	s["places"][place - 1] = int(s["places"][place - 1]) + 1
	s["races"] = int(s["races"]) + 1
	if _run.finished():
		var t := float(_run.d["finish"])
		r["time"] = t
		if float(s["best"]) <= 0.0 or t < float(s["best"]):
			s["best"] = t
	var after := Race.league_of(int(s["trophies"]))
	r["league"] = -1
	r["league_crystals"] = 0
	if after > before and after > int(s["league"]):
		s["league"] = after
		r["league"] = after
		r["league_crystals"] = int(Race.LEAGUES[after]["crystals"])
	Game.shop.add_crystals(int(r["crystals"]) + int(r["league_crystals"]))
	if r["key"] != "":
		Game.chests.add_keys(r["key"], 1, false)
	if _run.room() > 0:
		_run.mark(Clock.now())
		Game.save["racePending"].append({"room": _run.room(), "place": place, "times": _run.d["times"].duplicate()})
		send_pending()
	_run = null
	Game.save.erase("raceRun")
	Game.emit_event("race", {"place": place})
	Game.mark_dirty()
	Game.save_now()
	return r


## Отправить итоги для рейтинга (что не дошло - попробуем позже).
func send_pending() -> void:
	if demo or not OnlineConfig.enabled():
		return
	var list: Array = Game.save["racePending"]
	for p in list.duplicate():
		var res: Variant = await Game.rating.call_rpc("race_result",
			{"p_room": int(p["room"]), "p_place": int(p["place"]), "p_times": p.get("times", [])})
		# Принят или сервер его не возьмёт (комнату удалили) - больше не шлём; нет сети - попробуем позже
		if res != null or Game.rating.last_error in ["room", "early"]:
			list.erase(p)
			Game.mark_dirty()


## Рейтинг дня ("day") или месяца ("month") с сервера.
func fetch_top(period: String) -> void:
	if demo or not OnlineConfig.enabled():
		return
	await send_pending()
	var res: Variant = await Game.rating.call_rpc("race_top", {"p_period": period})
	top_error = not res is Dictionary
	if res is Dictionary:
		top[period] = res
	Game.changed.emit()


## Награды за места в рейтинге вчерашних дней и прошлого месяца.
func fetch_prizes() -> void:
	if demo or not OnlineConfig.enabled():
		return
	var res: Variant = await Game.rating.call_rpc("race_prizes", {})
	if res is Array:
		prizes = (res as Array).filter(func(p: Variant) -> bool: return p is Dictionary)
		Game.changed.emit()


## Кристаллы за место из ответа сервера ({period, place}).
static func prize_value(p: Dictionary) -> int:
	var place := int(p.get("place", 0))
	return Race.month_prize(place) if str(p.get("period", "")) == "month" else Race.day_prize(place)


## Забрать награду за место (место проверяет сервер): кристаллы, за месяц - титул.
func claim_prize(p: Dictionary) -> void:
	if busy:
		return
	busy = true
	var res: Variant = {"period": p["period"], "key": p["key"], "place": p["place"]}
	if not demo:
		res = await Game.rating.call_rpc("race_prize_claim", {"p_period": str(p["period"]), "p_key": int(p["key"])})
	busy = false
	prizes.erase(p)
	if res is Dictionary:
		grant_prize(res)
	Game.changed.emit()


## Выдать награду за место (ответ сервера {period, key, place}).
func grant_prize(res: Dictionary) -> void:
	var gems := prize_value(res)
	if gems <= 0:
		return
	Game.shop.add_crystals(gems)
	if str(res["period"]) == "month":
		Game.save["raceTitles"].append({"m": int(res["key"]), "p": int(res["place"])})
	Game.show_toast("px:gem", L.t("race.prizeGot", [gems]))
	Game.mark_dirty()
	Game.save_now()


## Лучший титул за месяц: {m, p} или {}.
func best_title() -> Dictionary:
	var out := {}
	for t in Game.save["raceTitles"]:
		if out.is_empty() or int(t["p"]) < int(out["p"]) or (int(t["p"]) == int(out["p"]) and int(t["m"]) > int(out["m"])):
			out = t
	return out


## Сохранить состояние забега (после добычи, продажи, ворот).
func touch() -> void:
	if _run != null:
		_run.mark(Clock.now())
		Game.save["raceRun"] = _run.d
		Game.mark_dirty()


# MARK: Статистика

func trophies() -> int:
	return int(_s()["trophies"])


func league() -> int:
	return Race.league_of(trophies())


func places() -> Array:
	return _s()["places"]


func races() -> int:
	return int(_s()["races"])


func best() -> float:
	return float(_s()["best"])


## Отметка на разделе: можно стартовать или забрать итог.
func ready_count() -> int:
	if not open():
		return 0
	if not prizes.is_empty():
		return 1
	if _run != null:
		return 1 if _run.decided(Clock.now()) else 0
	return 1 if flags() > 0 else 0
