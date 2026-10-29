class_name Joystick
extends Control
## Плавающий джойстик: появляется там, где палец коснулся свободного места экрана.

const RADIUS := 58.0

var vector := Vector2.ZERO
var active := false
var enabled := true

var _origin := Vector2.ZERO
var _knob := Vector2.ZERO
var _touch := -1
var _alpha := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Ловит касания там, где нет кнопок интерфейса (интерфейс лежит слоем выше)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_touch = 0
			_begin(event.position)
		elif _touch != -1:
			end()
		accept_event()
	elif event is InputEventMouseMotion and _touch != -1:
		_move(event.position)
		accept_event()


func _begin(p: Vector2) -> void:
	_origin = p
	_knob = p
	vector = Vector2.ZERO
	active = true
	var tw := create_tween()
	tw.tween_property(self, "_alpha", 1.0, 0.08)
	queue_redraw()
	# Первое касание - обучение пройдено
	if not bool(Game.save.get("tutorialDone", false)):
		Game.save["tutorialDone"] = true
		Game.mark_dirty()


func _move(p: Vector2) -> void:
	var d := p - _origin
	var len := d.length()
	if len > 0.5:
		var clamped := minf(len, RADIUS)
		_knob = _origin + d / len * clamped
		vector = d / len * minf(1.0, len / RADIUS)
	else:
		_knob = _origin
		vector = Vector2.ZERO
	queue_redraw()


func end() -> void:
	_touch = -1
	vector = Vector2.ZERO
	active = false
	var tw := create_tween()
	tw.tween_property(self, "_alpha", 0.0, 0.15)
	tw.tween_callback(queue_redraw)


func _process(_delta: float) -> void:
	if _alpha > 0.0:
		queue_redraw()


func _draw() -> void:
	if _alpha <= 0.01:
		return
	draw_circle(_origin, RADIUS, Color(1, 1, 1, 0.12 * _alpha))
	draw_arc(_origin, RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.45 * _alpha), 2.0, true)
	draw_circle(_knob, 26.0, Color(1, 1, 1, 0.6 * _alpha))
	draw_arc(_knob, 26.0, 0, TAU, 32, Color(1, 1, 1, 0.85 * _alpha), 2.0, true)
