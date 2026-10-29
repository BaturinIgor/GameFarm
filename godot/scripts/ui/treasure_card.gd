class_name TreasureCard
extends Control
## Награда за клад (порт TreasureCard): монеты и ресурсы. Показывается через Hud.show_overlay
## и сама исчезает через пару секунд.

## Сколько держится на экране после появления.
const SHOW_TIME := 2.6

var _treasure: Dictionary
var _title_key := "treasure.title"
var _stack := VBoxContainer.new()


## treasure - результат QuestSystem.open_treasure(): {coins, items: [[вид, n], ...]}.
## title_key - заголовок ленты (королевский сундук сада - "garden.chestTitle").
func _init(treasure: Dictionary, title_key := "treasure.title") -> void:
	_treasure = treasure
	_title_key = title_key


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Лента заголовка заходит на верх плашки
	_stack.add_theme_constant_override("separation", -16)
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.anchor_left = 0.5
	_stack.anchor_right = 0.5
	_stack.offset_top = UiKit.safe_insets(get_viewport())["top"] + 180.0
	_stack.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_stack)

	var ribbon := PanelContainer.new()
	var rs := UiKit.box(UiKit.TONES["gold"][1], UiKit.OUTLINE, 12, 3, false)
	rs.content_margin_left = 16
	rs.content_margin_right = 16
	rs.content_margin_top = 4
	rs.content_margin_bottom = 4
	ribbon.add_theme_stylebox_override("panel", rs)
	ribbon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ribbon.z_index = 1
	var title := QuestsPanel.with_icons(L.t(_title_key), 17, Color.WHITE, 6)
	title.alignment = BoxContainer.ALIGNMENT_CENTER
	ribbon.add_child(title)
	_stack.add_child(ribbon)

	var panel := PanelContainer.new()
	var ps := UiKit.box(UiKit.PARCHMENT_LIGHT, UiKit.GOLD, 18, 3)
	ps.content_margin_left = 20
	ps.content_margin_right = 20
	ps.content_margin_top = 26
	ps.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", ps)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	row.add_child(_amount("coins", int(_treasure.get("coins", 0)), 22.0))
	for it in _treasure.get("items", []):
		row.add_child(_amount(str(it[0]), int(it[1]), 24.0))

	_stack.modulate.a = 0.0
	_stack.scale = Vector2.ONE * 0.6
	_appear.call_deferred()


func _amount(icon_name: String, n: int, icon_size: float) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := UiKit.icon(icon_name, icon_size)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	h.add_child(UiKit.label("+" + Fmt.n(n), 17))
	return h


func _appear() -> void:
	_stack.pivot_offset = _stack.size / 2.0
	var tw := create_tween()
	tw.tween_property(_stack, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(_stack, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(SHOW_TIME - 0.4)
	tw.tween_property(_stack, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_OUT)
	tw.tween_callback(queue_free)
