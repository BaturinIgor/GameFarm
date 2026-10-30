class_name OfferPopup
extends Control
## Окно нового предложения поверх игры: стартовый набор, набор по уровню, пропуск нового ивента.
## Показывается только для предложения, которого игрок ещё не видел, не чаще раза в день, не в начале игры
## и не поверх других заставок (ShopSystem.popup_due). Остальное время о новом говорит точка на кнопке магазина.
## Показ: OfferPopup.check() - раз в полсекунды из ShopPill. Закрывается само, когда набор куплен или кончился.

static var current: OfferPopup

var product := ""
var _closing := false
var _tick := 0.0


static func check() -> void:
	Game.premium.check_starter_offer()
	Game.shop.check_level_bundles()
	if Hud.current == null:
		return
	if current != null and is_instance_valid(current):
		return
	if LevelUpOverlay.current != null and is_instance_valid(LevelUpOverlay.current):
		return
	# Открыто окно (магазин, склад...) - не мешаем, покажем позже
	if Hud.current.has_method("has_window") and Hud.current.call("has_window"):
		return
	if not Game.shop.popup_due():
		return
	var offer: Dictionary = Game.shop.new_offers()[0]
	Game.shop.note_popup_shown(offer["id"])
	var popup := OfferPopup.new()
	popup.product = offer["product"]
	current = popup
	Hud.current.show_overlay(popup)
	# Под другими заставками (итоги, календарь), как в iOS
	popup.get_parent().move_child(popup, 0)


func _exit_tree() -> void:
	if current == self:
		current = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = UiKit.DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			close())
	add_child(dim)

	var tone := Products.tone(product)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	var style := UiKit.box(UiKit.PARCHMENT, UiKit.TONES[tone][1], 22, 4)
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(minf(360.0, get_viewport_rect().size.x - 48.0), 0)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(col)

	col.add_child(ShopPanel.ribbon(Products.title(product), tone, 20))
	var ends := ShopPanel.offer_ends(product)
	if ends > 0.0:
		var timer := HBoxContainer.new()
		timer.alignment = BoxContainer.ALIGNMENT_CENTER
		timer.add_theme_constant_override("separation", 4)
		timer.add_child(UiKit.icon("stopwatch", 14))
		var left := func() -> String:
			return L.t("shop.endsIn", [EventsPanel.long_countdown(ends - Time.get_unix_time_from_system())])
		timer.add_child(CombatCards.LiveLabel.new(left, 13, UiKit.TONES["red"][2]))
		col.add_child(timer)
	var art := ShopPanel.art(product, 70.0)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(art)
	var text := UiKit.label(L.t("offer.text") if product == "starter" else ShopPanel.tagline(product), 14, UiKit.INK_SOFT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(text)
	# Что внутри - значками в ряд
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	for perk in ShopPanel.perks(product).slice(0, 5):
		row.add_child(UiKit.icon_any(perk[0], 34))
	col.add_child(ShopPanel.buy_button(product, tone))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	col.add_child(buttons)
	var more := UiKit.button(L.t("offer.toShop"), "wood", 14, true)
	more.pressed.connect(func() -> void:
		close()
		ShopPanel.open("offers"))
	buttons.add_child(more)
	var later := UiKit.button(L.t("offer.later"), "wood", 14, true)
	later.pressed.connect(close)
	buttons.add_child(later)

	# Появление с лёгким подпрыгиванием
	panel.resized.connect(func() -> void: panel.pivot_offset = panel.size / 2.0)
	panel.scale = Vector2.ONE * 0.85
	modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 1.0, 0.18)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.3
	# Набор куплен или время предложения вышло
	if not _still_offered():
		close()


func _still_offered() -> bool:
	return Game.shop.current_offers().any(func(o: Dictionary) -> bool: return o["product"] == product)


func close() -> void:
	if _closing:
		return
	_closing = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(queue_free)
