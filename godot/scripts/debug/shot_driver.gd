extends Node
## Снимки экрана для проверки в CI: запуск с "-- --shots <папка>".
## Герой идёт к ближайшей точке добычи, работает, потом открывается склад; на каждом шаге - снимок.

var dir := "/tmp/shots"
var main: Node
var _frame := 0
var _step := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--shots")
	if i >= 0 and i + 1 < args.size():
		dir = args[i + 1]
	DirAccess.make_dir_recursive_absolute(dir)


func _process(delta: float) -> void:
	_frame += 1
	var world: World = main.world
	if _frame % 30 == 0:
		var t := _nearest(world)
		print("f=%d dt=%.3f pos=%s pack=%d storage=%s hit=%.2f near=%s hp=%s alive=%s dist=%.1f" % [
			_frame, delta, world.player.position, Game.backpack_count, Game.save["storage"], world._hit_timer,
			t.type if t else "-", t.hp if t else -1, t.alive if t else false,
			t.position.distance_to(world.player.position) if t else -1.0])
	match _step:
		0:
			if _frame == 90:
				_shot("1_start")
				_step = 1
		1:
			# Идём к ближайшей добываемой точке настоящими касаниями (проверка джойстика)
			var target := _nearest(world)
			var origin := Vector2(195, 620)
			if _frame == 91:
				_touch(origin, true)
			elif target != null:
				var d := target.position - world.player.position
				var knob := origin + (d.normalized() * 50.0 if d.length() > 40.0 else Vector2.ZERO)
				_drag(knob)
			if _frame == 330:
				_touch(origin, false)
				_shot("2_gather")
				_step = 2
		2:
			if _frame == 420:
				# Несём добычу на склад
				_step = 3
		3:
			var d := world.layout.base - world.player.position
			world.joystick.vector = d.normalized() if d.length() > 30.0 else Vector2.ZERO
			if _frame == 640:
				world.joystick.vector = Vector2.ZERO
				_shot("3_storage_zone")
				main.hud.open_window(StoragePanel.new())
				_step = 4
		4:
			if _frame == 700:
				_shot("4_storage_window")
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
		if s.alive and Game.can_harvest(s.spec):
			var d := s.position.distance_to(world.player.position)
			if d < bd:
				bd = d
				best = s
	return best


func _shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(dir.path_join(name + ".png"))
	print("shot saved: ", name)
