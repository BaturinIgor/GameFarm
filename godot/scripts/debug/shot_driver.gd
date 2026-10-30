extends Node
## Снимки экрана для проверки в CI: запуск с "-- --shots <папка>".
## Сценарий по времени: старт, герой идёт касаниями к ближайшей точке и добывает,
## несёт добычу на склад, открывается окно склада. На каждом шаге - снимок.

const ORIGIN := Vector2(195, 620)
const WINDOWS := ["workshop", "talents", "animals", "quests", "level", "house", "kitchen", "garden", "trader", "hunt",
	"dungeon", "trophies", "collection", "legacy", "wardrobe", "map", "events", "shop"]

var dir := "/tmp/shots"
var main: Node
var _time := 0.0
var _step := 0
var _trace := 0.0
var _opened := ""
var _shot_done := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--shots")
	if i >= 0 and i + 1 < args.size():
		dir = args[i + 1]
	DirAccess.make_dir_recursive_absolute(dir)
	# Снимки на русском: длинные подписи лучше всего показывают, что не помещается
	L.set_language("ru", false)


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
				# Прокачанный герой: окна с содержимым
				Game.save["level"] = 18
				Game.save["coins"] = 25000
				for k in ["wood", "stone", "clay", "coal", "iron", "berries", "fish", "apples"]:
					Game.save["storage"][k] = 300
				Game.recalc()
				Game.mark_dirty()
				_step = 4
				_time = 200.0
		4:
			var t := int(_time - 200.0)
			if t < WINDOWS.size() * 2:
				var w: String = WINDOWS[t / 2]
				if t % 2 == 0 and _opened != w:
					_opened = w
					var path := "res://scripts/ui/%s_panel.gd" % w
					if ResourceLoader.exists(path):
						main.hud.open_window(load(path).new())
				elif t % 2 == 1 and _shot_done != w:
					_shot_done = w
					_shot("6_" + w)
					_check_layout(w)
			else:
				main.hud.close_window()
				_step = 5
				_time = 300.0
		5:
			if _time > 302.0:
				_shot("7_world_level18")
				LevelUpOverlay.present(17, 18)
				_step = 6
				_time = 400.0
		6:
			if _time > 401.5:
				_shot("8_level_up")
				if LevelUpOverlay.current != null and is_instance_valid(LevelUpOverlay.current):
					LevelUpOverlay.current.queue_free()
				if Game.house.has_method("enter_house"):
					Game.house.call("enter_house")
				_step = 7
				_time = 500.0
		7:
			if _time > 503.0:
				_shot("9_home")
				if Game.house.has_method("leave_house"):
					Game.house.call("leave_house")
				_step = 8
				_time = 600.0
		8:
			if _time > 603.0:
				_shot("10_meadow_door")
				Game.dungeons.start_dungeon("slimeCaves", 1)
				_step = 9
				_time = 700.0
		9:
			if _time > 704.0 and _shot_done != "dungeon_run":
				_shot_done = "dungeon_run"
				_shot("11_dungeon")
			if _time > 712.0:
				_shot("12_dungeon_later")
				get_tree().quit()

## Проверка вёрстки окна: панель не шире экрана, иначе ищем самые глубокие узлы,
## которые не помещаются в родителя, и печатаем их (LAYOUT OVERFLOW в журнале CI).
func _check_layout(w: String) -> void:
	var sheet: Sheet = null
	for n in main.hud.find_children("*", "", true, false):
		if n is Sheet:
			sheet = n
	if sheet == null:
		return
	var limit := get_viewport().get_visible_rect().size.x
	var panel: Control = sheet._panel
	var right := panel.get_global_rect().end.x
	if right <= limit + 0.5:
		print("LAYOUT OK %s width=%.0f" % [w, panel.size.x])
		return
	print("LAYOUT OVERFLOW %s panel_right=%.0f screen=%.0f" % [w, right, limit])
	_report_overflow(sheet.content, sheet._scroll.size.x, w, 0)


func _report_overflow(node: Control, avail: float, w: String, depth: int) -> void:
	var found := false
	for c in node.get_children():
		if not c is Control or not (c as Control).visible:
			continue
		var cm := (c as Control).get_combined_minimum_size().x
		if cm > avail + 0.5:
			found = true
			var inner := avail
			if c is PanelContainer:
				var st := (c as Control).get_theme_stylebox("panel")
				if st != null:
					inner -= st.get_margin(SIDE_LEFT) + st.get_margin(SIDE_RIGHT)
			elif c is MarginContainer:
				inner -= (c as Control).get_theme_constant("margin_left") + (c as Control).get_theme_constant("margin_right")
			if c is HBoxContainer or c is HFlowContainer:
				var parts: Array = []
				for k in c.get_children():
					if k is Control and (k as Control).visible:
						var txt := ""
						if k is Label:
							txt = (k as Label).text
						elif k is Button:
							txt = (k as Button).text
						parts.append("%s(%.0f)%s" % [k.get_class(), (k as Control).get_combined_minimum_size().x, " '" + txt + "'" if txt != "" else ""])
				print("  %s row min=%.0f avail=%.0f: %s" % [w, cm, avail, ", ".join(parts)])
			if depth < 12:
				_report_overflow(c, inner, w, depth + 1)
	if not found and depth == 0:
		print("  %s: no single child overflows" % w)


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
