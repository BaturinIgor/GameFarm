extends CanvasLayer
## Заставка при запуске. Показывает ту же картинку, что экран загрузки движка (boot splash,
## assets/splash.png из tools/make_splash.py), рисует под названием полоску загрузки, в фоне грузит
## scenes/main.tscn, кладёт игру под заставку и плавно её гасит.
## За картинкой - живой фон (Backdrop): закатное небо, вращающиеся лучи за иконкой, звёзды, облака,
## холмы с деревьями и цветами, светлячки и лепестки. Фон проявляется из цвета boot splash, иконка
## с названием слегка покачиваются.
## В CI (-- --check-scripts, -- --shots, запуск без экрана) сразу запускает главную сцену, с -- --run-tests - автотесты.
## -- --splash-shot <папка>: снимки заставки для CI, после перехода в игру выход.

const MAIN := "res://scenes/main.tscn"
const IMAGE := "res://assets/splash.png"
## Картинка в точках и места на ней, как в tools/make_splash.py
const IMAGE_SIZE := Vector2(390, 500)
const ICON_RECT := Rect2(120, 28, 150, 150)
const TITLE_RECT := Rect2(30, 196, 330, 150)
const BAR_RECT := Rect2(95, 391, 200, 18)
## Заставка не мелькает, даже если всё загрузилось сразу
const MIN_TIME := 1.5
const FADE_TIME := 0.45
## Доля полоски на фоновую загрузку, остальное - запуск игры
const LOAD_PART := 0.85

enum Step { LOADING, START, FADE, DONE }

var _step := Step.LOADING
var _time := 0.0
var _fade := 0.0
var _root: Control
var _art: Control
var _logo: Control
var _backdrop: Backdrop
var _bar: Bar
var _shot_dir := ""
var _shots := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	# Автотесты в CI: только состояние игры, без мира и интерфейса (tests/runner.gd)
	if "--run-tests" in args:
		set_process(false)
		get_tree().root.add_child.call_deferred(load("res://tests/runner.gd").new())
		return
	# Прогон ботов-симуляций (tests/sim): баланс, время прохождения, донат
	if "--simulate" in args:
		set_process(false)
		get_tree().root.add_child.call_deferred(load("res://tests/sim/sim_runner.gd").new())
		return
	if "--check-scripts" in args or "--shots" in args or "--clip" in args or DisplayServer.get_name() == "headless":
		set_process(false)
		get_tree().change_scene_to_file.call_deferred(MAIN)
		return
	var i := args.find("--splash-shot")
	if i >= 0 and i + 1 < args.size():
		_shot_dir = args[i + 1]
		DirAccess.make_dir_recursive_absolute(_shot_dir)
	_build()
	if ResourceLoader.load_threaded_request(MAIN) != OK:
		set_process(false)
		get_tree().change_scene_to_file.call_deferred(MAIN)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = ProjectSettings.get_setting("application/boot_splash/bg_color", Color(0.357, 0.247, 0.722))
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)
	_backdrop = Backdrop.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.modulate.a = 0.0
	_root.add_child(_backdrop)

	# Всё нарисованное - в координатах картинки, масштаб считает _layout()
	_art = Control.new()
	_art.size = IMAGE_SIZE
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_art)
	# Иконка и название покачиваются отдельно от полоски
	_logo = Control.new()
	_logo.size = IMAGE_SIZE
	_logo.pivot_offset = ICON_RECT.get_center()
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.add_child(_logo)
	if ResourceLoader.exists(IMAGE):
		var logo := TextureRect.new()
		logo.texture = load(IMAGE)
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_SCALE
		logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		logo.size = IMAGE_SIZE
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_logo.add_child(logo)
	else:
		_build_fallback()
	_bar = Bar.new()
	_bar.position = BAR_RECT.position
	_bar.size = BAR_RECT.size
	_art.add_child(_bar)

	get_viewport().size_changed.connect(_layout)
	_layout()


## Без картинки (не запускали tools/godot_sync.sh): иконка и название шрифтом игры.
func _build_fallback() -> void:
	var icon := TextureRect.new()
	icon.texture = load("res://icon.png")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.position = ICON_RECT.position
	icon.size = ICON_RECT.size
	_logo.add_child(icon)
	var title := UiKit.label(str(ProjectSettings.get_setting("application/config/name")), 56, UiKit.GOLD, 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	title.position = TITLE_RECT.position
	title.size = TITLE_RECT.size
	_logo.add_child(title)


## Картинка ложится так же, как boot splash движка: по ширине в портрете, по высоте в ландшафте.
func _layout() -> void:
	var view := _root.get_viewport_rect().size
	var k := view.y / IMAGE_SIZE.y if view.x > view.y else view.x / IMAGE_SIZE.x
	_art.scale = Vector2(k, k)
	_art.position = (view - IMAGE_SIZE * k) * 0.5
	# Лучи и солнце - за иконкой, холмы - под полоской загрузки
	_backdrop.focus = _art.position + ICON_RECT.get_center() * k
	_backdrop.horizon = _art.position.y + (BAR_RECT.end.y + 30.0) * k
	_backdrop.unit = k
	_backdrop.rebuild()


func _process(delta: float) -> void:
	# После запуска игры кадр бывает долгим: не перескакиваем анимацию
	var dt := minf(delta, 1.0 / 30.0)
	_time += dt
	_backdrop.modulate.a = minf(1.0, _time / 0.35)
	_backdrop.time = _time
	_backdrop.queue_redraw()
	_logo.position.y = sin(_time * 2.2) * 4.0
	_logo.rotation = sin(_time * 1.3) * 0.012
	match _step:
		Step.LOADING:
			var progress := []
			var status := ResourceLoader.load_threaded_get_status(MAIN, progress)
			if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				_step = Step.DONE
				get_tree().change_scene_to_file.call_deferred(MAIN)
				return
			var loaded := status == ResourceLoader.THREAD_LOAD_LOADED
			var real: float = 1.0 if loaded else (float(progress[0]) if not progress.is_empty() else 0.0)
			var target := minf(real, _time / MIN_TIME) * LOAD_PART
			_bar.value = move_toward(_bar.value, target, dt * 2.0)
			if _shot_dir != "" and _shots == 0 and _time > 0.9:
				_shot("0_splash")
			# Полоска дошла и этот кадр уже показан: дальше тяжёлый запуск игры
			if loaded and _bar.value >= LOAD_PART - 0.001:
				_step = Step.START
		Step.START:
			_start_main()
			_step = Step.FADE
		Step.FADE:
			_bar.value = move_toward(_bar.value, 1.0, dt * 4.0)
			if _bar.value >= 1.0:
				_fade += dt / FADE_TIME
				_root.modulate.a = 1.0 - smoothstep(0.0, 1.0, _fade)
				_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
				if _shot_dir != "" and _shots == 1 and _fade > 0.5:
					_shot("0_splash_fade")
			if _fade >= 1.0:
				_step = Step.DONE
				if _shot_dir != "":
					get_tree().quit()
				queue_free()


## Игра встаёт под заставку и становится текущей сценой.
func _start_main() -> void:
	var packed := ResourceLoader.load_threaded_get(MAIN) as PackedScene
	if packed == null:
		_step = Step.DONE
		get_tree().change_scene_to_file.call_deferred(MAIN)
		return
	var main := packed.instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main


func _shot(name: String) -> void:
	_shots += 1
	var img := get_viewport().get_texture().get_image()
	img.save_png(_shot_dir.path_join(name + ".png"))
	print("splash shot saved: ", name)


## Полоска загрузки в стиле кнопок: тёмный контур, тень вниз, золотая заливка с бликом.
class Bar extends Control:
	var value := 0.0:
		set(v):
			value = clampf(v, 0.0, 1.0)
			queue_redraw()

	var _shadow := _box(Color(UiKit.OUTLINE, 0.43))
	var _track := _box(UiKit.OUTLINE)
	var _fill := _box(UiKit.GOLD)
	var _shine := _box(Color(1, 1, 1, 0.35))

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := int(size.y * 0.5)
		for s: StyleBoxFlat in [_shadow, _track]:
			s.set_corner_radius_all(r)
		draw_style_box(_shadow, Rect2(Vector2(0, 4), size))
		draw_style_box(_track, Rect2(Vector2.ZERO, size))
		var inner := Rect2(Vector2(3, 3), size - Vector2(6, 6))
		if value <= 0.0:
			return
		var w := maxf(inner.size.y, inner.size.x * value)
		_fill.set_corner_radius_all(int(inner.size.y * 0.5))
		draw_style_box(_fill, Rect2(inner.position, Vector2(w, inner.size.y)))
		var shine_h := inner.size.y * 0.4
		if w > inner.size.y:
			_shine.set_corner_radius_all(int(shine_h * 0.5))
			draw_style_box(_shine, Rect2(inner.position + Vector2(inner.size.y * 0.4, 1), Vector2(w - inner.size.y * 0.8, shine_h)))

	static func _box(c: Color) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = c
		s.anti_aliasing = true
		return s


## Живой фон заставки. Всё рисуется кодом в _draw: небо, лучи, звёзды, облака, холмы, светлячки, лепестки.
class Backdrop extends Control:
	const SKY: Array[Color] = [Color("2a2a74"), Color("5b3fb8"), Color("c45bb0"), Color("ff8a7a"), Color("ffc46b"), Color("ffe9a8")]
	const SKY_AT: Array[float] = [0.0, 0.26, 0.48, 0.66, 0.82, 1.0]
	const HILLS: Array[Color] = [Color("8e6fd1"), Color("5fb86a"), Color("3f9a4f"), Color("2f7d3f")]
	const SPARK: Array[Color] = [Color("ffe066"), Color("ff8fc8"), Color("7ce8ff"), Color("b6ff7a"), Color("ffffff")]
	const PETAL: Array[Color] = [Color("ffb3d1"), Color("ffd27a"), Color("ffffff"), Color("ff9a9a")]

	var time := 0.0
	var focus := Vector2.ZERO     ## центр лучей (иконка)
	var horizon := 600.0          ## верх ближнего холма
	var unit := 1.0               ## точек картинки в точке экрана
	var _sky := TextureRect.new()
	var _hills: Array = []        ## [PackedVector2Array, Color, верхняя кромка]
	var _trees: Array = []        ## [позиция, размер, оттенок]
	var _flowers: Array = []      ## [позиция, цвет]
	var _path := PackedVector2Array()
	var _path_edge := PackedVector2Array()
	var _house := Vector2.ZERO
	var _stars: Array = []        ## [позиция, фаза, размер]
	var _clouds: Array = []       ## [x, y, размер, скорость]
	var _sparks: Array = []       ## [x, фаза, скорость, цвет, размер]
	var _petals: Array = []       ## [x, фаза, скорость, цвет]

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var g := Gradient.new()
		g.offsets = PackedFloat32Array(SKY_AT)
		g.colors = PackedColorArray(SKY)
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill_from = Vector2(0, 0)
		tex.fill_to = Vector2(0, 1)
		tex.width = 4
		tex.height = 256
		_sky.texture = tex
		_sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_sky.stretch_mode = TextureRect.STRETCH_SCALE
		_sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sky.show_behind_parent = true
		add_child(_sky)
		resized.connect(rebuild)

	## Холмы, деревья, звёзды и частицы под новый размер экрана (одинаковые при каждом запуске).
	func rebuild() -> void:
		var w := size.x
		var h := size.y
		if w <= 0.0 or h <= 0.0:
			return
		var rng := RandomNumberGenerator.new()
		rng.seed = 2024
		_hills.clear()
		# Дальние горы, два средних холма и ближний
		var tops := [horizon - 120.0 * unit, horizon - 62.0 * unit, horizon - 22.0 * unit, horizon + 26.0 * unit]
		var waves := [[0.011, 46.0], [0.017, 22.0], [0.013, 18.0], [0.02, 12.0]]
		for i in 4:
			var pts := PackedVector2Array()
			var edge := PackedVector2Array()
			var top: float = tops[i]
			var freq: float = waves[i][0] / unit
			var amp: float = waves[i][1] * unit
			var phase := rng.randf() * TAU
			var x := -8.0
			while x <= w + 8.0:
				var y := top - absf(sin(x * freq + phase)) * amp if i == 0 else top + sin(x * freq + phase) * amp
				edge.append(Vector2(x, y))
				x += 6.0
			pts.append_array(edge)
			pts.append(Vector2(w + 8.0, h + 8.0))
			pts.append(Vector2(-8.0, h + 8.0))
			_hills.append([pts, HILLS[i], edge])
		_trees.clear()
		for i in 9:
			var layer := 1 if i < 5 else 2
			var edge: PackedVector2Array = _hills[layer][2]
			var p: Vector2 = edge[rng.randi_range(2, edge.size() - 3)]
			_trees.append([p + Vector2(0, 6.0 * unit), rng.randf_range(0.8, 1.25) * (0.75 if layer == 1 else 1.0) * unit,
				rng.randf_range(-0.06, 0.06)])
		_flowers.clear()
		var near: PackedVector2Array = _hills[3][2]
		for i in 22:
			var p: Vector2 = near[rng.randi_range(0, near.size() - 1)]
			_flowers.append([p + Vector2(0, rng.randf_range(8.0, 70.0) * unit), PETAL[rng.randi() % PETAL.size()]])
		# Тропинка от нижнего края к домику на холме
		var hill: PackedVector2Array = _hills[2][2]
		var top_i := int(hill.size() * 0.87)
		_house = hill[top_i] + Vector2(0, 4.0 * unit)
		_path = PackedVector2Array()
		_path_edge = PackedVector2Array()
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		for i in 13:
			var t := float(i) / 12.0
			var y := lerpf(h + 10.0, _house.y + 2.0 * unit, t)
			var cx := lerpf(w * 0.42, _house.x, t) + sin(t * PI * 1.6) * 40.0 * unit
			var half := lerpf(46.0, 5.0, t) * unit
			left.append(Vector2(cx - half, y))
			right.append(Vector2(cx + half, y))
		_path.append_array(left)
		right.reverse()
		_path.append_array(right)
		_path_edge = left
		_stars.clear()
		for i in 34:
			_stars.append([Vector2(rng.randf() * w, rng.randf() * h * 0.36), rng.randf() * TAU, rng.randf_range(1.0, 2.4) * unit])
		_clouds.clear()
		for i in 5:
			_clouds.append([rng.randf() * w, rng.randf_range(0.08, 0.42) * h, rng.randf_range(0.7, 1.3) * unit,
				rng.randf_range(6.0, 14.0) * unit])
		_sparks.clear()
		for i in 28:
			_sparks.append([rng.randf() * w, rng.randf(), rng.randf_range(0.05, 0.11), SPARK[rng.randi() % SPARK.size()],
				rng.randf_range(2.5, 5.0) * unit])
		_petals.clear()
		for i in 14:
			_petals.append([rng.randf() * w, rng.randf(), rng.randf_range(0.06, 0.1), PETAL[rng.randi() % PETAL.size()]])

	func _draw() -> void:
		var w := size.x
		var h := size.y
		_draw_stars()
		_draw_rays(w, h)
		_draw_clouds(w)
		for i in _hills.size():
			var hill: Array = _hills[i]
			draw_colored_polygon(hill[0], hill[1])
			draw_polyline(hill[2], hill[1].lightened(0.25), 3.0 * unit, true)
			if i == 2:
				_draw_house(_house, unit)
			if i == 3 and _path.size() > 2:
				draw_colored_polygon(_path, Color("d9a467"))
				draw_polyline(_path_edge, Color("b8814a"), 2.0 * unit, true)
		for t in _trees:
			# Домик не прячем за деревом
			if absf(t[0].x - _house.x) > 34.0 * unit:
				_draw_tree(t[0], t[1], t[2])
		for f in _flowers:
			var p: Vector2 = f[0]
			draw_circle(p, 2.6 * unit, f[1])
			draw_circle(p, 1.1 * unit, Color("fff3a0"))
		_draw_petals(w, h)
		_draw_sparks(w, h)

	## Солнце и медленно вращающиеся лучи за иконкой.
	func _draw_rays(w: float, h: float) -> void:
		var r := maxf(w, h)
		var n := 16
		var spin := time * 0.25
		for i in n:
			var a := spin + TAU * float(i) / float(n)
			var b := a + TAU / float(n) * 0.5
			var pts := PackedVector2Array([focus, focus + Vector2(cos(a), sin(a)) * r, focus + Vector2(cos(b), sin(b)) * r])
			draw_colored_polygon(pts, Color(1, 0.95, 0.75, 0.10))
		for i in 6:
			var k := 1.0 - float(i) / 6.0
			draw_circle(focus, (70.0 + 26.0 * float(i)) * unit * (1.0 + 0.03 * sin(time * 2.0)), Color(1, 0.88, 0.55, 0.07 * k + 0.02))

	func _draw_stars() -> void:
		for s in _stars:
			var a := 0.35 + 0.65 * (0.5 + 0.5 * sin(time * 2.4 + s[1]))
			_sparkle(s[0], s[2] * 1.6, Color(1, 1, 1, a * 0.9))

	func _draw_clouds(w: float) -> void:
		for c in _clouds:
			var k: float = c[2]
			var x := fposmod(float(c[0]) + time * float(c[3]), w + 160.0 * k) - 80.0 * k
			var p := Vector2(x, c[1])
			var col := Color(1, 0.94, 0.97, 0.85)
			var shade := Color(0.98, 0.78, 0.86, 0.85)
			for b in [[Vector2(-26, 6), 18.0], [Vector2(26, 6), 17.0], [Vector2(0, 8), 20.0]]:
				draw_circle(p + b[0] * k + Vector2(0, 4 * k), b[1] * k, shade)
			for b in [[Vector2(-26, 0), 18.0], [Vector2(0, -10), 24.0], [Vector2(26, 0), 17.0], [Vector2(0, 4), 20.0]]:
				draw_circle(p + b[0] * k, b[1] * k, col)

	## Домик на холме: стены, красная крыша, тёплое окно и дымок.
	func _draw_house(p: Vector2, k: float) -> void:
		var base := p + Vector2(0, -2) * k
		draw_rect(Rect2(base + Vector2(-16, -20) * k, Vector2(32, 20) * k), Color("f2d9b0"))
		draw_colored_polygon(PackedVector2Array([base + Vector2(-21, -19) * k, base + Vector2(0, -36) * k,
			base + Vector2(21, -19) * k]), Color("d2453a"))
		draw_rect(Rect2(base + Vector2(10, -38) * k, Vector2(5, 10) * k), Color("8a4a32"))
		var glow := 0.75 + 0.25 * sin(time * 3.0)
		draw_rect(Rect2(base + Vector2(-11, -15) * k, Vector2(8, 7) * k), Color(1, 0.85, 0.35, glow))
		draw_rect(Rect2(base + Vector2(3, -13) * k, Vector2(7, 13) * k), Color("7a4a2c"))
		for i in 3:
			var t := fposmod(time * 0.35 + float(i) / 3.0, 1.0)
			draw_circle(base + Vector2(12.5 + sin(t * 6.0) * 3.0, -42.0 - t * 30.0) * k, (3.0 + t * 4.0) * k,
				Color(1, 1, 1, 0.55 * (1.0 - t)))

	func _draw_tree(p: Vector2, k: float, tint: float) -> void:
		draw_rect(Rect2(p + Vector2(-3, -16) * k, Vector2(6, 18) * k), Color("6b3f24"))
		var leaf := Color("2f8a46").lightened(0.1 + tint)
		var sway := sin(time * 1.6 + p.x * 0.05) * 1.5 * k
		draw_circle(p + Vector2(sway * 0.5, -26) * k, 15.0 * k, leaf.darkened(0.15))
		draw_circle(p + Vector2(-9 + sway, -32) * k, 11.0 * k, leaf)
		draw_circle(p + Vector2(8 + sway, -34) * k, 10.0 * k, leaf.lightened(0.12))
		draw_circle(p + Vector2(sway, -42) * k, 9.0 * k, leaf.lightened(0.2))

	## Светлячки и искры поднимаются от холмов и покачиваются.
	func _draw_sparks(w: float, h: float) -> void:
		for s in _sparks:
			var t := fposmod(float(s[1]) + time * float(s[2]), 1.0)
			var y := h * (1.05 - t * 0.95)
			var x := fposmod(float(s[0]) + sin(time * 1.7 + float(s[1]) * 9.0) * 14.0 * unit, w)
			var a := sin(t * PI)
			var col: Color = s[3]
			draw_circle(Vector2(x, y), float(s[4]) * 2.2, Color(col, 0.18 * a))
			_sparkle(Vector2(x, y), float(s[4]) * (0.8 + 0.3 * sin(time * 6.0 + float(s[0]))), Color(col, a))

	## Лепестки летят по диагонали и кружатся.
	func _draw_petals(w: float, h: float) -> void:
		for s in _petals:
			var t := fposmod(float(s[1]) + time * float(s[2]), 1.0)
			var p := Vector2(fposmod(float(s[0]) + t * w * 0.5, w + 20.0) - 10.0, -20.0 + t * (h + 40.0))
			var spin := time * 3.0 + float(s[0])
			var d := Vector2(cos(spin), sin(spin)) * 4.0 * unit
			var e := Vector2(-d.y, d.x) * (0.45 + 0.35 * sin(spin * 1.3))
			draw_colored_polygon(PackedVector2Array([p - d, p + e, p + d, p - e]), s[3])

	## Четырёхлучевая искорка.
	func _sparkle(p: Vector2, r: float, c: Color) -> void:
		var t := r * 0.28
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(t, 0), p + Vector2(0, r), p + Vector2(-t, 0)]), c)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-r, 0), p + Vector2(0, -t), p + Vector2(r, 0), p + Vector2(0, t)]), c)
