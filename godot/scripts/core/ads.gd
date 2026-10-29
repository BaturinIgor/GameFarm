class_name Ads
## Реклама только по желанию игрока и только за награду (порт Ads.swift, ветка SIDELOAD).
## Рекламы в сборке Android нет: награда выдаётся сразу с тостом, что это тест.
## Владельцы Pro получают награду сразу, без рекламы.


## Показать ролик и вызвать on_reward, если его досмотрели.
static func show_rewarded(on_reward: Callable) -> void:
	if Game.premium.has_pro():
		on_reward.call()
		return
	Game.show_toast("px:potion", L.t("ads.testSkipped"))
	on_reward.call()


## Ролик загружен и его можно показать.
static func ready() -> bool:
	return true


## Кнопка награды за рекламу: значок ролика (с Pro - корона) и подпись.
static func reward_button(text: String, tone := "green", font_size := 15, small := false) -> Button:
	var b := UiKit.button("", tone, font_size, small)
	var inner := HBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 6)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(inner)
	if Game.premium.has_pro():
		var crown := UiKit.icon("crown", font_size + 3.0)
		crown.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		inner.add_child(crown)
	else:
		inner.add_child(mark(font_size - 2.0))
	var l := UiKit.title(text, font_size)
	l.label_settings.outline_size = 5
	inner.add_child(l)
	b.custom_minimum_size = Vector2(inner.get_combined_minimum_size().x + 24.0, font_size + (16.0 if small else 22.0))
	return b


## Значок ролика (play.rectangle.fill): белый прямоугольник с треугольником.
static func mark(side := 14.0, color := Color.WHITE) -> Control:
	var m := PlayMark.new()
	m.tint = color
	m.custom_minimum_size = Vector2(side * 1.25, side)
	m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return m


class PlayMark extends Control:
	var tint := Color.WHITE

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var box := StyleBoxFlat.new()
		box.bg_color = tint
		box.border_color = UiKit.OUTLINE
		box.set_border_width_all(1)
		box.set_corner_radius_all(int(size.y * 0.25))
		box.anti_aliasing = true
		draw_style_box(box, r)
		var c := r.get_center()
		var h := size.y * 0.42
		var tri := PackedVector2Array([c + Vector2(-h * 0.45, -h / 2.0), c + Vector2(h * 0.6, 0), c + Vector2(-h * 0.45, h / 2.0)])
		draw_colored_polygon(tri, UiKit.OUTLINE)
