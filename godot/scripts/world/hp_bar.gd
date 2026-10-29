class_name HPBar
extends Node2D
## Полоска прочности над точкой добычи или здоровья над монстром.

var fixed_color = null   ## Color или null - цвет по доле
var _fraction := 1.0
var _shown := 1.0


func set_fraction(f: float) -> void:
	_fraction = clampf(f, 0.0, 1.0)
	var tw := create_tween()
	tw.tween_property(self, "_shown", _fraction, 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_callback(queue_redraw)
	queue_redraw()


func reset() -> void:
	_fraction = 1.0
	_shown = 1.0
	queue_redraw()


func _process(_delta: float) -> void:
	if modulate.a > 0.01:
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-20, -4, 40, 8), Color(0, 0, 0, 0.55))
	var f := _shown
	var c: Color = fixed_color if fixed_color != null else Color(1.0 - f * 0.7, 0.35 + f * 0.55, 0.25)
	draw_rect(Rect2(-18, -2, 36.0 * maxf(0.02, f), 4), c)
	draw_rect(Rect2(-18, -2, 36.0 * maxf(0.02, f), 1.5), Color(1, 1, 1, 0.35))
