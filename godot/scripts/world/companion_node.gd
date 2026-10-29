class_name CompanionNode
extends Node2D
## Зверь рядом с героем (и в загоне): ходит с разгоном, подпрыгивает, помощник бьёт по ресурсам.
## Пробуждение даёт ауру, редкая окраска перекрашивает зверя.

var animal := ""
## Точка добычи, которую сейчас бьёт помощник.
var target: ResourceSpot
var hit_timer := 0.0
var retarget_timer := 0.0

var _art := Node2D.new()      ## Сдвиги рывка и прыжка радости
var _body: Sprite2D
var _pixel: AnimalSheet.Pixel
var _aura: Sprite2D
var _aura_alpha := 0.0
var _look_key := ""
var _phase := randf_range(0.0, 6.0)
var _velocity := Vector2.ZERO
var _time := randf() * 10.0
var _fx_tween: Tween


func _init(id: String) -> void:
	animal = id
	var sheet := AnimalSheet.of(id)
	if sheet != null:
		_pixel = AnimalSheet.Pixel.new(sheet)
		_body = _pixel.node
	else:
		# Спрайта нет: лапка с тенью
		var shadow := Sprite2D.new()
		shadow.texture = Fx.glow_texture()
		shadow.modulate = Color(0, 0, 0, 0.24)
		shadow.scale = Vector2(24.0, 9.0) / 64.0
		add_child(shadow)
		_body = Sprite2D.new()
		_body.texture = Sprites.icon("paw")
		_body.centered = false
		_body.scale = Vector2.ONE * Sprites.SCALE
		if _body.texture != null:
			_body.offset = Sprites.anchor_offset(Vector2(0.5, 0.1), _body.texture.get_size())
	add_child(_art)
	_art.add_child(_body)


var can_swim: bool:
	get: return _pixel != null and _pixel.can_swim


func set_swimming(on: bool) -> void:
	if _pixel == null or _pixel.swimming == on:
		return
	_pixel.swimming = on


func set_look(awaken: int, shiny: bool) -> void:
	var key := "%d|%s" % [awaken, shiny]
	if key == _look_key:
		return
	_look_key = key
	if _aura != null:
		_aura.queue_free()
		_aura = null
	if awaken > 0:
		_aura_alpha = 0.35 + 0.1 * float(awaken)
		_aura = Fx.glow(Animals.awaken_color(awaken), 64.0 + float(awaken) * 10.0, 12.0, _aura_alpha)
		_aura.show_behind_parent = true
		add_child(_aura)
		move_child(_aura, 0)
	_body.material = AnimalSheet.shiny_material() if shiny else null


func _process(delta: float) -> void:
	_time += delta
	if _aura != null:
		# Аура мягко дышит
		_aura.modulate.a = _aura_alpha * (0.75 + 0.25 * sin(_time * 2.2))


## Плавно двигается к точке с разгоном и подпрыгивает при ходьбе.
func move_toward_point(point: Vector2, dt: float, speed: float, stop_at := 8.0) -> void:
	var d_vec := point - position
	var d := d_vec.length()
	var desired := Vector2.ZERO
	if d > stop_at:
		var want := minf(speed * minf(1.6, maxf(0.5, d / 90.0)), (d - stop_at) / maxf(dt, 0.001))
		desired = d_vec / d * want
	var k := minf(1.0, dt * 9.0)
	_velocity += (desired - _velocity) * k
	position += _velocity * dt
	var moving := _velocity.length()
	var flies := _pixel != null and _pixel.sheet.flies
	if _pixel != null and _pixel.swimming:
		_body.position.y = 0.0
	elif flies:
		_phase += dt * 4.0
		_body.position.y = -(10.0 + sin(_phase) * 5.0)
	elif moving > 12.0:
		_phase += dt * 15.0
		_body.position.y = -absf(sin(_phase)) * (6.0 if _pixel == null else 1.0)
		if _pixel == null and absf(_velocity.x) > 6.0:
			_body.scale.x = (-1.0 if _velocity.x > 0.0 else 1.0) * Sprites.SCALE
	else:
		_body.position.y += (0.0 - _body.position.y) * 0.3
	if _pixel != null:
		_pixel.update(_velocity, dt)


## Рывок к цели при ударе.
func attack(point: Vector2) -> void:
	var dx := point.x - position.x
	if _pixel != null:
		_pixel.look(dx)
	elif absf(dx) > 2.0:
		_body.scale.x = (-1.0 if dx > 0.0 else 1.0) * Sprites.SCALE
	if not is_inside_tree():
		return
	var lunge := (point - position) * 0.18
	_restart_tween()
	_fx_tween.tween_property(_art, "position", lunge, 0.07)
	_fx_tween.tween_property(_art, "position", Vector2.ZERO, 0.1)


## Прыжок радости: добыл ресурс или принёс продукт.
func cheer() -> void:
	if not is_inside_tree():
		return
	_restart_tween()
	_fx_tween.tween_property(_art, "position", Vector2(0, -10), 0.1)
	_fx_tween.tween_property(_art, "position", Vector2.ZERO, 0.12)


## Появление: из точки в полный рост.
func pop_in() -> void:
	scale = Vector2.ONE * 0.2
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT)


func _restart_tween() -> void:
	if _fx_tween != null and _fx_tween.is_valid():
		_fx_tween.kill()
	_art.position = Vector2.ZERO
	_fx_tween = create_tween()
