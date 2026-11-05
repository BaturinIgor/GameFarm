class_name RatingSystem
extends RefCounted
## Рейтинги ивентов через Supabase (данные Ratings, сервер docs/supabase/ratings.sql, адрес OnlineConfig).
## Игрок входит анонимно: токены лежат в user://online.cfg (не в сохранении, его формат общий с iOS).
## Раз в минуту отправляет очки праздника и фарм-ивента, после конца ивента забирает награду за место.
## В Game.save: ratingName (имя в таблицах), ratingJoined (ключи ивентов, куда отправлялись очки),
## ratingDone (ключи, за которые награда уже выдана или её нет).
## Без адреса сервера или без сети ничего не делает: ивенты работают как раньше.

const AUTH_PATH := "user://online.cfg"

## Таблицы по ключу ивента: {league: [], global: [], me: {}, at: секунды, error: bool}.
var cache: Dictionary = {}
var _node: Node
var _auth := {}
var _sent: Dictionary = {}       ## ключ -> последние отправленные очки
var _busy := false
var _fetching: Dictionary = {}


func defaults(save: Dictionary) -> void:
	var name := str(save.get("ratingName", ""))
	if name == "":
		name = "Farmer%04d" % (randi() % 10000)
	save["ratingName"] = name
	for key in ["ratingJoined", "ratingDone"]:
		var list: Array = []
		for k in save.get(key, []):
			list.append(str(k))
		save[key] = list
	if OnlineConfig.enabled():
		_start.call_deferred()


func enabled() -> bool:
	return OnlineConfig.enabled() and Game.events.events_open()


func _start() -> void:
	if _node != null:
		return
	_node = Node.new()
	_node.name = "Rating"
	Game.add_child(_node)
	var timer := Timer.new()
	timer.wait_time = Ratings.SUBMIT_EVERY
	timer.autostart = true
	timer.timeout.connect(tick)
	_node.add_child(timer)
	_load_auth()
	tick.call_deferred()


## Ключи рейтингов, которые идут сейчас: праздник и фарм-ивент.
func live_keys() -> Array:
	return [str(Events.current()["key"]), str(FarmEvents.current()["key"])]


func score_of(key: String) -> int:
	if key == str(Events.current()["key"]) and str(Game.save.get("eventKey", "")) == key:
		return int(Game.save.get("eventPoints", 0))
	if key == str(FarmEvents.current()["key"]) and str(Game.save.get("farmKey", "")) == key:
		return int(Game.save.get("farmPoints", 0))
	return 0


func player_name() -> String:
	return str(Game.save.get("ratingName", "Farmer"))


func rename(name: String) -> void:
	var clean := name.strip_edges().left(16)
	if clean == "" or clean == player_name():
		return
	Game.save["ratingName"] = clean
	_sent.clear()
	Game.mark_dirty()
	tick()


# MARK: Цикл

func tick() -> void:
	if not enabled() or _busy:
		return
	_busy = true
	var ok: bool = await _ensure_auth()
	if ok:
		for key in live_keys():
			var score := score_of(key)
			if score > 0 and int(_sent.get(key, -1)) != score:
				var res = await _rpc("submit_score", {"p_event": key, "p_score": score, "p_name": player_name(), "p_level": Game.level})
				if res != null:
					_sent[key] = score
					var joined: Array = Game.save["ratingJoined"]
					if not key in joined:
						joined.append(key)
						if joined.size() > 40:
							Game.save["ratingJoined"] = joined.slice(joined.size() - 40)
						Game.mark_dirty()
		await _claim_finished()
	_busy = false


## Ивенты кончились: награда за итоговое место.
func _claim_finished() -> void:
	var live := live_keys()
	for key in Game.save["ratingJoined"].duplicate():
		if key in live or key in Game.save["ratingDone"]:
			continue
		var rows = await _rpc("my_result", {"p_event": key})
		if rows == null:
			return
		var done: Array = Game.save["ratingDone"]
		done.append(key)
		if done.size() > 60:
			Game.save["ratingDone"] = done.slice(done.size() - 60)
		if rows is Array and not rows.is_empty() and int(rows[0].get("score", 0)) > 0:
			var r: Dictionary = rows[0]
			_grant(key, int(r.get("league_place", 0)), Ratings.league_reward(int(r.get("league_place", 0))))
			_grant(key, int(r.get("global_place", 0)), Ratings.global_reward(int(r.get("global_place", 0)), int(r.get("total", 0))))
		Game.mark_dirty()
		Game.save_now()


func _grant(key: String, place: int, reward: Dictionary) -> void:
	if reward.is_empty():
		return
	Game.shop.add_crystals(int(reward.get("crystals", 0)))
	var planks := Ratings.planks_scaled(int(reward.get("planks", 0)), Game.level)
	Game.save["storage"]["planks"] = int(Game.save["storage"].get("planks", 0)) + planks
	Game.show_toast("px:star", L.t("toast.ratingReward", [place, Ratings.event_name(key)]))
	Sound.play("treasure")


## Обновить таблицы ивента (окно рейтинга зовёт при показе). Результат - в cache, потом Game.changed.
func fetch(key: String) -> void:
	if not enabled() or _fetching.get(key, false):
		return
	var old: Dictionary = cache.get(key, {})
	if not old.is_empty() and Time.get_ticks_msec() / 1000.0 - float(old.get("at", 0.0)) < Ratings.FETCH_EVERY:
		return
	_fetching[key] = true
	var entry := {"league": [], "global": [], "at": Time.get_ticks_msec() / 1000.0, "error": true}
	var ok: bool = await _ensure_auth()
	if ok:
		var score := score_of(key)
		if score > 0 and int(_sent.get(key, -1)) != score:
			var sent = await _rpc("submit_score", {"p_event": key, "p_score": score, "p_name": player_name(), "p_level": Game.level})
			if sent != null:
				_sent[key] = score
		var league = await _rpc("get_league", {"p_event": key})
		var world = await _rpc("get_global", {"p_event": key, "p_limit": 100})
		if league is Array and world is Array:
			entry = {"league": league, "global": world, "at": Time.get_ticks_msec() / 1000.0, "error": false}
	cache[key] = entry
	_fetching.erase(key)
	Game.changed.emit()


# MARK: Сеть

func _load_auth() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(AUTH_PATH) == OK:
		for k in ["access", "refresh", "expires", "user"]:
			_auth[k] = cfg.get_value("auth", k, "")


func _save_auth() -> void:
	var cfg := ConfigFile.new()
	for k in _auth:
		cfg.set_value("auth", k, _auth[k])
	cfg.save(AUTH_PATH)


func _take_session(data) -> bool:
	if not (data is Dictionary) or str(data.get("access_token", "")) == "":
		return false
	_auth["access"] = str(data["access_token"])
	_auth["refresh"] = str(data.get("refresh_token", ""))
	_auth["expires"] = Clock.now() + float(data.get("expires_in", 3600))
	var user = data.get("user")
	_auth["user"] = str(user.get("id", "")) if user is Dictionary else ""
	_save_auth()
	return true


## Есть рабочий токен: вход анонимно или обновление по refresh-токену.
func _ensure_auth() -> bool:
	if str(_auth.get("access", "")) != "" and float(_auth.get("expires", 0.0)) - 60.0 > Clock.now():
		return true
	if str(_auth.get("refresh", "")) != "":
		var data = await _request("/auth/v1/token?grant_type=refresh_token", {"refresh_token": _auth["refresh"]}, false)
		if _take_session(data):
			return true
	var fresh = await _request("/auth/v1/signup", {"data": {}}, false)
	return _take_session(fresh)


func _rpc(fn: String, args: Dictionary) -> Variant:
	return await _request("/rest/v1/rpc/" + fn, args, true)


## POST с JSON. Возвращает разобранный ответ, true для пустого ответа 2xx, null при ошибке.
func _request(path: String, body: Dictionary, authed: bool) -> Variant:
	if _node == null:
		return null
	var http := HTTPRequest.new()
	http.timeout = 10.0
	_node.add_child(http)
	var headers := PackedStringArray(["apikey: " + OnlineConfig.ANON_KEY, "Content-Type: application/json"])
	headers.append("Authorization: Bearer " + (str(_auth.get("access", "")) if authed else OnlineConfig.ANON_KEY))
	var err := http.request(OnlineConfig.URL + path, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		http.queue_free()
		return null
	var res: Array = await http.request_completed
	http.queue_free()
	var code := int(res[1])
	var text: String = (res[3] as PackedByteArray).get_string_from_utf8()
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
		if code == 401 and authed:
			_auth["access"] = ""
		return null
	if text.strip_edges() == "":
		return true
	var parsed = JSON.parse_string(text)
	return parsed if parsed != null else true
