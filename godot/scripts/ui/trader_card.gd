class_name TraderCard
extends PanelContainer
## Карточка рядом с торговцем (порт TraderCard): портрет, подпись и кнопка "Торговать".
## Показывается через Hud.current.set_prompt("trader", card).

## "stall" (лавка) или "wanderer" (бродячий торговец).
var kind := "stall"


func _init(trader_kind: String) -> void:
	kind = trader_kind
	add_theme_stylebox_override("panel", UiKit.panel_style(18))
	mouse_filter = Control.MOUSE_FILTER_STOP
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	var stall := kind == "stall"
	var portrait := TraderPanel.portrait("merchant" if stall else "wanderer", 52)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(portrait)
	var text := UiKit.label(L.t("trader.near") if stall else L.t("wanderer.near"), 14)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text)
	var b := UiKit.button(L.t("trader.open"), "orange" if stall else "purple")
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(_open)
	row.add_child(b)


func _ready() -> void:
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)


func _open() -> void:
	if Hud.current == null:
		return
	if kind == "stall":
		Hud.current.open_window(TraderPanel.new())
	else:
		Hud.current.open_window(WandererPanel.new())
