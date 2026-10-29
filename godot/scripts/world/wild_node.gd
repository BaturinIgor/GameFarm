class_name WildNode
extends Node2D
## Дикий зверь: бродит у места появления со знаком вопроса над головой, пока его не приручат.
## Утки и лебеди уходят в воду, если к ним подойти.

const BUBBLE_COLOR := Color(0.95, 0.4, 0.6)
const HOP_TIME := 0.38

var animal := ""
var life := 160.0
## Утка или лебедь уже ушли в воду.
var diving := false
## Редкая окраска.
var shiny := false
## Можно ли выбрать эту точку целью (точка, на воде ли): сцена знает, где суша и где вода.
var allows: Callable = func(_p: Vector2, _water: bool) -> bool: return true
## Сцена показывает брызги, когда зверь плюхается в воду.
var on_splash: Callable

var _home := Vector2.ZERO
var _goal := Vector2.ZERO
var _wait := 1.0
var _move_speed := 40.0
## Прыжок в воду: сколько осталось.
var _hop := 0.0
var _body: Sprite2D
var _pixel: AnimalSheet.Pixel
var _bubble := Node2D.new()
var _bubble_y := -56.0
var _glows: Array = []      ## [sprite, alpha]
var _time := randf() * 10.0


func _init(id: String, at: Vector2, life_time: float) -> void:
	animal = id
	life = life_time
	position = at
	_home = at
	_goal = at
	_add_glow(Color(1, 0.85, 0.4), 90.0, 18.0, 0.4)
	var sheet := AnimalSheet.of(id)
	if sheet != null:
		_pixel = AnimalSheet.Pixel.new(sheet)
		_body = _pixel.node
	else:
		var shadow := Sprite2D.new()
		shadow.texture = Fx.glow_texture()
		shadow.modulate = Color(0, 0, 0, 0.24)
		shadow.scale = Vector2(28.0, 10.0) / 64.0
		add_child(shadow)
		_body = Sprite2D.new()
		_body.texture = Sprites.icon("paw")
		_body.centered = false
		_body.scale = Vector2.ONE * Sprites.SCALE * 1.2
		if _body.texture != null:
			_body.offset = Sprites.anchor_offset(Vector2(0.5, 0.1), _body.texture.get_size())
		_bubble_y = -54.0
	add_child(_body)

	# Розовый кружок со знаком вопроса
	_bubble.position = Vector2(0, _bubble_y)
	_bubble.z_index = 5
	_bubble.draw.connect(_draw_bubble)
	add_child(_bubble)
	var mark := Label.new()
	mark.text = "?"
	mark.label_settings = Fx.label_settings(18, Color.WHITE, 4)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.size = Vector2(24, 24)
	mark.position = Vector2(-12, -13)
	_bubble.add_child(mark)


func _ready() -> void:
	scale = Vector2.ONE * 0.1
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.35).set_ease(Tween.EASE_OUT)


func _draw_bubble() -> void:
	_bubble.draw_circle(Vector2.ZERO, 12.0, BUBBLE_COLOR)
	_bubble.draw_arc(Vector2.ZERO, 12.0, 0.0, TAU, 32, Color(Fx.OUTLINE, 0.9), 2.0, true)


func _add_glow(color: Color, size: float, y: float, alpha: float) -> void:
	var g := Fx.glow(color, size, y, alpha)
	add_child(g)
	move_child(g, 0)
	_glows.append([g, alpha])


func _process(delta: float) -> void:
	_time += delta
	# Кружок качается, свечение дышит
	_bubble.position.y = _bubble_y - 2.0 - 2.0 * sin(_time * PI / 0.5)
	for item in _glows:
		var g: Sprite2D = item[0]
		g.modulate.a = float(item[1]) * (0.75 + 0.25 * sin(_time * 2.0))


func make_shiny() -> void:
	shiny = true
	_body.material = AnimalSheet.shiny_material()
	_add_glow(Color(1, 0.6, 1), 110.0, 16.0, 0.5)


var can_swim: bool:
	get: return _pixel != null and _pixel.can_swim


func set_swimming(on: bool) -> void:
	if _pixel == null or _pixel.swimming == on:
		return
	if on and diving and _hop <= 0.0:
		_hop = HOP_TIME
		if on_splash.is_valid():
			on_splash.call(position)
	_pixel.swimming = on


## Убегает в воду, если к нему подходят (утки и лебеди).
func dive(point: Vector2) -> void:
	if diving:
		return
	diving = true
	_home = point
	_goal = point
	_move_speed = 115.0
	_wait = 0.8


func wander(dt: float) -> void:
	life -= dt
	_wait -= dt
	var d := position.distance_to(_goal)
	var v := (_goal - position) / d * _move_speed if d >= 4.0 else Vector2.ZERO
	if _pixel != null:
		_pixel.update(v, dt)
	var lift := 0.0
	if _hop > 0.0:
		_hop -= dt
		lift = sin(PI * maxf(0.0, _hop) / HOP_TIME) * 16.0
	if d < 4.0:
		_body.position.y += (-lift - _body.position.y) * 0.3
		_move_speed = 40.0
		if _wait <= 0.0:
			# Новая цель рядом с домом: на воде для нырнувших, на суше для остальных.
			for _i in 6:
				var a := randf() * TAU
				var r := randf_range(20.0, 55.0 if diving else 90.0)
				var p := _home + Vector2(cos(a), sin(a)) * r
				if allows.call(p, diving):
					_goal = p
					break
			_wait = randf_range(1.5, 3.5)
	else:
		var step := minf(d, _move_speed * dt)
		position += (_goal - position) / d * step
		_body.position.y = -absf(sin(life * 12.0)) * (4.0 if _pixel == null else 1.0) - lift
		if _pixel == null and absf(_goal.x - position.x) > 1.0:
			_body.scale.x = (-1.0 if _goal.x > position.x else 1.0) * Sprites.SCALE * 1.2


## Уходит: тает и уменьшается.
func leave() -> void:
	if not is_inside_tree():
		queue_free()
		return
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_property(self, "scale", Vector2.ONE * 0.4, 0.4)
	tw.chain().tween_callback(queue_free)
