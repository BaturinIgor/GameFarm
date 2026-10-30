class_name LanguagePopup
extends Control
## Выбор языка: окно со списком языков в два столбца, каждый - на своём языке, текущий отмечен зелёным.
## Раньше был выпадающий список: он закрывался сам, когда окно настроек перестраивалось.


static func open() -> void:
	if Hud.current == null:
		return
	Hud.current.show_overlay(LanguagePopup.new())


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
	panel.custom_minimum_size = Vector2(minf(360.0, get_viewport_rect().size.x - 32.0), 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	var ic := UiKit.icon("book", 26)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(ic)
	var title := UiKit.title(L.t("settings.language"), 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(title)
	var x := Sheet.CloseButton.new()
	x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	x.pressed.connect(queue_free)
	head.add_child(x)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	for code in L.CODES:
		var on: bool = code == L.code
		var b := UiKit.button(str(L.NAMES.get(code, code)), "green" if on else "wood", 14, true)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 40)
		b.clip_text = true
		var c: String = code
		b.pressed.connect(func() -> void:
			queue_free()
			if c != L.code:
				L.set_language(c))
		grid.add_child(b)
