class_name HudRound
extends RefCounted
## Кнопки правого столбца главного экрана: квадратные (магазин, сундуки, горячее предложение) и круглые
## таймеры (удача, ивент, набег, блюда). Все одного размера, правые края в одну линию.

## Сторона квадратной кнопки.
const SQUARE := 58.0
## Диаметр круглой кнопки.
const ROUND := 44.0
## Ширина правого столбца: квадрат шире круга.
const COLUMN := SQUARE


## Оформить кнопку квадратом: значок сверху, подпись снизу. Возвращает подпись.
static func square(b: Button, icon: TextureRect, fill: Color) -> Label:
	_style(b, fill, 14)
	b.custom_minimum_size = Vector2(SQUARE, SQUARE)
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.custom_minimum_size = Vector2(30, 30)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	icon.offset_left = -15
	icon.offset_right = 15
	icon.offset_top = 5
	icon.offset_bottom = 35
	b.add_child(icon)
	var t := UiKit.title("", 10)
	t.label_settings.outline_size = 4
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	t.offset_left = 2
	t.offset_right = -2
	t.offset_top = -21
	t.offset_bottom = -4
	t.clip_text = true
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(t)
	return t


## Подпись квадрата: длинное слово на другом языке уменьшается, а не вылезает.
static func caption(t: Label, text: String) -> void:
	t.text = text
	UiKit.fit_label(t, SQUARE - 6.0, 10)


## Оформить кнопку кругом: значок по центру, маленькая подпись-таймер на нижнем крае. Возвращает подпись.
static func circle(b: Button, icon: TextureRect, fill: Color) -> Label:
	_style(b, fill, int(ROUND / 2.0))
	b.custom_minimum_size = Vector2(ROUND, ROUND)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.custom_minimum_size = Vector2(26, 26)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	icon.offset_left = -13
	icon.offset_right = 13
	icon.offset_top = -15
	icon.offset_bottom = 11
	b.add_child(icon)
	var chip := PanelContainer.new()
	var cs := UiKit.box(Color(UiKit.OUTLINE, 0.85), UiKit.OUTLINE, 7, 1, false)
	cs.content_margin_left = 4
	cs.content_margin_right = 4
	cs.content_margin_top = 0
	cs.content_margin_bottom = 0
	chip.add_theme_stylebox_override("panel", cs)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Подпись намеренно лежит на нижнем крае круга
	chip.set_meta("overlay_ok", true)
	b.add_child(chip)
	var t := UiKit.title("", 10)
	t.label_settings.outline_size = 3
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.add_child(t)
	var place := func() -> void:
		var s := chip.get_combined_minimum_size()
		chip.size = s
		chip.position = Vector2((ROUND - s.x) / 2.0, ROUND - s.y + 7.0)
	chip.resized.connect(place)
	t.resized.connect(place)
	place.call()
	return t


static func _style(b: Button, fill: Color, radius: int) -> void:
	b.focus_mode = Control.FOCUS_NONE
	var s := UiKit.pill_style()
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(0)
	s.bg_color = fill
	var down := s.duplicate() as GameStyle
	down.bg_color = fill.darkened(0.15)
	for state in ["normal", "hover", "disabled"]:
		b.add_theme_stylebox_override(state, s)
	b.add_theme_stylebox_override("pressed", down)
	b.add_theme_stylebox_override("hover_pressed", down)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


## Перекрасить уже оформленную кнопку (сундуки с ключами - фиолетовые, удача - зелёная).
static func tint(b: Button, fill: Color) -> void:
	for state in ["normal", "hover", "disabled"]:
		var s := b.get_theme_stylebox(state) as GameStyle
		if s != null:
			s.bg_color = fill
	for state in ["pressed", "hover_pressed"]:
		var s := b.get_theme_stylebox(state) as GameStyle
		if s != null:
			s.bg_color = fill.darkened(0.15)
	b.queue_redraw()
