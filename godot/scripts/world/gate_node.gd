class_name GateNode
extends Node2D
## Ворота на краю локации: закрыты - преграда с табличкой, открыты - путь в соседнюю локацию.

var gate_id := ""
var to := ""
var side := "S"
var cell := 32.0
var is_open := false
var royal := false

var _barrier: Sprite2D
var _sign := Node2D.new()
var _label := Label.new()
var _tag := Label.new()


func setup(place: Dictionary, open: bool, cell_size: float, stone: bool) -> void:
	gate_id = place["id"]
	to = place["to"]
	side = place["side"]
	cell = cell_size
	is_open = open
	royal = gate_id == "meadow_garden"
	position = place["barrier"]
	var vertical := side == "W" or side == "E"
	var name := "gate_v_anim" if vertical else ("gate_stone_anim" if stone else "gate_anim")
	if royal and not vertical:
		name = "gate_gold_anim"
	_barrier = Sprites.make(name)
	if _barrier != null:
		var fs := Vector2(_barrier.texture.get_width() / float(_barrier.hframes), _barrier.texture.get_height() / float(_barrier.vframes))
		_barrier.offset = Sprites.anchor_offset(Vector2(0.5, 0.5) if vertical else Vector2(0.5, 0.3), fs)
		if open:
			_barrier.frame = _barrier.hframes * _barrier.vframes - 1
		if royal and vertical:
			_barrier.modulate = Color(1, 0.85, 0.4)
		add_child(_barrier)
	_sign.position = Vector2(0, -92 if vertical else -60)
	_sign.z_index = 30
	add_child(_sign)
	_label.label_settings = Fx.label_settings(14)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(220, 22)
	_label.position = Vector2(-110, -26)
	_sign.add_child(_label)
	_tag.label_settings = Fx.label_settings(11, Color(1, 0.88, 0.55), 4)
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag.size = Vector2(220, 16)
	_tag.position = Vector2(-110, -6)
	_sign.add_child(_tag)
	refresh_text()


func _ready() -> void:
	# Табличка покачивается (анимация только когда ворота уже на карте)
	var y := _sign.position.y
	var tw := _sign.create_tween().set_loops()
	tw.tween_property(_sign, "position:y", y - 3, 1.3).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_sign, "position:y", y, 1.3).set_trans(Tween.TRANS_SINE)


func refresh_text() -> void:
	_label.text = Locations.name_of(to)
	if is_open:
		_tag.text = ""
	elif royal:
		_tag.text = "👑"
	else:
		var g := WorldGraph.gate(gate_id)
		var lvl: int = WorldGraph.level(g) if not g.is_empty() else int(Locations.spec(to)["level"])
		_tag.text = "🔒 " + L.t("common.lvl", [lvl])


func set_open(open: bool) -> void:
	if open == is_open:
		return
	is_open = open
	refresh_text()
	if _barrier != null and _barrier.hframes > 1:
		var last := _barrier.hframes - 1
		var tw := create_tween()
		var from := 0.0 if open else float(last)
		var dest := float(last) if open else 0.0
		tw.tween_method(func(v: float) -> void: _barrier.frame = int(round(v)), from, dest, 0.08 * last)


## Прямоугольник, через который нельзя пройти, пока ворота закрыты.
var block_rect: Rect2:
	get:
		if side == "W" or side == "E":
			return Rect2(position.x - cell * 0.5, position.y - cell * 2.5, cell, cell * 5)
		return Rect2(position.x - cell * 2.5, position.y - cell * 0.5, cell * 5, cell)


## Герой прошёл за открытые ворота к краю карты.
func passed(p: Vector2) -> bool:
	var b := position
	var wide := cell * 2.6
	match side:
		"N": return p.y < b.y - cell * 0.6 and absf(p.x - b.x) < wide
		"S": return p.y > b.y + cell * 0.6 and absf(p.x - b.x) < wide
		"W": return p.x < b.x - cell * 0.6 and absf(p.y - b.y) < wide
	return p.x > b.x + cell * 0.6 and absf(p.y - b.y) < wide
