class_name ShopPill
extends HBoxContainer
## Плашки справа под монетами: удача и магазин (порт LuckButton(.pill) и shopPill из HUDView).
## Пока действует срочный набор (стартовый или по уровню), на плашке магазина золотой сундук и таймер.
## Новое предложение или кристаллы MAX - красная точка. Здесь же раз в полсекунды проверяется,
## не пора ли показать окно нового предложения (OfferPopup.check).

var _shop := Button.new()
var _row := HBoxContainer.new()
var _icon: TextureRect
var _text: Label
var _offer := false
var _dot: Control
var _built := false
var _tick := 0.0


func _init() -> void:
	add_theme_constant_override("separation", 6)
	alignment = BoxContainer.ALIGNMENT_END
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var luck := LuckButton.new("pill")
	luck.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(luck)
	_shop.focus_mode = Control.FOCUS_NONE
	_shop.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_shop.pressed.connect(func() -> void:
		if Hud.current != null:
			Hud.current.open_window(ShopPanel.new()))
	add_child(_shop)
	_row.add_theme_constant_override("separation", 5)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shop.add_child(_row)
	_icon = UiKit.icon("chest", 20)
	_row.add_child(_icon)
	_text = UiKit.title("", 12)
	_text.label_settings.outline_size = 4
	_row.add_child(_text)
	_dot = UiKit.count_badge(0)
	(_dot.get_child(0) as Label).text = "!"
	_dot.position = Vector2(-6, -7)
	_dot.visible = false
	_shop.add_child(_dot)
	_refresh()


func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.5
	_refresh()
	OfferPopup.check()


## Ближайший конец срочного набора (стартовый или по уровню), 0 - таких нет.
static func urgent_until() -> float:
	var best := 0.0
	for o in Game.shop.current_offers():
		if o["product"] == "eventPass":
			continue
		var ends := ShopPanel.offer_ends(o["product"])
		if ends > 0.0 and (best == 0.0 or ends < best):
			best = ends
	return best


func _refresh() -> void:
	var until := urgent_until()
	var offer := until > 0.0
	_dot.visible = Game.shop.has_news()
	if offer != _offer or not _built:
		_offer = offer
		_built = true
		_icon.texture = Sprites.icon("chest_gold" if offer else "chest")
		_text.label_settings.font_color = UiKit.GOLD if offer else Color.WHITE
		var s := UiKit.pill_style()
		s.set_corner_radius_all(13)
		s.set_content_margin_all(0)
		s.bg_color = UiKit.TONES["orange"][1] if offer else Color(UiKit.WOOD, 0.95)
		var down := s.duplicate() as StyleBoxFlat
		down.bg_color = s.bg_color.darkened(0.15)
		for state in ["normal", "hover", "disabled"]:
			_shop.add_theme_stylebox_override(state, s)
		_shop.add_theme_stylebox_override("pressed", down)
		_shop.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if offer:
		_text.text = House.countdown(until - Time.get_unix_time_from_system())
	else:
		_text.text = L.t("shop.short")
	_shop.custom_minimum_size = _row.get_combined_minimum_size() + Vector2(16, 10)
