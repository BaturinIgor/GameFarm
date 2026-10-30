class_name Sheet
extends Control
## Окно-лист поверх игры: затемнение, пергаментная панель, заголовок, монеты, кнопка закрытия
## и прокручиваемое содержимое. Наследники заполняют content в build() и обновляются при изменениях.

var title_key := ""
var content := VBoxContainer.new()
var _panel := PanelContainer.new()
var _title: Label
var _coins: Label
var _scroll := ScrollContainer.new()
var _dirty := true


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

	var insets := UiKit.safe_insets(get_viewport())
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.offset_left = 8
	_panel.offset_right = -8
	_panel.offset_top = insets["top"] + 54
	_panel.offset_bottom = -insets["bottom"] - 8
	_panel.add_theme_stylebox_override("panel", UiKit.panel_style(22))
	add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	col.add_child(head)
	_title = UiKit.title(L.t(title_key), 22)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var coin_box := PanelContainer.new()
	coin_box.add_theme_stylebox_override("panel", UiKit.pill_style())
	head.add_child(coin_box)
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 4)
	coin_box.add_child(crow)
	crow.add_child(UiKit.icon("coins", 18))
	_coins = UiKit.title("0", 14)
	crow.add_child(_coins)
	var x := UiKit.button("✕", "red", 16, true)
	x.custom_minimum_size = Vector2(40, 36)
	x.pressed.connect(close)
	head.add_child(x)

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
		_dirty = true)
	# Появление снизу
	_panel.modulate.a = 0.0
	_panel.position.y += 40
	var tw := create_tween().set_parallel()
	tw.tween_property(_panel, "modulate:a", 1.0, 0.18)
	tw.tween_property(_panel, "position:y", _panel.position.y - 40, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		_coins.text = Fmt.n(int(Game.save["coins"]))
		var keep := _scroll.scroll_vertical
		for c in content.get_children():
			c.queue_free()
		build()
		touch_scroll(content)
		_scroll.set_deferred("scroll_vertical", keep)


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
