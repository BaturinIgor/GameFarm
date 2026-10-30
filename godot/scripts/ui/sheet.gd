class_name Sheet
extends Control
## Окно-лист поверх игры: затемнение, пергаментная панель, заголовок, монеты, кнопка закрытия
## и прокручиваемое содержимое. Наследники заполняют content в build() и обновляются при изменениях.

var title_key := ""
## Что показывать в шапке рядом с названием: монеты или кристаллы (магазин).
var header_currency := "coins"
var content := VBoxContainer.new()
## Неподвижная полоса между шапкой и прокруткой (вкладки). Наследник заполняет её в build_top().
var top_bar := VBoxContainer.new()
var _panel := PanelContainer.new()
var _title: Label
var _coins: Label
var _scroll := ScrollContainer.new()
var _dirty := true
var _to_top := false
var _rebuild_cd := 0.0

## Поля содержимого слева и справа.
const BODY_MARGIN := 14.0


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

	# Окно как GameWindowFrame в iOS: во всю ширину, скруглено сверху, до низа экрана
	var insets := UiKit.safe_insets(get_viewport())
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.offset_top = insets["top"] + 34
	var frame := StyleBoxFlat.new()
	frame.bg_color = UiKit.PARCHMENT
	frame.border_color = UiKit.OUTLINE
	frame.border_width_left = 2
	frame.border_width_right = 2
	frame.border_width_top = 2
	frame.corner_radius_top_left = 24
	frame.corner_radius_top_right = 24
	frame.anti_aliasing = true
	_panel.add_theme_stylebox_override("panel", frame)
	add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	_panel.add_child(col)
	col.add_child(_header())
	var body := MarginContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("margin_left", int(BODY_MARGIN))
	body.add_theme_constant_override("margin_right", int(BODY_MARGIN))
	body.add_theme_constant_override("margin_top", 14)
	body.add_theme_constant_override("margin_bottom", int(insets["bottom"]) + 6)
	col.add_child(body)
	col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	body.add_child(col)

	top_bar.add_theme_constant_override("separation", 8)
	top_bar.visible = false
	col.add_child(top_bar)
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.scroll_deadzone = 8
	col.add_child(_scroll)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	_scroll.add_child(content)

	Game.changed.connect(func() -> void: _dirty = true)
	L.language_changed.connect(func() -> void:
		_title.text = L.t(title_key)
		_fit_title()
		_dirty = true)
	# Появление снизу
	_panel.modulate.a = 0.0
	_panel.position.y += 40
	var tw := create_tween().set_parallel()
	tw.tween_property(_panel, "modulate:a", 1.0, 0.18)
	tw.tween_property(_panel, "position:y", _panel.position.y - 40, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _process(delta: float) -> void:
	_rebuild_cd -= delta
	# Не перестраиваем окно под пальцем (нажатие потерялось бы) и не чаще 4 раз в секунду:
	# звери и плита меняют игру постоянно
	if _dirty and (_to_top or (_rebuild_cd <= 0.0 and not UiKit.touch_held(_panel))):
		_dirty = false
		_rebuild_cd = 0.25
		_coins.text = Fmt.n(Game.shop.crystals() if header_currency == "crystals" else int(Game.save["coins"]))
		var keep := 0 if _to_top else _scroll.scroll_vertical
		_to_top = false
		for c in top_bar.get_children():
			c.queue_free()
		build_top()
		top_bar.visible = top_bar.get_child_count() > 0
		for c in content.get_children():
			c.queue_free()
		build()
		touch_scroll(content)
		_scroll.set_deferred("scroll_vertical", keep)


## Шапка окна (WindowHeader): деревянная доска, монеты слева, название по центру, круглый крестик справа.
func _header() -> Control:
	var head := PanelContainer.new()
	var wood := GameStyle.make(UiKit.WOOD_LIGHT, UiKit.WOOD, 22.0)
	wood.radii = Vector4(22, 22, 0, 0)
	wood.outline_width = 0.0
	wood.content_margin_left = 14
	wood.content_margin_right = 14
	wood.content_margin_top = 12
	wood.content_margin_bottom = 10
	head.add_theme_stylebox_override("panel", wood)
	_title = UiKit.title(L.t(title_key), 20)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var title_box := MarginContainer.new()
	title_box.add_theme_constant_override("margin_left", 104)
	title_box.add_theme_constant_override("margin_right", 104)
	title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_box.add_child(_title)
	head.add_child(title_box)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(row)
	# Монеты (или кристаллы) в тёмной капсуле
	var badge := PanelContainer.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = UiKit.WOOD_DARK
	bs.border_color = UiKit.OUTLINE
	bs.set_border_width_all(2)
	bs.set_corner_radius_all(16)
	bs.content_margin_left = 6
	bs.content_margin_right = 10
	bs.content_margin_top = 4
	bs.content_margin_bottom = 4
	bs.anti_aliasing = true
	badge.add_theme_stylebox_override("panel", bs)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(badge)
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 5)
	crow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(crow)
	crow.add_child(UiKit.icon("gem" if header_currency == "crystals" else "coin", 18))
	_coins = UiKit.title("0", 15)
	_coins.label_settings.outline_size = 4
	crow.add_child(_coins)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	var x := CloseButton.new()
	x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	x.pressed.connect(close)
	row.add_child(x)
	_fit_title()
	_title.resized.connect(_fit_title)
	# Тёмная черта и тень под доской
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 0)
	wrap.add_child(head)
	var line := ColorRect.new()
	line.color = UiKit.OUTLINE
	line.custom_minimum_size = Vector2(0, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(line)
	var shade := ColorRect.new()
	shade.color = Color(UiKit.WOOD_DARK, 0.35)
	shade.custom_minimum_size = Vector2(0, 3)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(shade)
	return wrap


## Ширина содержимого окна (экран минус поля).
func content_width() -> float:
	return get_viewport_rect().size.x - BODY_MARGIN * 2.0


## Длинное название окна (особенно на русском) уменьшаем до 15, чтобы оно влезало рядом с монетами.
func _fit_title() -> void:
	var room := _title.size.x
	if room <= 0.0:
		room = get_viewport_rect().size.x - 28.0 - 208.0
	var fs := 20
	while fs > 14 and UiKit.font().get_string_size(_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 12.0 > room:
		fs -= 1
	if _title.label_settings.font_size != fs:
		_title.label_settings.font_size = fs


## Прокрутка пальцем: элементы внутри прокрутки не должны забирать касание себе (STOP),
## иначе ScrollContainer его не получает. Кнопки остаются кнопками: при начале прокрутки
## нажатие на них само отменяется.
static func touch_scroll(node: Node) -> void:
	for c in node.get_children():
		if c is ScrollContainer:
			touch_scroll(c)
			continue
		if c is Control and (c as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
			(c as Control).mouse_filter = Control.MOUSE_FILTER_PASS
		touch_scroll(c)


## Заполнить content. Вызывается заново после любых изменений игры.
func build() -> void:
	pass


## Заполнить top_bar (неподвижная полоса над прокруткой). Вызывается перед build().
func build_top() -> void:
	pass


## Прокрутить содержимое в начало (после смены вкладки).
func scroll_to_top() -> void:
	_to_top = true
	_dirty = true


func close() -> void:
	var hud := get_parent()
	while hud != null and not hud is Hud:
		hud = hud.get_parent()
	if hud != null:
		hud.close_window()
	else:
		queue_free()


# MARK: Помощники для наследников

## Карточка: пергаментная плашка со столбцом внутри.
func card(tint := UiKit.PARCHMENT_LIGHT) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.box(tint, Color(UiKit.WOOD_DARK, 0.5), 14, 2, false))
	content.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	return v


func section_title(text: String, parent: Control = null) -> Label:
	var l := UiKit.label(text, 14, UiKit.INK_SOFT)
	(parent if parent != null else content).add_child(l)
	return l


## Круглая красная кнопка закрытия (CloseButton): градиент, губа снизу, белый крестик.
class CloseButton extends Button:
	const SIDE := 34.0

	func _init() -> void:
		custom_minimum_size = Vector2(SIDE, SIDE + 3.0)
		focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		resized.connect(func() -> void: pivot_offset = size / 2.0)
		button_down.connect(func() -> void: scale = Vector2.ONE * 0.93)
		button_up.connect(func() -> void: scale = Vector2.ONE)

	func _draw() -> void:
		var red: Array = UiKit.TONES["red"]
		var c := Vector2(SIDE / 2.0, SIDE / 2.0)
		var r := SIDE / 2.0
		draw_circle(c + Vector2(0, 3), r, red[2])
		draw_circle(c + Vector2(0, 3), r, UiKit.OUTLINE, false, 2.0, true)
		var pressed := get_draw_mode() == DRAW_PRESSED or get_draw_mode() == DRAW_HOVER_PRESSED
		if pressed:
			c.y += 2.0
		_gradient_disc(c, r, red[0], red[1])
		draw_circle(c, r - 1.0, UiKit.OUTLINE, false, 2.0, true)
		# Крестик
		var k := r * 0.36
		for d in [Vector2(1, 1), Vector2(1, -1)]:
			draw_line(c - d * k, c + d * k, red[2], 6.0, true)
			draw_line(c - d * k, c + d * k, Color.WHITE, 3.5, true)

	func _gradient_disc(c: Vector2, r: float, top: Color, bottom: Color) -> void:
		var pts := PackedVector2Array()
		var colors := PackedColorArray()
		for i in 32:
			var a := TAU * float(i) / 32.0
			var p := c + Vector2(cos(a), sin(a)) * (r - 1.0)
			pts.append(p)
			colors.append(top.lerp(bottom, clampf((p.y - (c.y - r)) / (2.0 * r), 0.0, 1.0)))
		draw_polygon(pts, colors)
