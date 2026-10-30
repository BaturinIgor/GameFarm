class_name EnergyRow
extends HBoxContainer
## Энергия в блоке уровня под полосой опыта: молния, тонкая полоса с числом и маленький "+".
## Нажатие на полосу или "+" - окно "Где взять энергию". Точка на "+" - готова бесплатная энергия.
## Во время бесконечной энергии полоса золотая с таймером.

var bar: GameBar
var _dot: Control
var _tick := 0.0


func _init() -> void:
	add_theme_constant_override("separation", 3)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var ic := UiKit.icon("bolt", 14)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ic)
	bar = UiKit.bar(1.0, "blue", 101, 12, " ")
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	var plus := PanelContainer.new()
	var ps := UiKit.box(UiKit.TONES["green"][0], UiKit.OUTLINE, 7, 2, false)
	ps.set_content_margin_all(0)
	plus.add_theme_stylebox_override("panel", ps)
	plus.custom_minimum_size = Vector2(16, 16)
	plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p := UiKit.title("+", 11)
	p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plus.add_child(p)
	add_child(plus)
	# Готова бесплатная энергия: маленькая красная точка в углу плюса
	_dot = Panel.new()
	_dot.add_theme_stylebox_override("panel", UiKit.box(UiKit.BAD, Color.WHITE, 5, 1, false))
	_dot.size = Vector2(9, 9)
	_dot.position = Vector2(10, -4)
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dot.visible = false
	plus.add_child(_dot)
	gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			EnergyPopup.open())
	_refresh()


func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.5
	_refresh()


func _refresh() -> void:
	var e := Game.energy
	_dot.visible = Freebies.ready("energy")
	var label := bar.get_child(0) as Label
	if e.infinite():
		bar.value = 1.0
		bar.tone = "gold"
		label.text = "∞ " + House.countdown(e.infinite_left())
		return
	var v := e.value()
	var mx := e.max_value()
	bar.value = minf(1.0, v / maxf(1.0, mx))
	bar.tone = "red" if v < 40.0 else ("orange" if v < mx * 0.2 else "blue")
	label.text = "%d/%d" % [int(v), int(mx)]
