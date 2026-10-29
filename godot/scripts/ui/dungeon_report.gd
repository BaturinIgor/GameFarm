class_name DungeonReport
extends Control
## Итог забега после выхода из подземелья (порт DungeonReportOverlay): этаж пройден или нет, награды,
## новое оружие и кнопка сразу в бой: следующий этаж после победы или ещё раз этот же.
## Показ: DungeonReport.present_pending() - когда в Game.dungeons.report есть итог и нет заставки уровня.

static var current: DungeonReport

var report: Dictionary = {}
var _closing := false


## Показать итог, если он есть и ещё не на экране (после заставки нового уровня).
static func present_pending() -> void:
	var r = Game.dungeons.report
	if r == null or Hud.current == null:
		return
	if current != null and is_instance_valid(current):
		return
	if LevelUpOverlay.current != null and is_instance_valid(LevelUpOverlay.current):
		return
	var overlay := DungeonReport.new(r)
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
	var won: bool = report.get("won", false)
	var id: String = report.get("dungeon", "slimeCaves")
	var floor_n := int(report.get("floor", 1))
	var dim := ColorRect.new()
	dim.color = UiKit.DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			close())
	add_child(dim)
	if won:
		var confetti := LevelUpOverlay.Confetti.new()
		confetti.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(confetti)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	var style := UiKit.panel_style(22)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 10
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(minf(340.0, get_viewport_rect().size.x - 40.0), 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	# Лента с названием над верхним краем панели
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(holder)
	var ribbon := LevelUpOverlay.Ribbon.new()
	ribbon.tone = UiKit.TONES["gold" if won else "red"]
	ribbon.label.label_settings.font_size = 18
	ribbon.label.label_settings.outline_color = ribbon.tone[2]
	ribbon.anchor_left = 0.5
	ribbon.anchor_right = 0.5
	ribbon.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ribbon.offset_top = -30
	ribbon.set_text(Dungeons.name_of(id))
	holder.add_child(ribbon)

	var boss := TextureRect.new()
	boss.texture = Monsters.icon(Dungeons.boss(id))
	boss.custom_minimum_size = Vector2(64, 64)
	boss.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	boss.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	boss.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	boss.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	boss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := MarginContainer.new()
	top.add_theme_constant_override("margin_top", 16)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(boss)
	col.add_child(top)
	var head := UiKit.label(L.t("dungeon.report.won", [floor_n]) if won else L.t("dungeon.report.lost", [floor_n]), 18)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(head)
	if report.get("first_clear", false):
		var first := UiKit.label(L.t("dungeon.report.first"), 13, UiKit.GOOD)
		first.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(first)

	var rewards := HBoxContainer.new()
	rewards.alignment = BoxContainer.ALIGNMENT_CENTER
	rewards.add_theme_constant_override("separation", 14)
	col.add_child(rewards)
	rewards.add_child(_reward(UiKit.icon("coin", 22), "+" + Fmt.n(int(report.get("coins", 0)))))
	rewards.add_child(_reward(DungeonPanel.essence_icon(22), "+%d" % int(report.get("essence", 0))))
	if int(report.get("potions", 0)) > 0:
		rewards.add_child(_reward(UiKit.icon("potion", 22), "+%d" % int(report["potions"])))
	if int(report.get("maps", 0)) > 0:
		rewards.add_child(_reward(UiKit.icon("tmap", 22), "+%d" % int(report["maps"])))

	var weapon := str(report.get("weapon", ""))
	if weapon != "":
		var wbox := PanelContainer.new()
		var ws := UiKit.box(UiKit.PARCHMENT_LIGHT, Color(UiKit.WOOD_DARK, 0.45), 12, 2, false)
		ws.set_content_margin_all(10)
		wbox.add_theme_stylebox_override("panel", ws)
		wbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(wbox)
		var wrow := HBoxContainer.new()
		wrow.add_theme_constant_override("separation", 8)
		wbox.add_child(wrow)
		var sword := UiKit.icon("sword", 30)
		sword.modulate = Weapons.color(weapon)
		sword.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		wrow.add_child(sword)
		var wcol := VBoxContainer.new()
		wcol.add_theme_constant_override("separation", 2)
		wrow.add_child(wcol)
		wcol.add_child(UiKit.label(L.t("dungeon.report.weapon", [Weapons.name_of(weapon)]), 14))
		wcol.add_child(UiKit.label(Weapons.effect_text(weapon), 11, UiKit.GOOD))

	# Сразу в бой: следующий этаж после победы или ещё раз этот же
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	col.add_child(buttons)
	var next := floor_n + 1
	var d := Game.dungeons
	if won and next <= Dungeons.FLOORS and d.can_enter(id, next):
		_button(buttons, L.t("dungeon.floorN", [next]), "green", func() -> void:
			close()
			Game.dungeons.start_dungeon(id, next))
	elif d.can_enter(id, floor_n):
		_button(buttons, L.t("dungeon.retry"), "orange", func() -> void:
			close()
			Game.dungeons.start_dungeon(id, floor_n))
	_button(buttons, L.t("common.great"), "wood", close)

	# Появление с лёгким подпрыгиванием
	panel.resized.connect(func() -> void: panel.pivot_offset = panel.size / 2.0)
	panel.scale = Vector2.ONE * 0.85
	modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 1.0, 0.18)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _reward(icon: Control, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	row.add_child(UiKit.label(text, 16))
	return row


func _button(parent: Control, text: String, tone: String, action: Callable) -> void:
	var b := UiKit.button(text, tone, 14, true)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(action)
	parent.add_child(b)


func close() -> void:
	if _closing:
		return
	_closing = true
	if Game.dungeons.report == report:
		Game.dungeons.report = null
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(queue_free)
