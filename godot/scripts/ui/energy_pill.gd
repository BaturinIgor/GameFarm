class_name EnergyPill
extends Button
## Плашка энергии справа под рюкзаком: молния, полоса с числом и зелёный "+". Нажатие - окно "Где взять энергию".
## Во время бесконечной энергии полоса золотая с таймером.

var _bar: GameBar
var _tick := 0.0


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var s := UiKit.pill_style()
	s.set_corner_radius_all(13)
	s.set_content_margin_all(0)
	var down := s.duplicate() as GameStyle
	down.bg_color = s.bg_color.darkened(0.15)
	for state in ["normal", "hover", "disabled", "focus"]:
		add_theme_stylebox_override(state, s)
	add_theme_stylebox_override("pressed", down)
	add_theme_stylebox_override("hover_pressed", down)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(row)
	row.add_child(UiKit.icon("bolt", 20))
	_bar = UiKit.bar(1.0, "gold", 92, 14, " ")
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_bar)
	var plus := PanelContainer.new()
	plus.add_theme_stylebox_override("panel", UiKit.box(UiKit.TONES["green"][0], UiKit.OUTLINE, 9, 2, false))
	plus.custom_minimum_size = Vector2(20, 20)
	plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p := UiKit.title("+", 14)
	p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plus.add_child(p)
	row.add_child(plus)
	custom_minimum_size = Vector2(150, 30)
	pressed.connect(EnergyPopup.open)
	_refresh()


func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.5
	_refresh()


func _refresh() -> void:
	var e := Game.energy
	var label := _bar.get_child(0) as Label
	if e.infinite():
		_bar.value = 1.0
		_bar.tone = "gold"
		label.text = "∞ " + House.countdown(e.infinite_left())
		return
	var v := e.value()
	var mx := e.max_value()
	_bar.value = minf(1.0, v / maxf(1.0, mx))
	_bar.tone = "red" if v < 50.0 else ("orange" if v < mx * 0.2 else "blue")
	label.text = "%d/%d" % [int(v), int(mx)]
