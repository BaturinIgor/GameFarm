class_name NavFeature
extends WorldFeature
## Стрелка к нужному ресурсу ("Где взять" -> "Перейти"): у края экрана, пока цель за экраном.
## Добыл этот ресурс - стрелка пропадает.

var _arrow: PointerArrow
var _kind := ""


func _init() -> void:
	Game.event.connect(func(name: String, data: Dictionary) -> void:
		if name == "gather" and Game.nav_target != "" and str(data.get("kind", "")) == Game.nav_target:
			Game.nav_target = "")


func build(world: World) -> void:
	_arrow = null
	_kind = ""


func clear(_w: World) -> void:
	_arrow = null
	_kind = ""


func process(world: World, _dt: float) -> void:
	var target := Game.nav_target
	if target != _kind:
		_kind = target
		if _arrow != null and is_instance_valid(_arrow):
			_arrow.queue_free()
		_arrow = null
		if target != "":
			_arrow = PointerArrow.new(Color(0.55, 0.9, 0.4), target)
			world.fx.add_child(_arrow)
	if _arrow == null or not is_instance_valid(_arrow):
		return
	_arrow.track(world, _nearest(world, target))


func _nearest(world: World, kind: String) -> Variant:
	var best: Variant = null
	var bd := INF
	for s in world.spots:
		if not s.alive:
			continue
		var yields: Array = s.spec.get("yields", [])
		var has := false
		for y in yields:
			if str(y[0]) == kind:
				has = true
				break
		if not has:
			continue
		var d: float = s.position.distance_to(world.player.position)
		if d < bd:
			bd = d
			best = s.position
	return best
