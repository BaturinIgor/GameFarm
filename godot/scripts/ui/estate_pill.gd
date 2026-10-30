class_name EstatePill
extends Button
## Плашка усадьбы справа: молоток и таймер ближайшей стройки (или "Усадьба"), точка - есть что забрать
## или выполнить. Раз в секунду проверяет стройку, чтобы готовое здание достроилось и без открытого окна.

var _row := HBoxContainer.new()
var _text: Label
var _dot: Control
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
	_row.add_theme_constant_override("separation", 5)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_row)
	_row.add_child(UiKit.icon("hammer", 20))
	_text = UiKit.title("", 12)
	_text.label_settings.outline_size = 4
	_row.add_child(_text)
	_dot = UiKit.count_badge(0)
	(_dot.get_child(0) as Label).text = "!"
	_dot.position = Vector2(-6, -7)
	_dot.visible = false
	add_child(_dot)
	pressed.connect(func() -> void: EstatePanel.open())
	_refresh()


func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 1.0
	Game.estate.tick()
	_refresh()


func _refresh() -> void:
	var e := Game.estate
	var soonest := INF
	for id in Estate.IDS:
		if e.building(id):
			soonest = minf(soonest, e.build_left(id))
	_text.text = House.countdown(soonest) if soonest < INF else L.t("estate.short")
	_dot.visible = e.ready_count() > 0 or e.ready_orders() > 0
	custom_minimum_size = _row.get_combined_minimum_size() + Vector2(16, 10)
