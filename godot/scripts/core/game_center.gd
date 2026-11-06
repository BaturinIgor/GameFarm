class_name GCenter
## Game Center: достижения и таблицы лидеров. Плагин GameCenter из godot-ios-plugins собирает ios-godot.yml.
## Без плагина (Android, ПК, тесты) LIVE = false и ничего не происходит.
## Достижения Game Center повторяют достижения игры (Quests.achievements) и трофеи гостиной (Trophies):
## отправляем, как только условие выполнено. Таблицы: уровень героя, лучший этап праздника, заработанные монеты.
## Что уже отправлено - в Game.save.gc = {ach: [id], scores: {таблица: значение}}, чтобы не слать повторно.
## Сами достижения и таблицы заводит в App Store Connect tools/appstore/asc_gamecenter.py (те же id).

static var LIVE: bool = Engine.has_singleton("GameCenter")

const PREFIX := "hh."
## Таблицы лидеров: id -> откуда берём значение.
const BOARDS := ["level", "event_stage", "coins"]
## Как часто сверять достижения и очки (секунды).
const SYNC_EVERY := 30.0

static var authed := false
static var _poller: Timer
static var _since := 0.0


static func _plugin() -> Object:
	return Engine.get_singleton("GameCenter") if LIVE else null


static func setup(host: Node) -> void:
	if not LIVE or _poller != null:
		return
	_poller = Timer.new()
	_poller.wait_time = 1.0
	_poller.autostart = true
	_poller.process_mode = Node.PROCESS_MODE_ALWAYS
	_poller.timeout.connect(GCenter._poll)
	host.add_child(_poller)
	_plugin().authenticate()


static func _poll() -> void:
	var p := _plugin()
	while p.get_pending_event_count() > 0:
		var e: Variant = p.pop_pending_event()
		if e is Dictionary and str(e.get("type", "")) == "authentication":
			authed = str(e.get("result", "")) == "ok"
			if authed:
				sync()
	_since += _poller.wait_time
	if authed and _since >= SYNC_EVERY:
		sync()


## Отправить всё новое: выполненные достижения и выросшие очки.
static func sync() -> void:
	_since = 0.0
	if not LIVE or not authed:
		return
	for id in pending_achievements():
		_plugin().award_achievement({"name": PREFIX + id, "progress": 100.0, "show_completion_banner": true})
		_state()["ach"].append(id)
	var scores := pending_scores()
	for board in scores:
		_plugin().post_score({"score": scores[board], "category": PREFIX + board})
		_state()["scores"][board] = scores[board]
	if not scores.is_empty():
		Game.mark_dirty()


## Открыть окно Game Center (view: default, leaderboards, achievements).
static func show(view := "default") -> void:
	if LIVE and authed:
		_plugin().show_game_center({"view": view})
	elif LIVE:
		_plugin().authenticate()


# MARK: Что отправлять (без плагина тоже работает - для тестов)

static func _state() -> Dictionary:
	var g: Variant = Game.save.get("gc", {})
	if not g is Dictionary:
		g = {}
	if not g.get("ach") is Array:
		g["ach"] = []
	if not g.get("scores") is Dictionary:
		g["scores"] = {}
	Game.save["gc"] = g
	return g


## Все id достижений Game Center: ach.<id достижения> и trophy.<трофей>.
static func all_achievements() -> Array:
	var out: Array = []
	for a in Quests.achievements():
		out.append("ach." + str(a["id"]))
	for t in Trophies.IDS:
		out.append("trophy." + str(t))
	return out


static func earned(id: String) -> bool:
	if id.begins_with("trophy."):
		return Trophies.is_earned(id.substr(7))
	var key := id.substr(4)
	for a in Quests.achievements():
		if a["id"] == key:
			return Game.quests.is_claimed(a) or Quests.progress(a) >= int(a["target"])
	return false


static func pending_achievements() -> Array:
	var sent: Array = _state()["ach"]
	return all_achievements().filter(func(id: String) -> bool: return not id in sent and earned(id))


static func score(board: String) -> int:
	match board:
		"level": return Game.level
		"event_stage": return int(Game.save.get("eventBestEver", 0))
		"coins": return int(Game.save.get("coinsEarned", 0))
	return 0


static func pending_scores() -> Dictionary:
	var sent: Dictionary = _state()["scores"]
	var out := {}
	for b in BOARDS:
		var v := score(b)
		if v > int(sent.get(b, 0)):
			out[b] = v
	return out


# MARK: Список для App Store Connect

## Достижения и таблицы со всеми переводами: его пишет "-- --gc-manifest <файл>",
## а tools/appstore/asc_gamecenter.py заводит по нему всё в App Store Connect.
static func manifest() -> Dictionary:
	var keep := L.code
	var ach: Array = []
	var tier_points := [5, 10, 20, 35, 50]
	for a in Quests.achievements():
		var tier := int(str(a["id"]).get_slice("_", str(a["id"]).get_slice_count("_") - 1)) - 1
		ach.append({"id": PREFIX + "ach." + str(a["id"]), "ref": "ach " + str(a["id"]), "family": str(a["family"]),
			"points": tier_points[clampi(tier, 0, tier_points.size() - 1)], "a": a})
	for t in Trophies.IDS:
		ach.append({"id": PREFIX + "trophy." + str(t), "ref": "trophy " + str(t), "family": "trophy_" + str(t),
			"points": 40, "trophy": str(t)})
	# Game Center: не больше 1000 очков на игру
	var total := 0
	for x in ach:
		total += int(x["points"])
	var k := minf(1.0, 1000.0 / float(maxi(1, total)))
	var boards: Array = []
	for b in BOARDS:
		boards.append({"id": PREFIX + b, "ref": "board " + b, "names": {}})
	for x in ach:
		x["points"] = maxi(1, floori(float(x["points"]) * k))
		x["names"] = {}
		x["text"] = {}
	for c in L.CODES:
		L.set_language(c, false)
		for x in ach:
			if x.has("trophy"):
				x["names"][c] = Trophies.name_of(str(x["trophy"]))
				x["text"][c] = Trophies.condition(str(x["trophy"]))
			else:
				x["names"][c] = Quests.achievement_title(x["a"])
				x["text"][c] = Quests.achievement_detail(x["a"])
		for b in boards:
			b["names"][c] = L.t("gc.board." + str(b["id"]).substr(PREFIX.length()))
	L.set_language(keep, false)
	for x in ach:
		x.erase("a")
		x.erase("trophy")
	return {"achievements": ach, "leaderboards": boards}
