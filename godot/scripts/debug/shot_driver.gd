extends Node
## Снимки экрана для проверки в CI: запуск с "-- --shots <папка>".
## Сценарий по времени: старт, герой идёт касаниями к ближайшей точке и добывает,
## несёт добычу на склад, открывается окно склада. На каждом шаге - снимок.

const ORIGIN := Vector2(195, 620)

var dir := "/tmp/shots"
var main: Node
var _time := 0.0
var _step := 0
var _trace := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--shots")
	if i >= 0 and i + 1 < args.size():
		dir = args[i + 1]
	DirAccess.make_dir_recursive_absolute(dir)


func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	_time += dt
	var world: World = main.world
	_trace -= dt
	if _trace <= 0.0:
		_trace = 1.0
		print("t=%.1f pos=%s pack=%d coins=%d storage=%s" % [_time, world.player.position, Game.backpack_count,
			int(Game.save["coins"]), Game.save["storage"]])
	match _step:
		0:
			if _time > 1.5:
				_shot("1_start")
				_touch(ORIGIN, true)
				_step = 1
		1:
			var target := _nearest(world)
			if target != null:
				var d := target.position - world.player.position
				_drag(ORIGIN + (d.normalized() * 50.0 if d.length() > 40.0 else Vector2.ZERO))
			if _time > 4.0 and _time - dt <= 4.0:
				_shot("2_walk")
			if Game.backpack_count >= 6 or _time > 14.0:
				_shot("3_gathered")
				_step = 2
		2:
			var d := world.layout.base - world.player.position
			_drag(ORIGIN + (d.normalized() * 50.0 if d.length() > 30.0 else Vector2.ZERO))
			if Game.backpack_count == 0 or _time > 24.0:
				_touch(ORIGIN, false)
				_shot("4_deposited")
				main.hud.open_window(StoragePanel.new())
				_step = 3
				_time = 100.0
		3:
			if _time > 101.0:
				_shot("5_storage_window")
				get_tree().quit()


func _touch(p: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = p
	e.global_position = p
	Input.parse_input_event(e)


func _drag(p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = p
	e.global_position = p
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(e)


func _nearest(world: World) -> ResourceSpot:
	var best: ResourceSpot = null
	var bd := INF
	for s in world.spots:
		if s.alive and Game.can_harvest(s.spec) and s.spec["tool"] != "rod":
			var d := s.position.distance_to(world.player.position)
			if d < bd:
				bd = d
				best = s
	return best


func _shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(dir.path_join(name + ".png"))
	print("shot saved: ", name)
