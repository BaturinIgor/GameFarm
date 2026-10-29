class_name TreasureFeature
extends WorldFeature
## Клады на карте (порт updateTreasure и checkTreasure из GameScene) и стрелки к кладу и складу.

## Сколько клад лежит на карте, секунд.
const TREASURE_LIFE := 120.0
## С какого расстояния клад открывается.
const OPEN_DISTANCE := 42.0
## Клад не появляется ближе к герою.
const MIN_FROM_PLAYER := 300.0
## Где кладов не бывает.
const NO_TREASURE_KINDS := ["expedition", "home", "dungeon"]

var _treasure: TreasureNode
var _timer := 40.0
var _treasure_arrow: PointerArrow
var _base_arrow: PointerArrow


func build(world: World) -> void:
	_treasure = null
	_timer = randf_range(30.0, 50.0)
	_base_arrow = PointerArrow.new(Color(1, 0.78, 0.2), "chest")
	world.fx.add_child(_base_arrow)
	_treasure_arrow = PointerArrow.new(Color(1, 0.9, 0.3), "chest_gold")
	world.fx.add_child(_treasure_arrow)


func clear(_world: World) -> void:
	# Узлы удаляет сама карта
	_treasure = null
	_treasure_arrow = null
	_base_arrow = null


func process(world: World, dt: float) -> void:
	_check_treasure(world)
	_update_treasure(world, dt)
	_update_arrows(world)


func _update_treasure(world: World, dt: float) -> void:
	if _treasure != null:
		_treasure.life -= dt
		if _treasure.life <= 0.0:
			_treasure.vanish()
			_treasure = null
		return
	if world.spec["kind"] in NO_TREASURE_KINDS:
		return
	_timer -= dt * Game.stats.spawn_mult
	if _timer > 0.0:
		return
	_timer = randf_range(60.0, 110.0)
	var point = _random_open_point(world, MIN_FROM_PLAYER)
	if point == null:
		return
	_treasure = TreasureNode.new(point, TREASURE_LIFE)
	world.entities.add_child(_treasure)
	Game.show_toast("px:chest", L.t("toast.treasure"))


func _check_treasure(world: World) -> void:
	if _treasure == null or _treasure.position.distance_to(world.player.position) >= OPEN_DISTANCE:
		return
	var t := _treasure
	_treasure = null
	var reward := Game.quests.open_treasure()
	var p := t.position
	Fx.scatter(world.fx, p - Vector2(0, 20), 10, Color.WHITE, Sprites.icon("coin"), 18.0, 60.0, 40.0, 0.8)
	Fx.scatter(world.fx, p - Vector2(0, 24), 8, Color(1, 0.9, 0.4), Sprites.icon("spark"), 14.0, 50.0, 30.0)
	Fx.ring(world.fx, p, Color(1, 0.85, 0.3), 40.0)
	Fx.text(world.fx, "+%s 🪙" % Fmt.n(int(reward["coins"])), p - Vector2(0, 60), Color(1, 0.9, 0.4), 18)
	t.burst()
	world.shake = maxf(world.shake, 4.0)
	world.player.celebrate()
	Input.vibrate_handheld(30)
	if Hud.current != null:
		Hud.current.show_overlay(TreasureCard.new(reward))


## Стрелки: к кладу, к складу - когда рюкзак почти полон.
func _update_arrows(world: World) -> void:
	var stats := Game.stats
	var count := Game.backpack_count
	var direct := Game.premium.in_expedition()
	var full := not stats.auto_deposit and not direct and Game.backpack_free <= 0
	var base_target = null
	if not direct and (full or (count > 0 and float(count) >= float(stats.capacity) * 0.85)):
		base_target = world.layout.base
	var treasure_target = null
	if _treasure != null:
		treasure_target = _treasure.position
	if is_instance_valid(_base_arrow):
		_base_arrow.track(world, base_target)
	if is_instance_valid(_treasure_arrow):
		_treasure_arrow.track(world, treasure_target)


## Случайная проходимая точка вдали от героя, точек добычи, проходов, грядок и лавки.
func _random_open_point(world: World, min_from_player: float):
	var layout := world.layout
	var farm := _farm_rect(layout)
	for _i in 60:
		var c := randi_range(2, maxi(3, layout.cols - 2) - 1)
		var r := randi_range(2, maxi(3, layout.rows - 2) - 1)
		var cell := layout.at(c, r)
		if cell != MapLayout.Cell.LAND and cell != MapLayout.Cell.PATH:
			continue
		# Не у самого края: все соседи тоже проходимы
		if not (layout.walkable_cell(c - 1, r) and layout.walkable_cell(c + 1, r)
				and layout.walkable_cell(c, r - 1) and layout.walkable_cell(c, r + 1)):
			continue
		var p := layout.center(c, r)
		if p.distance_to(world.player.position) < min_from_player:
			continue
		if world.spots.any(func(s: ResourceSpot) -> bool: return p.distance_to(s.position) < 44.0):
			continue
		if world.gates.any(func(g: GateNode) -> bool: return p.distance_to(g.position) < 120.0):
			continue
		if farm.has_area() and farm.grow(48.0).has_point(p):
			continue
		if layout.stall != null and p.distance_to(layout.stall) < 120.0:
			continue
		return p
	return null


## Прямоугольник грядок у дома (клетки вокруг точек огорода).
func _farm_rect(layout: MapLayout) -> Rect2:
	var rect := Rect2()
	for i in layout.farm.size():
		var pt: Vector2 = layout.farm[i]
		var cell_rect := Rect2(pt - Vector2.ONE * layout.cell / 2.0, Vector2.ONE * layout.cell)
		rect = cell_rect if i == 0 else rect.merge(cell_rect)
	return rect
