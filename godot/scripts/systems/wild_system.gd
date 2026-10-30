class_name WildSystem
extends RefCounted
## Дикие земли. В Game.save: wild = {week, done: {сектор: true}, squads: [{sector, animals, until, loot}]}.
## Зверь в походе не ходит с героем: выбор между бонусом сейчас и редкими материалами потом.
## Логово - подземелье кольца; после победы сектор пуст до конца недели.

## Логово, которое сейчас проходит герой (id сектора), пока идёт подземелье.
var lair := ""


func defaults(save: Dictionary) -> void:
	var raw: Variant = save.get("wild", {})
	var w: Dictionary = raw if raw is Dictionary else {}
	var squads: Array = []
	for s in w.get("squads", []):
		if s is Dictionary and s.has("sector") and s.has("until"):
			squads.append({"sector": str(s["sector"]), "animals": s.get("animals", []), "until": float(s["until"]),
				"loot": s.get("loot", {})})
	save["wild"] = {"week": int(w.get("week", -1)), "done": w.get("done", {}) if w.get("done") is Dictionary else {},
		"squads": squads}


func _w() -> Dictionary:
	var w: Dictionary = Game.save["wild"]
	# Новая неделя - новые сектора; отряды в пути возвращаются как обычно
	if int(w["week"]) != Wild.week():
		w["week"] = Wild.week()
		w["done"] = {}
	return w


static func _now() -> float:
	return Time.get_unix_time_from_system()


func open() -> bool:
	return Game.level >= int(Wild.RINGS[0]["level"])


func ring_open(ring: int) -> bool:
	return Game.level >= int(Wild.RINGS[ring]["level"])


func squads_total() -> int:
	return Wild.squads(Game.estate.level("camp"))


func squads() -> Array:
	return _w()["squads"]


func squads_free() -> int:
	return maxi(0, squads_total() - squads().size())


func done(sector_id: String) -> bool:
	return bool(_w()["done"].get(sector_id, false))


## Отряд в этом секторе (пусто - нет).
func squad_at(sector_id: String) -> Dictionary:
	for s in squads():
		if s["sector"] == sector_id:
			return s
	return {}


func on_squad(animal: String) -> bool:
	for s in squads():
		if animal in s["animals"]:
			return true
	return false


## Звери, которых можно отправить: есть хотя бы одна звезда и не в другом отряде.
func free_animals() -> Array:
	return Game.animals.owned().filter(func(id: String) -> bool: return not on_squad(id))


## Отправить отряд в месторождение. Звери, взятые с собой, остаются дома.
func send(sector_id: String, animals: Array) -> bool:
	var sec := Wild.sector(sector_id)
	if sec.is_empty() or sec["kind"] != "deposit" or done(sector_id) or not squad_at(sector_id).is_empty():
		return false
	if animals.is_empty() or animals.size() > Wild.SQUAD_SIZE or squads_free() <= 0 or not ring_open(int(sec["ring"])):
		return false
	var stars := 0
	for a in animals:
		if on_squad(a) or Game.animals.stars(a) <= 0:
			return false
		stars += Game.animals.stars(a)
	for a in animals:
		if Game.animals.is_active(a):
			Game.animals.toggle_active(a)
	var loot := Wild.deposit_loot(int(sec["ring"]), float(sec["hours"]), stars)
	squads().append({"sector": sector_id, "animals": animals.duplicate(), "until": _now() + float(sec["hours"]) * 3600.0 * Game.academy.mult("squads"),
		"loot": loot})
	_w()["done"][sector_id] = true
	Game.emit_event("squad", {"sector": sector_id})
	Game.mark_dirty()
	Game.save_now()
	return true


func squad_left(s: Dictionary) -> float:
	return maxf(0.0, float(s["until"]) - _now())


func ready_count() -> int:
	return squads().filter(func(s: Dictionary) -> bool: return squad_left(s) <= 0.0).size()


## Забрать вернувшиеся отряды: добыча на склад (сверх лимита не влезет). Возвращает собранное.
func collect() -> Dictionary:
	var got := {}
	var keep: Array = []
	for s in squads():
		if squad_left(s) > 0.0:
			keep.append(s)
			continue
		for k in s["loot"]:
			var n := Game.add_to_storage(k, int(s["loot"][k]))
			if n > 0:
				got[k] = int(got.get(k, 0)) + n
	_w()["squads"] = keep
	if not got.is_empty():
		Sound.play("coinBig")
		Game.mark_dirty()
		Game.save_now()
	return got


# MARK: Логово, руины, тайник

func start_lair(sector_id: String) -> bool:
	var sec := Wild.sector(sector_id)
	if sec.is_empty() or sec["kind"] != "lair" or done(sector_id) or not ring_open(int(sec["ring"])):
		return false
	var spec: Dictionary = Wild.RINGS[int(sec["ring"])]
	var id: String = spec["dungeon"]
	var fl := clampi(int(spec["floor"]), 1, Game.dungeons.dungeon_best(id) + 1)
	if not Game.dungeons.can_enter(id, fl):
		return false
	lair = sector_id
	Game.dungeons.start_dungeon(id, fl)
	return true


func start_ruins(sector_id: String) -> bool:
	var sec := Wild.sector(sector_id)
	if sec.is_empty() or sec["kind"] != "ruins" or str(sec["expedition"]) == "":
		return false
	return Game.premium.start_expedition(str(sec["expedition"]))


func open_cache(sector_id: String) -> Dictionary:
	var sec := Wild.sector(sector_id)
	if sec.is_empty() or sec["kind"] != "cache" or done(sector_id) or not ring_open(int(sec["ring"])):
		return {}
	var r := Wild.cache_reward(int(sec["ring"]))
	Game.add_coins(int(r["coins"]))
	Game.add_to_storage(str(r["rare"]), int(r["n"]))
	_w()["done"][sector_id] = true
	Sound.play("coinBig")
	Game.mark_dirty()
	Game.save_now()
	return r


func on_event(name: String, data: Dictionary) -> void:
	# Этаж подземелья пройден: если это было логово, сектор пуст до конца недели, плюс награда
	if name == "dungeon" and lair != "":
		var sec := Wild.sector(lair)
		if not sec.is_empty() and str(data.get("dungeon", "")) == str(Wild.RINGS[int(sec["ring"])]["dungeon"]):
			var r := Wild.lair_reward(int(sec["ring"]))
			Game.add_to_storage("essence", int(r["essence"]))
			Game.shop.add_crystals(int(r["crystals"]), true)
			_w()["done"][lair] = true
			Game.show_toast("px:skull", L.t("wild.lairDone", [int(r["essence"]), int(r["crystals"])]))
			Game.mark_dirty()
		lair = ""
