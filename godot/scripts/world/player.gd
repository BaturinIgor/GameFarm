class_name Player
extends Node2D
## Герой: анимированный персонаж из листа pl_<образ> (9 кадров в ряду, клетка 64 пикселя).
## Ряды: 0-2 стоит (вниз, вбок, вверх), 3-5 идёт, 6-8 топор, 9-11 кирка, 12-14 мотыга, 15-17 удочка.

enum Facing { DOWN = 0, SIDE = 1, UP = 2 }

const ROW_FRAMES := [6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 9, 9, 9, 8, 8, 8]
const COLS := 9

var body := Sprite2D.new()
var root := Node2D.new()
var facing := Facing.DOWN
var skin := ""

var _flip := 1.0
var _clock := 0.0
var _action_row := -1
var _action_time := 0.0
var _action_length := 0.0
var _frame_time := 0.06
var _ring := RingFx.new()


func _ready() -> void:
	_ring.radius = 19.0
	_ring.scale = Vector2(1, 0.4)
	_ring.color = Color(1, 1, 1, 0.55)
	_ring.fill_alpha = 0.08
	add_child(_ring)
	add_child(root)
	root.add_child(body)
	body.centered = false
	body.scale = Vector2.ONE * Sprites.SCALE
	set_skin(str(Game.save.get("skin", "farmer")))


func set_skin(name: String) -> void:
	if name == skin:
		return
	var tex := Sprites.texture("pl_" + name)
	if tex == null:
		tex = Sprites.texture("pl_farmer")
	if tex == null:
		return
	skin = name
	body.texture = tex
	body.hframes = COLS
	body.vframes = maxi(1, tex.get_height() / 64)
	body.offset = Sprites.anchor_offset(Sprites.anchor("pl"), Vector2(64, 64))
	_show(0, 0)
	root.scale = Vector2.ONE * 0.6
	create_tween().tween_property(root, "scale", Vector2.ONE, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _show(row: int, index: int) -> void:
	if body.texture == null:
		return
	var n: int = ROW_FRAMES[clampi(row, 0, ROW_FRAMES.size() - 1)]
	body.frame = mini(row * COLS + (index % n), body.hframes * body.vframes - 1)
	body.flip_h = facing == Facing.SIDE and _flip < 0.0


func _face(dir: Vector2) -> void:
	if absf(dir.x) > absf(dir.y) * 0.85:
		facing = Facing.SIDE
		_flip = 1.0 if dir.x >= 0.0 else -1.0
	else:
		# В Godot ось y смотрит вниз: отрицательная скорость - движение вверх
		facing = Facing.UP if dir.y < 0.0 else Facing.DOWN


var busy: bool:
	get: return _action_time < _action_length


## speed_ratio от 0 до 1: насколько быстро бежит персонаж.
func animate(velocity: Vector2, speed_ratio: float, dt: float) -> void:
	if _action_time < _action_length:
		_action_time += dt
		if speed_ratio > 0.35:
			_action_length = 0.0
		else:
			var n: int = ROW_FRAMES[_action_row]
			_show(_action_row, mini(n - 1, int(_action_time / _frame_time)))
			return
	if speed_ratio > 0.05:
		if velocity.length() > 6.0:
			_face(velocity)
		_clock += dt * (8.0 + 6.0 * speed_ratio)
		_show(3 + facing, int(_clock))
	else:
		_clock += dt * 6.0
		_show(facing, int(_clock))


## Замах инструментом в сторону цели.
func swing(tool: String, target: Vector2, interval := 0.55) -> void:
	var d := target - position
	_face(d)
	var duration := clampf(interval * 0.8, 0.24, 0.42)
	var base := 6
	match tool:
		"pickaxe": base = 9
		"hand": base = 12
		"rod":
			base = 15
			duration = maxf(duration, 0.4)
	_action_row = base + facing
	_frame_time = duration / float(ROW_FRAMES[_action_row])
	_action_time = 0.0
	_action_length = duration
	_show(_action_row, 0)


func look(target: Vector2) -> void:
	_face(target - position)
	_action_length = 0.0
	_show(facing, 0)


func celebrate() -> void:
	var tw := create_tween()
	for i in 2:
		tw.tween_property(root, "position:y", -18.0, 0.15).set_ease(Tween.EASE_OUT)
		tw.tween_property(root, "position:y", 0.0, 0.15).set_ease(Tween.EASE_IN)
