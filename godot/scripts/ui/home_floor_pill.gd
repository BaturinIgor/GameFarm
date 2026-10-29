class_name HomeFloorPill
extends VBoxContainer
## В доме: плашка с текущим этажом (порт HomeFloorPill). По нажатию раскрывается список:
## переход на другой этаж, план дома и выход на поляну. Вне дома прячется.

var _head := PanelContainer.new()
var _title: Label
var _menu := PanelContainer.new()
var _list := VBoxContainer.new()
var _shown_floor := ""
var _shown_lang := ""


func _init() -> void:
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_BEGIN
	visible = false

	_head.add_theme_stylebox_override("panel", UiKit.pill_style())
	_head.mouse_filter = Control.MOUSE_FILTER_STOP
	_head.size_flags_horizontal = Control.SIZE_SHRINK_END
	_head.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_toggle())
	add_child(_head)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_head.add_child(row)
	row.add_child(UiKit.icon("stairs", 20))
	_title = UiKit.title("", 13)
	_title.label_settings.outline_size = 4
	row.add_child(_title)
	row.add_child(_chevron())

	var ms := UiKit.panel_style(14)
	ms.set_content_margin_all(8)
	_menu.add_theme_stylebox_override("panel", ms)
	_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu.size_flags_horizontal = Control.SIZE_SHRINK_END
	_menu.visible = false
	_list.add_theme_constant_override("separation", 6)
	_menu.add_child(_list)
	add_child(_menu)


## Стрелка вниз (в шрифте нет значка).
func _chevron() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(10, 10)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		c.draw_polyline(PackedVector2Array([Vector2(1, 3), Vector2(5, 7), Vector2(9, 3)]), UiKit.OUTLINE, 4.0, true)
		c.draw_polyline(PackedVector2Array([Vector2(1, 3), Vector2(5, 7), Vector2(9, 3)]), Color.WHITE, 2.0, true))
	return c


func _process(_delta: float) -> void:
	var f := Game.house.current_floor()
	visible = f != ""
	if f == _shown_floor and L.code == _shown_lang:
		return
	_shown_floor = f
	_shown_lang = L.code
	_menu.visible = false
	if f != "":
		_title.text = House.floor_title(f)


func _toggle() -> void:
	_menu.visible = not _menu.visible
	if _menu.visible:
		_build_menu()


func _build_menu() -> void:
	for c in _list.get_children():
		c.queue_free()
	var here := Game.house.current_floor()
	var floors := House.FLOORS.duplicate()
	floors.reverse()
	for f in floors:
		if Game.house.is_built(f):
			var b := _item(House.floor_title(f), "orange" if f == here else "wood", "stairs")
			b.disabled = f == here
			b.pressed.connect(func() -> void:
				_menu.visible = false
				Game.house.switch_floor(f))
		else:
			var b := _item(L.t("home.floor.locked", [House.floor_title(f), House.floor_level(f)]), "gray", "plan")
			b.pressed.connect(_open_plan)
	var line := ColorRect.new()
	line.color = Color(UiKit.WOOD_DARK, 0.25)
	line.custom_minimum_size = Vector2(0, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.add_child(line)
	_item(L.t("home.plan"), "green", "plan").pressed.connect(_open_plan)
	_item(L.t("home.goOut"), "blue", "door").pressed.connect(func() -> void:
		_menu.visible = false
		Game.house.leave_house())


func _item(text: String, tone: String, icon_name: String) -> Button:
	var b := UiKit.button(text, tone, 13, true)
	b.icon = Sprites.icon(icon_name)
	b.add_theme_constant_override("icon_max_width", 18)
	b.add_theme_constant_override("h_separation", 6)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_list.add_child(b)
	return b


func _open_plan() -> void:
	_menu.visible = false
	if Hud.current != null:
		Hud.current.open_window(HousePanel.new())
