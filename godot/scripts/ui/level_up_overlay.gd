class_name LevelUpOverlay
extends Control
## Заставка нового уровня: звезда с номером, награды, что открылось, конфетти (порт LevelUpOverlay и ConfettiView).
## Показ: LevelUpOverlay.present(from, to). Закрывается кнопкой или нажатием мимо панели.

## Открытая заставка: если уровень вырос ещё раз, пока она на экране, уровни дописываются в неё.
static var current: LevelUpOverlay

var from_level := 1
var to_level := 2
var _panel := PanelContainer.new()
var _star := Control.new()
var _number: Label
var _multi: Label
var _list := VBoxContainer.new()
var _ribbon := Ribbon.new()
var _closing := false


func _init(from := 1, to := 2) -> void:
	from_level = from
	to_level = maxi(to, from + 1)


## Показать заставку через шапку или дописать уровни в уже открытую (как levelUp в GameState).
static func present(from: int, to: int) -> void:
	if current != null and is_instance_valid(current) and not current._closing:
		current.extend_to(to)
		return
	if Hud.current != null:
		Hud.current.show_overlay(LevelUpOverlay.new(from, to))


func extend_to(to: int) -> void:
	to_level = maxi(to_level, to)
	_fill()


func _ready() -> void:
	current = self
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = UiKit.DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			close())
	add_child(dim)
	var confetti := Confetti.new()
	confetti.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(confetti)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var style := UiKit.panel_style(22)
	style.set_content_margin_all(22)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.custom_minimum_size = Vector2(minf(360.0, get_viewport_rect().size.x - 48.0), 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.resized.connect(func() -> void: _panel.pivot_offset = _panel.size / 2.0)
	center.add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	_panel.add_child(col)

	# Лента с заголовком над верхним краем панели
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(holder)
	_ribbon.anchor_left = 0.5
	_ribbon.anchor_right = 0.5
	_ribbon.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_ribbon.offset_top = -42
	holder.add_child(_ribbon)

	# Звезда с номером уровня
	_star.custom_minimum_size = Vector2(110, 100)
	_star.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_star.pivot_offset = Vector2(55, 50)
	_star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_star)
	var star_icon := UiKit.icon("star", 92)
	star_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_star.add_child(star_icon)
	_number = UiKit.title("", 30)
	_number.label_settings.outline_color = UiKit.TONES["orange"][2]
	_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_number.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_number.offset_top = 4
	_number.offset_bottom = 4
	_star.add_child(_number)

	_multi = UiKit.label("", 14, UiKit.INK_SOFT)
	_multi.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_multi)

	var box := PanelContainer.new()
	var bs := UiKit.box(UiKit.PARCHMENT_LIGHT, Color(UiKit.WOOD_DARK, 0.45), 14, 2, false)
	bs.set_content_margin_all(12)
	box.add_theme_stylebox_override("panel", bs)
	col.add_child(box)
	_list.add_theme_constant_override("separation", 8)
	box.add_child(_list)

	var ok := UiKit.button(L.t("common.great"), "green")
	ok.pressed.connect(close)
	col.add_child(ok)
	_fill()

	# Появление: затемнение, панель пружинит, звезда вырастает с поворотом
	modulate.a = 0.0
	_panel.scale = Vector2.ONE * 0.88
	_star.scale = Vector2.ONE * 0.4
	_star.rotation_degrees = -30.0
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_star, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_star, "rotation_degrees", 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _exit_tree() -> void:
	if current == self:
		current = null


## Номер, заголовок, награды за все уровни и что на них открылось.
func _fill() -> void:
	_number.text = str(to_level)
	_ribbon.set_text(L.t("levelup.title", [to_level]))
	_multi.visible = to_level - from_level > 1
	_multi.text = L.t("levelup.multi", [to_level - from_level])
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	for line in LevelPanel.rewards(from_level, to_level):
		_list.add_child(_row(line))
	var lines: Array = []
	for lv in range(from_level + 1, to_level + 1):
		lines.append_array(LevelPanel.unlocks(lv))
	if lines.is_empty():
		return
	var divider := ColorRect.new()
	divider.color = Color(UiKit.WOOD_DARK, 0.18)
	divider.custom_minimum_size = Vector2(0, 2)
	_list.add_child(divider)
	_list.add_child(UiKit.label(L.t("levelup.unlocked"), 12, UiKit.INK_SOFT))
	for line in lines:
		_list.add_child(_row(line))


func _row(line: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var ic := UiKit.icon_any(line["icon"], 22)
	ic.custom_minimum_size = Vector2(28, 22)
	row.add_child(ic)
	var t := UiKit.label(line["text"], 14)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(t)
	return row


func close() -> void:
	if _closing:
		return
	_closing = true
	if current == self:
		current = null
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(queue_free)


## Лента с вырезами по краям (RibbonTitle): размер по тексту, рисуется сама.
class Ribbon extends Control:
	var tone: Array = UiKit.TONES["orange"]
	var label := UiKit.title("", 22)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.label_settings.outline_color = tone[2]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(label)

	func set_text(text: String) -> void:
		label.text = text
		update_minimum_size()

	func _get_minimum_size() -> Vector2:
		return label.get_minimum_size() + Vector2(52, 16)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			label.position = Vector2.ZERO
			label.size = size
			queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var notch := minf(12.0, h * 0.35)
		var pts := PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w - notch, h / 2.0),
			Vector2(w, h), Vector2(0, h), Vector2(notch, h / 2.0)])
		# Тень снизу, заливка сверху вниз от светлого к основному, контур
		var lip := PackedVector2Array()
		for p in pts:
			lip.append(p + Vector2(0, 3))
		draw_colored_polygon(lip, tone[2])
		var mid: Color = tone[0].lerp(tone[1], 0.5)
		draw_polygon(pts, PackedColorArray([tone[0], tone[0], mid, tone[1], tone[1], mid]))
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, UiKit.OUTLINE, 2.0, true)


## Конфетти, падающее сверху (ConfettiView): 90 бумажек, через 6 секунд перестаёт рисоваться.
class Confetti extends Control:
	const COLORS := [Color(1, 0.8, 0), Color(1, 0.58, 0), Color(1, 0.18, 0.33), Color(0, 0.78, 0.75),
		Color(0.2, 0.68, 0.9), Color(0.69, 0.32, 0.87), Color(1, 0.23, 0.19)]
	var pieces: Array = []
	var time := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for i in 90:
			pieces.append({
				"x": randf(), "delay": randf_range(0.0, 0.8), "speed": randf_range(0.22, 0.42),
				"sway": randf_range(10.0, 40.0), "spin": randf_range(2.0, 7.0), "size": randf_range(6.0, 11.0),
				"color": COLORS.pick_random(),
			})

	func _process(delta: float) -> void:
		time += delta
		if time > 6.0:
			visible = false
			set_process(false)
			return
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		for p in pieces:
			var local := time - float(p["delay"])
			if local <= 0.0:
				continue
			var y := -20.0 + local * float(p["speed"]) * h
			if y > h + 20.0:
				continue
			var x := float(p["x"]) * w + sin(local * 3.0 + float(p["x"]) * 10.0) * float(p["sway"])
			var s := float(p["size"])
			draw_set_transform(Vector2(x, y), local * float(p["spin"]), Vector2.ONE)
			draw_rect(Rect2(-s / 2.0, -s / 4.0, s, s / 2.0), p["color"])
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
