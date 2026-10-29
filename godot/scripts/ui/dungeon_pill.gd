class_name DungeonPill
extends PanelContainer
## Плашка под монетами в подземелье (порт DungeonPill): этаж, волна, "Глубже" и выход.
## Выход до победы спрашивает подтверждение: награды за этаж не будет. Вне подземелья прячется.

var _row := HBoxContainer.new()
var _shown := ""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_row.add_theme_constant_override("separation", 8)
	add_child(_row)
	visible = false


func _process(_delta: float) -> void:
	var d := Game.dungeons
	var run = d.run
	visible = run != null and d.in_dungeon()
	if not visible:
		_shown = ""
		return
	var key := "%s|%d|%d|%d|%s|%s|%s" % [run["dungeon"], int(run["floor"]), int(run["wave"]), int(run["waves"]),
		run["cleared"], d.can_go_deeper(), L.code]
	if key == _shown:
		return
	_shown = key
	_build(run)


func _build(run: Dictionary) -> void:
	for c in _row.get_children():
		c.queue_free()
	var id: String = run["dungeon"]
	var s := UiKit.pill_style()
	s.bg_color = Color(Dungeons.colors(id)[1], 0.95)
	s.set_corner_radius_all(16)
	s.content_margin_left = 12
	s.content_margin_right = 6
	s.content_margin_top = 5
	s.content_margin_bottom = 5
	add_theme_stylebox_override("panel", s)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row.add_child(col)
	var title := UiKit.label(Dungeons.name_of(id), 12, Color.WHITE, 3)
	col.add_child(title)
	var cleared: bool = run["cleared"]
	var text := L.t("dungeon.pill.cleared", [run["floor"]]) if cleared \
		else L.t("dungeon.pill", [run["floor"], maxi(1, int(run["wave"])), run["waves"]])
	col.add_child(UiKit.label(text, 11, UiKit.GOLD if cleared else Color(1, 1, 1, 0.9), 3))
	if cleared and Game.dungeons.can_go_deeper():
		var deeper := UiKit.button(L.t("dungeon.deeper"), "green", 13, true)
		deeper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		deeper.pressed.connect(func() -> void: Game.dungeons.go_deeper())
		_row.add_child(deeper)
	var leave := UiKit.button(L.t("dungeon.leave"), "wood" if cleared else "red", 13, true)
	leave.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	leave.pressed.connect(func() -> void:
		if Game.dungeons.run != null and Game.dungeons.run["cleared"]:
			Game.dungeons.leave_dungeon()
		else:
			DungeonPill.confirm_leave())
	_row.add_child(leave)


## "Выйти из подземелья?": награда за этаж пропадёт, собранное останется.
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
	var ic := UiKit.icon("door", 44)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var title := UiKit.label(L.t("dungeon.leave.confirm"), 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(title)
	var msg := UiKit.label(L.t("dungeon.leave.message"), 13, UiKit.INK_SOFT)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(msg)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	v.add_child(buttons)
	var cancel := UiKit.button(L.t("common.cancel"), "wood", 15)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(layer.queue_free)
	buttons.add_child(cancel)
	var ok := UiKit.button(L.t("dungeon.leave"), "red", 15)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(func() -> void:
		Game.dungeons.leave_dungeon()
		layer.queue_free())
	buttons.add_child(ok)
	Hud.current.show_overlay(layer)
