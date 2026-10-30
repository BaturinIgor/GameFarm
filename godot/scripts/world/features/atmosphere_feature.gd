class_name AtmosphereFeature
extends WorldFeature
## Атмосфера локации как в iOS (addAtmosphere, decorateWater, updateAmbient): блики на воде и пузыри лавы,
## тени облаков, бабочки и пчёлы, погода (лепестки, листья, пыльца, светлячки, песок, снег, искры, угольки,
## звёзды), лёгкая тонировка и темнота в пещерах. Всё берётся из Locations: weather, tint, cloud_shadows,
## critters, dark, lava.

var _clouds: Array = []        ## Sprite2D
var _critters: Array = []      ## {node, heading, phase, flier}
var _on_camera: Array = []     ## узлы на камере (погода, тонировка, темнота) - убрать при смене карты
var _size := Vector2.ZERO
## Сияющая поляна: её узлы, чтобы включать и выключать без перезахода (примерка, настройки).
var _night: Array = []
var _night_on := false
var _night_tick := 0.0

static var _spark: Texture2D
static var _dark: Texture2D


func build(world: World) -> void:
	_size = world.layout.size
	var spec: Dictionary = world.spec
	if spec["kind"] == "home" or spec["kind"] == "dungeon":
		return
	_water(world, bool(spec.get("lava", false)))
	if bool(spec.get("cloud_shadows", false)) and not bool(spec.get("dark", false)):
		_build_clouds(world, bool(spec.get("lava", false)))
	for emoji in spec.get("critters", []):
		for i in 3:
			_add_critter(world, str(emoji))
	_weather(world, str(spec.get("weather", "")))
	var tint: Color = spec.get("tint", Color(0, 0, 0, 0))
	if tint.a > 0.0:
		var rect := ColorRect.new()
		rect.color = tint
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.size = Vector2(1400, 2000)
		rect.position = -rect.size / 2.0
		rect.z_index = 900
		_camera_child(world, rect)
	# Сияющая поляна (покупка): ночь, светлячки и светящиеся грибы, ягоды и цветы
	_night.clear()
	_night_on = false
	_sync_night(world)
	if bool(spec.get("dark", false)):
		var dark := Sprite2D.new()
		dark.texture = _darkness()
		dark.scale = Vector2.ONE * 2600.0 / 512.0
		dark.z_index = 940
		_camera_child(world, dark)


## Включить или выключить сияющую поляну, если это изменилось.
func _sync_night(world: World) -> void:
	var want := world.loaded == "meadow" and Settings.cosmetic("glowMeadow")
	if want == _night_on:
		return
	_night_on = want
	if want:
		var before := _on_camera.size()
		_glow_meadow(world, str(world.spec.get("weather", "")))
		for i in range(before, _on_camera.size()):
			_night.append(_on_camera[i])
		return
	for n in _night:
		if is_instance_valid(n):
			n.queue_free()
		_on_camera.erase(n)
	_night.clear()


func _glow_meadow(world: World, weather: String) -> void:
	var night := ColorRect.new()
	night.color = Color(0.05, 0.07, 0.22, 0.42)
	night.mouse_filter = Control.MOUSE_FILTER_IGNORE
	night.size = Vector2(1400, 2000)
	night.position = -night.size / 2.0
	night.z_index = 900
	_camera_child(world, night)
	if weather != "fireflies":
		_weather(world, "fireflies")
	var colors := [Color(0.5, 1.0, 0.8), Color(1.0, 0.75, 0.4), Color(0.75, 0.6, 1.0)]
	var i := 0
	for s in world.spots:
		i += 1
		if i % 3 != 0:
			continue
		var g := Fx.glow(colors[i % colors.size()], 64.0, -10.0, 0.55)
		g.position += s.position
		g.z_index = 950
		world.fx.add_child(g)
		_night.append(g)
		var tw := g.create_tween().set_loops()
		tw.tween_property(g, "modulate:a", 0.25, randf_range(1.2, 2.2)).set_trans(Tween.TRANS_SINE)
		tw.tween_property(g, "modulate:a", 0.6, randf_range(1.2, 2.2)).set_trans(Tween.TRANS_SINE)
	# Окна дома светятся
	if world.house_rect.has_area():
		var w := Fx.glow(Color(1.0, 0.8, 0.4), 160.0, 0.0, 0.5)
		w.position = world.house_rect.get_center()
		w.z_index = 950
		world.fx.add_child(w)
		_night.append(w)


func clear(_w: World) -> void:
	_night.clear()
	_night_on = false
	_clouds.clear()
	_critters.clear()
	for n in _on_camera:
		if is_instance_valid(n):
			n.queue_free()
	_on_camera.clear()


func process(world: World, dt: float) -> void:
	_night_tick -= dt
	if _night_tick <= 0.0:
		_night_tick = 0.5
		if world.spec.get("kind", "") != "home" and world.spec.get("kind", "") != "dungeon":
			_sync_night(world)
	for s in _clouds:
		var c: Sprite2D = s
		if not is_instance_valid(c):
			continue
		var half := c.texture.get_size() * c.scale / 2.0
		c.position += Vector2(16.0, -5.0) * dt
		if c.position.x - half.x > _size.x:
			c.position.x = -half.x
			c.position.y = randf_range(0.0, _size.y)
		if c.position.y + half.y < 0.0:
			c.position.y = _size.y + half.y
	for cr in _critters:
		var n: Node2D = cr["node"]
		if not is_instance_valid(n):
			continue
		cr["phase"] = float(cr["phase"]) + dt
		cr["heading"] = float(cr["heading"]) + sin(float(cr["phase"]) * 0.7) * dt * 1.4
		var speed := 34.0 if cr["flier"] else 10.0
		var h: float = cr["heading"]
		n.position += Vector2(cos(h), -sin(h)) * speed * dt
		if n.position.x < 60.0 or n.position.x > _size.x - 60.0 or n.position.y < 60.0 or n.position.y > _size.y - 60.0:
			cr["heading"] = h + PI
			n.position = n.position.clamp(Vector2(60, 60), _size - Vector2(60, 60))
		var dir := cos(float(cr["heading"]))
		if absf(dir) > 0.2:
			(n as Sprite2D).flip_h = dir < 0.0


func _camera_child(world: World, n: Node) -> void:
	world.camera.add_child(n)
	_on_camera.append(n)


# MARK: Вода

## Блики на воде (или пузыри на лаве) в случайных клетках.
func _water(world: World, lava: bool) -> void:
	var lay := world.layout
	var cells: Array = []
	for r in lay.rows:
		for c in lay.cols:
			if lay.is_water(c, r):
				cells.append(Vector2i(c, r))
	if cells.is_empty():
		return
	cells.shuffle()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for cell in cells.slice(0, mini(40, cells.size() / 3 + 1)):
		var s := Sprite2D.new()
		s.position = lay.center(cell.x, cell.y)
		s.modulate.a = 0.0
		s.z_index = -5
		if lava:
			s.texture = Fx.dot_texture()
			s.scale = Vector2.ONE * 4.5
			s.modulate = Color(1, 0.85, 0.3, 0.0)
		else:
			s.texture = spark_texture()
			s.material = add
		world.flat.add_child(s)
		var base := s.scale
		var tw := s.create_tween().set_loops()
		tw.tween_interval(randf_range(0.0, 3.0))
		if lava:
			tw.tween_property(s, "modulate:a", 1.0, 0.2)
			tw.parallel().tween_property(s, "scale", base * 1.4, 0.8)
			tw.tween_property(s, "modulate:a", 0.0, 0.15)
			tw.parallel().tween_property(s, "scale", base * 2.0, 0.15)
			tw.tween_property(s, "scale", base * 0.5, 0.0)
			tw.tween_interval(randf_range(0.8, 2.5))
		else:
			tw.tween_property(s, "modulate:a", 0.7, 0.4)
			tw.parallel().tween_property(s, "scale", base * 1.3, 0.4)
			tw.tween_property(s, "modulate:a", 0.0, 0.6)
			tw.parallel().tween_property(s, "scale", base * 0.6, 0.6)
			tw.tween_interval(randf_range(1.0, 3.0))


## Блик: крестик из четырёх лучей, яркий в середине.
static func spark_texture() -> Texture2D:
	if _spark == null:
		var n := 15
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		var c := n / 2
		for y in n:
			for x in n:
				var dx := absi(x - c)
				var dy := absi(y - c)
				var a := 0.0
				if dx == 0 or dy == 0:
					a = 1.0 - float(maxi(dx, dy)) / float(c + 1)
				elif dx == 1 and dy == 1:
					a = 0.5
				img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
		_spark = ImageTexture.create_from_image(img)
	return _spark


# MARK: Облака

func _build_clouds(world: World, lava: bool) -> void:
	for i in 5:
		var tex := Sprites.texture("cloud_shadow" if i % 2 == 0 else "cloud_shadow2")
		if tex == null:
			tex = Fx.glow_texture()
		var s := Sprite2D.new()
		s.texture = tex
		var want := Vector2(randf_range(420.0, 620.0), randf_range(300.0, 420.0))
		s.scale = want / tex.get_size()
		s.position = Vector2(randf_range(0.0, _size.x), randf_range(0.0, _size.y))
		s.modulate = Color(0, 0, 0, 0.14 if lava else 0.08) if tex == Fx.glow_texture() else Color(1, 1, 1, 0.14 if lava else 0.08)
		s.z_index = 40
		world.fx.add_child(s)
		_clouds.append(s)


# MARK: Живность

## Бабочки и пчёлы из пака (остальные эмодзи в шрифте не нарисовать - их пропускаем).
func _add_critter(world: World, emoji: String) -> void:
	var name := ""
	var cell := 8
	match emoji:
		"🦋":
			name = "an_butterfly"
			cell = 8
		"🐝":
			name = "an_bee"
			cell = 16
		_:
			return
	var tex := Sprites.texture(name)
	if tex == null:
		return
	var s := Sprite2D.new()
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.hframes = maxi(1, tex.get_width() / cell)
	s.vframes = maxi(1, tex.get_height() / cell)
	var frames: Array = []
	if name == "an_butterfly":
		# Ряд - цвет бабочки, в ряду два кадра взмаха
		var row := randi() % maxi(1, s.vframes)
		frames = [row * s.hframes, row * s.hframes + mini(1, s.hframes - 1)]
	else:
		for i in mini(4, s.hframes):
			frames.append(i)
	s.frame = frames[0]
	var side := 16.0 if name == "an_butterfly" else 26.0
	s.scale = Vector2.ONE * side / float(cell)
	s.position = Vector2(randf_range(80.0, _size.x - 80.0), randf_range(80.0, _size.y - 80.0))
	s.z_index = 45
	world.fx.add_child(s)
	var step := 0.14 if name == "an_butterfly" else 0.06
	var tw := s.create_tween().set_loops()
	for f in frames:
		var fr: int = f
		tw.tween_callback(func() -> void: s.frame = fr)
		tw.tween_interval(step)
	_critters.append({"node": s, "heading": randf() * TAU, "phase": randf() * 6.0, "flier": true})


# MARK: Погода

func _weather(world: World, kind: String) -> void:
	# Экономия батареи: без погоды
	if kind == "" or Sound.battery_saver:
		return
	var p := CPUParticles2D.new()
	p.amount = 24
	p.lifetime = 8.0
	p.preprocess = 8.0
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(390.0, 844.0) * 0.7
	p.gravity = Vector2.ZERO
	p.z_index = 930
	p.texture = Fx.dot_texture()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	match kind:
		"petals":
			p.amount = 16
			p.lifetime = 10.0
			p.texture = Fx.glow_texture()
			p.color = Color(1, 0.72, 0.85, 0.85)
			p.scale_amount_min = 0.12
			p.scale_amount_max = 0.2
			_drift(p, 22.0, Vector2(-0.6, 0.8))
			p.angular_velocity_min = -70.0
			p.angular_velocity_max = 70.0
		"leaves":
			var leaf := Sprites.texture("fx_leaf_birch")
			p.amount = 14
			p.lifetime = 9.0
			if leaf != null:
				p.texture = leaf
				p.scale_amount_min = 12.0 / float(leaf.get_width()) * 0.8
				p.scale_amount_max = 12.0 / float(leaf.get_width()) * 1.2
			else:
				p.color = Color(0.9, 0.6, 0.2)
				p.scale_amount_min = 4.0
				p.scale_amount_max = 6.0
			_drift(p, 30.0, Vector2(-0.7, 0.7))
			p.angular_velocity_min = -90.0
			p.angular_velocity_max = 90.0
		"pollen":
			p.amount = 40
			p.lifetime = 7.0
			p.material = add
			p.color = Color(1, 0.97, 0.7, 0.45)
			p.scale_amount_min = 1.2
			p.scale_amount_max = 2.4
			_wander(p, 9.0)
		"fireflies":
			p.amount = 28
			p.lifetime = 6.0
			p.material = add
			p.texture = Fx.glow_texture()
			p.scale_amount_min = 0.16
			p.scale_amount_max = 0.26
			p.color_ramp = _ramp([Color(0.85, 1, 0.35, 0), Color(0.85, 1, 0.35, 0.9), Color(0.85, 1, 0.35, 0.2),
				Color(0.85, 1, 0.35, 0.9), Color(0.85, 1, 0.35, 0)], [0.0, 0.2, 0.5, 0.75, 1.0])
			_wander(p, 14.0)
		"sand":
			p.amount = 80
			p.lifetime = 4.0
			p.color = Color(0.95, 0.85, 0.6, 0.5)
			p.scale_amount_min = 1.0
			p.scale_amount_max = 2.0
			_drift(p, 110.0, Vector2(1.0, -0.1))
			p.initial_velocity_min = 60.0
		"snow":
			p.amount = 90
			p.lifetime = 10.0
			p.color = Color(1, 1, 1, 0.9)
			p.scale_amount_min = 1.6
			p.scale_amount_max = 3.0
			_drift(p, 36.0, Vector2(0.15, 1.0))
		"motes":
			p.amount = 28
			p.lifetime = 6.0
			p.material = add
			p.texture = spark_texture()
			p.color_ramp = _ramp([Color(0.7, 0.6, 1, 0), Color(0.7, 0.6, 1, 0.9), Color(0.7, 0.6, 1, 0)], [0.0, 0.5, 1.0])
			p.scale_amount_min = 0.4
			p.scale_amount_max = 0.8
			_wander(p, 8.0)
		"spray":
			p.amount = 10
			p.lifetime = 3.0
			p.material = add
			p.texture = spark_texture()
			p.color_ramp = _ramp([Color(1, 1, 1, 0), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)], [0.0, 0.4, 1.0])
			p.scale_amount_min = 0.5
			p.scale_amount_max = 0.9
			_wander(p, 4.0)
		"embers":
			p.amount = 70
			p.lifetime = 5.0
			p.material = add
			p.texture = Fx.glow_texture()
			p.scale_amount_min = 0.1
			p.scale_amount_max = 0.18
			p.color_ramp = _ramp([Color(1, 0.55, 0.15, 0), Color(1, 0.55, 0.15, 1), Color(1, 0.55, 0.15, 0.6),
				Color(1, 0.55, 0.15, 0)], [0.0, 0.15, 0.6, 1.0])
			_drift(p, 46.0, Vector2(0, -1))
		"stars":
			p.amount = 24
			p.lifetime = 4.0
			p.material = add
			p.texture = spark_texture()
			p.color_ramp = _ramp([Color(1, 0.95, 0.7, 0), Color(1, 0.95, 0.7, 1), Color(1, 0.95, 0.7, 0)], [0.0, 0.5, 1.0])
			p.scale_amount_min = 0.5
			p.scale_amount_max = 1.0
			_wander(p, 6.0)
			p.angular_velocity_min = -60.0
			p.angular_velocity_max = 60.0
		_:
			p.queue_free()
			return
	_camera_child(world, p)


static func _drift(p: CPUParticles2D, speed: float, dir: Vector2) -> void:
	p.direction = dir.normalized()
	p.spread = 25.0
	p.initial_velocity_min = speed * 0.7
	p.initial_velocity_max = speed * 1.3


static func _wander(p: CPUParticles2D, speed: float) -> void:
	p.direction = Vector2.RIGHT
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed


static func _ramp(colors: Array, offsets: Array) -> Gradient:
	var g := Gradient.new()
	g.colors = PackedColorArray(colors)
	g.offsets = PackedFloat32Array(offsets)
	return g


## Темнота пещер: прозрачно вокруг героя, темнее к краям экрана (Art.darkness).
static func _darkness() -> Texture2D:
	if _dark == null:
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0.72)])
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		# Градиент от 6% до 24% размера, дальше - самый тёмный цвет
		t.fill_to = Vector2(0.5 + 0.24, 0.5)
		t.width = 512
		t.height = 512
		_dark = t
	return _dark
