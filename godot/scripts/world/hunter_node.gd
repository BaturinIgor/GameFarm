class_name HunterNode
extends Node2D
## Стражник у доски заказов (часть buildFarm из GameScene): доска, стражник и табличка "Охота" над ними.
## Позиция узла - точка доски из раскладки (layout.board).

const NPC_FRAMES := 6
const NPC_FPS := 6.0
## Препятствие доски: сдвиг от точки и радиус.
const OBSTACLE_OFFSET := Vector2(22, -8)
const OBSTACLE_RADIUS := 26.0

var _sign := Node2D.new()


func _init() -> void:
	var board := Sprites.make("quest_board", Vector2(22, 0))
	if board != null:
		add_child(board)
	var tex := Sprites.texture("pl_guard")
	if tex != null:
		var npc := AnimSprite.new()
		npc.texture = tex
		npc.centered = false
		npc.hframes = Player.COLS
		npc.vframes = maxi(1, tex.get_height() / 64)
		npc.offset = Sprites.anchor_offset(Sprites.anchor("pl"), Vector2(64, 64))
		npc.scale = Vector2.ONE * Sprites.SCALE
		npc.position = Vector2(-34, 4)
		npc.setup(NPC_FRAMES, NPC_FPS)
		add_child(npc)
	_sign.position = Vector2(0, -92)
	_sign.z_index = 30
	add_child(_sign)
	_build_sign()


func _build_sign() -> void:
	var title := L.t("hunt.title")
	var size := 14
	var settings := Fx.label_settings(size)
	var width := settings.font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var icon_size := 20.0
	var total := width + icon_size + 4.0
	var tex := Sprites.icon("swords")
	if tex != null:
		var ic := Sprite2D.new()
		ic.texture = tex
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.scale = Vector2.ONE * icon_size / float(maxi(1, tex.get_width()))
		ic.position = Vector2(-total / 2.0 + icon_size / 2.0, -14)
		_sign.add_child(ic)
	var label := Label.new()
	label.text = title
	label.label_settings = settings
	label.size = Vector2(width + 8.0, 22)
	label.position = Vector2(-total / 2.0 + icon_size + 4.0 if tex != null else -width / 2.0, -26)
	_sign.add_child(label)


func _ready() -> void:
	# Табличка покачивается
	var y := _sign.position.y
	var tw := _sign.create_tween().set_loops()
	tw.tween_property(_sign, "position:y", y - 3, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_sign, "position:y", y, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
