class_name ConsumableBar
extends HBoxContainer
## Кнопки расходников в бою слева от зелья: эликсиры и бомба, которые есть у героя.
## Видны там же, где зелье: рядом монстры или идёт забег. Действующий эликсир - кольцо оставшегося времени.

const SIDE := 46.0

var _buttons: Dictionary = {}
var _shown := ""
var _tick := 0.0


func _init() -> void:
	add_theme_constant_override("separation", 6)
	alignment = BoxContainer.ALIGNMENT_END
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.1
	var c := Game.combat
	var show := c.in_combat or Game.dungeons.in_dungeon()
	var ids: Array = []
	if show:
		for id in Consumables.IDS:
			if Consumables.usable(id) and c.consumable_count(id) > 0:
				ids.append(id)
	visible = not ids.is_empty()
	var key := ",".join(PackedStringArray(ids))
	if key != _shown:
		_shown = key
		for b in get_children():
			b.queue_free()
		_buttons.clear()
		for id in ids:
			var b := ItemButton.new(id)
			_buttons[id] = b
			add_child(b)
	for id in _buttons:
		(_buttons[id] as ItemButton).refresh()


class ItemButton extends Button:
	var id := ""
	var _count: Label
	var _left := 0.0

	func _init(item: String) -> void:
		id = item
		custom_minimum_size = Vector2(SIDE, SIDE)
		focus_mode = Control.FOCUS_NONE
		var tone: Array = UiKit.TONES[str(Consumables.spec(id).get("tone", "wood"))]
		for state in ["normal", "hover", "pressed", "disabled"]:
			var s := UiKit.box(tone[2].lerp(tone[1], 0.5) if state == "pressed" else tone[1], UiKit.OUTLINE,
				int(SIDE / 2.0), 2, false)
			s.set_content_margin_all(0)
			s.shadow_color = Color(UiKit.OUTLINE, 0.5)
			s.shadow_offset = Vector2(0, 3)
			s.shadow_size = 1
			add_theme_stylebox_override(state, s)
		add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var ic := Consumables.icon(id, 30)
		ic.position = Vector2(SIDE - 30.0, SIDE - 30.0) / 2.0
		add_child(ic)
		var badge := PanelContainer.new()
		var bs := UiKit.box(Color(UiKit.OUTLINE, 0.6), Color(0, 0, 0, 0), 8, 0, false)
		bs.content_margin_left = 4
		bs.content_margin_right = 4
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
		_count = UiKit.title("0", 11)
		_count.label_settings.outline_size = 4
		badge.add_child(_count)
		pressed.connect(func() -> void:
			if Game.combat.use_consumable(id):
				Input.vibrate_handheld(25)
				var tw := create_tween()
				tw.tween_property(self, "scale", Vector2.ONE * 1.15, 0.06)
				tw.tween_property(self, "scale", Vector2.ONE, 0.12))
		resized.connect(func() -> void: pivot_offset = size / 2.0)

	func refresh() -> void:
		_count.text = str(Game.combat.consumable_count(id))
		var left := Game.combat.buff_left(id)
		if absf(left - _left) > 0.05:
			_left = left
			queue_redraw()

	func _draw() -> void:
		if _left <= 0.0 or not Consumables.is_elixir(id):
			return
		# Кольцо: сколько ещё действует эликсир
		var part := clampf(_left / float(Consumables.spec(id)["duration"]), 0.0, 1.0)
		var c := size / 2.0
		draw_arc(c, SIDE / 2.0 + 3.0, -PI / 2.0, -PI / 2.0 + TAU * part, 40, Color("fff3c4"), 3.0, true)
