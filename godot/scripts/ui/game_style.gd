class_name GameStyle
extends StyleBox
## Рисованная рамка в стиле iOS-версии (StyleBoxFlat не умеет градиент и "губу"):
## скруглённый прямоугольник с заливкой сверху вниз (top -> bottom), контуром, светлой полоской сверху
## и тёмной губой снизу. pressed - тело опущено на губу (нажатая кнопка).

# Поля с @export: duplicate() копирует только сохраняемые свойства
@export var top := Color.WHITE
@export var bottom := Color.WHITE
## Радиусы углов: верх-лево, верх-право, низ-право, низ-лево.
@export var radii := Vector4(13, 13, 13, 13)
@export var outline := Color("2b1a0f")
@export var outline_width := 2.0
@export var lip := 0.0
@export var lip_color := Color.BLACK
@export var pressed := false
## Светлая полоска сверху (толщина, 0 - нет).
@export var highlight := 0.0
## Внутренняя рамка (как у деревянной плашки): цвет и отступ от края, 0 - нет.
@export var frame_color := Color(0, 0, 0, 0)
@export var frame_width := 0.0
## Широкая рамка цвета border_color внутри контура (деревянная рамка панели), 0 - нет.
@export var border_width := 0.0
@export var border_color := Color("a0673a")
## Жёсткая тень под фигурой: сдвиг вниз и цвет.
@export var shadow_offset := 0.0
@export var shadow_color := Color(0, 0, 0, 0)

## Как у StyleBoxFlat: один цвет - градиент от чуть светлее к нему (woodPill в iOS).
var bg_color: Color:
	get: return bottom
	set(v):
		bottom = v
		top = Color(v.lerp(Color.WHITE, 0.18), v.a)
		emit_changed()


func set_corner_radius_all(r: float) -> void:
	radii = Vector4(r, r, r, r)
	emit_changed()


static func make(top_c: Color, bottom_c: Color, radius := 13.0) -> GameStyle:
	var s := GameStyle.new()
	s.top = top_c
	s.bottom = bottom_c
	s.radii = Vector4(radius, radius, radius, radius)
	return s


## Кнопка в цветах тона UiKit.TONES: [верх, основа, губа].
static func button(tone: String, small := false, is_pressed := false) -> GameStyle:
	var c: Array = UiKit.TONES.get(tone, UiKit.TONES["green"])
	var r := 10.0 if small else 13.0
	var s := make(c[0], c[1], r)
	s.lip = 3.0 if small else 4.0
	s.lip_color = c[2]
	s.pressed = is_pressed
	s.highlight = 2.0 if small else 3.0
	var h := 10.0 if small else 16.0
	var v := 6.0 if small else 10.0
	s.content_margin_left = h
	s.content_margin_right = h
	s.content_margin_top = v + (s.lip if is_pressed else 0.0)
	s.content_margin_bottom = v + (0.0 if is_pressed else s.lip)
	return s


func _draw(ci: RID, rect: Rect2) -> void:
	var body := rect
	if shadow_offset > 0.0:
		var sh := body
		sh.position.y += shadow_offset
		_fill(ci, sh, shadow_color, shadow_color)
	if lip > 0.0:
		body.size.y -= lip
		var under := body
		under.position.y += lip
		_fill(ci, under, lip_color, lip_color)
		_stroke(ci, under, outline, outline_width)
		if pressed:
			body.position.y += lip
	if border_width > 0.0:
		# Рамка: сначала вся фигура цветом рамки, внутри - заливка, по краю заливки тонкая тёмная черта
		_fill(ci, body, border_color, border_color)
		var inner := GameStyle.make(top, bottom)
		var k := border_width
		inner.radii = Vector4(maxf(0.0, radii.x - k), maxf(0.0, radii.y - k), maxf(0.0, radii.z - k), maxf(0.0, radii.w - k))
		var ir := body.grow(-k)
		inner._fill(ci, ir, top, bottom)
		inner._stroke(ci, ir, Color(outline, 0.35), 1.0)
	else:
		_fill(ci, body, top, bottom)
	if frame_width > 0.0:
		var inner := body.grow(-frame_width)
		_stroke(ci, inner, frame_color, 1.0, frame_width)
	if highlight > 0.0:
		var inset := maxf(radii.x, radii.y)
		var strip := Rect2(body.position.x + inset, body.position.y + 3.0, body.size.x - inset * 2.0, highlight)
		if strip.size.x > highlight:
			var hs := GameStyle.make(Color(1, 1, 1, 0.4), Color(1, 1, 1, 0.4), highlight / 2.0)
			hs._fill(ci, strip, hs.top, hs.bottom)
	if outline_width > 0.0:
		_stroke(ci, body, outline, outline_width)


func _fill(ci: RID, r: Rect2, c_top: Color, c_bottom: Color) -> void:
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	var pts := points(r, radii)
	var colors := PackedColorArray()
	for p in pts:
		var t := clampf((p.y - r.position.y) / maxf(1.0, r.size.y), 0.0, 1.0)
		colors.append(c_top.lerp(c_bottom, t))
	RenderingServer.canvas_item_add_polygon(ci, pts, colors)


func _stroke(ci: RID, r: Rect2, color: Color, width: float, inset := 0.0) -> void:
	var half := width / 2.0
	var rr := r.grow(-half)
	if rr.size.x <= 0.0 or rr.size.y <= 0.0:
		return
	var k := Vector4(maxf(0.0, radii.x - half - inset), maxf(0.0, radii.y - half - inset),
		maxf(0.0, radii.z - half - inset), maxf(0.0, radii.w - half - inset))
	var pts := points(rr, k)
	pts.append(pts[0])
	RenderingServer.canvas_item_add_polyline(ci, pts, PackedColorArray([color]), width, true)


## Точки скруглённого прямоугольника по часовой стрелке, начиная с верхнего левого угла.
static func points(r: Rect2, k: Vector4) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var lim := minf(r.size.x, r.size.y) / 2.0
	var rad := [minf(k.x, lim), minf(k.y, lim), minf(k.z, lim), minf(k.w, lim)]
	var centers := [r.position + Vector2(rad[0], rad[0]), Vector2(r.end.x - rad[1], r.position.y + rad[1]),
		r.end - Vector2(rad[2], rad[2]), Vector2(r.position.x + rad[3], r.end.y - rad[3])]
	var starts := [PI, PI * 1.5, 0.0, PI * 0.5]
	for i in 4:
		var radius: float = rad[i]
		var c: Vector2 = centers[i]
		if radius <= 0.5:
			pts.append(c)
			continue
		var steps := 6
		for j in steps + 1:
			var a: float = starts[i] + PI * 0.5 * float(j) / float(steps)
			pts.append(c + Vector2(cos(a), sin(a)) * radius)
	return pts
