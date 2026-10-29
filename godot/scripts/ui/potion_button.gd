class_name PotionButton
extends Button
## Кнопка зелья лечения в бою (порт PotionButton): видна, когда есть зелья и рядом монстры или идёт забег.
## Пока зелье "остывает" - полупрозрачная; при полном здоровье не нажимается.

const SIDE := 52.0

var _count: Label
var _tick := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(SIDE, SIDE)
	focus_mode = Control.FOCUS_NONE
	var red: Array = UiKit.TONES["red"]
	for state in ["normal", "hover", "pressed", "disabled"]:
		var s := UiKit.box(red[2].lerp(red[1], 0.5) if state == "pressed" else red[1], UiKit.OUTLINE, int(SIDE / 2.0), 2, false)
		s.set_content_margin_all(0)
		s.shadow_color = Color(UiKit.OUTLINE, 0.5)
		s.shadow_offset = Vector2(0, 3)
		s.shadow_size = 1
		add_theme_stylebox_override(state, s)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var ic := UiKit.icon("heart_plus", 34)
	ic.position = Vector2(SIDE - 34.0, SIDE - 34.0) / 2.0
	add_child(ic)

	var badge := PanelContainer.new()
	var bs := UiKit.box(Color(UiKit.OUTLINE, 0.6), Color(0, 0, 0, 0), 8, 0, false)
	bs.content_margin_left = 5
	bs.content_margin_right = 5
	bs.content_margin_top = 0
	bs.content_margin_bottom = 0
	badge.add_theme_stylebox_override("panel", bs)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge.grow_vertical = Control.GROW_DIRECTION_BEGIN
	badge.offset_left = 4
	badge.offset_right = 4
	badge.offset_top = 4
	badge.offset_bottom = 4
	add_child(badge)
	_count = UiKit.title("0", 12)
	_count.label_settings.outline_size = 4
	badge.add_child(_count)

	pressed.connect(func() -> void:
		Game.combat.drink_potion()
		Input.vibrate_handheld(25))
	visible = false


func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.1
	var c := Game.combat
	var n := c.potions()
	visible = n > 0 and (c.in_combat or Game.dungeons.in_dungeon())
	if not visible:
		return
	_count.text = str(n)
	var can_drink := c.potion_ready()
	modulate.a = 1.0 if can_drink else 0.5
	disabled = not can_drink or c.hp_fraction() >= 0.999
