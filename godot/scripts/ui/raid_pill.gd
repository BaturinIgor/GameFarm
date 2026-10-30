class_name RaidPill
extends Button
## Плашка набега справа: за 5 минут до набега - таймер (нажатие - окно с кнопкой "Отложить на час"),
## во время набега - сколько монстров осталось. В остальное время скрыта. Раз в секунду ведёт расписание.

var _row := HBoxContainer.new()
var _text: Label
var _tick := 0.0


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var s := UiKit.pill_style()
	s.set_corner_radius_all(13)
	s.set_content_margin_all(0)
	s.bg_color = Color(0.62, 0.18, 0.14, 0.92)
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
	_row.add_child(UiKit.icon("swords", 20))
	_text = UiKit.title("", 12)
	_text.label_settings.outline_size = 4
	_row.add_child(_text)
	pressed.connect(_open)
	visible = false


func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 1.0
	Game.raids.tick()
	_refresh()


func _refresh() -> void:
	var rs := Game.raids
	if not rs.live.is_empty():
		visible = true
		_text.text = L.t("raid.left", [rs.monsters_left()])
	elif rs.warning():
		visible = true
		_text.text = House.countdown(rs.left())
	else:
		visible = false
	custom_minimum_size = _row.get_combined_minimum_size() + Vector2(16, 10)


## Что будет и что можно сделать: вернуться домой, отложить.
func _open() -> void:
	var rs := Game.raids
	if not rs.live.is_empty():
		return
	if Hud.current == null:
		return
	var p := RaidInfo.new()
	Hud.current.show_overlay(p)


## Окно перед набегом: когда, кто придёт, кнопки "Домой" и "Отложить на час".
class RaidInfo:
	extends Control

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var dim := ColorRect.new()
		dim.color = UiKit.DIM
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dim.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed:
				queue_free())
		add_child(dim)
		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(center)
		var panel := PanelContainer.new()
		var st := UiKit.panel_style(20)
		st.set_content_margin_all(16)
		panel.add_theme_stylebox_override("panel", st)
		panel.custom_minimum_size = Vector2(minf(340.0, get_viewport_rect().size.x - 32.0), 0)
		center.add_child(panel)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 10)
		panel.add_child(v)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		v.add_child(head)
		head.add_child(UiKit.icon("swords", 36))
		head.add_child(UiKit.label(L.t("raid.title"), 18))
		var rs := Game.raids
		var e := Game.estate
		var text := UiKit.label(L.t("raid.info", [House.countdown(rs.left()), Raids.wave_size(e.level("main")),
			Raids.tower_count(e.level("tower"))]), 14, UiKit.INK_SOFT)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(text)
		if Game.current != "meadow":
			var home := UiKit.button(L.t("raid.home"), "green", 14)
			home.pressed.connect(func() -> void:
				queue_free()
				Game.world_map.travel("meadow"))
			v.add_child(home)
		if rs.can_postpone():
			var later := UiKit.button(L.t("raid.postpone"), "wood", 14)
			later.pressed.connect(func() -> void:
				rs.postpone()
				queue_free())
			v.add_child(later)
		var close_b := UiKit.button(L.t("common.close"), "wood", 14, true)
		close_b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		close_b.pressed.connect(queue_free)
		v.add_child(close_b)

	func close() -> void:
		queue_free()
