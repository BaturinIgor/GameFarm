class_name ChestPill
extends Button
## Квадратная кнопка сундуков под магазином: значок сундука и подпись. Есть ключи - кнопка фиолетовая
## и красный кружок с числом. Нажатие открывает окно сундуков.

var _text: Label
var _dot: PanelContainer
var _shown := -1
var _tick := 0.0


func _init() -> void:
	_text = HudRound.square(self, UiKit.icon("chest_gold", 30), Color(UiKit.WOOD, 0.95))
	pressed.connect(func() -> void:
		if Hud.current != null:
			Hud.current.open_window(ChestsPanel.new()))
	_dot = UiKit.count_badge(0)
	_dot.visible = false
	UiKit.pin_badge(_dot, self)
	L.language_changed.connect(func() -> void: _shown = -1)
	_refresh()


func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.5
	_refresh()


func _refresh() -> void:
	var n := Game.chests.total_keys()
	visible = Game.level >= 3 or n > 0
	if n == _shown:
		return
	_shown = n
	HudRound.caption(_text, L.t("chest.short"))
	_dot.visible = n > 0
	(_dot.get_child(0) as Label).text = str(n) if n < 100 else "99+"
	HudRound.tint(self, UiKit.TONES["purple"][1] if n > 0 else Color(UiKit.WOOD, 0.95))
