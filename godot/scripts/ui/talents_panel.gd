class_name TalentsPanel
extends Sheet
## Таланты: свободные очки, ветки, дерево с линиями связей и карточка выбранного таланта (порт TalentsView).

const ROW_HEIGHT := 112.0
const TOP := 50.0
const LEFT := 54.0
const RADIUS := 30.0
## Суперталанты крупнее обычных.
const SUPER_RADIUS := 38.0

const GRAY_SHADER := """shader_type canvas_item;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(vec3(g), c.a * COLOR.a);
}
"""

static var _gray: ShaderMaterial

var branch := "mining"
var selected := ""
## Шапка и ветки над прокруткой, карточка таланта под ней.
var _top := VBoxContainer.new()
var _dock := VBoxContainer.new()
var _confirm: Control


func _init() -> void:
	title_key = "hud.talents"


func _ready() -> void:
	super._ready()
	var col := _scroll.get_parent()
	_top.add_theme_constant_override("separation", 10)
	col.add_child(_top)
	col.move_child(_top, _scroll.get_index())
	_dock.add_theme_constant_override("separation", 0)
	col.add_child(_dock)
	_scroll.draw.connect(_draw_scroll_bg)


func build() -> void:
	_clear(_top)
	_clear(_dock)
	if selected != "" and Talents.branch(selected) != branch:
		selected = ""
	_header()
	_branch_picker()
	_tree()
	_dock.visible = selected != ""
	if selected != "":
		_detail(selected)
	_scroll.queue_redraw()


func _clear(holder: Control) -> void:
	for c in holder.get_children():
		holder.remove_child(c)
		c.queue_free()


func _width() -> float:
	return _scroll.size.x if _scroll.size.x > 0.0 else 350.0


## Фон прокрутки: лёгкий отсвет цвета ветки сверху.
func _draw_scroll_bg() -> void:
	var s := _scroll.size
	var c := Talents.branch_color(branch)
	_scroll.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
		PackedColorArray([Color(c, 0.1), Color(c, 0.1), Color(c, 0.0), Color(c, 0.0)]))


# MARK: Шапка и ветки

func _header() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_top.add_child(row)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	col.add_child(UiKit.label(L.t("talents.free", [Game.talents.points_free()]), 16))
	var hint := UiKit.label(L.t("talents.hint"), 12, UiKit.INK_SOFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(hint)

	var reset := UiKit.button("", "wood", 15, true)
	reset.custom_minimum_size = Vector2(46, 38)
	reset.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reset.disabled = not Game.talents.can_reset()
	var g := Control.new()
	g.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.draw.connect(func() -> void: glyph_reset(g, g.size / 2.0, 18.0, Color.WHITE))
	reset.add_child(g)
	reset.pressed.connect(_open_confirm)
	row.add_child(reset)


func _branch_picker() -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_top.add_child(grid)
	var cell_w := (_width() - 12.0) / 3.0
	for b in Talents.BRANCHES:
		var active: bool = b == branch
		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 36)
		var fill := Talents.branch_color(b) if active else UiKit.PARCHMENT_LIGHT
		var border := UiKit.OUTLINE if active else Color(UiKit.WOOD_DARK, 0.4)
		var st := UiKit.box(fill, border, 12, 2, false)
		st.shadow_color = Color(UiKit.WOOD_DARK, 0.3)
		st.shadow_offset = Vector2(0, 3)
		st.shadow_size = 1
		var down := st.duplicate() as StyleBoxFlat
		down.bg_color = fill.darkened(0.12)
		for state in ["normal", "hover", "disabled"]:
			btn.add_theme_stylebox_override(state, st)
		btn.add_theme_stylebox_override("pressed", down)
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

		var row := HBoxContainer.new()
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 8
		row.offset_right = -8
		row.add_theme_constant_override("separation", 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(row)
		var ic := UiKit.icon(Talents.branch_icon(b), 22)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)
		var spent := str(Game.talents.points_in(b))
		var title := Talents.branch_title(b)
		var room := cell_w - 16.0 - 22.0 - 12.0 - (14.0 + 7.0 * spent.length())
		var t := UiKit.label(title, fit_size(title, room, 12, 8), Color.WHITE if active else UiKit.INK, 3 if active else 0)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		t.clip_text = true
		row.add_child(t)
		var pill := PanelContainer.new()
		var ps := UiKit.box(UiKit.WOOD_DARK if active else Color(UiKit.INK_SOFT, 0.6), Color(0, 0, 0, 0), 8, 0, false)
		ps.content_margin_left = 6
		ps.content_margin_right = 6
		ps.content_margin_top = 1
		ps.content_margin_bottom = 1
		pill.add_theme_stylebox_override("panel", ps)
		pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.add_child(UiKit.label(spent, 10, Color.WHITE))
		row.add_child(pill)

		btn.pressed.connect(func() -> void:
			if branch != b:
				branch = b
				selected = ""
				_scroll.scroll_vertical = 0
				_dirty = true)
		grid.add_child(btn)


# MARK: Дерево

static func node_radius(id: String) -> float:
	return SUPER_RADIUS if Talents.is_super(id) else RADIUS


static func node_pos(id: String, width: float) -> Vector2:
	var column_width := (width - LEFT - 12.0) / 3.0
	return Vector2(LEFT + column_width * (float(Talents.column(id)) + 0.5), TOP + float(Talents.tier(id)) * ROW_HEIGHT)


## Линия между талантами идёт от края круга до края круга, а не через центр.
static func edge_points(a: Vector2, b: Vector2, ra: float, rb: float) -> Array:
	var d := maxf(a.distance_to(b), 1.0)
	if d <= ra + rb + 6.0:
		return [a, a]
	var u := (b - a) / d
	return [a + u * (ra + 3.0), b - u * (rb + 3.0)]


func _tree() -> void:
	var list := Talents.in_branch(branch)
	var rows := 0
	for id in list:
		rows = maxi(rows, Talents.tier(id) + 1)
	var canvas := Control.new()
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.custom_minimum_size = Vector2(0, TOP + float(rows - 1) * ROW_HEIGHT + 70.0)
	canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	content.add_child(canvas)
	# Нажатие мимо узлов закрывает описание таланта
	var press := [Vector2.ZERO]
	canvas.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			press[0] = mb.global_position
		elif selected != "" and mb.global_position.distance_to(press[0]) < 12.0:
			selected = ""
			_dirty = true)
	var nodes: Array = []
	var color := Talents.branch_color(branch)
	for id in list:
		var node := TalentNode.new(id, color, selected == id, _on_node_tap)
		canvas.add_child(node)
		nodes.append(node)
	canvas.draw.connect(_draw_tree.bind(canvas, list, rows))
	canvas.resized.connect(func() -> void:
		for n in nodes:
			n.place(node_pos(n.id, canvas.size.x))
		canvas.queue_redraw())


func _on_node_tap(id: String) -> void:
	selected = "" if selected == id else id
	_dirty = true


## Подписи рядов, разделители и линии от родителей к детям. Узлы рисуются поверх.
func _draw_tree(canvas: Control, list: Array, rows: int) -> void:
	var w := canvas.size.x
	for i in rows:
		var lvl: int = Talents.TIER_LEVELS[i]
		var y := TOP + float(i) * ROW_HEIGHT
		var tc := UiKit.INK if Game.level >= lvl else UiKit.INK_SOFT
		text_block(canvas, L.t("talents.rowLevel", [lvl]), Vector2(26, y), 40.0, 11, tc)
		canvas.draw_rect(Rect2(42, y + ROW_HEIGHT / 2.0 - 0.5, maxf(0.0, w - 60.0), 1), Color(UiKit.INK_SOFT, 0.08))
	var bc := Talents.branch_color(branch)
	for id in list:
		var sup := Talents.is_super(id)
		for p in Talents.parents(id):
			# К суперталанту линия загорается, только когда родитель прокачан до конца.
			var r := Game.talents.rank(p)
			var active: bool = r >= Talents.max_rank(p) if sup else r > 0
			var ends := edge_points(node_pos(p, w), node_pos(id, w), node_radius(p), node_radius(id))
			var a: Vector2 = ends[0]
			var b: Vector2 = ends[1]
			if a == b:
				continue
			if active:
				var lc := UiKit.GOLD if sup else bc
				canvas.draw_line(a, b, lc, 4.0, true)
				canvas.draw_circle(a, 2.0, lc)
				canvas.draw_circle(b, 2.0, lc)
			else:
				canvas.draw_dashed_line(a, b, Color(UiKit.INK_SOFT, 0.3), 3.0, 6.0)


# MARK: Карточка таланта

func _detail(id: String) -> void:
	var t: TalentSystem = Game.talents
	var rank := t.rank(id)
	var max_rank := Talents.max_rank(id)
	var maxed := rank >= max_rank
	var sup := Talents.is_super(id)
	var orange_lip: Color = UiKit.TONES["orange"][2]

	var panel := PanelContainer.new()
	var st := UiKit.box(UiKit.PARCHMENT_LIGHT, UiKit.OUTLINE, 18, 3)
	st.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", st)
	_dock.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	head.add_child(_medal(Talents.icon(id), Talents.branch_color(Talents.branch(id))))
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 1)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(names)
	names.add_child(UiKit.label(Talents.name_of(id), 16))
	var sub := L.t("talents.superCost", [Talents.cost(id)]) if sup else L.t("talents.rank", [rank, max_rank])
	names.add_child(UiKit.label(sub, 12, orange_lip if sup else UiKit.INK_SOFT))

	if sup and rank == 0:
		_wrap(v, L.t("talents.superHint"), 11, UiKit.INK_SOFT)
	if rank > 0:
		_wrap(v, L.t("talents.now", [Talents.effect(id, rank)]), 14, UiKit.INK)
	if not maxed:
		if rank > 0:
			_wrap(v, L.t("talents.next", [Talents.effect(id, rank + 1)]), 14, UiKit.INK_SOFT)
		else:
			_wrap(v, Talents.effect(id, 1), 14, UiKit.INK)
	_requirements(v, id, orange_lip)
	if not maxed:
		var free := t.points_free()
		var cost := Talents.cost(id)
		var text := ""
		if cost > 1:
			text = L.t("talents.learnFor", [cost]) if free >= cost else L.t("talents.needPoints", [cost])
		else:
			text = L.t("talents.learn") if free > 0 else L.t("talents.noPoints")
		var b := UiKit.button(text, "green", 16)
		b.disabled = not t.can_learn(id)
		b.pressed.connect(func() -> void: Game.talents.learn(id))
		v.add_child(b)


func _requirements(parent: Control, id: String, color: Color) -> void:
	var need := Talents.required_level(id)
	var level_ok := Game.level >= need
	var missing := Game.talents.missing_parents(id)
	if level_ok and missing.is_empty():
		return
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	parent.add_child(box)
	if not level_ok:
		_req_row(box, "lock", L.t("common.needLevel", [need]), color)
	for p in missing:
		if Talents.is_super(id):
			_req_row(box, "up", L.t("talents.needMax", [Talents.name_of(p), Game.talents.rank(p), Talents.max_rank(p)]), color)
		else:
			_req_row(box, "up", L.t("talents.needParent", [Talents.name_of(p)]), color)


func _req_row(parent: Control, glyph: String, text: String, color: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var g := Control.new()
	g.custom_minimum_size = Vector2(14, 14)
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.draw.connect(func() -> void:
		if glyph == "lock":
			glyph_lock(g, g.size / 2.0, 12.0, color)
		else:
			glyph_up(g, g.size / 2.0, 13.0, color))
	row.add_child(g)
	var l := UiKit.label(text, 12, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)


func _wrap(parent: Control, text: String, font_size: int, color: Color) -> void:
	var l := UiKit.label(text, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)


## Иконка таланта в светлом круге цвета ветки.
func _medal(icon_name: String, color: Color) -> Control:
	var m := Control.new()
	m.custom_minimum_size = Vector2(44, 44)
	m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.draw.connect(func() -> void:
		m.draw_circle(Vector2(22, 22), 22.0, color.lerp(Color.WHITE, 0.6))
		m.draw_arc(Vector2(22, 22), 21.0, 0.0, TAU, 40, UiKit.OUTLINE, 2.0, true))
	var ic := UiKit.icon(icon_name, 34)
	ic.position = Vector2(5, 5)
	ic.size = Vector2(34, 34)
	m.add_child(ic)
	return m


# MARK: Сброс

func _open_confirm() -> void:
	_close_confirm()
	var tone: Array = UiKit.TONES["orange"]
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(layer)
	_confirm = layer
	var dim := ColorRect.new()
	dim.color = UiKit.DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_close_confirm())
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)

	var box := PanelContainer.new()
	var st := UiKit.panel_style(18)
	st.content_margin_left = 20
	st.content_margin_right = 20
	st.content_margin_top = 38
	st.content_margin_bottom = 16
	box.add_theme_stylebox_override("panel", st)
	box.custom_minimum_size = Vector2(clampf(size.x - 48.0, 260.0, 340.0), 0)
	center.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	box.add_child(v)
	var title := UiKit.label(L.t("talents.reset.confirm"), 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(title)
	var msg := UiKit.label(L.t("talents.reset.message"), 14, UiKit.INK_SOFT)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(msg)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	v.add_child(buttons)
	var cancel := UiKit.button(L.t("common.cancel"), "wood", 15)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(_close_confirm)
	buttons.add_child(cancel)
	var ok := _coin_button(L.t("talents.reset.action", [Fmt.n(Game.talents.respec_cost())]), "orange",
		(box.custom_minimum_size.x - 50.0) / 2.0)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(func() -> void:
		_close_confirm()
		Game.talents.reset_talents()
		selected = ""
		_dirty = true)
	buttons.add_child(ok)

	# Значок в цветном круге над окном
	var badge := Control.new()
	badge.size = Vector2(62, 62)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.draw.connect(func() -> void:
		var c := Vector2(31, 31)
		badge.draw_circle(c + Vector2(0, 3), 31.0, tone[2])
		fill_disc_v(badge, c, 31.0, tone[0], tone[1])
		badge.draw_arc(c, 29.75, 0.0, TAU, 48, UiKit.OUTLINE, 2.5, true))
	var ic := UiKit.icon("hourglass", 36)
	ic.position = Vector2(13, 13)
	ic.size = Vector2(36, 36)
	badge.add_child(ic)
	layer.add_child(badge)
	box.item_rect_changed.connect(func() -> void:
		badge.position = box.global_position - layer.global_position + Vector2(box.size.x / 2.0 - 31.0, -31.0))

	layer.modulate.a = 0.0
	layer.create_tween().tween_property(layer, "modulate:a", 1.0, 0.15)


func _close_confirm() -> void:
	if _confirm != null and is_instance_valid(_confirm):
		_confirm.queue_free()
	_confirm = null


## Кнопка с монетой вместо значка 🪙 в тексте (Text.withCoins).
func _coin_button(text: String, tone: String, width: float) -> Button:
	var b := UiKit.button("", tone, 15)
	b.custom_minimum_size = Vector2(0, 44)
	var parts := text.split("🪙")
	var plain := "".join(parts)
	var fs := fit_size(plain, width - 20.0 - 18.0 * float(parts.size() - 1), 15, 10)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	for i in parts.size():
		if i > 0:
			var coin := UiKit.icon("coin", fs + 3)
			coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(coin)
		if parts[i] != "":
			var l := UiKit.label(parts[i], fs, Color.WHITE, 5)
			l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(l)
	return b


# MARK: Рисование

static func gray_material() -> ShaderMaterial:
	if _gray == null:
		var sh := Shader.new()
		sh.code = GRAY_SHADER
		_gray = ShaderMaterial.new()
		_gray.shader = sh
	return _gray


## Наибольший размер шрифта, при котором текст влезает в ширину.
static func fit_size(text: String, max_width: float, font_size: int, min_size: int) -> int:
	var f := UiKit.font()
	var s := font_size
	while s > min_size and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > max_width:
		s -= 1
	return s


## Несколько строк по центру точки c.
static func text_block(ci: CanvasItem, text: String, c: Vector2, width: float, font_size: int, color: Color) -> void:
	var f := UiKit.font()
	var lines := text.split("\n")
	var lh := f.get_height(font_size)
	var y := c.y - lh * float(lines.size()) / 2.0 + f.get_ascent(font_size)
	for line in lines:
		ci.draw_string(f, Vector2(c.x - width / 2.0, y), line, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)
		y += lh


## Круг веером треугольников: цвет в центре и цвет каждой точки края.
static func _fan(ci: CanvasItem, c: Vector2, r: float, center_color: Color, edge: Callable) -> void:
	var n := 40
	var pts := PackedVector2Array([c])
	var cols := PackedColorArray([center_color])
	var idx := PackedInt32Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		var p := c + Vector2(cos(a), sin(a)) * r
		pts.append(p)
		cols.append(edge.call(p))
		idx.append_array([0, 1 + i, 1 + (i + 1) % n])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols)


## Круг с вертикальным градиентом сверху вниз.
static func fill_disc_v(ci: CanvasItem, c: Vector2, r: float, top: Color, bottom: Color) -> void:
	_fan(ci, c, r, top.lerp(bottom, 0.5), func(p: Vector2) -> Color:
		return top.lerp(bottom, clampf((p.y - c.y + r) / (2.0 * r), 0.0, 1.0)))


## Круг с радиальным градиентом от центра к краю.
static func fill_disc_r(ci: CanvasItem, c: Vector2, r: float, inner: Color, outer: Color) -> void:
	_fan(ci, c, r, inner, func(_p: Vector2) -> Color: return outer)


## Мягкое свечение кольцом от r0 (цвет) до r1 (прозрачно).
static func glow_ring(ci: CanvasItem, c: Vector2, r0: float, r1: float, color: Color) -> void:
	var n := 40
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for i in n:
		var d := Vector2(cos(TAU * float(i) / float(n)), sin(TAU * float(i) / float(n)))
		pts.append(c + d * r0)
		pts.append(c + d * r1)
		cols.append(color)
		cols.append(Color(color, 0.0))
		var j := (i + 1) % n
		idx.append_array([i * 2, i * 2 + 1, j * 2, j * 2, i * 2 + 1, j * 2 + 1])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols)


## Плашка-капсула с контуром.
static func capsule(ci: CanvasItem, rect: Rect2, fill: Color, border := 2) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = UiKit.OUTLINE
	sb.set_border_width_all(border)
	sb.set_corner_radius_all(int(rect.size.y / 2.0))
	sb.anti_aliasing = true
	ci.draw_style_box(sb, rect)


## Замок (lock.fill).
static func glyph_lock(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	ci.draw_rect(Rect2(c.x - 0.4 * s, c.y - 0.08 * s, 0.8 * s, 0.56 * s), color)
	var w := 0.15 * s
	var top := c + Vector2(0, -0.2 * s)
	ci.draw_arc(top, 0.24 * s, PI, TAU, 12, color, w, true)
	ci.draw_line(top + Vector2(-0.24 * s, 0), top + Vector2(-0.24 * s, 0.14 * s), color, w)
	ci.draw_line(top + Vector2(0.24 * s, 0), top + Vector2(0.24 * s, 0.14 * s), color, w)


## Плюс (plus).
static func glyph_plus(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	var h := 0.36 * s
	ci.draw_line(c + Vector2(-h, 0), c + Vector2(h, 0), color, 0.2 * s)
	ci.draw_line(c + Vector2(0, -h), c + Vector2(0, h), color, 0.2 * s)


## Стрелка вверх в круге (arrow.up.circle).
static func glyph_up(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	var w := 0.11 * s
	ci.draw_arc(c, 0.44 * s, 0.0, TAU, 24, color, w, true)
	ci.draw_line(c + Vector2(0, 0.22 * s), c + Vector2(0, -0.2 * s), color, w, true)
	ci.draw_line(c + Vector2(0, -0.22 * s), c + Vector2(-0.16 * s, -0.06 * s), color, w, true)
	ci.draw_line(c + Vector2(0, -0.22 * s), c + Vector2(0.16 * s, -0.06 * s), color, w, true)


## Круговая стрелка против часовой (arrow.counterclockwise) с тёмным контуром.
static func glyph_reset(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	var r := 0.36 * s
	var tip := c + Vector2(0, -r)
	var head := PackedVector2Array([tip + Vector2(-0.2 * s, 0), tip + Vector2(0.06 * s, -0.17 * s), tip + Vector2(0.06 * s, 0.17 * s)])
	for pass_n in 2:
		var col := UiKit.OUTLINE if pass_n == 0 else color
		var w := 0.14 * s + (3.0 if pass_n == 0 else 0.0)
		ci.draw_arc(c, r, -PI / 2.0, PI, 24, col, w, true)
		if pass_n == 0:
			var ring := PackedVector2Array(head)
			ring.append(head[0])
			ci.draw_polyline(ring, col, 3.0, true)
		ci.draw_colored_polygon(head, col)


## Узел дерева (TalentNode): медальон, иконка, замок или плюс, цена суперталанта и ранг.
class TalentNode extends Control:
	var id := ""
	var color := Color.WHITE
	var is_selected := false
	var radius := 30.0
	var _tap: Callable
	var _press_at := Vector2.ZERO
	var _overlay := Control.new()

	func _init(p_id: String, p_color: Color, p_selected: bool, tap: Callable) -> void:
		id = p_id
		color = p_color
		is_selected = p_selected
		_tap = tap
		radius = TalentsPanel.node_radius(id)
		size = Vector2(radius, radius) * 2.0
		mouse_filter = Control.MOUSE_FILTER_PASS
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var avail := Game.talents.available(id)
		modulate.a = 1.0 if avail else 0.55
		var s := 38.0 if Talents.is_super(id) else 30.0
		var ic := UiKit.icon(Talents.icon(id), s)
		ic.position = Vector2(radius - s / 2.0, radius - s / 2.0)
		ic.size = Vector2(s, s)
		if not avail:
			ic.material = TalentsPanel.gray_material()
		ic.modulate.a = 1.0 if avail or Game.talents.rank(id) > 0 else 0.7
		add_child(ic)
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_overlay.size = size
		_overlay.draw.connect(_draw_badges)
		add_child(_overlay)

	## Поставить центр круга в точку c.
	func place(c: Vector2) -> void:
		position = c - Vector2(radius, radius)

	func _has_point(p: Vector2) -> bool:
		return p.distance_to(Vector2(radius, radius)) <= radius + 4.0 or Rect2(0, radius * 2.0, radius * 2.0, 22).has_point(p)

	func _gui_input(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_press_at = mb.global_position
		elif mb.global_position.distance_to(_press_at) < 12.0:
			_tap.call(id)
			# Касание узла не доходит до поля: иначе оно сразу закроет описание
			accept_event()

	## Медальон: тень, каменное кольцо цвета ветки, тёмная или светлая середина.
	func _draw() -> void:
		var c := Vector2(radius, radius)
		var r := radius
		var sup := Talents.is_super(id)
		var rank := Game.talents.rank(id)
		var ring := UiKit.GOLD if sup else color
		if sup:
			var a := 0.55 if Game.talents.available(id) else 0.25
			TalentsPanel.glow_ring(self, c, r * 0.6, r * 1.35, Color(UiKit.GOLD, a))
		draw_circle(c + Vector2(0, 3), r, Color(UiKit.WOOD_DARK, 0.4))
		if rank > 0 or sup:
			TalentsPanel.fill_disc_v(self, c, r, ring.lerp(Color.WHITE, 0.25), ring.lerp(Color.BLACK, 0.25))
		else:
			TalentsPanel.fill_disc_v(self, c, r, Color("8a7a66"), Color("5e5040"))
		var ri := r - (8.0 if sup else 6.0)
		# Радиальный градиент от 2 до r, обрезанный по внутреннему кругу
		var edge_t := clampf((ri - 2.0) / (r - 2.0), 0.0, 1.0)
		var inner := Color("fff6dc") if rank > 0 else Color("4a4034")
		var outer := color.lerp(Color.WHITE, 0.6) if rank > 0 else Color("2e2820")
		TalentsPanel.fill_disc_r(self, c, ri, inner, inner.lerp(outer, edge_t))
		draw_arc(c, ri - 1.0, 0.0, TAU, 48, UiKit.OUTLINE, 2.0, true)
		var w := 3.0 if is_selected else 2.0
		var stroke := (Color.WHITE if sup else UiKit.GOLD) if is_selected else UiKit.OUTLINE
		draw_arc(c, r - w / 2.0, 0.0, TAU, 48, stroke, w, true)

	## Поверх иконки: замок или плюс, цена суперталанта, ранг под кругом.
	func _draw_badges() -> void:
		var o := _overlay
		var c := Vector2(radius, radius)
		var r := radius
		var sup := Talents.is_super(id)
		var rank := Game.talents.rank(id)
		var maxed := rank >= Talents.max_rank(id)
		var f := UiKit.font()
		var corner := c + Vector2(r * 0.67, -r * 0.67)
		if not Game.talents.available(id):
			o.draw_circle(corner, 10.0, UiKit.WOOD_DARK)
			o.draw_arc(corner, 9.25, 0.0, TAU, 24, UiKit.OUTLINE, 1.5, true)
			TalentsPanel.glyph_lock(o, corner, 11.0, Color.WHITE)
		elif Game.talents.can_learn(id):
			o.draw_circle(corner, 10.0, UiKit.TONES["green"][1])
			o.draw_arc(corner, 9.25, 0.0, TAU, 24, UiKit.OUTLINE, 1.5, true)
			TalentsPanel.glyph_plus(o, corner, 11.0, Color.WHITE)
		if sup:
			# Цена в очках слева сверху
			var txt := str(Talents.cost(id))
			var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			var bw := 5.0 + 9.0 + 1.0 + tw + 5.0
			var bh := 4.0 + f.get_height(11)
			var bc := c + Vector2(-r * 0.72, -r * 0.72)
			var rect := Rect2(bc.x - bw / 2.0, bc.y - bh / 2.0, bw, bh)
			TalentsPanel.capsule(o, rect, UiKit.TONES["orange"][1])
			var star := Sprites.icon("star")
			if star != null:
				o.draw_texture_rect(star, Rect2(rect.position.x + 5.0, bc.y - 4.5, 9, 9), false)
			o.draw_string(f, Vector2(rect.position.x + 15.0, rect.position.y + 2.0 + f.get_ascent(11)), txt,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
		var label := L.t("talents.super") if sup else "%d/%d" % [rank, Talents.max_rank(id)]
		var lw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 14.0
		var lh := f.get_height(11) + 4.0
		var lr := Rect2(c.x - lw / 2.0, r * 2.0 + 20.0 - lh, lw, lh)
		var ring := UiKit.GOLD if sup else color
		TalentsPanel.capsule(o, lr, ring if maxed else UiKit.PARCHMENT_LIGHT)
		o.draw_string(f, Vector2(lr.position.x + 7.0, lr.position.y + 2.0 + f.get_ascent(11)), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE if maxed else UiKit.INK)
