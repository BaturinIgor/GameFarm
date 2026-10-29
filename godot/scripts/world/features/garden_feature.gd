class_name GardenFeature
extends WorldFeature
## Огород у дома (порт buildFarm и updateFarm из GameScene): грядки и пугало, эффекты действий из карточки,
## полив и сбор, когда герой встаёт на грядку, и карточка огорода рядом с грядками.

## Грядки ближе этого к герою поливаются и собираются сами.
const STEP_DISTANCE := 20.0
## На сколько вокруг грядок показывается карточка огорода.
const NEAR_MARGIN := 44.0
const SOIL_PUFF := Color(0.6, 0.42, 0.3)
const BOOST_SPARK := Color(0.7, 1, 0.6)
const WATER_RING := Color(0.6, 0.85, 1)
const WATER_SPARK := Color(0.55, 0.8, 1)

var _beds: Array[BedNode] = []
var _rect := Rect2()
var _refresh_timer := 0.0
var _cooldown := 0.0
var _card: Control


func build(world: World) -> void:
	_beds.clear()
	_rect = Rect2()
	_refresh_timer = 0.0
	_cooldown = 0.0
	var kind: String = world.spec["kind"]
	if kind == "home" or kind == "dungeon":
		return
	var layout := world.layout
	for i in layout.farm.size():
		var point: Vector2 = layout.farm[i]
		_beds.append(BedNode.new(i, point, world.flat, world.entities))
		var r := Rect2(point - Vector2.ONE * layout.cell / 2.0, Vector2.ONE * layout.cell)
		_rect = r if i == 0 else _rect.merge(r)
	if _beds.is_empty():
		return
	var scarecrow := Sprites.make("scarecrow", Vector2(_rect.end.x + 20.0, _rect.position.y + 6.0))
	if scarecrow != null:
		world.entities.add_child(scarecrow)
	_refresh_all(GardenSystem.now())


func clear(_world: World) -> void:
	_beds.clear()
	_rect = Rect2()
	_set_card(false)


func process(world: World, dt: float) -> void:
	var g := Game.garden
	if _beds.is_empty():
		g.garden_events.clear()
		return
	var now := GardenSystem.now()
	if not g.garden_events.is_empty():
		_show_events(world, now)
	_refresh_timer -= dt
	if _refresh_timer <= 0.0:
		_refresh_timer = 0.5
		_refresh_all(now)
	# Карточка огорода: если рядом торговец, у него карточка важнее
	var near := _rect.grow(NEAR_MARGIN).has_point(world.player.position)
	_set_card(near and g.trader_prompt == "")
	_cooldown -= dt
	if _cooldown > 0.0:
		return
	_step_on_beds(world, now)


func _refresh_all(now: float) -> void:
	var count := Game.garden.bed_count()
	for node in _beds:
		node.refresh(Game.garden.bed(node.index), node.index < count, now)


## Эффекты действий из карточки огорода (посадка, сбор, полив и удобрение).
func _show_events(world: World, now: float) -> void:
	var g := Game.garden
	for e in g.garden_events:
		var node := _node(int(e["bed"]))
		if node == null:
			continue
		node.invalidate()
		node.refresh(g.bed(node.index), true, now)
		var p := node.position
		match str(e["kind"]):
			"planted":
				Fx.puff(world.flat, p, SOIL_PUFF, 18.0, 5)
			"harvested":
				var got: Dictionary = e.get("got", {})
				if not got.is_empty():
					Fx.gain(world.fx, got["kind"], int(got["amount"]), p - Vector2(0, 30))
				Fx.scatter(world.fx, p - Vector2(0, 12), 5, Color.WHITE, Sprites.icon("spark"), 10.0, 24.0, 18.0, 0.5)
			"boosted":
				Fx.scatter(world.fx, p - Vector2(0, 10), 6, BOOST_SPARK, Sprites.icon("spark"), 9.0, 20.0, 16.0, 0.5)
	g.garden_events.clear()


## Герой встал на грядку: спелое собирается, растущее поливается. Сажать - только из карточки.
func _step_on_beds(world: World, now: float) -> void:
	var g := Game.garden
	var count := g.bed_count()
	for node in _beds:
		if node.index >= count or node.position.distance_to(world.player.position) >= STEP_DISTANCE:
			continue
		var i := node.index
		var bed := g.bed(i)
		var p := node.position
		if Farming.is_ripe(bed, now):
			var got := g.harvest_bed(i)
			if got.is_empty():
				continue
			world.player.swing("hand", p, 0.4)
			Fx.gain(world.fx, got["kind"], int(got["amount"]), p - Vector2(0, 30))
			Fx.scatter(world.fx, p - Vector2(0, 12), 6, Color.WHITE, Sprites.icon("spark"), 10.0, 24.0, 18.0, 0.5)
			Sound.play("pickup")
		elif Farming.is_empty(bed) or bool(bed.get("watered", false)):
			continue
		else:
			if not g.water(i):
				continue
			Fx.ring(world.flat, p, WATER_RING, 18.0)
			Fx.scatter(world.fx, p - Vector2(0, 10), 5, WATER_SPARK, Sprites.icon("spark"), 9.0, 18.0, 10.0, 0.4)
			Sound.play("splash")
		node.invalidate()
		node.refresh(g.bed(i), true, GardenSystem.now())
		_cooldown = 0.3
		break


func _node(index: int) -> BedNode:
	for node in _beds:
		if node.index == index:
			return node
	return null


func _set_card(on: bool) -> void:
	if Hud.current == null:
		return
	if on:
		if _card == null or not is_instance_valid(_card):
			_card = BedsCard.new()
			Hud.current.set_prompt("beds", _card)
	elif _card != null:
		_card = null
		Hud.current.set_prompt("beds", null)
