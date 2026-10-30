class_name TowerNode
extends Node2D
## Сторожевая башня у склада: свой рисунок (tools/make_defense_art.py), во время набега стреляет
## стрелами по ближайшему монстру волны в пределах дальности.

var _cooldown := 0.0


func _init() -> void:
	var s := Sprites.make("tower")
	if s != null:
		# Рисунок стоит на земле нижним краем
		s.centered = false
		s.offset = Vector2(-s.texture.get_width() / 2.0, -s.texture.get_height())
		add_child(s)


## Выстрел, если готов и есть цель. damage_cb(foe, damage, from) наносит урон.
func shoot(fx: Node2D, raiders: Array, range_px: float, damage: float, rate: float, dt: float, damage_cb: Callable) -> void:
	_cooldown -= dt
	if _cooldown > 0.0:
		return
	var best: MonsterNode = null
	var best_d := range_px
	for m in raiders:
		if not is_instance_valid(m) or not m.alive:
			continue
		var d := position.distance_to(m.position)
		if d < best_d:
			best_d = d
			best = m
	if best == null:
		return
	_cooldown = rate
	var from := position - Vector2(0, 52)
	var target := best.position - Vector2(0, 20)
	var arrow := Line2D.new()
	arrow.width = 3.0
	arrow.default_color = Color(0.35, 0.22, 0.1)
	arrow.points = PackedVector2Array([Vector2.ZERO, (target - from).normalized() * 14.0])
	arrow.position = from
	arrow.z_index = 40
	fx.add_child(arrow)
	var foe := best
	var tw := arrow.create_tween()
	tw.tween_property(arrow, "position", target, clampf(best_d / 600.0, 0.08, 0.3))
	tw.tween_callback(func() -> void:
		arrow.queue_free()
		if is_instance_valid(foe) and foe.alive:
			damage_cb.call(foe, damage, from))
