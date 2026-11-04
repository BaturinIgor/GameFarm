class_name ChestPill
extends HBoxContainer
## Плашка сундуков под магазином: значок сундука и число ключей. Есть ключи - плашка золотая
## и красный кружок с числом. Нажатие открывает окно сундуков.

var _button := Button.new()
var _row := HBoxContainer.new()
var _text: Label
var _dot: PanelContainer
var _shown := -1
var _tick := 0.0


func _init() -> void:
	alignment = BoxContainer.ALIGNMENT_END
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button.focus_mode = Control.FOCUS_NONE
	_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_button.pressed.connect(func() -> void:
		if Hud.current != null:
			Hud.current.open_window(ChestsPanel.new()))
	add_child(_button)
	_row.add_theme_constant_override("separation", 5)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_button.add_child(_row)
	_row.add_child(UiKit.icon("chest_gold", 20))
	_text = UiKit.title(L.t("chest.short"), 12)
	_text.label_settings.outline_size = 4
	_row.add_child(_text)
	_dot = UiKit.count_badge(0)
	_dot.position = Vector2(-6, -7)
	_dot.visible = false
	_button.add_child(_dot)
	L.language_changed.connect(func() -> void: _shown = -1)
	_refresh()


func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.5
	_refresh()


func _refresh() -> void:
	var n := Game.chests.total_keys()
	visible = Game.level >= 3 or n > 0
	if n == _shown:
		return
	_shown = n
	_text.text = L.t("chest.short")
	_dot.visible = n > 0
	(_dot.get_child(0) as Label).text = str(n) if n < 100 else "99+"
	var s := UiKit.pill_style()
	s.set_corner_radius_all(13)
	s.set_content_margin_all(0)
	s.bg_color = UiKit.TONES["purple"][1] if n > 0 else Color(UiKit.WOOD, 0.95)
	var down := s.duplicate() as GameStyle
	down.bg_color = s.bg_color.darkened(0.15)
	for state in ["normal", "hover", "disabled"]:
		_button.add_theme_stylebox_override(state, s)
	_button.add_theme_stylebox_override("pressed", down)
	_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_button.custom_minimum_size = _row.get_combined_minimum_size() + Vector2(16, 10)
