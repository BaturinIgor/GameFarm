class_name RaidFeature
extends WorldFeature
## Защита усадьбы на Лесной поляне: башни и частокол у склада, набег вживую.
## Монстры волны выходят с краёв карты и идут к складу; постояв у склада, уносят добычу и уходят.
## Башни стреляют по ним, частокол замедляет в своей зоне, герой и питомцы дерутся как обычно.

## Желаемые места башен относительно склада.
const SPOTS := [Vector2(-230, 60), Vector2(230, 60), Vector2(-170, 300), Vector2(170, 300)]

var _towers: Array = []
var _walls: Array = []
var _raiders: Array = []
var _steal: Dictionary = {}
var _key := ""
var _ring: Line2D
var _world: World
var _slow_tick := 0.0


func build(world: World) -> void:
	_world = world
	_towers = []
	_walls = []
	_raiders = []
	_steal = {}
	_key = ""
	_ring = null
	if world.loaded == "meadow":
		_build_defense(world)


func clear(_w: World) -> void:
	if not Game.raids.live.is_empty():
		Game.raids.abandon_live()
	_towers = []
	_walls = []
	_raiders = []
	_steal = {}
	_key = ""
	_ring = null


## Сквозь башни не пройти.
func resolve(_w: World, p: Vector2, radius: float) -> Vector2:
	for t in _towers:
		if not is_instance_valid(t):
			continue
		var c: Vector2 = t.position - Vector2(0, 8)
		var min_d := 20.0 + radius
		var d := p.distance_to(c)
		if d < min_d:
			return c + Vector2(0, min_d) if d < 0.01 else c + (p - c) * (min_d / d)
	return p


## Башни и частокол по уровням зданий; перестраиваются, когда уровни меняются.
func _build_defense(world: World) -> void:
	var e := Game.estate
	var towers := Raids.tower_count(e.level("tower"))
	var wall := e.level("wall")
	var key := "%d|%d" % [towers, wall]
	if key == _key:
		return
	_key = key
	for n in _towers + _walls:
		if is_instance_valid(n):
			n.queue_free()
	_towers = []
	_walls = []
	var count := maxi(towers, 2 if wall > 0 else 0)
	var taken: Array = []
	for n in world.entities.get_children():
		if n is ResidentNode:
			taken.append(n.position)
	for i in count:
		var p = _place(world, world.layout.base + SPOTS[i], taken)
		if not (p is Vector2):
			continue
		taken.append(p)
		if i < towers:
			var t := TowerNode.new()
			t.position = p
			world.entities.add_child(t)
			_towers.append(t)
		if wall > 0:
			# Частокол по бокам от места башни: с 10 уровня - по два звена
			var links := 1 if wall < 10 else 2
			for side in [-1, 1]:
				for k in links:
					var q: Vector2 = p + Vector2(side * (34 + 34 * k), 4)
					if not world.layout.walkable(q):
						continue
					var s := Sprites.make("palisade", q)
					if s != null:
						world.entities.add_child(s)
						_walls.append(s)


## Ближайшая к желаемой подходящая клетка (кольцами до 5 клеток).
func _place(world: World, want: Vector2, taken: Array):
	var layout := world.layout
	var start := layout.col_row(want)
	for radius in 6:
		for dr in range(-radius, radius + 1):
			for dc in range(-radius, radius + 1):
				if maxi(absi(dc), absi(dr)) != radius:
					continue
				var c := start.x + dc
				var r := start.y + dr
				if not (layout.walkable_cell(c, r) and layout.walkable_cell(c - 1, r) and layout.walkable_cell(c + 1, r)
						and layout.walkable_cell(c, r - 1)):
					continue
				var p := layout.center(c, r)
				if p.distance_to(layout.base) < 120.0:
					continue
				if world.house_rect.has_area() and world.house_rect.grow(40.0).has_point(p):
					continue
				if world.spots.any(func(s: ResourceSpot) -> bool: return p.distance_to(s.position) < 50.0):
					continue
				if layout.props.any(func(pr: Dictionary) -> bool: return p.distance_to(pr["pos"]) < 44.0):
					continue
				if taken.any(func(q: Vector2) -> bool: return p.distance_to(q) < 110.0):
					continue
				if layout.stall is Vector2 and p.distance_to(layout.stall) < 120.0:
					continue
				if layout.board is Vector2 and p.distance_to(layout.board) < 90.0:
					continue
				if layout.pen.has_area() and layout.pen.grow(40.0).has_point(p):
					continue
				var on_farm := false
				for f in layout.farm:
					if p.distance_to(f) < 60.0:
						on_farm = true
						break
				if not on_farm:
					return p
	return null


func process(world: World, dt: float) -> void:
	if world.loaded != "meadow":
		return
	_build_defense(world)
	var rs := Game.raids
	if rs.due() and MonstersFeature.current != null:
		_start(world)
	if rs.live.is_empty():
		if _ring != null and is_instance_valid(_ring):
			_ring.queue_free()
		_ring = null
		_raiders = []
		return
	_raiders = _raiders.filter(func(m) -> bool: return is_instance_valid(m) and m.alive)
	var store := world.layout.base
	var e := Game.estate
	var slow := Raids.wall_slow(e.level("wall"))
	_slow_tick -= dt
	var slow_now := _slow_tick <= 0.0
	if slow_now:
		_slow_tick = 0.5
	for m in _raiders:
		var d: float = m.position.distance_to(store)
		if slow_now and slow < 1.0 and d < Raids.WALL_RADIUS:
			m.apply_slow(slow, 0.7)
		var id: int = m.get_instance_id()
		if d < Raids.STEAL_RADIUS:
			_steal[id] = float(_steal.get(id, 0.0)) + dt
			if float(_steal[id]) >= Raids.STEAL_TIME:
				_steal.erase(id)
				Fx.text(world.fx, L.t("raid.steal"), m.position - Vector2(0, 50), Color(1, 0.5, 0.4), 14)
				MonstersFeature.current.remove_raider(m)
				rs.note_stolen()
	# Башни стреляют
	var t_lvl := e.working_level("tower") if e.level("tower") > 0 else 0
	var dmg := Raids.tower_damage(t_lvl)
	var rng := Raids.tower_range(t_lvl)
	for t in _towers:
		if is_instance_valid(t):
			t.shoot(world.fx, _raiders, rng, dmg, Raids.TOWER_RATE, dt, func(foe: MonsterNode, amount: float, from: Vector2) -> void:
				if MonstersFeature.current != null:
					MonstersFeature.current.damage_monster(foe, amount, from, false, true))


## Волна выходит с краёв карты: точки суши, откуда к складу ведёт прямая проходимая дорога.
func _start(world: World) -> void:
	var main := Game.estate.level("main")
	var kinds := Raids.wave(main)
	var points := _edge_points(world, kinds.size())
	if points.is_empty():
		# Подходящих точек нет: набег считается без героя
		Game.raids.resolve_absent()
		return
	Game.raids.start_live(kinds.size())
	Game.show_toast("px:swords", L.t("raid.started"))
	world.shake = maxf(world.shake, 6.0)
	var lvl := Raids.wave_level()
	for i in kinds.size():
		var p: Vector2 = points[i % points.size()] + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		if not world.layout.walkable(p):
			p = points[i % points.size()]
		_raiders.append(MonstersFeature.current.spawn_raider(kinds[i], lvl, p, world.layout.base))
	# Зона частокола
	if Game.estate.level("wall") > 0:
		_ring = Line2D.new()
		_ring.width = 3.0
		_ring.default_color = Color(1, 0.85, 0.4, 0.45)
		var pts := PackedVector2Array()
		for k in 49:
			var a := TAU * float(k) / 48.0
			pts.append(world.layout.base + Vector2(cos(a), sin(a) * 0.6) * Raids.WALL_RADIUS)
		_ring.points = pts
		_ring.z_index = -1
		world.fx.add_child(_ring)


func _edge_points(world: World, want: int) -> Array:
	var layout := world.layout
	var store := layout.base
	var out: Array = []
	for _i in 300:
		if out.size() >= mini(want, 4):
			break
		var c := randi_range(2, maxi(3, layout.cols - 3))
		var r := randi_range(2, maxi(3, layout.rows - 3))
		if not layout.walkable_cell(c, r):
			continue
		var p := layout.center(c, r)
		var d := p.distance_to(store)
		if d < 420.0 or d > 760.0:
			continue
		if out.any(func(q: Vector2) -> bool: return q.distance_to(p) < 160.0):
			continue
		# Прямая дорога до склада по суше
		var ok := true
		var steps := int(d / 16.0)
		for k in steps:
			if not layout.walkable(p.lerp(store, float(k) / float(steps))):
				ok = false
				break
		if ok:
			out.append(p)
	return out
