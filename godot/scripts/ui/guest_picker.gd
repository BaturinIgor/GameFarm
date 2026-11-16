class_name GuestPicker
extends Control
## Выбор зверя, который пойдёт в гости к участнику альянса (на сутки).

var _host_id := ""
var _host_name := ""


static func open(host_id: String, host_name: String) -> void:
	if Hud.current == null:
		return
	var p := GuestPicker.new()
	p._host_id = host_id
	p._host_name = host_name
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
	var w := minf(340.0, get_viewport_rect().size.x - 32.0)
	panel.custom_minimum_size = Vector2(w, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title := UiKit.label(L.t("guests.pickTitle", [_host_name]), 17)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	var hint := UiKit.label(L.t("guests.pickHint", [Fmt.pct(Guests.BONUS_PER_STAR)]), 12, UiKit.INK_SOFT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, minf(380.0, get_viewport_rect().size.y * 0.5))
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	var al := Game.alliance
	var ids: Array = Game.animals.owned()
	ids.sort_custom(func(a: String, b: String) -> bool: return Game.animals.stars(a) > Game.animals.stars(b))
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
		var stars := Game.animals.stars(id)
		col.add_child(UiKit.label(L.t("guests.gives", [Fmt.pct(Guests.BONUS_PER_STAR * stars)]), 11, UiKit.INK_SOFT))
		var b := UiKit.button(L.t("guests.send"), "green", 13, true)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.disabled = not al.can_send_guest(id)
		var animal: String = id
		b.pressed.connect(func() -> void:
			al.send_guest(_host_id, animal)
			queue_free())
		row.add_child(b)
	var close := UiKit.button(L.t("common.close"), "wood", 14)
	close.pressed.connect(queue_free)
	box.add_child(close)
