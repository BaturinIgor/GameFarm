class_name TraderNode
extends Node2D
## Торговец у прилавка (порт TraderNode): лавка у дома или бродячий с фиолетовым навесом,
## над ними покачивается табличка с названием.

## Кадров стойки в первом ряду листа персонажа и их скорость.
const NPC_FRAMES := 6
const NPC_FPS := 6.0

## "stall" или "wanderer".
var kind := "stall"
var _title := ""
var _icon := ""
var _sign := Node2D.new()


func _init(trader_kind: String, title: String, icon: String) -> void:
	kind = trader_kind
	_title = title
	_icon = icon
	var stall := Sprites.make("stall" if kind == "stall" else "stall_purple")
	if stall != null:
		add_child(stall)
	var tex := Sprites.texture("pl_merchant" if kind == "stall" else "pl_wanderer")
	if tex != null:
		var npc := AnimSprite.new()
		npc.texture = tex
		npc.centered = false
		npc.hframes = Player.COLS
		npc.vframes = maxi(1, tex.get_height() / 64)
		npc.offset = Sprites.anchor_offset(Sprites.anchor("pl"), Vector2(64, 64))
		npc.scale = Vector2.ONE * Sprites.SCALE
		npc.position = Vector2(-58, 4)
		npc.setup(NPC_FRAMES, NPC_FPS)
		add_child(npc)
	_sign.position = Vector2(0, -112)
	_sign.z_index = 30
	add_child(_sign)
	_build_sign()


func _build_sign() -> void:
	var size := 14
	var color := Color(1, 0.88, 0.55) if kind == "wanderer" else Color.WHITE
	var settings := Fx.label_settings(size, color)
	var width := settings.font.get_string_size(_title, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var icon_size := 20.0
	var total := width + icon_size + 4.0
	var tex := Sprites.icon(_icon)
	if tex != null:
		var ic := Sprite2D.new()
		ic.texture = tex
		ic.scale = Vector2.ONE * icon_size / float(maxi(1, tex.get_width()))
		ic.position = Vector2(-total / 2.0 + icon_size / 2.0, -14)
		_sign.add_child(ic)
	var label := Label.new()
	label.text = _title
	label.label_settings = settings
	label.size = Vector2(width + 8.0, 22)
	label.position = Vector2(-total / 2.0 + icon_size + 4.0 if tex != null else -width / 2.0, -26)
	_sign.add_child(label)


func _ready() -> void:
	# Табличка покачивается
	var y := _sign.position.y
	var tw := _sign.create_tween().set_loops()
	tw.tween_property(_sign, "position:y", y - 3, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_sign, "position:y", y, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Появляется из точки (бродячий торговец).
func pop_in() -> void:
	scale = Vector2.ONE * 0.1
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.35)


## Уходит: тает и уменьшается, потом удаляется.
func vanish() -> void:
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_property(self, "scale", Vector2.ONE * 0.3, 0.4)
	tw.chain().tween_callback(queue_free)
