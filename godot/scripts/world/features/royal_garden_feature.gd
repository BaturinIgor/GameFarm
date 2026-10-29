class_name RoyalGardenFeature
extends WorldFeature
## Королевский сад (покупка "сад"): капибары в пруду и королевский сундук раз в сутки (порт buildGarden
## и checkRoyalChest из GameScene).

var _chest: Node2D
var _capybaras: Array = []      ## {sprite, frames: [индексы кадров], t, i}


func build(world: World) -> void:
	_chest = null
	_capybaras.clear()
	if world.loaded != "garden":
		return
	_build_capybaras(world)
	var point := world.layout.base + Vector2(-110, 20)
	_chest = Node2D.new()
	_chest.position = point
	_chest.add_child(Fx.glow(Color(1, 0.8, 0.3), 90.0, 14.0, 0.45))
	var box := Sprites.make("chest_royal_anim")
	if box != null:
		_chest.add_child(box)
	else:
		_chest.add_child(UiKit.icon("crown", 36))
	world.entities.add_child(_chest)
	world.obstacles.append({"center": point, "radius": 16.0})


func clear(_world: World) -> void:
	_chest = null
	_capybaras.clear()


func process(world: World, dt: float) -> void:
	_animate_capybaras(dt)
	if _chest == null or not is_instance_valid(_chest):
		return
	var ready := Game.premium.garden_chest_ready()
	# Готовый сундук пульсирует
	_chest.scale = Vector2.ONE * (1.0 + 0.04 * (1.0 + sin(Time.get_ticks_msec() / 1000.0 * PI))) if ready else Vector2.ONE
	if not ready or _chest.position.distance_to(world.player.position) >= 50.0:
		return
	Game.premium.open_garden_chest()
	Fx.scatter(world.fx, _chest.position - Vector2(0, 20), 14, Color.WHITE, Sprites.icon("coin"), 18.0, 70.0, 50.0, 0.9)
	Fx.ring(world.fx, _chest.position, Color(1, 0.85, 0.3), 50.0)
	world.player.celebrate()
	Input.vibrate_handheld(40)
	var found = Game.premium.garden_chest_found
	if found is Dictionary and Hud.current != null:
		var items: Array = (found["items"] as Array).duplicate()
		items.append(["ticket", 1])
		Hud.current.show_overlay(TreasureCard.new({"coins": found["coins"], "items": items}, "garden.chestTitle"))
	Game.premium.garden_chest_found = null


## Две капибары в пруду: белая и обычная, дышат и оглядываются.
func _build_capybaras(world: World) -> void:
	var layout := world.layout
	var sum := Vector2.ZERO
	var n := 0
	for r in layout.rows:
		for c in layout.cols:
			if layout.is_water(c, r):
				sum += Vector2(c, r)
				n += 1
	if n == 0:
		return
	var center := layout.center(int(round(sum.x / n)), int(round(sum.y / n)))
	for i in 2:
		var name: String = ["an_capybaraAlbino", "an_capybara"][i]
		var tex := Sprites.texture(name)
		if tex == null:
			continue
		var s := Sprite2D.new()
		s.texture = tex
		s.hframes = maxi(1, tex.get_width() / 32)
		s.vframes = maxi(1, tex.get_height() / 32)
		if s.hframes * s.vframes < 20:
			continue
		s.scale = Vector2(-2 if i == 1 else 2, 2)
		s.position = center + Vector2(-26 if i == 0 else 30, -6 if i == 0 else 10)
		s.z_index = -5
		world.flat.add_child(s)
		# Дважды дышит, потом оглядывается
		var idle: Array = range(0, 9)
		var look: Array = range(10, 20)
		var seq: Array = []
		seq.append_array(idle.map(func(f: int) -> Array: return [f, 0.18]))
		seq.append_array(idle.map(func(f: int) -> Array: return [f, 0.18]))
		seq.append_array(look.map(func(f: int) -> Array: return [f, 0.16]))
		_capybaras.append({"sprite": s, "seq": seq, "i": 0, "t": 0.0})


func _animate_capybaras(dt: float) -> void:
	for c in _capybaras:
		var s: Sprite2D = c["sprite"]
		if not is_instance_valid(s):
			continue
		var seq: Array = c["seq"]
		c["t"] = float(c["t"]) + dt
		var step: Array = seq[int(c["i"])]
		if float(c["t"]) >= float(step[1]):
			c["t"] = 0.0
			c["i"] = (int(c["i"]) + 1) % seq.size()
			s.frame = int(seq[int(c["i"])][0])
