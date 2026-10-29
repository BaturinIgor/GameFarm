class_name PointerArrow
extends Node2D
## Стрелка у края экрана, указывающая на склад, зверя или клад (порт PointerArrow).
## Добавлять в world.fx и каждый кадр звать track(world, цель в мире или null).

## Поля экрана, куда стрелка не заходит: по бокам, сверху шапка, снизу кнопки.
const INSET_X := 36.0
const INSET_TOP := 150.0
const INSET_BOTTOM := 170.0
## Цель ближе к краю, чем это, считается видимой.
const VISIBLE_X := 20.0
const RADIUS := 19.0

var color: Color
## Пульсация (0.5 с туда и обратно).
var pulse := 1.0
var _pointer := Polygon2D.new()


## icon - имя иконки ic_<имя> (например "chest") или эмодзи.
func _init(tint: Color, icon: String) -> void:
	color = tint
	visible = false
	z_index = 60
	var tex: Texture2D = Sprites.icon(icon)
	if tex != null:
		var s := Sprite2D.new()
		s.texture = tex
		s.scale = Vector2.ONE * 26.0 / float(maxi(tex.get_width(), tex.get_height()))
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(s)
	else:
		var l := Label.new()
		l.text = icon
		l.label_settings = Fx.label_settings(20, Color.WHITE, 0)
		l.size = Vector2(40, 40)
		l.position = Vector2(-20, -20)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(l)
	# Наконечник как в iOS (картинка 40x40, уменьшенная до 30)
	_pointer.polygon = PackedVector2Array([Vector2(13.5, 0), Vector2(-9, -12), Vector2(-3.75, 0), Vector2(-9, 12)])
	_pointer.color = tint
	_pointer.antialiased = true
	add_child(_pointer)
	point(0.0)


func _ready() -> void:
	var tw := create_tween().set_loops()
	tw.tween_property(self, "pulse", 1.1, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "pulse", 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, Color(0, 0, 0, 0.45))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 40, color, 2.5, true)


func point(angle: float) -> void:
	_pointer.rotation = angle
	_pointer.position = Vector2(cos(angle), sin(angle)) * 30.0


## Каждый кадр: цель на экране или null - стрелка скрыта, иначе стоит у края и смотрит на цель.
func track(world: World, target) -> void:
	if not (target is Vector2) or world == null or world.camera == null:
		visible = false
		return
	var goal: Vector2 = target
	var cam := world.camera
	var zoom := cam.zoom
	var half := world.get_viewport_rect().size / 2.0
	var center := cam.get_screen_center_position()
	# Смещение до цели в точках экрана (y вниз)
	var rel := (goal - center) * zoom
	if absf(rel.x) < half.x - VISIBLE_X and rel.y > -(half.y - INSET_TOP) and rel.y < half.y - INSET_BOTTOM:
		visible = false
		return
	var sx := (half.x - INSET_X) / maxf(absf(rel.x), 0.001)
	var sy := ((half.y - INSET_TOP) if rel.y < 0.0 else (half.y - INSET_BOTTOM)) / maxf(absf(rel.y), 0.001)
	var k := minf(minf(sx, sy), 1.0)
	position = center + rel * k / zoom
	scale = Vector2.ONE * pulse / zoom
	point(atan2(rel.y, rel.x))
	visible = true
