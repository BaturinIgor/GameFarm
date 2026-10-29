class_name EventMapPill
extends VBoxContainer
## Плашка на карте ивента (порт EventMapPill и BoonStrip): этап, цель этапа, "Дальше" после этапа,
## дорога домой и значки взятых усилений. Нажатие на этап открывает окно ивентов. Вне ивента прячется.

var _shown := ""


func _init() -> void:
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _process(_delta: float) -> void:
	var ev := Game.events
	visible = ev.in_event()
	if not visible:
		_shown = ""
		return
	var boons: Array = Events.BOONS.map(func(b: String) -> int: return ev.boon_rank(b))
	var key := "%d|%d|%d|%s|%s|%s|%s|%s" % [ev.event_stage(), ev.event_progress(), ev.event_goal(),
		ev.event_stage_cleared(), ev.event_boss_due(), Game.save.get("eventChoice", []).is_empty(), boons, L.code]
	if key == _shown:
		return
	_shown = key
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var ev := Game.events
	var pill := PanelContainer.new()
	var s := UiKit.pill_style()
	s.set_corner_radius_all(16)
	s.content_margin_left = 10
	s.content_margin_right = 6
	s.content_margin_top = 5
	s.content_margin_bottom = 5
	pill.add_theme_stylebox_override("panel", s)
	pill.size_flags_horizontal = Control.SIZE_SHRINK_END
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pill)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(row)

	# Этап и цель: по нажатию окно ивентов
	var open := HBoxContainer.new()
	open.add_theme_constant_override("separation", 6)
	open.mouse_filter = Control.MOUSE_FILTER_STOP
	open.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			EventsPanel.open())
	row.add_child(open)
	var icon := UiKit.icon(Events.ICON[Events.current()["event"]], 20)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	open.add_child(icon)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	open.add_child(col)
	var title := L.t("event.stage", [ev.event_stage()])
	if ev.event_boss_stage():
		title += " · " + L.t("event.bossStage")
	var t := UiKit.title(title, 11)
	t.label_settings.outline_size = 4
	col.add_child(t)
	var progress := ev.event_progress()
	var goal := ev.event_goal()
	var cleared := ev.event_stage_cleared()
	var due := ev.event_boss_due()
	var text := L.t("event.portalOpen") if cleared else (L.t("event.bossDue") if due else "%d/%d" % [progress, ev.event_target()])
	col.add_child(UiKit.bar(float(mini(progress, goal)) / float(maxi(1, goal)),
		"green" if cleared else ("red" if due else "orange"), 110, 12, text))

	# Не нужно бежать к порталу: следующий этап одной кнопкой
	if cleared and Game.save.get("eventChoice", []).is_empty():
		var next := UiKit.button(L.t("event.next"), "green", 13, true)
		next.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		next.pressed.connect(func() -> void: Game.events.enter_event_portal())
		row.add_child(next)
	var home := UiKit.button(L.t("event.home"), "wood", 13, true)
	home.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	home.pressed.connect(func() -> void: Game.events.leave_event())
	row.add_child(home)

	# Значки взятых усилений с рангом
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 3)
	strip.size_flags_horizontal = Control.SIZE_SHRINK_END
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for b in Events.BOONS:
		var rank := ev.boon_rank(b)
		if rank <= 0:
			continue
		var cell := Control.new()
		cell.custom_minimum_size = Vector2(24, 24)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.add_child(cell)
		var circle := PanelContainer.new()
		var cs := UiKit.box(UiKit.PARCHMENT_LIGHT, UiKit.OUTLINE, 12, 2, false)
		cs.set_content_margin_all(0)
		circle.add_theme_stylebox_override("panel", cs)
		circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		circle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cell.add_child(circle)
		var ic := UiKit.icon(Events.boon_icon(b), 18)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		circle.add_child(ic)
		var n := UiKit.label(str(rank), 9, Color.WHITE, 3)
		n.position = Vector2(18, 13)
		cell.add_child(n)
	if strip.get_child_count() > 0:
		add_child(strip)
	else:
		strip.free()
