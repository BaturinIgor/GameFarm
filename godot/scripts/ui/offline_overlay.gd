class_name OfflineOverlay
extends Control
## Заставка "С возвращением": что звери-производители собрали, пока игры не было (порт OfflineOverlay).
## Всё уже лежит на складе. Удвоить за рекламу (с Pro - сразу): одно нажатие удваивает и закрывает окно.

var report: Dictionary = {}
var _closing := false


## Посчитать время без игры и показать заставку, если звери что-то собрали.
## Звать при запуске (после создания Hud) и при возвращении в игру.
static func check() -> void:
	var r := Game.animals.apply_offline()
	if r.is_empty() or Hud.current == null:
		return
	Hud.current.show_overlay(OfflineOverlay.new(r))


func _init(r: Dictionary) -> void:
	report = r


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

	# Лента с заголовком
	var ribbon := PanelContainer.new()
	var rs := UiKit.box(UiKit.TONES["green"][1], UiKit.OUTLINE, 12, 3)
	rs.content_margin_left = 20
	rs.content_margin_right = 20
	rs.content_margin_top = 6
	rs.content_margin_bottom = 6
	ribbon.add_theme_stylebox_override("panel", rs)
	ribbon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ribbon.add_child(UiKit.title(L.t("offline.title"), 20))
	col.add_child(ribbon)

	var bed := UiKit.icon("bed", 54)
	bed.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(bed)
	col.add_child(_text(L.t("offline.text", [Fmt.seconds(float(report.get("duration", 0.0)))]), 14))

	var flow := HFlowContainer.new()
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	col.add_child(flow)
	for it in report.get("items", []):
		flow.add_child(_chip(str(it[0]), int(it[1])))

	col.add_child(_text(L.t("offline.inStorage"), 12))
	if not bool(report.get("doubled", false)):
		var pro := Game.premium.has_pro()
		var double := Ads.reward_button(L.t("offline.double.pro") if pro else L.t("offline.double"), "green", 15)
		double.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		double.pressed.connect(_double)
		col.add_child(double)
	var b := UiKit.button(L.t("offline.collect"), "wood", 15, true)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(close)
	col.add_child(b)

	# Появление с лёгким подпрыгиванием
	panel.resized.connect(func() -> void: panel.pivot_offset = panel.size / 2.0)
	panel.scale = Vector2.ONE * 0.85
	modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 1.0, 0.18)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _text(value: String, size: int) -> Label:
	var l := UiKit.label(value, size, UiKit.INK_SOFT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## Награда: иконка ресурса и "+N" (RewardChip).
func _chip(kind: String, n: int) -> PanelContainer:
	var p := PanelContainer.new()
	var s := UiKit.box(Color(1, 1, 1, 0.55), Color(UiKit.OUTLINE, 0.35), 12, 1, false)
	s.content_margin_left = 6
	s.content_margin_right = 10
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	p.add_child(row)
	row.add_child(UiKit.icon(kind, 24))
	row.add_child(UiKit.label("+" + Fmt.n(n), 14))
	return p


## Удвоить добычу: окно закрывается сразу, награда приходит после ролика.
func _double() -> void:
	if _closing:
		return
	close()
	Ads.show_rewarded(func() -> void:
		Game.animals.double_offline(not Game.premium.has_pro())
		Input.vibrate_handheld(20))


func close() -> void:
	if _closing:
		return
	_closing = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(queue_free)
