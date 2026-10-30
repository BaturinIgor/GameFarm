class_name ConfirmPopup
extends Control
## Окно подтверждения: значок, заголовок, пояснение и две кнопки (левая - второе действие или "Отмена",
## правая - главное). Нажатие мимо окна закрывает его.

var _icon := ""
var _title := ""
var _text := ""
var _ok_text := ""
var _ok_tone := "orange"
var _on_ok: Callable
var _alt_text := ""
var _on_alt: Callable


## alt_text пустой - левая кнопка "Отмена".
static func ask(icon: String, title: String, text: String, ok_text: String, ok_tone: String, on_ok: Callable,
		alt_text := "", on_alt := Callable()) -> void:
	if Hud.current == null:
		return
	var p := ConfirmPopup.new()
	p._icon = icon
	p._title = title
	p._text = text
	p._ok_text = ok_text
	p._ok_tone = ok_tone
	p._on_ok = on_ok
	p._alt_text = alt_text
	p._on_alt = on_alt
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
	var box := PanelContainer.new()
	var st := UiKit.panel_style(18)
	st.set_content_margin_all(20)
	box.add_theme_stylebox_override("panel", st)
	box.custom_minimum_size = Vector2(minf(320.0, get_viewport_rect().size.x - 40.0), 0)
	center.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	box.add_child(v)
	if _icon != "":
		var ic := UiKit.icon_any(_icon, 44)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
	var title := UiKit.label(_title, 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(title)
	if _text != "":
		var msg := UiKit.label(_text, 13, UiKit.INK_SOFT)
		msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(msg)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	v.add_child(buttons)
	var alt := UiKit.button(_alt_text if _alt_text != "" else L.t("common.cancel"), "wood", 14)
	alt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alt.pressed.connect(func() -> void:
		queue_free()
		if _on_alt.is_valid():
			_on_alt.call())
	buttons.add_child(alt)
	var ok := UiKit.button(_ok_text, _ok_tone, 14)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(func() -> void:
		queue_free()
		_on_ok.call())
	buttons.add_child(ok)
