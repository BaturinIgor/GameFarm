class_name IntroPopup
extends Control
## Знакомство с разделом: несколько слайдов (значок, заголовок, текст), точки и кнопки "Дальше" / "Понятно".
## Показывается один раз при первом открытии раздела (Nav.open_sub).

var _sub := ""
var _slide := 0
var _box: VBoxContainer


static func open(sub: String) -> void:
	if Hud.current == null or not Guide.INTROS.has(sub):
		return
	var p := IntroPopup.new()
	p._sub = sub
	Game.guide.mark_intro(sub)
	Hud.current.show_overlay(p)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = UiKit.DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	var st := UiKit.panel_style(18)
	st.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", st)
	panel.custom_minimum_size = Vector2(minf(330.0, get_viewport_rect().size.x - 40.0), 0)
	center.add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 12)
	panel.add_child(_box)
	_build()


func _count() -> int:
	return int(Guide.INTROS[_sub]["slides"])


func _build() -> void:
	for c in _box.get_children():
		c.queue_free()
	var icons: Array = Guide.SLIDE_ICONS.get(_sub, [])
	var icon_name := str(icons[_slide]) if _slide < icons.size() else str(Guide.INTROS[_sub]["icon"])
	var ic: Control = AnimalsPanel.animal_icon(icon_name, 64) if Animals.IDS.has(icon_name) else UiKit.icon(icon_name, 56)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(ic)
	var tag := UiKit.label(L.t("intro.new"), 12, UiKit.TONES["green"][2])
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(tag)
	var title := UiKit.label(L.t(str(Nav.SUBS[_sub][0])), 19)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(title)
	var text := UiKit.label(L.t("intro.%s.%d" % [_sub, _slide + 1]), 14, UiKit.INK_SOFT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(0, 60)
	_box.add_child(text)
	# Точки: где мы среди слайдов
	var dots := HBoxContainer.new()
	dots.alignment = BoxContainer.ALIGNMENT_CENTER
	dots.add_theme_constant_override("separation", 6)
	for i in _count():
		var d := Panel.new()
		d.custom_minimum_size = Vector2(9, 9)
		d.add_theme_stylebox_override("panel", UiKit.box(UiKit.GOLD if i == _slide else Color(UiKit.WOOD_DARK, 0.3),
			Color(UiKit.OUTLINE, 0.6), 5, 1, false))
		dots.add_child(d)
	_box.add_child(dots)
	var last := _slide >= _count() - 1
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_box.add_child(row)
	if not last:
		var skip := UiKit.button(L.t("intro.skip"), "wood", 14)
		skip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		skip.pressed.connect(queue_free)
		row.add_child(skip)
	var next := UiKit.button(L.t("intro.got") if last else L.t("intro.next"), "green", 14)
	next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next.pressed.connect(func() -> void:
		if last:
			queue_free()
		else:
			_slide += 1
			_build())
	row.add_child(next)
