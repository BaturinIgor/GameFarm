class_name GameBar
extends ProgressBar
## Полоска прогресса как GameBar в iOS: тёмная капсула, заливка с градиентом сверху вниз,
## светлый блик, тёмный контур и подпись поверх (дочерний Label, если есть).

## Тон заливки из UiKit.TONES.
var tone := "green":
	set(v):
		tone = v
		queue_redraw()


func _init() -> void:
	show_percentage = false
	min_value = 0.0
	max_value = 1.0
	step = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for s in ["background", "fill"]:
		add_theme_stylebox_override(s, StyleBoxEmpty.new())


func _draw() -> void:
	var h := size.y
	if h <= 0.0 or size.x <= 0.0:
		return
	_fill_capsule(Rect2(Vector2.ZERO, size), Color(UiKit.WOOD_DARK, 0.85), Color(UiKit.WOOD_DARK, 0.85))
	var span := max_value - min_value
	var v := clampf((value - min_value) / span, 0.0, 1.0) if span > 0.0 else 0.0
	if v > 0.0:
		var w := maxf(h, size.x * v)
		var c: Array = UiKit.TONES.get(tone, UiKit.TONES["green"])
		_fill_capsule(Rect2(0, 0, w, h), c[0], c[1])
		# Блик в верхней части заливки
		var bh := maxf(1.0, h * 0.2)
		var inset := h * 0.4
		if w - inset * 2.0 > bh:
			_fill_capsule(Rect2(inset, h * 0.15, w - inset * 2.0, bh), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.35))
	var outline := _capsule_points(Rect2(Vector2(0.75, 0.75), size - Vector2(1.5, 1.5)))
	outline.append(outline[0])
	draw_polyline(outline, UiKit.OUTLINE, 1.5, true)


## Капсула с вертикальным градиентом: цвет вершины зависит от её высоты.
func _fill_capsule(r: Rect2, top: Color, bottom: Color) -> void:
	var pts := _capsule_points(r)
	var colors := PackedColorArray()
	for p in pts:
		var t := clampf((p.y - r.position.y) / maxf(1.0, r.size.y), 0.0, 1.0)
		colors.append(top.lerp(bottom, t))
	draw_polygon(pts, colors)


func _capsule_points(r: Rect2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var rad := minf(r.size.y, r.size.x) / 2.0
	var cy := r.position.y + r.size.y / 2.0
	var right := Vector2(r.end.x - rad, cy)
	var left := Vector2(r.position.x + rad, cy)
	var steps := 10
	for i in steps + 1:
		var a := -PI / 2.0 + PI * float(i) / float(steps)
		pts.append(right + Vector2(cos(a), sin(a)) * rad)
	for i in steps + 1:
		var a := PI / 2.0 + PI * float(i) / float(steps)
		pts.append(left + Vector2(cos(a), sin(a)) * rad)
	return pts
