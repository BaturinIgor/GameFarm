class_name SquadPicker
extends Control
## Выбор зверя в ячейку отряда турнира: свои звери по мощи.

var _slot := 0


static func open(slot: int) -> void:
	if Hud.current == null:
		return
	var p := SquadPicker.new()
	p._slot = slot
	Hud.current.show_overlay(p)


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
	var st := UiKit.panel_style(18)
	st.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", st)
	panel.custom_minimum_size = Vector2(minf(340.0, get_viewport_rect().size.x - 32.0), 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title := UiKit.label(L.t("tourney.pickTitle", [_slot + 1]), 17)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, minf(380.0, get_viewport_rect().size.y * 0.5))
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	var squad := Game.tourney.squad()
	var ids: Array = Game.animals.owned().filter(func(id: String) -> bool: return Power.animal(id) > 0)
	ids.sort_custom(func(a: String, b: String) -> bool: return Power.animal(a) > Power.animal(b))
	for id in ids:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		list.add_child(row)
		row.add_child(AnimalsPanel.animal_icon(id, 36))
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 0)
		row.add_child(col)
		col.add_child(UiKit.label(Animals.name_of(id), 14))
		col.add_child(UiKit.label(L.t("power.value", [Fmt.n(Power.animal(id))]), 11, UiKit.INK_SOFT))
		var at := squad.find(id)
		var b := UiKit.button(L.t("tourney.inSlot", [at + 1]) if at >= 0 else L.t("tourney.put"), "wood" if at >= 0 else "green", 13, true)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.disabled = at == _slot
		var animal: String = id
		b.pressed.connect(func() -> void:
			Game.tourney.set_slot(_slot, animal)
			queue_free())
		row.add_child(b)
	var close := UiKit.button(L.t("common.close"), "wood", 14)
	close.pressed.connect(queue_free)
	box.add_child(close)
