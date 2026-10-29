class_name ExpeditionReport
extends Control
## Итог экспедиции (порт ExpeditionReportOverlay): что добыто, монеты и ещё одна вылазка туда же,
## если хватает билетов и карт. Показ: ExpeditionReport.present_pending() - когда в
## Game.premium.expedition_report есть итог и на экране нет заставки нового уровня.

static var current: ExpeditionReport

var report: Dictionary = {}
var _closing := false


## Показать итог, если он есть и ещё не на экране (после заставки нового уровня).
static func present_pending() -> void:
	var r = Game.premium.expedition_report
	if r == null or Hud.current == null:
		return
	if current != null and is_instance_valid(current):
		return
	if LevelUpOverlay.current != null and is_instance_valid(LevelUpOverlay.current):
		return
	var overlay := ExpeditionReport.new(r)
	current = overlay
	Hud.current.show_overlay(overlay)


func _init(r: Dictionary) -> void:
	report = r


func _exit_tree() -> void:
	if current == self:
		current = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var id := str(report.get("location", "goldMine"))
	var coins := int(report.get("coins", 0))
	var items: Array = report.get("items", [])
	var dim := ColorRect.new()
	dim.color = UiKit.DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			close())
	add_child(dim)
	var confetti := LevelUpOverlay.Confetti.new()
	confetti.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(confetti)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	var style := UiKit.panel_style(22)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 10
	style.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(minf(360.0, get_viewport_rect().size.x - 48.0), 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)

	# Лента "Экспедиция завершена" над верхним краем панели
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(holder)
	var ribbon := LevelUpOverlay.Ribbon.new()
	ribbon.tone = UiKit.TONES["blue"]
	ribbon.label.label_settings.font_size = 20
	ribbon.label.label_settings.outline_color = ribbon.tone[2]
	ribbon.anchor_left = 0.5
	ribbon.anchor_right = 0.5
	ribbon.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ribbon.offset_top = -30
	ribbon.set_text(L.t("exp.done"))
	holder.add_child(ribbon)

	var top := MarginContainer.new()
	top.add_theme_constant_override("margin_top", 12)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := UiKit.icon(Locations.icon(id), 54)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	top.add_child(ic)
	col.add_child(top)
	var name_l := UiKit.label(Locations.name_of(id), 15, UiKit.INK_SOFT)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name_l)
	if items.is_empty() and coins == 0:
		var empty := UiKit.label(L.t("exp.empty"), 14, UiKit.INK_SOFT)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(empty)
	else:
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		flow.alignment = FlowContainer.ALIGNMENT_CENTER
		flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(flow)
		if coins > 0:
			flow.add_child(_chip(UiKit.icon("coin", 22), "+" + Fmt.n(coins)))
		for it in items:
			flow.add_child(_chip(UiKit.icon(str(it[0]), 24), "+" + Fmt.n(int(it[1]))))
		var stored := UiKit.label(L.t("offline.inStorage"), 12, UiKit.INK_SOFT)
		stored.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(stored)

	# Ещё одна вылазка туда же, если хватает билетов и карт
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	col.add_child(buttons)
	var price := Expeditions.cost(id)
	var maps := Expeditions.maps(id)
	var p := Game.premium
	if p.tickets() >= price and p.maps() >= maps:
		var parts: Array = [["t", L.t("exp.again")], ["t", str(price)], ["i", "ticket"]]
		if maps > 0:
			parts.append_array([["t", str(maps)], ["i", "tmap"]])
		var again := MapPanel.icon_button(parts, "orange")
		again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		again.pressed.connect(func() -> void:
			close()
			Game.premium.start_expedition(id))
		buttons.add_child(again)
	var ok := UiKit.button(L.t("common.great"), "green", 14, true)
	ok.custom_minimum_size = Vector2(0, MapPanel.SMALL_BUTTON_HEIGHT)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(close)
	buttons.add_child(ok)

	# Появление с лёгким подпрыгиванием
	panel.resized.connect(func() -> void: panel.pivot_offset = panel.size / 2.0)
	panel.scale = Vector2.ONE * 0.85
	modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 1.0, 0.18)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


## Награда "+N" с иконкой в светлой капсуле (RewardChip).
func _chip(icon: Control, text: String) -> PanelContainer:
	var p := PanelContainer.new()
	var s := UiKit.box(UiKit.PARCHMENT_LIGHT, Color(UiKit.WOOD_DARK, 0.5), 16, 2, false)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 5
	s.content_margin_bottom = 5
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	row.add_child(UiKit.label(text, 16))
	return p


func close() -> void:
	if _closing:
		return
	_closing = true
	if Game.premium.expedition_report == report:
		Game.premium.expedition_report = null
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(queue_free)
