class_name BedNode
extends RefCounted
## Грядка (порт BedNode): земля (плоская, под всеми), мокрая земля после полива и растение по стадиям.
## Земля лежит в world.flat, растение - в world.entities (сортируется по высоте).

var index: int
var position: Vector2

var _soil: Node2D
var _wet: Node2D
var _plant := Sprite2D.new()
var _ripe_tween: Tween
var _shown_key := ""


func _init(bed_index: int, point: Vector2, flat: Node2D, entities: Node2D) -> void:
	index = bed_index
	position = point
	_soil = _ground("soil", Color(0.7, 0.45, 0.3), 28.0)
	flat.add_child(_soil)
	_wet = _ground("soil_wet", Color(0.45, 0.27, 0.2), 26.0)
	_wet.z_index = 1
	_wet.visible = false
	flat.add_child(_wet)
	_plant.centered = false
	_plant.position = point + Vector2(0, 8)
	_plant.visible = false
	entities.add_child(_plant)


## Спрайт земли или цветной квадрат, если спрайта нет.
func _ground(name: String, color: Color, size: float) -> Node2D:
	var s := Sprites.make(name, position)
	if s != null:
		return s
	var p := Polygon2D.new()
	var h := size / 2.0
	p.polygon = PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	p.color = color
	p.position = position
	return p


## Обновляет вид, только если что-то поменялось.
func refresh(bed: Dictionary, unlocked: bool, now: float) -> void:
	if not is_instance_valid(_plant):
		return
	var stage := Farming.stage(bed, now)
	var ripe := Farming.is_ripe(bed, now)
	var watered := bool(bed.get("watered", false))
	var key := "%s|%s|%d|%s" % [unlocked, str(bed.get("crop", "-")), stage, watered]
	if key == _shown_key:
		return
	_shown_key = key
	_soil.modulate.a = 1.0 if unlocked else 0.3
	_wet.visible = watered and not ripe
	if _ripe_tween != null:
		_ripe_tween.kill()
		_ripe_tween = null
	if Farming.is_empty(bed):
		_plant.visible = false
		return
	var crop: String = bed["crop"]
	var name := "%s_%d" % [Farming.sprite(crop), stage]
	var tex := Sprites.texture(name)
	var anchor := Sprites.anchor(name)
	var k: float = Sprites.SCALE
	if tex == null:
		# Нет спрайта: иконка урожая
		tex = Res.icon(Farming.spec(crop)["produce"])
		anchor = Vector2(0.5, 0.0)
		k = 24.0 / float(maxi(1, tex.get_width())) if tex != null else 1.0
	if tex == null:
		_plant.visible = false
		return
	_plant.texture = tex
	_plant.offset = Sprites.anchor_offset(anchor, Vector2(tex.get_width(), tex.get_height()))
	_plant.scale = Vector2.ONE * k
	_plant.visible = true
	if ripe and _plant.is_inside_tree():
		var base := _plant.scale
		_ripe_tween = _plant.create_tween().set_loops()
		_ripe_tween.tween_property(_plant, "scale", base * 1.08, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_ripe_tween.tween_property(_plant, "scale", base, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Сбросить кеш вида (после действия игрока).
func invalidate() -> void:
	_shown_key = ""
