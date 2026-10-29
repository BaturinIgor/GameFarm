class_name Fx
## Эффекты в мире: всплывающий текст, осколки, облачка пыли, круги, вспышки.
## Всё живёт на слое эффектов карты и само удаляется.

const OUTLINE := Color(0.17, 0.1, 0.06)

static var _glow: Texture2D
static var _dot: Texture2D
static var _settings: Dictionary = {}


## Мягкое круглое свечение (белое, красится через modulate).
static func glow_texture() -> Texture2D:
	if _glow == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_glow = t
	return _glow


static func dot_texture() -> Texture2D:
	if _dot == null:
		var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_dot = ImageTexture.create_from_image(img)
	return _dot


static func label_settings(size: int, color := Color.WHITE, outline := 5) -> LabelSettings:
	var key := "%d|%s|%d" % [size, color.to_html(), outline]
	if _settings.has(key):
		return _settings[key]
	var ls := LabelSettings.new()
	ls.font = preload("res://fonts/Nunito-900.ttf")
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = outline
	ls.outline_color = OUTLINE
	_settings[key] = ls
	return ls


## Надпись, которая всплывает и тает.
static func text(parent: Node, value: String, pos: Vector2, color := Color.WHITE, size := 15, delay := 0.0) -> void:
	if parent == null:
		return
	var label := Label.new()
	label.text = value
	label.label_settings = label_settings(size, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(240, size * 1.6)
	label.position = pos - Vector2(120, size)
	label.pivot_offset = label.size / 2.0
	label.modulate.a = 0.0
	label.z_index = 50
	parent.add_child(label)
	var tw := label.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(label, "modulate:a", 1.0, 0.08)
	tw.parallel().tween_property(label, "scale", Vector2.ONE * 1.15, 0.08).from(Vector2.ONE * 0.6)
	tw.tween_property(label, "scale", Vector2.ONE, 0.08)
	tw.parallel().tween_property(label, "position:y", label.position.y - 38, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(label, "modulate:a", 0.0, 0.3)
	tw.tween_callback(label.queue_free)


## Иконка ресурса и "+N".
static func gain(parent: Node, kind: String, n: int, pos: Vector2, delay := 0.0, small := false) -> void:
	var holder := Node2D.new()
	holder.position = pos
	holder.z_index = 50
	holder.modulate.a = 0.0
	parent.add_child(holder)
	var tex := Res.icon(kind)
	var size := 13 if small else 16
	if tex != null:
		var icon := Sprite2D.new()
		icon.texture = tex
		icon.scale = Vector2.ONE * (1.1 if small else 1.4)
		icon.position = Vector2(-16, 0)
		holder.add_child(icon)
	var label := Label.new()
	label.text = "+%d" % n
	label.label_settings = label_settings(size, Color(1, 1, 0.85))
	label.position = Vector2(-4, -size * 0.8)
	holder.add_child(label)
	var tw := holder.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(holder, "modulate:a", 1.0, 0.1)
	tw.parallel().tween_property(holder, "position:y", pos.y - 44, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(holder, "modulate:a", 0.0, 0.3)
	tw.tween_callback(holder.queue_free)


## Осколки разлетаются от удара.
static func chips(parent: Node, pos: Vector2, color: Color, count := 5) -> void:
	for i in count:
		var s := Sprite2D.new()
		s.texture = dot_texture()
		s.modulate = color.lightened(randf() * 0.25)
		s.scale = Vector2.ONE * randf_range(1.5, 3.0)
		s.position = pos + Vector2(randf_range(-6, 6), randf_range(-26, -10))
		s.z_index = 40
		parent.add_child(s)
		var target := s.position + Vector2(randf_range(-30, 30), randf_range(-24, 10))
		var tw := s.create_tween().set_parallel()
		tw.tween_property(s, "position", target, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(s, "modulate:a", 0.0, 0.35).set_delay(0.12)
		tw.chain().tween_callback(s.queue_free)


## Разлёт частиц (искры, листья): текстура или точка.
static func scatter(parent: Node, pos: Vector2, count: int, color := Color.WHITE, tex: Texture2D = null, size := 6.0,
		spread := 30.0, rise := 16.0, duration := 0.6) -> void:
	for i in count:
		var s := Sprite2D.new()
		s.texture = tex if tex != null else dot_texture()
		var k := size / float(maxi(1, s.texture.get_width()))
		s.scale = Vector2.ONE * k * randf_range(0.7, 1.2)
		s.modulate = color
		s.position = pos
		s.z_index = 40
		s.rotation = randf() * TAU
		parent.add_child(s)
		var a := randf() * TAU
		var target := pos + Vector2(cos(a), sin(a)) * spread * randf_range(0.5, 1.0) + Vector2(0, -rise)
		var tw := s.create_tween().set_parallel()
		tw.tween_property(s, "position", target, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(s, "rotation", s.rotation + randf_range(-2, 2), duration)
		tw.tween_property(s, "modulate:a", 0.0, duration * 0.6).set_delay(duration * 0.4)
		tw.chain().tween_callback(s.queue_free)


## Облачко пыли.
static func puff(parent: Node, pos: Vector2, color: Color, size := 16.0, z := 0) -> void:
	var s := Sprite2D.new()
	s.texture = glow_texture()
	s.modulate = Color(color, 0.55)
	s.scale = Vector2.ONE * size / 64.0
	s.position = pos
	s.z_index = z
	parent.add_child(s)
	var tw := s.create_tween().set_parallel()
	tw.tween_property(s, "scale", s.scale * 2.0, 0.45).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate:a", 0.0, 0.45)
	tw.tween_property(s, "position:y", pos.y - 6, 0.45)
	tw.chain().tween_callback(s.queue_free)


## Расходящийся круг.
static func ring(parent: Node, pos: Vector2, color := Color(1, 1, 1, 0.7), radius := 20.0) -> void:
	var r := RingFx.new()
	r.position = pos
	r.color = color
	r.radius = radius * 0.3
	r.z_index = 30
	parent.add_child(r)
	var tw := r.create_tween().set_parallel()
	tw.tween_property(r, "radius", radius, 0.4).set_ease(Tween.EASE_OUT)
	tw.tween_property(r, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(r.queue_free)


## Свечение под предметом (руда, светящиеся деревья).
static func glow(color: Color, size: float, y := 0.0, alpha := 0.5) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = glow_texture()
	s.modulate = Color(color, alpha)
	s.scale = Vector2.ONE * size / 64.0
	s.position = Vector2(0, -y)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = mat
	return s
