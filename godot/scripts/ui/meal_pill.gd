class_name MealPill
extends PanelContainer
## Плашка под монетами: какие блюда сейчас действуют и сколько осталось до конца первого (порт MealPill).
## По нажатию открывает кухню. Без действующих блюд прячется.

var _row := HBoxContainer.new()
var _time: Label
var _signature: Array = []
var _tick := 0.0


func _init() -> void:
	var s := UiKit.pill_style()
	s.bg_color = UiKit.TONES["green"][1]
	s.set_corner_radius_all(13)
	add_theme_stylebox_override("panel", s)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_row.add_theme_constant_override("separation", 2)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	visible = false


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT and Hud.current != null:
		Hud.current.open_window(KitchenPanel.new())


func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.5
	var meals := Game.house.active_meal_list()
	visible = not meals.is_empty()
	if meals.is_empty():
		return
	var dishes: Array = meals.map(func(m: Dictionary) -> String: return m["dish"])
	if dishes != _signature:
		_signature = dishes
		for c in _row.get_children():
			c.queue_free()
		for d in dishes:
			_row.add_child(UiKit.icon(House.dish_icon(d), 18))
		_time = UiKit.title("", 12)
		_time.label_settings.outline_size = 4
		_row.add_child(_time)
	_time.text = " " + House.countdown(float(meals[0]["until"]) - Time.get_unix_time_from_system())
