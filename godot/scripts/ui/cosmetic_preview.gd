class_name CosmeticPreview
extends PanelContainer
## Примерка украшения перед покупкой: на 20 секунд включает сияние, переливы, светлячков питомцев или ночную
## поляну, магазин закрывается, внизу экрана - плашка с таймером, кнопкой покупки и крестиком.
## Купил - украшение остаётся, время вышло или нажал крестик - пропадает.

const SECONDS := 20.0

var product := ""
var _left: Label
var _tick := 0.0


static func start(p: String) -> void:
	if Hud.current == null:
		return
	# Ночная поляна видна только на Лесной поляне
	if p == "glowMeadow" and Game.current != "meadow":
		Game.show_toast("px:spark", L.t("preview.meadowOnly", [L.t("loc.meadow")]))
		Sound.play("error")
		return
	Settings.preview_id = p
	Settings.preview_until = _now() + SECONDS
	Hud.current.close_window()
	Hud.current.set_prompt("preview", CosmeticPreview.new(p))
	Sound.play("success")


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _init(p: String) -> void:
	product = p
	add_theme_stylebox_override("panel", UiKit.panel_style(18))
	mouse_filter = Control.MOUSE_FILTER_STOP
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	var ic := UiKit.icon(ShopPanel.extra_icon(p), 32)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(col)
	var t := UiKit.label(L.t("preview.title", [Products.title(p)]), 14)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(t)
	_left = UiKit.label("", 12, UiKit.INK_SOFT)
	col.add_child(_left)
	var buy := ShopPanel.BuyButton.new(p, Products.tone(p), "", true)
	buy.size_flags_horizontal = Control.SIZE_SHRINK_END
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy.custom_minimum_size = Vector2(84, 36)
	row.add_child(buy)
	var x := Sheet.CloseButton.new()
	x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	x.pressed.connect(finish)
	row.add_child(x)
	_refresh()


func _ready() -> void:
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)


func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.25
	_refresh()


func _refresh() -> void:
	# Купил - примерка больше не нужна, украшение уже своё
	if Game.premium.owns(product):
		Game.show_toast("px:" + ShopPanel.extra_icon(product), L.t("preview.bought", [Products.title(product)]))
		finish()
		return
	var left := Settings.preview_until - _now()
	if Settings.preview_id != product or left <= 0.0:
		finish()
		return
	_left.text = L.t("preview.left", [int(ceil(left))])


func finish() -> void:
	if Settings.preview_id == product:
		Settings.preview_id = ""
		Settings.preview_until = 0.0
	set_process(false)
	if Hud.current != null:
		Hud.current.set_prompt("preview", null)
	else:
		queue_free()
