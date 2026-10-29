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


func _process(_delta: float) -> void:
	_frame += 1
	var world: World = main.world
	match _step:
		0:
			if _frame == 90:
				_shot("1_start")
				_step = 1
		1:
			# Идём к ближайшей добываемой точке
			var target := _nearest(world)
			if target != null:
				var d := target.position - world.player.position
				world.joystick.vector = d.normalized() if d.length() > 40.0 else Vector2.ZERO
			if _frame == 330:
				world.joystick.vector = Vector2.ZERO
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
