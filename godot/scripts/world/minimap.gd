class_name MiniMap
extends Control
## Мини-карта текущей локации в углу экрана (порт MiniMap и MiniMapNode): форма земли, вода, тропы, ресурсы,
## склад и проходы. Картинка рисуется один раз на локацию и кешируется, двигается только точка героя.
## Нажатие открывает крупную карту локации (BigMapOverlay), а с неё - карту мира.
## Сцену видит через GatesFeature.current.world. В доме прячется.

## Пикселей картинки на одну клетку.
const PIXELS_PER_CELL := 6
## Толщина деревянной рамки в пикселях картинки.
const BORDER := 10.0
const MAX_SIZE := Vector2(82, 104)
const OUTLINE := Color(0.17, 0.10, 0.06)
const FRAME := Color(0.63, 0.40, 0.23)

static var _cache: Dictionary = {}

var _layout: MapLayout
var _tex: Texture2D
var _k := 1.0
var _border := 0.0
var _player := Vector2.ZERO
var _time := 0.0
var _frame := StyleBoxFlat.new()
var _stroke := StyleBoxFlat.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	visible = false


func _process(delta: float) -> void:
	_time += delta
	var w := _world()
	var on := w != null and w.layout != null and str(w.spec.get("kind", "")) != "home"
	visible = on
	if not on:
		return
	if w.layout != _layout:
		_configure(w.layout, w.spec)
	_player = w.player.position
	queue_redraw()


static func _world() -> World:
	var f := GatesFeature.current
	if f == null or f.world == null or not is_instance_valid(f.world):
		return null
	return f.world


func _configure(layout: MapLayout, spec: Dictionary) -> void:
	_layout = layout
	_tex = texture(layout, spec, 14.0)
	_k = minf(MAX_SIZE.x / float(layout.cols), MAX_SIZE.y / float(layout.rows))
	_border = BORDER / PIXELS_PER_CELL * _k
	var s := Vector2(layout.cols * _k + _border * 2.0, layout.rows * _k + _border * 2.0)
	custom_minimum_size = s
	size = s
	# Рамка и обводка в масштабе картинки: в iOS рамка нарисована в самой картинке
	var px := _k / PIXELS_PER_CELL
	_frame.bg_color = FRAME
	_frame.border_color = OUTLINE
	_frame.set_border_width_all(1)
	_frame.set_corner_radius_all(int(round((14.0 + BORDER * 0.6) * px)))
	_frame.anti_aliasing = true
	_stroke.draw_center = false
	_stroke.border_color = OUTLINE
	_stroke.set_border_width_all(1)
	_stroke.set_corner_radius_all(int(round(14.0 * px)))
	_stroke.anti_aliasing = true


func _draw() -> void:
	if _tex == null:
		return
	var px := _k / PIXELS_PER_CELL
	draw_style_box(_frame, Rect2(Vector2.ZERO, size))
	draw_rect(Rect2(_border * 0.6, 3.0 * px, size.x - _border * 1.2, 2.0 * px), Color(1, 1, 1, 0.18))
	var inner := Rect2(Vector2(_border, _border), size - Vector2(_border, _border) * 2.0)
	draw_texture_rect(_tex, inner, false)
	draw_style_box(_stroke, inner)
	# Точка героя пульсирует
	var p := inner.position + _player / _layout.cell * _k
	var s := 1.15 - 0.15 * cos(TAU * _time)
	draw_circle(p, 4.0 * s, OUTLINE)
	draw_circle(p, 2.75 * s, Color.WHITE)
	draw_circle(p, 1.5 * s, Color(0.2, 0.6, 1))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if Hud.current != null and _layout != null:
			Hud.current.show_overlay(BigMap.new(_layout, _player))


# MARK: Картинка карты

## Цвет точки ресурса: деревья зелёные, руда своего цвета, рыба голубая, ягоды и прочее красное.
static func dot_color(type: String) -> Color:
	var spec := Nodes.spec(type)
	if type == "treasureChest":
		return Color(1, 0.82, 0.2)
	if Game.events.points_for_node(type) > 1:
		return Color(1, 0.55, 0.1)
	match spec["tool"]:
		"axe":
			return Color(0.12, 0.42, 0.15)
		"pickaxe":
			match Nodes.main_resource(type):
				"stone", "clay": return Color(0.62, 0.62, 0.62)
				"ice": return Color(0.75, 0.92, 1)
				"diamond": return Color(0.45, 0.9, 1)
				"crystal": return Color(0.85, 0.55, 1)
				"ruby": return Color(0.95, 0.2, 0.3)
			return Res.ORE_COLOR.get(Nodes.main_resource(type), Color(0.5, 0.5, 0.5))
		"rod":
			return Color(0.6, 0.88, 1)
		"hand":
			return Color(0.95, 0.35, 0.45)
	return Color.WHITE


## Картинка карты (без рамки) со скруглёнными углами radius (в пикселях картинки). Кешируется.
static func texture(layout: MapLayout, spec: Dictionary, radius := 0.0) -> Texture2D:
	var key := "%d|%d" % [layout.get_instance_id(), int(radius)]
	if _cache.has(key):
		return _cache[key]
	var img := render(layout, spec)
	_round(img, radius)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## Квадратная картинка локации для схемы мира и карточки прохода (как scaledToFill), углы скруглены.
static func thumb(id: String) -> Texture2D:
	var key := "thumb|" + id
	if _cache.has(key):
		return _cache[key]
	var img := render(MapLayout.load_layout(id), Locations.spec(id))
	var side := mini(img.get_width(), img.get_height())
	img = img.get_region(Rect2i((img.get_width() - side) / 2, (img.get_height() - side) / 2, side, side))
	_round(img, side * 12.0 / 58.0)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func render(layout: MapLayout, spec: Dictionary) -> Image:
	var ppc := PIXELS_PER_CELL
	var img := Image.create(layout.cols * ppc, layout.rows * ppc, false, Image.FORMAT_RGBA8)
	var ground: Color = spec["ground"]
	var water: Color = spec["water"]
	var edge := _darker(ground, 0.62)
	match layout.edge:
		"sea", "lava": edge = water
		"void": edge = Color(0.05, 0.05, 0.05) if spec["dark"] else Color(0.7, 0.85, 1)
	var land := _lighter(ground, 0.06)
	var forest := _darker(ground, 0.62)
	var ice := Color(0.82, 0.93, 1)
	img.fill(edge)
	for r in layout.rows:
		for c in layout.cols:
			var cell := layout.at(c, r)
			if cell == MapLayout.Cell.VOID:
				continue
			var color := land
			match cell:
				MapLayout.Cell.PATH: color = spec["path"]
				MapLayout.Cell.WATER: color = water
				MapLayout.Cell.ICE: color = ice
				MapLayout.Cell.BLOCKED: color = forest
			img.fill_rect(Rect2i(c * ppc, r * ppc, ppc, ppc), color)
	var k := float(ppc) / layout.cell

	# Огород и лавка
	for bed in layout.farm:
		var b: Vector2 = bed * k
		_fill(img, Rect2(b - Vector2.ONE * ppc * 0.4, Vector2.ONE * ppc * 0.8), Color(0.72, 0.45, 0.3))
	if layout.pen.has_area():
		var pen := Rect2(layout.pen.position * k, layout.pen.size * k).grow(-1.0)
		_frame_rect(img, pen, 2, Color(0.55, 0.36, 0.2))
	if layout.stall is Vector2:
		var st: Vector2 = layout.stall * k
		var w := ppc * 2.2
		var awning := Rect2(st.x - w / 2.0, st.y - w * 0.9, w, w * 0.5)
		_fill(img, awning, Color(0.95, 0.35, 0.35))
		_fill(img, Rect2(awning.position.x + w * 0.33, awning.position.y, w * 0.33, awning.size.y), Color.WHITE)
		_frame_rect(img, awning, 1, OUTLINE)

	# Ресурсы
	var dot := ppc * 1.15
	for s in layout.spots:
		var p: Vector2 = s["pos"] * k
		_disc(img, p, dot / 2.0 + 1.5, Color(OUTLINE, 0.85))
		_disc(img, p, dot / 2.0, dot_color(s["type"]))

	# Проходы: золотые ромбы
	for g in layout.gates:
		var p: Vector2 = g["barrier"] * k
		var ds := ppc * 1.4
		_diamond(img, p, ds + 1.0, OUTLINE)
		_diamond(img, p, ds - 0.75, Color(1, 0.83, 0.25))

	# Склад: домик
	var home := layout.base * k
	var hw := ppc * 2.6
	var body := Rect2(home.x - hw / 2.0, home.y - hw * 0.3, hw, hw * 0.75)
	_fill(img, body.grow(1.0), OUTLINE)
	_fill(img, body, Color(0.98, 0.93, 0.82))
	var roof := PackedVector2Array([Vector2(home.x - hw * 0.62, body.position.y + 1.0),
		Vector2(home.x, body.position.y - hw * 0.55), Vector2(home.x + hw * 0.62, body.position.y + 1.0)])
	_triangle(img, _grown(roof, 1.2), OUTLINE)
	_triangle(img, roof, Color(0.82, 0.25, 0.18))
	return img


static func _darker(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, 1.0)


static func _lighter(c: Color, k: float) -> Color:
	return Color(c.r + (1.0 - c.r) * k, c.g + (1.0 - c.g) * k, c.b + (1.0 - c.b) * k, 1.0)


static func _put(img: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	if color.a >= 0.999:
		img.set_pixel(x, y, color)
	else:
		img.set_pixel(x, y, img.get_pixel(x, y).blend(color))


static func _fill(img: Image, r: Rect2, color: Color) -> void:
	var a := Vector2i(floori(r.position.x), floori(r.position.y))
	var b := Vector2i(ceili(r.end.x), ceili(r.end.y))
	for y in range(a.y, b.y):
		for x in range(a.x, b.x):
			_put(img, x, y, color)


static func _frame_rect(img: Image, r: Rect2, w: int, color: Color) -> void:
	_fill(img, Rect2(r.position, Vector2(r.size.x, w)), color)
	_fill(img, Rect2(r.position.x, r.end.y - w, r.size.x, w), color)
	_fill(img, Rect2(r.position, Vector2(w, r.size.y)), color)
	_fill(img, Rect2(r.end.x - w, r.position.y, w, r.size.y), color)


static func _disc(img: Image, c: Vector2, r: float, color: Color) -> void:
	for y in range(floori(c.y - r), ceili(c.y + r) + 1):
		for x in range(floori(c.x - r), ceili(c.x + r) + 1):
			if Vector2(x + 0.5, y + 0.5).distance_squared_to(c) <= r * r:
				_put(img, x, y, color)


static func _diamond(img: Image, c: Vector2, s: float, color: Color) -> void:
	for y in range(floori(c.y - s), ceili(c.y + s) + 1):
		for x in range(floori(c.x - s), ceili(c.x + s) + 1):
			if absf(x + 0.5 - c.x) + absf(y + 0.5 - c.y) <= s:
				_put(img, x, y, color)


static func _triangle(img: Image, t: PackedVector2Array, color: Color) -> void:
	var lo := Vector2(minf(t[0].x, minf(t[1].x, t[2].x)), minf(t[0].y, minf(t[1].y, t[2].y)))
	var hi := Vector2(maxf(t[0].x, maxf(t[1].x, t[2].x)), maxf(t[0].y, maxf(t[1].y, t[2].y)))
	for y in range(floori(lo.y), ceili(hi.y) + 1):
		for x in range(floori(lo.x), ceili(hi.x) + 1):
			if Geometry2D.point_is_inside_triangle(Vector2(x + 0.5, y + 0.5), t[0], t[1], t[2]):
				_put(img, x, y, color)


## Треугольник, раздвинутый от центра на d пикселей (для обводки).
static func _grown(t: PackedVector2Array, d: float) -> PackedVector2Array:
	var c := (t[0] + t[1] + t[2]) / 3.0
	var perimeter := t[0].distance_to(t[1]) + t[1].distance_to(t[2]) + t[2].distance_to(t[0])
	var area := absf((t[1] - t[0]).cross(t[2] - t[0])) / 2.0
	var inradius := 2.0 * area / maxf(0.001, perimeter)
	var k := (inradius + d) / maxf(0.001, inradius)
	var out := PackedVector2Array()
	for p in t:
		out.append(c + (p - c) * k)
	return out


## Скругляет углы картинки (прозрачность за краем, с мягкой кромкой).
static func _round(img: Image, radius: float) -> void:
	if radius <= 0.0:
		return
	var w := img.get_width()
	var h := img.get_height()
	var r := ceili(radius)
	for y in r:
		for x in r:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(radius, radius))
			var cover := clampf(radius - d + 0.5, 0.0, 1.0)
			if cover >= 1.0:
				continue
			for q in [Vector2i(x, y), Vector2i(w - 1 - x, y), Vector2i(x, h - 1 - y), Vector2i(w - 1 - x, h - 1 - y)]:
				var c := img.get_pixelv(q)
				c.a *= cover
				img.set_pixelv(q, c)


# MARK: Крупная карта

## Крупная карта текущей локации (порт BigMapOverlay): форма, ресурсы, склад, проходы и где стоит герой.
class BigMap extends Control:
	var _layout: MapLayout
	var _player := Vector2.ZERO
	var _closing := false

	func _init(layout: MapLayout, player: Vector2) -> void:
		_layout = layout
		_player = player

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var dim := ColorRect.new()
		dim.color = UiKit.DIM
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dim.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed:
				close())
		add_child(dim)
		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(center)
		var id := _layout.id
		var view := get_viewport_rect().size
		var panel := PanelContainer.new()
		var style := UiKit.panel_style(22)
		style.set_content_margin_all(16)
		panel.add_theme_stylebox_override("panel", style)
		panel.custom_minimum_size = Vector2(minf(400.0, view.x - 40.0), 0)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		center.add_child(panel)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 12)
		panel.add_child(col)

		# Лента с названием над верхним краем панели
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(holder)
		var ribbon := LevelUpOverlay.Ribbon.new()
		ribbon.tone = UiKit.TONES["green"]
		ribbon.label.label_settings.font_size = 18
		ribbon.label.label_settings.outline_color = ribbon.tone[2]
		ribbon.anchor_left = 0.5
		ribbon.anchor_right = 0.5
		ribbon.grow_horizontal = Control.GROW_DIRECTION_BOTH
		ribbon.offset_top = -34
		ribbon.set_text(Locations.name_of(id))
		holder.add_child(ribbon)

		# Карта: вписана в 400 точек по высоте
		var aspect := float(_layout.cols) / float(maxi(1, _layout.rows))
		var w := minf(panel.custom_minimum_size.x - 32.0, 400.0 * aspect)
		var h := w / aspect
		var map_box := Control.new()
		map_box.custom_minimum_size = Vector2(w, h)
		map_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		map_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var top := MarginContainer.new()
		top.add_theme_constant_override("margin_top", 6)
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(map_box)
		col.add_child(top)
		var px_per_point := float(_layout.cols * MiniMap.PIXELS_PER_CELL) / w
		var pic := TextureRect.new()
		pic.texture = MiniMap.texture(_layout, Locations.spec(id), 12.0 * px_per_point)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_SCALE
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.size = Vector2(w, h)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		map_box.add_child(pic)
		var border := Panel.new()
		var bs := StyleBoxFlat.new()
		bs.draw_center = false
		bs.border_color = UiKit.OUTLINE
		bs.set_border_width_all(3)
		bs.set_corner_radius_all(12)
		bs.anti_aliasing = true
		border.add_theme_stylebox_override("panel", bs)
		border.size = Vector2(w, h)
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		map_box.add_child(border)
		var face := _face()
		face.position = Vector2(_player.x / maxf(1.0, _layout.size.x) * w, _player.y / maxf(1.0, _layout.size.y) * h - 10.0) \
			- Vector2(15, 15)
		map_box.add_child(face)

		col.add_child(_legend())

		var buttons := HBoxContainer.new()
		buttons.add_theme_constant_override("separation", 10)
		col.add_child(buttons)
		var close_b := UiKit.button(L.t("common.close"), "wood", 15)
		close_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		close_b.pressed.connect(close)
		buttons.add_child(close_b)
		var world_b := UiKit.button(L.t("hud.map"), "blue", 15)
		world_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		world_b.icon = Sprites.icon("map")
		world_b.expand_icon = false
		world_b.add_theme_constant_override("icon_max_width", 20)
		world_b.pressed.connect(func() -> void:
			close()
			if Hud.current != null:
				Hud.current.open_named("map"))
		buttons.add_child(world_b)

		panel.resized.connect(func() -> void: panel.pivot_offset = panel.size / 2.0)
		panel.scale = Vector2.ONE * 0.85
		modulate.a = 0.0
		var tw := create_tween().set_parallel()
		tw.tween_property(self, "modulate:a", 1.0, 0.18)
		tw.tween_property(panel, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	## Лицо героя в кружке.
	func _face() -> Control:
		var c := Control.new()
		c.size = Vector2(30, 30)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tex := LevelPanel.portrait(str(Game.save.get("skin", "farmer")))
		c.draw.connect(func() -> void:
			c.draw_circle(Vector2(15, 15), 15.0, UiKit.PARCHMENT_LIGHT)
			if tex != null:
				c.draw_texture_rect(tex, Rect2(5, 5, 20, 20), false)
			c.draw_arc(Vector2(15, 15), 14.0, 0.0, TAU, 32, UiKit.OUTLINE, 2.0, true))
		return c

	## Ресурсы локации по цвету точки (без повторов), склад и проходы.
	func _legend() -> HFlowContainer:
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		flow.alignment = FlowContainer.ALIGNMENT_CENTER
		flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var seen: Array = []
		for type in _layout.node_types():
			var kind := Nodes.main_resource(type)
			if kind in seen:
				continue
			seen.append(kind)
			var color := MiniMap.dot_color(type)
			var dot := Control.new()
			dot.custom_minimum_size = Vector2(11, 11)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			dot.draw.connect(func() -> void:
				dot.draw_circle(Vector2(5.5, 5.5), 5.5, UiKit.OUTLINE)
				dot.draw_circle(Vector2(5.5, 5.5), 4.0, color))
			flow.add_child(_chip([dot, UiKit.icon(kind, 20)]))
		var store := UiKit.label(L.t("hud.storage"), 12)
		store.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		flow.add_child(_chip([UiKit.icon("chest", 16), store]))
		var diamond := Control.new()
		diamond.custom_minimum_size = Vector2(12, 12)
		diamond.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		diamond.mouse_filter = Control.MOUSE_FILTER_IGNORE
		diamond.draw.connect(func() -> void:
			var pts := PackedVector2Array([Vector2(6, 0), Vector2(12, 6), Vector2(6, 12), Vector2(0, 6)])
			diamond.draw_colored_polygon(pts, UiKit.GOLD)
			pts.append(pts[0])
			diamond.draw_polyline(pts, UiKit.OUTLINE, 1.5, true))
		flow.add_child(_chip([diamond, UiKit.icon("door", 16)]))
		return flow

	func _chip(items: Array) -> PanelContainer:
		var p := PanelContainer.new()
		var s := UiKit.box(UiKit.PARCHMENT_LIGHT, Color(UiKit.WOOD_DARK, 0.35), 12, 1, false)
		s.content_margin_left = 7
		s.content_margin_right = 7
		s.content_margin_top = 3
		s.content_margin_bottom = 3
		p.add_theme_stylebox_override("panel", s)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(row)
		for it in items:
			row.add_child(it)
		return p

	func close() -> void:
		if _closing:
			return
		_closing = true
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.2)
		tw.tween_callback(queue_free)
