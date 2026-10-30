class_name RaidSystem
extends RefCounted
## Набеги. В Game.save: raid = {next, postponed, shield, wins, losses}.
## Герой дома на поляне - набег идёт вживую (RaidFeature). Герой в другом месте или игры не было -
## набег считается сам: сила башен и частокола против силы волны, награда вдвое меньше, потеря не больше 2,5%.
## За время отсутствия считается не больше одного набега.

## Живой набег: {total, killed, stolen} или пусто.
var live: Dictionary = {}
var _warned := false


func defaults(save: Dictionary) -> void:
	var raw: Variant = save.get("raid", {})
	var r: Dictionary = raw if raw is Dictionary else {}
	save["raid"] = {"next": float(r.get("next", 0.0)), "postponed": bool(r.get("postponed", false)),
		"shield": float(r.get("shield", 0.0)), "wins": int(r.get("wins", 0)), "losses": int(r.get("losses", 0))}


func _r() -> Dictionary:
	return Game.save["raid"]


static func _now() -> float:
	return Time.get_unix_time_from_system()


## Набеги вообще идут: главный дом 4 и не выключены в настройках.
func enabled() -> bool:
	return Settings.raids() and Game.estate.level("main") >= Raids.MAIN_LEVEL


## Секунд до набега (INF - не запланирован).
func left() -> float:
	var next := float(_r()["next"])
	return INF if next <= 0.0 else next - _now()


func warning() -> bool:
	var l := left()
	return enabled() and live.is_empty() and l > 0.0 and l <= Raids.WARN


func can_postpone() -> bool:
	return warning() and not bool(_r()["postponed"])


func postpone() -> void:
	if not can_postpone():
		return
	_r()["next"] = float(_r()["next"]) + Raids.POSTPONE
	_r()["postponed"] = true
	_warned = false
	Game.mark_dirty()


## Пора начинать живой набег (только что наступил; пропущенный во время отсутствия считается сам).
func due() -> bool:
	var l := left()
	return enabled() and live.is_empty() and float(_r()["next"]) > 0.0 and l <= 0.0 and l > -20.0


## Раз в секунду (из плашки набега): расписание, предупреждение, набег без героя.
func tick() -> void:
	var r := _r()
	if not enabled():
		# Выключены или ещё рано: расписания нет
		if float(r["next"]) != 0.0 and not Settings.raids():
			r["next"] = 0.0
			Game.mark_dirty()
		return
	var now := _now()
	if float(r["next"]) <= 0.0:
		r["next"] = maxf(now + Raids.FIRST, float(r["shield"]))
		Game.mark_dirty()
		return
	if warning() and not _warned:
		_warned = true
		Game.show_toast("px:swords", L.t("raid.warn"))
		Sound.play("levelUp", 0.6)
	# Герой не дома: через 20 секунд после начала набег считается сам
	if live.is_empty() and left() < -20.0:
		resolve_absent()


## Сила защиты без героя против силы волны.
func absent_win() -> bool:
	var e := Game.estate
	var main := e.level("main")
	var t := e.working_level("tower") if e.level("tower") > 0 else 0
	var dps := float(Raids.tower_count(t)) * Raids.tower_damage(t) / Raids.TOWER_RATE
	var defense := dps * 40.0 / Raids.wall_slow(e.level("wall"))
	var hp := 0.0
	for kind in Raids.wave(main):
		hp += float(Monsters.stats(kind, Raids.wave_level())["hp"])
	return defense >= hp * 0.6


func resolve_absent() -> void:
	if absent_win():
		_finish(true, 0.5)
	else:
		_finish(false, 0.5)


# MARK: Живой набег

func start_live(total: int) -> void:
	live = {"total": total, "killed": 0, "stolen": 0}
	Game.emit_event("raid_start", {})


func note_killed() -> void:
	if live.is_empty():
		return
	live["killed"] = int(live["killed"]) + 1
	_check_live()


func note_stolen() -> void:
	if live.is_empty():
		return
	live["stolen"] = int(live["stolen"]) + 1
	_check_live()


func monsters_left() -> int:
	if live.is_empty():
		return 0
	return int(live["total"]) - int(live["killed"]) - int(live["stolen"])


func _check_live() -> void:
	if monsters_left() > 0:
		return
	# Отбились, если до склада дошла не больше трети волны
	var win := int(live["stolen"]) * 3 <= int(live["total"])
	live = {}
	_finish(win, 1.0)


## Герой ушёл с поляны посреди набега: остаток считается без него.
func abandon_live() -> void:
	if live.is_empty():
		return
	live = {}
	resolve_absent()


# MARK: Итог

## Награда за победу: монеты за 2 часа производства усадьбы (не меньше четверти награды за уровень), 2-5 кристаллов.
func win_coins() -> int:
	var e := Game.estate
	var per_hour := 0.0
	for id in Estate.IDS:
		if Estate.produces(id) and e.level(id) > 0:
			per_hour += Estate.PROD_BASE * pow(Estate.PROD_GROWTH, float(e.working_level(id) - 1))
	return int(round(maxf(per_hour * 2.0, Game.level_coin_reward(Game.level) * 0.25) / 10.0)) * 10


func _finish(win: bool, mult: float) -> void:
	var r := _r()
	var now := _now()
	r["postponed"] = false
	_warned = false
	if win:
		var coins := int(round(float(win_coins()) * mult))
		var crystals := maxi(1, int(round(float(randi_range(2, 5)) * mult)))
		Game.add_coins(coins)
		Game.shop.add_crystals(crystals)
		r["wins"] = int(r["wins"]) + 1
		r["next"] = now + Raids.EVERY
		Sound.play("coinBig")
		InfoPopup.show_info(L.t("raid.won"), L.t("raid.won.text" if mult >= 1.0 else "raid.won.away",
			[Fmt.n(coins), crystals]), "px:swords")
	else:
		var lost := _lose(Raids.LOSS * mult)
		r["losses"] = int(r["losses"]) + 1
		r["shield"] = now + Raids.SHIELD
		r["next"] = now + Raids.SHIELD
		InfoPopup.show_info(L.t("raid.lost"), L.t("raid.lost.text", [Fmt.n(lost)]), "px:shield")
	Game.emit_event("raid", {"win": win})
	Game.mark_dirty()
	Game.save_now()


## Монстры уносят долю незащищённой части каждого ресурса на складе. Возвращает, сколько унесли всего.
func _lose(share: float) -> int:
	var keep := Raids.protected_share(Game.estate.level("storage"))
	var frac := share * (1.0 - keep)
	var total := 0
	var storage: Dictionary = Game.save["storage"]
	for kind in storage.keys():
		var n := int(storage[kind])
		var lost := int(floor(float(n) * frac))
		if lost > 0:
			storage[kind] = n - lost
			total += lost
	return total
