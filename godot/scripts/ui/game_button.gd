class_name GameButton
extends Button
## Объёмная кнопка как GameButtonStyle в iOS: заливка с градиентом сверху вниз, светлая полоска сверху,
## тёмный контур и "губа" снизу (GameStyle). При нажатии кнопка опускается на губу. Выключенная - серая.
## Надпись белая с тонкой обводкой цвета губы (на золотой - тёмная без обводки).

var tone := "green":
	set(v):
		tone = v
		_restyle()
var small := false


func _init(t := "green", is_small := false, font_size := -1) -> void:
	small = is_small
	focus_mode = Control.FOCUS_NONE
	add_theme_font_override("font", UiKit.font())
	add_theme_font_size_override("font_size", font_size if font_size > 0 else (13 if small else 16))
	add_theme_constant_override("outline_size", 4)
	add_theme_constant_override("h_separation", 6)
	custom_minimum_size = Vector2(0, 33.0 if small else 46.0)
	tone = t
	# Своё содержимое (ряд с иконками) - над губой и опускается вместе с кнопкой
	child_entered_tree.connect(func(_n: Node) -> void: _shift_inner.call_deferred(false))
	button_down.connect(func() -> void: _shift_inner(true))
	button_up.connect(func() -> void: _shift_inner(false))


func _lip() -> float:
	return 3.0 if small else 4.0


func _shift_inner(down: bool) -> void:
	var lip := _lip()
	for c in get_children():
		if c is BoxContainer and is_equal_approx((c as Control).anchor_right, 1.0) \
				and is_equal_approx((c as Control).anchor_bottom, 1.0):
			(c as Control).offset_top = lip if down else 0.0
			(c as Control).offset_bottom = 0.0 if down else -lip


func _restyle() -> void:
	var c: Array = UiKit.TONES.get(tone, UiKit.TONES["green"])
	add_theme_stylebox_override("normal", GameStyle.button(tone, small))
	add_theme_stylebox_override("hover", GameStyle.button(tone, small))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	add_theme_stylebox_override("pressed", GameStyle.button(tone, small, true))
	add_theme_stylebox_override("hover_pressed", GameStyle.button(tone, small, true))
	add_theme_stylebox_override("disabled", GameStyle.button("gray", small))
	var text := UiKit.INK if tone == "gold" else Color.WHITE
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		add_theme_color_override(k, text)
	add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.85))
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 0) if tone == "gold" else c[2])


func _notification(what: int) -> void:
	# Прокрутка началась - нажатие отменено, содержимое возвращаем на место
	if what == NOTIFICATION_SCROLL_BEGIN or what == NOTIFICATION_MOUSE_EXIT:
		_shift_inner(false)
