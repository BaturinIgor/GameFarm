class_name InfoPopup
extends Control
## Сообщение в стиле игры (DialogView в iOS): значок в кружке над панелью, заголовок, текст, кнопка "Понятно".

var title := ""
var message := ""
var icon := "px:scroll2"


static func show_info(t: String, m: String, ic := "px:scroll2") -> void:
	if Hud.current == null:
		return
	var p := InfoPopup.new()
	p.title = t
	p.message = m
	p.icon = ic
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
	var holder := MarginContainer.new()
	holder.add_theme_constant_override("margin_top", 31)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(holder)
	var panel := PanelContainer.new()
	var st := UiKit.panel_style(20)
	st.content_margin_left = 20
	st.content_margin_right = 20
	st.content_margin_top = 38
	st.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", st)
	panel.custom_minimum_size = Vector2(minf(340.0, get_viewport_rect().size.x - 48.0), 0)
	holder.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var t := UiKit.label(title, 20)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	var m := UiKit.label(message, 14, UiKit.INK_SOFT)
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(m)
	var ok := UiKit.button(L.t("common.ok"), "green", 16)
	ok.pressed.connect(func() -> void: queue_free())
	v.add_child(ok)
	# Значок в зелёном кружке над верхним краем
	var badge := PanelContainer.new()
	var bs := UiKit.box(UiKit.TONES["green"][1], UiKit.OUTLINE, 31, 3, false)
	bs.set_content_margin_all(12)
	badge.add_theme_stylebox_override("panel", bs)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(UiKit.icon_any(icon, 36))
	holder.add_child(badge)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	badge.resized.connect(func() -> void: badge.position.y = -31.0)
	# PanelContainer-ы в MarginContainer лежат друг на друге: кружок поднимаем над панелью
	holder.sort_children.connect(func() -> void:
		badge.position = Vector2((holder.size.x - badge.size.x) / 2.0, -31.0))
