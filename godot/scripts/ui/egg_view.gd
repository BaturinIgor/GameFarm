class_name EggView
extends Control
## Яйцо, нарисованное кодом: цвет скорлупы - редкость (радужное переливается), пятнышки, трещины.
## cracks 0..1 - насколько треснуло (сцена вылупления), wobble - покачивание.

var rarity := "green"
var cracks := 0.0
var glow := 0.0
var _t := 0.0


static func icon(r: String, side := 22.0) -> EggView:
	var e := EggView.new()
	e.rarity = r
	e.custom_minimum_size = Vector2(side, side)
	e.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return e


func _process(delta: float) -> void:
	if rarity == "rainbow" or glow > 0.0:
		_t += delta
		queue_redraw()


func _draw() -> void:
	draw_egg(self, Rect2(Vector2.ZERO, size), rarity, _t, cracks, glow)


static func shell_color(r: String, t := 0.0) -> Color:
	return Chests.color(r, t).lerp(Color.WHITE, 0.15)


## Яйцо в прямоугольнике r (вписано по высоте).
static func draw_egg(ci: CanvasItem, r: Rect2, rar: String, t := 0.0, cracks := 0.0, glow := 0.0) -> void:
	var h := r.size.y * 0.94
	var w := h * 0.76
	var c := r.get_center() + Vector2(0, r.size.y * 0.02)
	if glow > 0.0:
		ci.draw_circle(c, h * 0.62, Color(shell_color(rar, t), 0.25 * glow))
		ci.draw_circle(c, h * 0.5, Color(shell_color(rar, t), 0.3 * glow))
	var pts := _egg_points(c, w, h, 28)
	var outline := _egg_points(c, w + 3.0, h + 3.0, 28)
	ci.draw_colored_polygon(outline, UiKit.OUTLINE)
	var col := shell_color(rar, t)
	ci.draw_colored_polygon(pts, col)
	# Тень снизу и блик сверху
	var shade := _egg_points(c + Vector2(w * 0.06, h * 0.08), w * 0.86, h * 0.8, 20)
	ci.draw_colored_polygon(shade, col.darkened(0.12))
	ci.draw_colored_polygon(_egg_points(c + Vector2(-w * 0.05, -h * 0.02), w * 0.8, h * 0.82, 20), col)
	ci.draw_circle(c + Vector2(-w * 0.2, -h * 0.22), w * 0.1, Color(1, 1, 1, 0.55))
	# Пятнышки
	var spot := col.darkened(0.25) if rar != "rainbow" else Chests.rainbow_color(t + 0.5)
	ci.draw_circle(c + Vector2(w * 0.18, -h * 0.05), w * 0.09, spot)
	ci.draw_circle(c + Vector2(-w * 0.12, h * 0.18), w * 0.07, spot)
	ci.draw_circle(c + Vector2(w * 0.05, h * 0.3), w * 0.05, spot)
	if cracks > 0.0:
		var lw := maxf(1.5, w * 0.05)
		var zig := PackedVector2Array()
		var n := 7
		var shown := int(ceil(float(n) * clampf(cracks, 0.0, 1.0)))
		for i in shown + 1:
			var x := -w * 0.45 + w * 0.9 * float(i) / float(n)
			var y := -h * 0.02 + (h * 0.07 if i % 2 == 0 else -h * 0.07)
			zig.append(c + Vector2(x, y))
		if zig.size() >= 2:
			ci.draw_polyline(zig, UiKit.OUTLINE, lw)
		if cracks > 0.6:
			ci.draw_line(c + Vector2(w * 0.1, -h * 0.05), c + Vector2(w * 0.18, -h * 0.25), UiKit.OUTLINE, lw)


static func _egg_points(c: Vector2, w: float, h: float, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		var x := cos(a) * w * 0.5
		var y := sin(a) * h * 0.5
		# Верх уже низа: острый конец сверху
		if y < 0.0:
			x *= 0.82 + 0.18 * (1.0 + y / (h * 0.5))
		out.append(c + Vector2(x, y))
	return out
