class_name RingFx
extends Node2D
## Круг-обводка: расходящиеся круги, зона склада.

var color := Color(1, 1, 1, 0.7):
	set(v):
		color = v
		queue_redraw()
var radius := 20.0:
	set(v):
		radius = v
		queue_redraw()
var width := 2.0
var dashed := false
var fill_alpha := 0.0


func _draw() -> void:
	if fill_alpha > 0.0:
		draw_circle(Vector2.ZERO, radius, Color(color, fill_alpha))
	if dashed:
		var steps := 40
		for i in steps:
			if i % 2 == 1:
				continue
			var a0 := TAU * i / steps
			var a1 := TAU * (i + 1) / steps
			draw_arc(Vector2.ZERO, radius, a0, a1, 4, color, width, true)
	else:
		draw_arc(Vector2.ZERO, radius, 0, TAU, 48, color, width, true)
