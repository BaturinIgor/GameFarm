class_name ExpeditionPill
extends PanelContainer
## Таймер экспедиции под монетами (порт ExpeditionPill): сколько осталось и "Вернуться" раньше времени
## (с подтверждением). Вне экспедиции прячется.

var _row := HBoxContainer.new()
var _time: Label
var _shown := ""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var s := UiKit.pill_style()
	s.set_corner_radius_all(16)
	s.content_margin_left = 12
	s.content_margin_right = 6
	s.content_margin_top = 5
	s.content_margin_bottom = 5
	add_theme_stylebox_override("panel", s)
	_row.add_theme_constant_override("separation", 8)
	add_child(_row)
	visible = false


func _process(_delta: float) -> void:
	var run = Game.premium.expedition()
	visible = run != null and str(run["location"]) == Game.current
	if not visible:
		_shown = ""
		return
	if _shown != L.code:
		_shown = L.code
		_build()
	var left := Game.premium.expedition_left()
	_time.text = TraderPanel.countdown(left)
	_time.label_settings.font_color = Color("ff8a7a") if left < 30.0 else Color.WHITE


func _build() -> void:
	for c in _row.get_children():
		c.queue_free()
	var ic := UiKit.icon("compass", 20)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row.add_child(ic)
	_time = UiKit.label("", 16, Color.WHITE, 4)
	_time.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row.add_child(_time)
	var leave := UiKit.button(L.t("exp.leave"), "red", 13, true)
	leave.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	leave.pressed.connect(func() -> void: ExpeditionPill.confirm_leave())
	_row.add_child(leave)


## "Закончить экспедицию раньше?": добыча уже на складе, оставшееся время пропадёт.
static func confirm_leave() -> void:
	if Hud.current == null:
		return
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = UiKit.DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			layer.queue_free())
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	var box := PanelContainer.new()
	var st := UiKit.panel_style(18)
	st.set_content_margin_all(20)
	box.add_theme_stylebox_override("panel", st)
	box.custom_minimum_size = Vector2(300, 0)
	center.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	box.add_child(v)
	var ic := UiKit.icon("compass", 44)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var title := UiKit.label(L.t("exp.leave.confirm"), 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(title)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	v.add_child(buttons)
	var cancel := UiKit.button(L.t("common.cancel"), "wood", 15)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(layer.queue_free)
	buttons.add_child(cancel)
	var ok := UiKit.button(L.t("exp.leave"), "red", 15)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(func() -> void:
		Game.premium.finish_expedition()
		layer.queue_free())
	buttons.add_child(ok)
	Hud.current.show_overlay(layer)
