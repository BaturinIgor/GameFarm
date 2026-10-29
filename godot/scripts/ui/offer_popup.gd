class_name OfferPopup
extends Control
## Всплывающее предложение стартового набора (порт OfferPopup): на 5 уровне и ещё раз на 15, на 48 часов.
## Показ: OfferPopup.check() - проверяет, не пора ли открыть предложение, и показывает окно, когда на экране
## нет заставки нового уровня (как offerPopup в iOS). Закрывается само, когда набор куплен.

static var current: OfferPopup

var _closing := false
var _tick := 0.0


static func check() -> void:
	var p := Game.premium
	p.check_starter_offer()
	if not p.offer_popup or not p.starter_available() or Hud.current == null:
		return
	if current != null and is_instance_valid(current):
		return
	if LevelUpOverlay.current != null and is_instance_valid(LevelUpOverlay.current):
		return
	var popup := OfferPopup.new()
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

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	var style := UiKit.panel_style(22)
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(minf(360.0, get_viewport_rect().size.x - 48.0), 0)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(col)

	col.add_child(ShopPanel.ribbon(Products.title("starter"), "red", 20))
	var art := ShopPanel.art("starter", 70.0)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(art)
	var text := UiKit.label(L.t("offer.text"), 14, UiKit.INK_SOFT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	row.add_child(UiKit.icon_any("an:duckHat", 34))
	row.add_child(UiKit.icon("coins", 34))
	row.add_child(UiKit.icon("bag", 32))
	row.add_child(UiKit.icon_any("skin:robot", 34))
	col.add_child(ShopPanel.buy_button("starter", "red"))
	var later := UiKit.button(L.t("offer.later"), "wood", 14, true)
	later.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	later.pressed.connect(close)
	col.add_child(later)

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
	if Game.premium.owns("starter") or not Game.premium.starter_available():
		close()


func close() -> void:
	if _closing:
		return
	_closing = true
	Game.premium.offer_popup = false
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(queue_free)
