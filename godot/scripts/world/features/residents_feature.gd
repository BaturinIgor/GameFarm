class_name ResidentsFeature
extends WorldFeature
## Жители стоят у дома на Лесной поляне. Рядом с жителем - карточка с кнопкой разговора.
## Места подбираются по сетке карты вокруг дома: проходимая клетка вдали от точек добычи, грядок и лавки.

const NEAR_DISTANCE := 80.0
## Желаемые места относительно дома, по порядку переезда.
const OFFSETS := [Vector2(-150, 140), Vector2(150, 150), Vector2(-260, 230), Vector2(260, 240), Vector2(0, 250),
	Vector2(330, 120)]

var _nodes: Dictionary = {}
var _count := -1
var _card: Control
var _card_key := ""


func build(world: World) -> void:
	_nodes = {}
	_count = -1
	if world.loaded != "meadow":
		return
	_spawn(world)


func clear(_world: World) -> void:
	_nodes = {}
	_count = -1
	_set_card("", "")


func _spawn(world: World) -> void:
	var list := Game.residents.arrived_list()
	_count = list.size()
	var taken: Array = []
	for i in list.size():
		var id: String = list[i]
		if _nodes.has(id):
			taken.append(_nodes[id].position)
			continue
		var p = _place(world, world.layout.base + OFFSETS[i % OFFSETS.size()], taken)
		if not (p is Vector2):
			continue
		taken.append(p)
		var n := ResidentNode.new(id)
		n.position = p
		world.entities.add_child(n)
		_nodes[id] = n


## Ближайшая к желаемой подходящая клетка (поиск кольцами до 5 клеток).
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
				if p.distance_to(layout.base) < 110.0:
					continue
				if world.spots.any(func(s: ResourceSpot) -> bool: return p.distance_to(s.position) < 46.0):
					continue
				if layout.props.any(func(pr: Dictionary) -> bool: return p.distance_to(pr["pos"]) < 40.0):
					continue
				if taken.any(func(q: Vector2) -> bool: return p.distance_to(q) < 90.0):
					continue
				if layout.stall is Vector2 and p.distance_to(layout.stall) < 110.0:
					continue
				if layout.board is Vector2 and p.distance_to(layout.board) < 80.0:
					continue
				if layout.pen.has_area() and layout.pen.grow(32.0).has_point(p):
					continue
				var on_farm := false
				for f in layout.farm:
					if p.distance_to(f) < 56.0:
						on_farm = true
						break
				if on_farm:
					continue
				return p
	return null


func process(world: World, _dt: float) -> void:
	if world.loaded != "meadow":
		return
	if Game.residents.arrived_list().size() != _count:
		_spawn(world)
	var near := ""
	var best := NEAR_DISTANCE
	for id in _nodes:
		var n: ResidentNode = _nodes[id]
		if not is_instance_valid(n):
			continue
		n.refresh()
		var d := n.position.distance_to(world.player.position)
		if d < best:
			best = d
			near = id
	if near == "":
		_set_card("", "")
		return
	# Карточка перестраивается, когда меняется житель, его состояние, прогресс или язык
	var p := Game.residents.progress(near)
	_set_card(near, "%s|%s|%s|%s" % [near, Game.residents.state(near), p[0], L.code])


func _set_card(id: String, key: String) -> void:
	if Hud.current == null:
		return
	if id == "":
		if _card != null:
			_card = null
			_card_key = ""
			Hud.current.set_prompt("resident", null)
		return
	if _card != null and is_instance_valid(_card) and _card_key == key:
		return
	_card_key = key
	_card = ResidentCard.new(id)
	Hud.current.set_prompt("resident", _card)
