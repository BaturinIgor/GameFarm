extends WorldFeature
## Звери на карте (порт части GameScene): спутники идут за героем, помощники сами добывают,
## производители приносят продукты, дикие звери появляются в своих локациях и ждут приручения.
## Загон у дома: в нём гуляют найденные звери, которые сейчас не с героем.

const POINTER_ARROW := "res://scripts/world/pointer_arrow.gd"
const WILD_ARROW_COLOR := Color(0.95, 0.4, 0.6)
## Места спутников вокруг героя (в SpriteKit y смотрел вверх, здесь вниз).
const SLOTS := [Vector2(-36, 24), Vector2(36, 24), Vector2(-60, -6), Vector2(60, -6), Vector2(0, 48)]

var companions: Array[CompanionNode] = []
var wild: WildNode

var _world: World
var _signature: Array = []
var _look_timer := 0
var _wild_timer := 20.0
var _producer_timers: Dictionary = {}
var _arrow: Node2D
var _encounter: Control
var _garden_rect := Rect2()
# Загон
var _pen_rect := Rect2()
var _pen_animals: Array = []    ## {node, area, goal, wait}
var _pen_signature: Array = []
var _pen_timer := 0.0
var _pen_card: Control
var _pen_count := -1


func build(world: World) -> void:
	_world = world
	_signature = []
	companions.clear()
	wild = null
	_wild_timer = randf_range(14.0, 24.0)
	# Грядки: дикие звери там не появляются
	_garden_rect = Rect2()
	var cell := world.layout.cell
	for p in world.layout.farm:
		var r := Rect2(p - Vector2(cell, cell) / 2.0, Vector2(cell, cell))
		_garden_rect = r if _garden_rect.size == Vector2.ZERO else _garden_rect.merge(r)
	if ResourceLoader.exists(POINTER_ARROW):
		_arrow = load(POINTER_ARROW).new(WILD_ARROW_COLOR, "paw")
		world.fx.add_child(_arrow)
	var kind: String = world.spec["kind"]
	if kind != "home" and kind != "dungeon" and world.layout.pen.size != Vector2.ZERO:
		_build_pen(world, world.layout.pen)
	_sync_companions(world)


func clear(_w: World) -> void:
	_hide_encounter()
	_set_pen_prompt(false)
	companions.clear()
	wild = null
	_arrow = null
	_signature = []
	_pen_animals.clear()
	_pen_signature = []
	_pen_rect = Rect2()


func process(world: World, dt: float) -> void:
	var stats := Game.stats
	_sync_companions(world)
	_sync_looks()
	_update_companions(world, dt, stats)
	_update_producers(world, dt, stats)
	_update_wild(world, dt, stats)
	_update_pen(world, dt)
	if _arrow != null and is_instance_valid(_arrow):
		var target = null
		if wild != null:
			target = wild.position
		_arrow.call("track", world, target)


## Герой не заходит в загон.
func resolve(_w: World, p: Vector2, radius: float) -> Vector2:
	if _pen_rect.size == Vector2.ZERO:
		return p
	return _push_out(p, _pen_rect, radius)


# MARK: Спутники

func _sync_companions(world: World) -> void:
	# Звери ждут во дворе: домой за героем не заходят.
	var ids: Array = []
	if world.spec["kind"] != "home":
		ids = (Game.save.get("active", []) as Array).duplicate()
	if ids == _signature:
		return
	_signature = ids
	var keep: Array[CompanionNode] = []
	for c in companions:
		if c.animal in ids:
			keep.append(c)
		else:
			_sparkle(world, c.position)
			c.queue_free()
	companions = keep
	for id in ids:
		if companions.any(func(c: CompanionNode) -> bool: return c.animal == id):
			continue
		var node := CompanionNode.new(id)
		node.position = world.player.position + Vector2(randf_range(-30.0, 30.0), randf_range(0.0, 30.0))
		world.entities.add_child(node)
		node.pop_in()
		companions.append(node)
		_sparkle(world, node.position)
	companions.sort_custom(func(a: CompanionNode, b: CompanionNode) -> bool: return ids.find(a.animal) < ids.find(b.animal))
	for c in companions:
		c.set_look(Game.animals.awaken_level(c.animal), Game.animals.is_shiny(c.animal))


func _sync_looks() -> void:
	_look_timer -= 1
	if _look_timer > 0:
		return
	_look_timer = 30
	for c in companions:
		c.set_look(Game.animals.awaken_level(c.animal), Game.animals.is_shiny(c.animal))
	for a in _pen_animals:
		var node: CompanionNode = a["node"]
		node.set_look(Game.animals.awaken_level(node.animal), Game.animals.is_shiny(node.animal))


func _update_companions(world: World, dt: float, stats: Stats) -> void:
	var helpers := {}
	for h in stats.helpers:
		helpers[h["animal"]] = h
	var follow := maxf(stats.speed * 1.05, 160.0)
	var hero := world.player.position
	for i in companions.size():
		var c := companions[i]
		var slot: Vector2 = hero + SLOTS[i % SLOTS.size()]
		if helpers.has(c.animal):
			_update_helper(world, c, helpers[c.animal], slot, dt, stats, follow)
		else:
			c.move_toward_point(slot, dt, follow)
		if c.position.distance_to(hero) > 420.0:
			# Отстал за препятствием: догоняет прыжком к персонажу.
			c.position = hero + Vector2(randf_range(-24.0, 24.0), 20.0)
			Fx.puff(world.fx, c.position, Color.WHITE, 26.0)
		c.position = _keep_on_ground(world, c.position, c.can_swim, c.set_swimming)


## Помощник выбирает ближайшую точку добычи рядом с героем и бьёт её.
func _update_helper(world: World, c: CompanionNode, helper: Dictionary, slot: Vector2, dt: float, stats: Stats,
		follow: float) -> void:
	var reach_range := stats.helper_range
	var spec: Dictionary = helper["spec"]
	var max_tier := int(spec["max_tier"]) + stats.helper_tier_bonus
	var hero := world.player.position
	if not is_instance_valid(c.target) or not c.target.alive or c.target.position.distance_to(hero) > reach_range + 70.0:
		c.target = null
	if c.target == null:
		c.retarget_timer -= dt
		if c.retarget_timer <= 0.0:
			c.retarget_timer = 0.4
			var tools: Array = spec["tools"]
			var best: ResourceSpot = null
			var best_d := INF
			for spot in world.spots:
				if not spot.alive or not spot.spec["tool"] in tools or int(spot.spec["tier"]) > max_tier:
					continue
				if spot.position.distance_to(hero) >= reach_range or _taken(spot, c):
					continue
				var d := spot.position.distance_to(c.position)
				if d < best_d:
					best = spot
					best_d = d
			c.target = best
	if c.target == null:
		c.move_toward_point(slot, dt, follow)
		return
	var target := c.target
	var reach := target.radius + 16.0
	if c.position.distance_to(target.position) > reach + 4.0:
		c.move_toward_point(target.position, dt, maxf(follow, 180.0), reach)
	else:
		c.move_toward_point(c.position, dt, 0.0)
		c.hit_timer -= dt * stats.helper_speed
		if c.hit_timer <= 0.0:
			c.hit_timer = float(spec["interval"])
			c.attack(target.position)
			world.helper_hit(target, float(helper["damage"]) * stats.helper_mult)
			if not target.alive:
				c.cheer()


func _taken(spot: ResourceSpot, by: CompanionNode) -> bool:
	for o in companions:
		if o != by and o.target == spot:
			return true
	return false


func _update_producers(world: World, dt: float, stats: Stats) -> void:
	for p in stats.producers:
		var id: String = p["animal"]
		var t := float(_producer_timers.get(id, 0.0)) + dt * stats.producer_mult
		if t < float(p["interval"]):
			_producer_timers[id] = t
			continue
		_producer_timers[id] = 0.0
		var n := 2 if randf() < stats.double_product_chance else 1
		Game.add_to_storage(p["kind"], n)
		Game.collection.roll_card(p["kind"], 0.02)
		for c in companions:
			if c.animal == id:
				Fx.gain(world.fx, p["kind"], n, c.position - Vector2(0, 40), 0.0, true)
				c.cheer()
				break


# MARK: Дикие звери

func _update_wild(world: World, dt: float, stats: Stats) -> void:
	var hero := world.player.position
	if wild != null:
		# Утки и лебеди прыгают в воду, когда к ним подходят.
		if wild.can_swim and not wild.diving and wild.position.distance_to(hero) < 150.0:
			var water = _nearest_water(world, wild.position, 6)
			if water != null:
				wild.dive(water)
		wild.wander(dt)
		wild.position = _keep_on_ground(world, wild.position, wild.can_swim, wild.set_swimming)
		var d := wild.position.distance_to(hero)
		if d < 80.0:
			_show_encounter()
		elif d > 104.0:
			_hide_encounter()
		if wild.life <= 0.0:
			wild.leave()
			wild = null
			_hide_encounter()
		return
	var here: Array = world.spec.get("wild", [])
	if here.is_empty():
		return
	_wild_timer -= dt * stats.spawn_mult
	if _wild_timer <= 0.0:
		_wild_timer = randf_range(45.0, 80.0)
		_spawn_wild(world, stats, here)


func _spawn_wild(world: World, stats: Stats, here: Array) -> void:
	var candidates := here.filter(func(id: String) -> bool: return Game.animals.stars(id) < Animals.MAX_STARS)
	if candidates.is_empty():
		return
	# Новых зверей встречаем чаще
	var weights: Array = []
	var total := 0.0
	for id in candidates:
		var w := Animals.wild_weight(id) * (1.6 if Game.animals.stars(id) == 0 else 1.0)
		weights.append(w)
		total += w
	var roll := randf() * total
	var chosen: String = candidates[0]
	for i in candidates.size():
		roll -= float(weights[i])
		if roll <= 0.0:
			chosen = candidates[i]
			break
	var point = _random_open_point(world, 240.0)
	if point == null:
		return
	var node := WildNode.new(chosen, point, 160.0 * stats.spawn_mult)
	if randf() < Animals.SHINY_CHANCE:
		node.make_shiny()
	var layout := world.layout
	node.allows = func(p: Vector2, water: bool) -> bool:
		var cr := layout.col_row(p)
		return layout.is_water(cr.x, cr.y) if water else layout.walkable_cell(cr.x, cr.y)
	var fx := world.fx
	node.on_splash = func(p: Vector2) -> void: Fx.ring(fx, p, Color(0.75, 0.92, 1), 22.0)
	world.entities.add_child(node)
	wild = node
	Game.show_toast("an:" + chosen, L.t("toast.wild", [Animals.name_of(chosen)]))


## Свободная клетка суши подальше от героя, ресурсов, проходов, грядок и лавки (null - не нашлось).
func _random_open_point(world: World, min_from_player: float) -> Variant:
	var layout := world.layout
	for _i in 60:
		var c := randi_range(2, maxi(3, layout.cols - 2) - 1)
		var r := randi_range(2, maxi(3, layout.rows - 2) - 1)
		var kind := layout.at(c, r)
		if kind != MapLayout.Cell.LAND and kind != MapLayout.Cell.PATH:
			continue
		# Не у самого края: все соседи тоже проходимы.
		if not (layout.walkable_cell(c - 1, r) and layout.walkable_cell(c + 1, r)
				and layout.walkable_cell(c, r - 1) and layout.walkable_cell(c, r + 1)):
			continue
		var p := layout.center(c, r)
		if p.distance_to(world.player.position) < min_from_player:
			continue
		if world.spots.any(func(s: ResourceSpot) -> bool: return p.distance_to(s.position) < 44.0):
			continue
		if layout.gates.any(func(g: Dictionary) -> bool: return p.distance_to(g["barrier"]) < 120.0):
			continue
		if _garden_rect.size != Vector2.ZERO and _garden_rect.grow(48.0).has_point(p):
			continue
		if layout.stall != null and p.distance_to(layout.stall) < 120.0:
			continue
		return p
	return null


## Центр ближайшей клетки воды (не у самого берега) в пределах radius клеток.
func _nearest_water(world: World, p: Vector2, radius: int) -> Variant:
	var layout := world.layout
	var cr := layout.col_row(p)
	var best = null
	var best_d := INF
	for r in range(cr.y - radius, cr.y + radius + 1):
		for c in range(cr.x - radius, cr.x + radius + 1):
			if not layout.is_water(c, r):
				continue
			var wet := 0
			for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if layout.is_water(c + dir.x, r + dir.y):
					wet += 1
			if wet < 3:
				continue
			var q := layout.center(c, r)
			var d := q.distance_to(p)
			if d < best_d:
				best_d = d
				best = q
	return best


func _show_encounter() -> void:
	if _encounter != null and is_instance_valid(_encounter):
		return
	if Hud.current == null or wild == null:
		return
	_set_pen_prompt(false)
	_encounter = EncounterCard.new(wild.animal, wild.shiny, _tame_nearby)
	Hud.current.set_prompt("encounter", _encounter)


func _hide_encounter() -> void:
	if _encounter == null:
		return
	_encounter = null
	if Hud.current != null:
		Hud.current.set_prompt("encounter", null)


## Кнопка "Приручить" на карточке.
func _tame_nearby() -> void:
	if wild == null or not is_instance_valid(_world):
		return
	var w := wild
	if not Game.animals.tame(w.animal, w.shiny):
		return
	var fx := _world.fx
	Fx.scatter(fx, w.position - Vector2(0, 24), 7, Color(1, 0.55, 0.75), Sprites.icon("heart"), 16.0, 44.0, 36.0, 0.9)
	Fx.ring(fx, w.position, Color(1, 0.5, 0.7), 34.0)
	w.queue_free()
	wild = null
	_hide_encounter()
	_world.player.celebrate()
	Input.vibrate_handheld(30)


# MARK: Загон

func _build_pen(world: World, rect: Rect2) -> void:
	_pen_rect = rect
	var cols := int(round(rect.size.x / 32.0))
	var rows := int(round(rect.size.y / 32.0))
	var top := rect.position.y + 16.0
	var bottom := rect.end.y - 16.0
	var left := rect.position.x + 16.0
	var right := rect.end.x - 16.0
	_fence(world, "fence_tl", left, top)
	_fence(world, "fence_tr", right, top)
	_fence(world, "fence_bl", left, bottom)
	_fence(world, "fence_br", right, bottom)
	for i in range(1, maxi(1, cols - 1)):
		_fence(world, "fence_h", left + i * 32.0, top)
		_fence(world, "fence_h", left + i * 32.0, bottom)
	for j in range(1, maxi(1, rows - 1)):
		_fence(world, "fence_v", left, bottom - j * 32.0)
		_fence(world, "fence_v", right, bottom - j * 32.0)
	var props := [["hay_big", rect.position.x + 64.0, rect.position.y + 46.0],
		["trough", rect.end.x - 70.0, rect.position.y + 44.0],
		["nest", rect.position.x + 44.0, rect.end.y - 36.0],
		["ic_pen", rect.get_center().x, rect.end.y + 2.0]]
	for it in props:
		var s := Sprites.make(it[0], Vector2(it[1], it[2]))
		if s != null:
			world.entities.add_child(s)
	_sync_pen(world)


## Секция забора сортируется чуть ниже своей точки, чтобы звери внутри были за ней.
func _fence(world: World, sprite: String, x: float, y: float) -> void:
	var s := Sprites.make(sprite, Vector2(0, -10))
	if s == null:
		return
	var holder := Node2D.new()
	holder.position = Vector2(x, y + 10.0)
	holder.add_child(s)
	world.entities.add_child(holder)


## Звери в загоне совпадают с найденными (кроме тех, что сейчас с героем).
func _sync_pen(world: World) -> void:
	if _pen_rect.size == Vector2.ZERO:
		return
	var want := Animals.IDS.filter(func(id: String) -> bool:
		return Game.animals.stars(id) > 0 and not Game.animals.is_active(id))
	if want == _pen_signature:
		return
	_pen_signature = want
	for a in _pen_animals:
		var old: CompanionNode = a["node"]
		if is_instance_valid(old):
			old.queue_free()
	_pen_animals.clear()
	var area := _pen_rect.grow_individual(-40.0, -36.0, -40.0, -36.0)
	for id in want:
		var p := Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))
		var node := CompanionNode.new(id)
		node.position = p
		world.entities.add_child(node)
		node.set_look(Game.animals.awaken_level(id), Game.animals.is_shiny(id))
		_pen_animals.append({"node": node, "area": area, "goal": p, "wait": randf_range(0.5, 3.0)})


func _update_pen(world: World, dt: float) -> void:
	if _pen_rect.size == Vector2.ZERO:
		return
	_pen_timer -= dt
	if _pen_timer <= 0.0:
		_pen_timer = 1.0
		_sync_pen(world)
	_set_pen_prompt(_encounter == null and _pen_rect.grow(40.0).has_point(world.player.position))
	# Звери далеко от камеры не двигаются: не тратим на них кадры.
	var view := world.get_viewport_rect().size
	if world.camera.position.distance_to(_pen_rect.get_center()) >= maxf(view.x, view.y):
		return
	for a in _pen_animals:
		var node: CompanionNode = a["node"]
		var goal: Vector2 = a["goal"]
		if node.position.distance_to(goal) < 6.0:
			a["wait"] = float(a["wait"]) - dt
			if float(a["wait"]) <= 0.0:
				var area: Rect2 = a["area"]
				a["wait"] = randf_range(1.5, 5.0)
				a["goal"] = Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))
		node.move_toward_point(a["goal"], dt, 38.0, 4.0)


## Подсказка у загона (PlaceCard для загона): сколько зверей и кнопка окна зверей.
func _set_pen_prompt(on: bool) -> void:
	if Hud.current == null:
		return
	var count := Game.animals.owned().size()
	if on and _pen_card != null and is_instance_valid(_pen_card) and count == _pen_count:
		return
	if not on:
		if _pen_card != null:
			_pen_card = null
			Hud.current.set_prompt("pen", null)
		return
	_pen_count = count
	_pen_card = _make_pen_card(count)
	Hud.current.set_prompt("pen", _pen_card)


func _make_pen_card(count: int) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.panel_style(18))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	p.add_child(row)
	var ic := UiKit.icon("paw", 36)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	col.add_child(UiKit.label(L.t("pen.title"), 15))
	var sub := UiKit.label(L.t("pen.count", [count]), 12, UiKit.INK_SOFT)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(sub)
	var b := UiKit.button(L.t("hud.animals"), "green")
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void:
		if Hud.current != null:
			Hud.current.open_named("animals"))
	row.add_child(b)
	return p


# MARK: Помощники

## Звери ходят только по суше, а утки и лебеди могут плавать.
func _keep_on_ground(world: World, point: Vector2, swims: bool, swimming: Callable) -> Vector2:
	var layout := world.layout
	var cr := layout.col_row(point)
	if swims and layout.is_water(cr.x, cr.y):
		swimming.call(true)
		return point
	swimming.call(false)
	var p := point
	for dr in range(-1, 2):
		for dc in range(-1, 2):
			var c := cr.x + dc
			var r := cr.y + dr
			if layout.walkable_cell(c, r) or (swims and layout.is_water(c, r)):
				continue
			p = _push_out(p, layout.rect(c, r), 6.0)
	return p


## Выталкивает круг из прямоугольника.
func _push_out(p: Vector2, r: Rect2, radius: float) -> Vector2:
	if r.size == Vector2.ZERO:
		return p
	var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
	var d := p.distance_to(q)
	if d >= radius:
		return p
	if d > 0.01:
		return q + (p - q) / d * radius
	# Центр внутри прямоугольника: выходим через ближайшую сторону
	var left := p.x - r.position.x
	var right := r.end.x - p.x
	var top := p.y - r.position.y
	var bottom := r.end.y - p.y
	var m := minf(minf(left, right), minf(top, bottom))
	if m == left:
		return Vector2(r.position.x - radius, p.y)
	if m == right:
		return Vector2(r.end.x + radius, p.y)
	if m == top:
		return Vector2(p.x, r.position.y - radius)
	return Vector2(p.x, r.end.y + radius)


func _sparkle(world: World, pos: Vector2) -> void:
	Fx.scatter(world.fx, pos - Vector2(0, 18), 6, Color(1, 0.95, 0.7), null, 5.0, 28.0, 18.0, 0.5)
