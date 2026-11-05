class_name IncubatorSystem
extends RefCounted
## Инкубатор и Гнездо (данные - data/incubator.gd).
## В Game.save: incubator = {eggs: [яйцо], slot: {egg, until} или {}, nest: {a, b, until} или {}, found: [гибриды]}.
## Яйцо: {r: редкость, a: гибрид или "", s: шанс редкой окраски (0 - по редкости)}.


func defaults(save: Dictionary) -> void:
	var raw: Dictionary = save.get("incubator", {}) if save.get("incubator") is Dictionary else {}
	var eggs: Array = []
	if raw.get("eggs") is Array:
		for e in raw["eggs"]:
			var egg := _clean_egg(e)
			if not egg.is_empty() and eggs.size() < Incubator.MAX_EGGS:
				eggs.append(egg)
	var slot := {}
	if raw.get("slot") is Dictionary and not (raw["slot"] as Dictionary).is_empty():
		var egg := _clean_egg(raw["slot"].get("egg"))
		if not egg.is_empty():
			slot = {"egg": egg, "until": float(raw["slot"].get("until", 0.0))}
	var nest := {}
	if raw.get("nest") is Dictionary and not (raw["nest"] as Dictionary).is_empty():
		var a := str(raw["nest"].get("a", ""))
		var b := str(raw["nest"].get("b", ""))
		if a in Animals.IDS and b in Animals.IDS:
			nest = {"a": a, "b": b, "until": float(raw["nest"].get("until", 0.0))}
	var found: Array = []
	if raw.get("found") is Array:
		for h in raw["found"]:
			if str(h) in Incubator.HYBRIDS and not str(h) in found:
				found.append(str(h))
	save["incubator"] = {"eggs": eggs, "slot": slot, "nest": nest, "found": found}


static func _clean_egg(e: Variant) -> Dictionary:
	if not e is Dictionary:
		return {}
	var r := str(e.get("r", ""))
	if not r in Incubator.RARITIES:
		return {}
	var a := str(e.get("a", ""))
	if a != "" and not a in Incubator.HYBRIDS:
		a = ""
	return {"r": r, "a": a, "s": clampf(float(e.get("s", 0.0)), 0.0, 1.0)}


func _d() -> Dictionary:
	return Game.save["incubator"]


static func _now() -> float:
	return Clock.now()


func open() -> bool:
	return Game.level >= Incubator.MIN_LEVEL


func eggs() -> Array:
	return _d()["eggs"]


func found() -> Array:
	return _d()["found"]


# MARK: Яйца

## Положить яйцо в запас. Запас полный - кристаллы вместо яйца. toast - показать всплывашку.
func add_egg(r: String, hybrid := "", shiny := 0.0, toast := true) -> void:
	if not r in Incubator.RARITIES:
		return
	if eggs().size() >= Incubator.MAX_EGGS:
		Game.shop.add_crystals(int(Incubator.CRYSTALS.get(r, 3)))
		return
	eggs().append({"r": r, "a": hybrid, "s": shiny})
	if toast:
		Game.show_toast("egg:" + r, L.t("egg.got", [Incubator.name_of(r)]))
	Game.mark_dirty()
	Game.changed.emit()


func buy_egg() -> bool:
	if eggs().size() >= Incubator.MAX_EGGS or not Game.shop.spend_crystals(Incubator.EGG_PRICE):
		return false
	add_egg(Incubator.EGG_PRICE_RARITY, "", 0.0, false)
	Sound.play("purchase")
	return true


# MARK: Инкубатор

func slot() -> Dictionary:
	return _d()["slot"]


func busy() -> bool:
	return not slot().is_empty()


func time_left() -> float:
	if not busy():
		return 0.0
	return maxf(0.0, float(slot()["until"]) - _now())


func ready() -> bool:
	return busy() and time_left() <= 0.0


## Положить яйцо из запаса (индекс) в инкубатор.
func incubate(index: int) -> bool:
	if not open() or busy() or index < 0 or index >= eggs().size():
		return false
	var egg: Dictionary = eggs()[index]
	eggs().remove_at(index)
	_d()["slot"] = {"egg": egg, "until": _now() + Incubator.hours(str(egg["r"])) * 3600.0}
	Sound.play("open")
	Game.save_now()
	Game.changed.emit()
	return true


static func speed_price(seconds: float) -> int:
	return maxi(1, int(ceil(seconds / 60.0 / Incubator.SPEED_MINUTES)))


func speed_up() -> bool:
	if not busy() or ready():
		return false
	if not Game.shop.spend_crystals(speed_price(time_left())):
		return false
	slot()["until"] = _now()
	Sound.play("purchase")
	Game.save_now()
	Game.changed.emit()
	return true


## Вылупить готовое яйцо. Возвращает {animal, stars, shiny, new, crystals, rarity} или {}.
func hatch() -> Dictionary:
	if not ready():
		return {}
	var egg: Dictionary = slot()["egg"]
	_d()["slot"] = {}
	var out := roll(egg, Game.level)
	give(out)
	Game.emit_event("hatch", {"animal": out["animal"], "rarity": egg["r"]})
	Game.save_now()
	Game.changed.emit()
	return out


## Кто вылупится (без выдачи). Отдельно - для тестов.
static func roll(egg: Dictionary, level: int) -> Dictionary:
	var r := str(egg["r"])
	var animal := str(egg.get("a", ""))
	if animal == "":
		var pool := Incubator.pool(r, level)
		animal = str(pool.pick_random()) if not pool.is_empty() else "chicken"
	var chance := float(egg.get("s", 0.0))
	if chance <= 0.0:
		chance = float(Incubator.SHINY.get(r, 0.03))
	return {"animal": animal, "stars": int(Incubator.STARS.get(r, 1)), "shiny": randf() < chance, "rarity": r,
		"new": false, "crystals": 0}


func give(out: Dictionary) -> void:
	var id := str(out["animal"])
	var a := Game.animals
	out["new"] = a.stars(id) == 0
	if a.stars(id) >= Animals.MAX_STARS:
		var n := int(Incubator.CRYSTALS.get(str(out["rarity"]), 3))
		Game.shop.add_crystals(n)
		out["crystals"] = n
	else:
		a.add_star(id, int(out["stars"]))
	if bool(out["shiny"]):
		a.mark_shiny(id)
	if Animals.is_hybrid(id) and not id in found():
		found().append(id)


# MARK: Гнездо

func nest() -> Dictionary:
	return _d()["nest"]


func nesting() -> bool:
	return not nest().is_empty()


func nest_left() -> float:
	if not nesting():
		return 0.0
	return maxf(0.0, float(nest()["until"]) - _now())


func nest_ready() -> bool:
	return nesting() and nest_left() <= 0.0


## Звери, которых можно посадить в гнездо: от 3 звёзд.
func parents() -> Array:
	return Game.animals.owned().filter(func(id: String) -> bool: return Game.animals.stars(id) >= Incubator.NEST_STARS)


func can_breed(a: String, b: String) -> bool:
	return open() and not nesting() and a != b and a in parents() and b in parents()


func breed(a: String, b: String) -> bool:
	if not can_breed(a, b):
		return false
	_d()["nest"] = {"a": a, "b": b, "until": _now() + Incubator.NEST_SECONDS}
	Sound.play("tame")
	Game.save_now()
	Game.changed.emit()
	return true


## Яйцо пары: гибрид по рецепту (золотое) или обычное синее. Окраска наследуется: один редкий родитель - 25%, оба - 50%.
static func nest_egg(a: String, b: String, shiny_a: bool, shiny_b: bool) -> Dictionary:
	var hybrid := Incubator.hybrid_of(a, b)
	var s := 0.0
	if shiny_a and shiny_b:
		s = 0.5
	elif shiny_a or shiny_b:
		s = 0.25
	return {"r": "gold" if hybrid != "" else "blue", "a": hybrid, "s": s}


func collect_nest() -> Dictionary:
	if not nest_ready():
		return {}
	var n := nest()
	var egg := nest_egg(str(n["a"]), str(n["b"]), Game.animals.is_shiny(str(n["a"])), Game.animals.is_shiny(str(n["b"])))
	_d()["nest"] = {}
	add_egg(str(egg["r"]), str(egg["a"]), float(egg["s"]), false)
	Sound.play("success")
	Game.save_now()
	return egg


func nest_speed_up() -> bool:
	if not nesting() or nest_ready():
		return false
	if not Game.shop.spend_crystals(speed_price(nest_left())):
		return false
	nest()["until"] = _now()
	Sound.play("purchase")
	Game.save_now()
	Game.changed.emit()
	return true


## Отметка на вкладке: яйцо готово, гнездо готово или инкубатор пуст при запасе яиц.
func ready_count() -> int:
	if not open():
		return 0
	var n := 0
	if ready() or (not busy() and not eggs().is_empty()):
		n += 1
	if nest_ready():
		n += 1
	return n


# MARK: Откуда яйца

func on_event(name: String, data: Dictionary) -> void:
	match name:
		"mine":
			var f := int(data.get("floor", 0))
			if f > 0 and f % 3 == 0:
				add_egg(Incubator.mine_egg(f))
