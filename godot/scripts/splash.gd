extends CanvasLayer
## Заставка при запуске. Показывает ту же картинку, что экран загрузки движка (boot splash,
## assets/splash.png из tools/make_splash.py), рисует под названием полоску загрузки, в фоне грузит
## scenes/main.tscn, кладёт игру под заставку и плавно её гасит.
## В CI (-- --check-scripts, -- --shots, запуск без экрана) сразу запускает главную сцену.
## -- --splash-shot <папка>: снимки заставки для CI, после перехода в игру выход.

const MAIN := "res://scenes/main.tscn"
const IMAGE := "res://assets/splash.png"
## Картинка в точках и места на ней, как в tools/make_splash.py
const IMAGE_SIZE := Vector2(390, 500)
const ICON_RECT := Rect2(120, 28, 150, 150)
const TITLE_RECT := Rect2(30, 196, 330, 150)
const BAR_RECT := Rect2(95, 391, 200, 18)
## Заставка не мелькает, даже если всё загрузилось сразу
const MIN_TIME := 1.0
const FADE_TIME := 0.45
## Доля полоски на фоновую загрузку, остальное - запуск игры
const LOAD_PART := 0.85

enum Step { LOADING, START, FADE, DONE }

var _step := Step.LOADING
var _time := 0.0
var _fade := 0.0
var _root: Control
var _art: Control
var _bar: Bar
var _shot_dir := ""
var _shots := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--check-scripts" in args or "--shots" in args or DisplayServer.get_name() == "headless":
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
	bg.color = ProjectSettings.get_setting("application/boot_splash/bg_color", Color(0.2, 0.596, 0.294))
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)

	# Всё нарисованное - в координатах картинки, масштаб считает _layout()
	_art = Control.new()
	_art.size = IMAGE_SIZE
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_art)
	if ResourceLoader.exists(IMAGE):
		var logo := TextureRect.new()
		logo.texture = load(IMAGE)
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_SCALE
		logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		logo.size = IMAGE_SIZE
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_art.add_child(logo)
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
	_art.add_child(icon)
	var title := UiKit.label(str(ProjectSettings.get_setting("application/config/name")), 56, UiKit.GOLD, 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	title.position = TITLE_RECT.position
	title.size = TITLE_RECT.size
	_art.add_child(title)


## Картинка ложится так же, как boot splash движка: по ширине в портрете, по высоте в ландшафте.
func _layout() -> void:
	var view := _root.get_viewport_rect().size
	var k := view.y / IMAGE_SIZE.y if view.x > view.y else view.x / IMAGE_SIZE.x
	_art.scale = Vector2(k, k)
	_art.position = (view - IMAGE_SIZE * k) * 0.5


func _process(delta: float) -> void:
	# После запуска игры кадр бывает долгим: не перескакиваем анимацию
	var dt := minf(delta, 1.0 / 30.0)
	_time += dt
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
			if _shot_dir != "" and _shots == 0 and _time > 0.6:
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
