class_name RaceSystem
extends RefCounted
## Гонка к Сердцу долины: флажки (попытки), идущий забег, трофеи, лиги и статистика мест.
## В Game.save: raceRun - идущий забег (RaceRun.d) или нет ключа; raceFlags = {n, at} - флажки и когда
## пересчитаны; raceStats = {trophies, places [4], races, best (с), league (лучшая лига, за которую дана награда)}.
## Правила забега - RaceRun, данные - Race.

var _run: RaceRun


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


# MARK: Забег

func run() -> RaceRun:
	return _run


## Идёт забег, итог которого ещё не забран.
func active() -> bool:
	return _run != null


func can_start() -> bool:
	return open() and _run == null and flags() > 0


## Новый забег: флажок, место (угол) и странники. Возвращает забег или null.
func start(seed_value := -1) -> RaceRun:
	if not can_start():
		return null
	var f: Dictionary = Game.save["raceFlags"]
	if int(f["n"]) >= Race.FLAGS_MAX:
		f["at"] = Clock.now()
	f["n"] = int(f["n"]) - 1
	var s := seed_value if seed_value >= 0 else randi()
	_run = RaceRun.create(s % Race.SEATS, Clock.now(), s, Game.rating.player_name())
	Game.save["raceRun"] = _run.d
	Game.mark_dirty()
	Game.save_now()
	return _run


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
	_run = null
	Game.save.erase("raceRun")
	Game.emit_event("race", {"place": place})
	Game.mark_dirty()
	Game.save_now()
	return r


## Сохранить состояние забега (после добычи, продажи, ворот).
func touch() -> void:
	if _run != null:
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
	if _run != null:
		return 1 if _run.decided(Clock.now()) else 0
	return 1 if flags() > 0 else 0
