class_name GateCard
extends PanelContainer
## Карточка у закрытых ворот (порт GateCard): куда ведут и что нужно, чтобы открыть.
## Показывается через Hud.current.set_prompt("gate", card). Королевские ворота открываются покупкой (этап 6),
## поэтому у них только подпись. Перестраивается после изменений игры (цена, уровень).

var gate_id := ""
var _row := HBoxContainer.new()
var _dirty := true
var _cooldown := 0.0


func _init(id: String) -> void:
	gate_id = id
	var s := UiKit.panel_style(18)
	s.set_content_margin_all(12)
	add_theme_stylebox_override("panel", s)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_row.add_theme_constant_override("separation", 12)
	add_child(_row)
	Game.changed.connect(_on_changed)


func _ready() -> void:
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)


func _on_changed() -> void:
	_dirty = true


func _process(delta: float) -> void:
	_cooldown -= delta
	if _dirty and _cooldown <= 0.0:
		_dirty = false
		_cooldown = 0.25
		_build()


func _build() -> void:
	for c in _row.get_children():
		c.queue_free()
	var gate := WorldGraph.gate(gate_id)
	if gate.is_empty():
		return
	var target := WorldGraph.other(gate, Game.current)
	var pic := GateCard.location_thumb(target, 52.0, 26.0)
	pic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_row.add_child(pic)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row.add_child(col)
	col.add_child(_wrap(L.t("gate.to", [Locations.name_of(target)]), 16, UiKit.INK))
	if gate["royal"]:
		col.add_child(_wrap(L.t("gate.royal"), 12, UiKit.INK_SOFT))
		return
	if str(gate["group"]) != "":
		col.add_child(_wrap(L.t("gate.bundle.short"), 12, UiKit.TONES["orange"][2]))
	var level := WorldGraph.level(gate)
	if Game.level < level:
		col.add_child(_wrap(L.t("common.needLevel", [level]), 12, UiKit.BAD))
	var wm := Game.world_map
	col.add_child(UiKit.cost_view(wm.gate_cost(gate)))
	var b := UiKit.button(L.t("gate.open"), "green", 14, true)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.disabled = not wm.can_open_gate(gate)
	b.pressed.connect(func() -> void:
		if Game.world_map.open_gate(gate_id):
			Input.vibrate_handheld(30))
	col.add_child(b)


func _wrap(text: String, font_size: int, color: Color) -> Label:
	var l := UiKit.label(text, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(160, 0)
	return l


## Квадратная картинка локации с её иконкой посередине (как на схеме мира). outline - тёмная обводка,
## saturation и pic_alpha - насыщенность и прозрачность (закрытая локация - серая и бледная).
static func location_thumb(id: String, side: float, icon_side := 26.0, saturation := 1.0, outline := true,
		pic_alpha := 1.0) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(side, side)
	box.size = Vector2(side, side)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pic := TextureRect.new()
	pic.texture = MiniMap.thumb(id)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	pic.size = Vector2(side, side)
	pic.modulate.a = pic_alpha
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(pic)
	var ic := UiKit.icon(Locations.icon(id), icon_side)
	ic.position = Vector2(side - icon_side, side - icon_side) / 2.0
	ic.size = Vector2(icon_side, icon_side)
	box.add_child(ic)
	if saturation < 1.0:
		pic.material = HousePanel.gray_material(saturation)
		ic.material = HousePanel.gray_material(saturation)
	if outline:
		var ring := Panel.new()
		var s := StyleBoxFlat.new()
		s.draw_center = false
		s.border_color = UiKit.OUTLINE
		s.set_border_width_all(2)
		s.set_corner_radius_all(int(round(side * 12.0 / 58.0)))
		s.anti_aliasing = true
		ring.add_theme_stylebox_override("panel", s)
		ring.size = Vector2(side, side)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(ring)
	return box
