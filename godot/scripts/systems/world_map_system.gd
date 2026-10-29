class_name WorldMapSystem
extends RefCounted
## Проходы между локациями, их открытие, переход по карте мира и планеты (порт части GameState:
## isUnlocked, refreshReachable, migrateGates, isGateOpen, gateCost, openGate, walk, travel).
## В Game.save: openGates (открытые проходы), unlocked (локации родной планеты, куда можно дойти), current.

## Локации родной планеты, куда можно дойти от луга через открытые проходы.
var reachable: Array = ["meadow"]


func defaults(save: Dictionary) -> void:
	var open: Array = []
	for g in save.get("openGates", []):
		if not str(g) in open:
			open.append(str(g))
	save["openGates"] = open
	var unlocked: Array = []
	for id in save.get("unlocked", ["meadow"]):
		if Locations.SPECS.has(str(id)) and not str(id) in unlocked:
			unlocked.append(str(id))
	if not "meadow" in unlocked:
		unlocked.insert(0, "meadow")
	save["unlocked"] = unlocked
	# Проверки при чтении сохранения (как в SaveData): закрытая локация или чужая планета не по уровню - на луг
	var cur := str(save.get("current", "meadow"))
	if Locations.kind(cur) == "world" and Locations.planet(cur) == "home" and not cur in unlocked:
		cur = "meadow"
	if Locations.planet(cur) != "home" and int(save.get("level", 1)) < int(Locations.spec(cur)["level"]):
		cur = "meadow"
	save["current"] = cur
	_migrate_gates(save)
	_refresh(save)
	if cur == "garden" and not Game.premium.owns("garden"):
		save["current"] = "meadow"


## Старые сохранения: локации открывались без проходов. Открываем проходы по цепочке до каждой.
func _migrate_gates(save: Dictionary) -> void:
	var open: Array = save["openGates"]
	var had: Array = save["unlocked"]
	if not open.is_empty() or had.size() <= 1:
		return
	for id in had:
		if id == "meadow":
			continue
		var path = WorldGraph.path(id, had)
		if path == null:
			path = WorldGraph.path(id, null)
		if path == null:
			continue
		for gate_id in path:
			if gate_id in open:
				continue
			open.append(gate_id)
			for g in WorldGraph.bundle(WorldGraph.gate(gate_id)):
				if not g["id"] in open:
					open.append(g["id"])


## Пересчитать, куда можно дойти (после открытия прохода, перерождения, копии из файла).
func refresh_reachable() -> void:
	_refresh(Game.save)


func _refresh(save: Dictionary) -> void:
	reachable = WorldGraph.reachable(save.get("openGates", []))
	save["unlocked"] = Locations.world().filter(func(id: String) -> bool: return id in reachable)


func is_reachable(id: String) -> bool:
	return id in reachable


# MARK: Локации

## Можно ли сейчас попасть в локацию.
func is_unlocked(id: String) -> bool:
	match Locations.kind(id):
		"world":
			var p := Locations.planet(id)
			if p == "home":
				return id in reachable
			return Game.level >= maxi(WorldGraph.planet_level(p), int(Locations.spec(id)["level"]))
		"garden":
			return Game.premium.owns("garden")
		"expedition":
			var run = Game.save.get("expedition")
			return run is Dictionary and str(run.get("location", "")) == id
		"event":
			return Game.events.is_unlocked(id)
		"home":
			var f := House.floor_of(id)
			return f != "" and Game.house.is_built(f)
		"dungeon":
			var run = Game.dungeons.run
			return run != null and Dungeons.location(run["dungeon"]) == id
	return false


func planet_open(p: String) -> bool:
	return Game.level >= WorldGraph.planet_level(p)


## Быстрый переход по карте: появляемся у склада. true - перешли.
func travel(id: String) -> bool:
	if not is_unlocked(id) or Game.current == id or Game.save.get("expedition") != null or Game.dungeons.run != null:
		return false
	var was_event := Locations.kind(Game.current) == "event"
	Game.arrival_gate = ""
	Game.save["current"] = id
	# Усиления ивента действуют только на его картах
	if was_event or Locations.kind(id) == "event":
		Game.recalc()
	Game.mark_dirty()
	return true


## Персонаж прошёл через открытые ворота на краю карты.
func walk_through(gate_id: String) -> void:
	var g := WorldGraph.gate(gate_id)
	if g.is_empty() or not is_gate_open(gate_id) or not WorldGraph.connects(g, Game.current):
		return
	var target := WorldGraph.other(g, Game.current)
	if not is_unlocked(target):
		return
	Game.arrival_gate = gate_id
	Game.save["current"] = target
	Game.mark_dirty()


# MARK: Проходы

func is_gate_open(id: String) -> bool:
	var g := WorldGraph.gate(id)
	if g.is_empty():
		return false
	if g["royal"]:
		return Game.premium.owns("garden")
	return id in Game.save.get("openGates", [])


## Цена прохода. Короткий путь между двумя уже открытыми локациями стоит вдвое дешевле.
func gate_cost(g: Dictionary) -> Dictionary:
	var cost := Game.discounted(g["cost"])
	if g["a"] in reachable and g["b"] in reachable:
		return _scaled(cost, 0.5)
	return cost


static func _scaled(cost: Dictionary, f: float) -> Dictionary:
	var items: Array = []
	for it in cost.get("items", []):
		items.append([it[0], maxi(1, int(ceil(float(it[1]) * f)))])
	return {"coins": int(ceil(float(cost.get("coins", 0)) * f)), "items": items}


func can_open_gate(g: Dictionary) -> bool:
	return not g["royal"] and not is_gate_open(g["id"]) and Game.level >= WorldGraph.level(g) \
		and Game.can_afford(gate_cost(g))


## Сколько закрытых проходов можно открыть прямо сейчас (для значка на карте).
func openable_gates() -> int:
	var n := 0
	for g in WorldGraph.GATES:
		if (g["a"] in reachable or g["b"] in reachable) and can_open_gate(g):
			n += 1
	return n


## Открыть проход (вместе со всей его группой). true - открыли.
func open_gate(id: String) -> bool:
	var g := WorldGraph.gate(id)
	if g.is_empty() or not can_open_gate(g):
		return false
	var before := reachable.duplicate()
	Game.pay(gate_cost(g))
	var open: Array = Game.save["openGates"]
	for b in WorldGraph.bundle(g):
		if not b["id"] in open:
			open.append(b["id"])
	refresh_reachable()
	var fresh := Locations.world().filter(func(loc: String) -> bool: return loc in reachable and not loc in before)
	for loc in fresh:
		Game.show_toast("px:map", L.t("toast.locationOpened", [Locations.name_of(loc)]))
		Game.gain_xp(int(Locations.spec(loc)["level"]) * 15)
	if fresh.is_empty():
		Game.show_toast("px:door", L.t("toast.gateOpened"))
	Sound.play("gateOpen")
	Game.mark_dirty()
	Game.save_now()
	return true
