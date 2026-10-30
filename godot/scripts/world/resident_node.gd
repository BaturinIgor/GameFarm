class_name ResidentNode
extends Node2D
## Житель у дома: персонаж из пака, табличка с именем, над головой "!" (новое задание)
## или "?" (задание можно сдать).

const NPC_FRAMES := 6
const NPC_FPS := 5.0

var id := ""
var _sign := Node2D.new()
var _mark: Label
var _mark_state := ""


func _init(resident: String) -> void:
	id = resident
	var tex := Sprites.texture("pl_" + Residents.sheet(id))
	if tex == null:
		tex = Sprites.texture("pl_merchant")
	if tex != null:
		var npc := AnimSprite.new()
		npc.texture = tex
		npc.centered = false
		npc.hframes = Player.COLS
		npc.vframes = maxi(1, tex.get_height() / 64)
		npc.offset = Sprites.anchor_offset(Sprites.anchor("pl"), Vector2(64, 64))
		npc.scale = Vector2.ONE * Sprites.SCALE
		npc.setup(NPC_FRAMES, NPC_FPS)
		add_child(npc)
	_sign.position = Vector2(0, -96)
	_sign.z_index = 30
	add_child(_sign)
	var title := Residents.name_of(id)
	var size := 13
	var settings := Fx.label_settings(size, Color.WHITE)
	var width := settings.font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var label := Label.new()
	label.text = title
	label.label_settings = settings
	label.size = Vector2(width + 8.0, 20)
	label.position = Vector2(-width / 2.0 - 4.0, -20)
	_sign.add_child(label)
	_mark = Label.new()
	_mark.label_settings = Fx.label_settings(26, Color(1, 0.85, 0.2), 6).duplicate()
	_mark.size = Vector2(30, 34)
	_mark.position = Vector2(-15, -54)
	_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sign.add_child(_mark)


func _ready() -> void:
	var y := _sign.position.y
	var tw := _sign.create_tween().set_loops()
	tw.tween_property(_sign, "position:y", y - 3, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_sign, "position:y", y, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	refresh()


## Значок над головой по состоянию жителя.
func refresh() -> void:
	var s := Game.residents.state(id)
	if s == _mark_state:
		return
	_mark_state = s
	_mark.text = "!" if s == "new" else ("?" if s == "ready" else "")
	_mark.label_settings.font_color = Color(1, 0.85, 0.2) if s == "new" else Color(0.55, 1, 0.45)
