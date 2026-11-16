class_name MealPill
extends Button
## Кружок блюда в ряду таймеров под магазином (порт MealPill): значок первого действующего блюда,
## сколько осталось и число блюд, если их несколько. По нажатию открывает кухню. Без блюд прячется.

var _icon: TextureRect
var _time: Label
var _count: PanelContainer
var _tick := 0.0


func _init() -> void:
	_icon = UiKit.icon("star", 26)
	_time = HudRound.circle(self, _icon, UiKit.TONES["green"][1])
	_count = UiKit.count_badge(0)
	_count.visible = false
	UiKit.pin_badge(_count, self)
	pressed.connect(func() -> void:
		if Hud.current != null:
			Hud.current.open_window(KitchenPanel.new()))
	visible = false


func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.5
	var meals := Game.house.active_meal_list()
	visible = not meals.is_empty()
	if meals.is_empty():
		return
	var dish := House.dish_icon(meals[0]["dish"])
	_icon.texture = Sprites.icon(str(UiKit.ICON_ALIAS.get(dish, dish)))
	_count.visible = meals.size() > 1
	(_count.get_child(0) as Label).text = str(meals.size())
	_time.text = House.countdown(float(meals[0]["until"]) - Time.get_unix_time_from_system())
