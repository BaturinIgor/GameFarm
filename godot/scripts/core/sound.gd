extends Node
## Звук игры (порт Sound из iOS): эффекты, музыка локаций и фон окружения, шаги героя,
## настройки (музыка, звуки, экономия батареи) и частота кадров.
## Если какого-то файла нет, соответствующий звук просто не играет.

const SETTINGS := "user://settings.cfg"
const VOICES := 10
const MAX_VARIANTS := 16

## Короткие звуки. Файлы: sfx_<имя>_<n>.ogg, n = 0, 1, 2... (варианты).
const SFX := [
	"chop", "mine", "pick", "splash", "treeFall", "rockBreak", "coin", "coinBig", "pickup", "deposit",
	"levelUp", "success", "treasure", "unlock", "purchase", "tap", "open", "close", "error",
	"tame", "wildAppear", "luck", "whoosh", "gateOpen", "crit", "quack",
	"footstepGrass", "footstepSnow", "footstepStone", "footstepSand",
]
## Короткие мелодии наград: не накладываются друг на друга.
const JINGLES := ["levelUp", "success", "treasure", "unlock", "purchase", "tame", "luck", "gateOpen"]
## Мелодии и интерфейс не меняют скорость. Остальные частые звуки слегка меняют, чтобы не звучать одинаково.
const STEADY := ["levelUp", "success", "treasure", "unlock", "purchase", "gateOpen", "luck", "tame",
	"wildAppear", "coinBig", "tap", "open", "close", "error"]

## Музыка. Выключение плавно глушит трек, включение продолжает текущий.
var music_on := true:
	set(v):
		if v == music_on:
			return
		music_on = v
		_save_settings()
		if music_on:
			if not _app_paused:
				_music.resume()
		else:
			_music.suspend()

## Звуковые эффекты и фон окружения.
var sfx_on := true:
	set(v):
		if v == sfx_on:
			return
		sfx_on = v
		_save_settings()
		if sfx_on:
			if not _app_paused:
				_ambience.resume()
		else:
			_ambience.suspend()
			_stop_all_effects()

## Экономия батареи: не больше 30 кадров вместо 60.
var battery_saver := false:
	set(v):
		if v == battery_saver:
			return
		battery_saver = v
		_save_settings()

var _bank: Dictionary = {}          ## имя -> Array[AudioStream]
var _voices: Array[AudioStreamPlayer] = []
var _ends_at: Array[float] = []
var _last_play: Dictionary = {}
var _last_variant: Dictionary = {}
var _last_jingle := -10.0
var _music: LoopChannel
var _ambience: LoopChannel
var _app_paused := false
var _location := ""
var _step_timer := 0.0
var _window_open := false
var _window_want := false
var _active_time := 0.0
var _loading := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music = LoopChannel.new(self, 0.35)
	_ambience = LoopChannel.new(self, 0.25)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)
		_ends_at.append(0.0)
	_load_bank()
	_load_settings()


func _load_bank() -> void:
	for sfx in SFX:
		var list: Array[AudioStream] = []
		for i in MAX_VARIANTS:
			var s := LoopChannel.stream("sfx_%s_%d" % [sfx, i])
			if s == null:
				break
			list.append(s)
		_bank[sfx] = list


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


# MARK: Настройки

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		music_on = bool(cfg.get_value("settings", "music_on", true))
		sfx_on = bool(cfg.get_value("settings", "sfx_on", true))
		battery_saver = bool(cfg.get_value("settings", "battery_saver", false))
	_loading = false


func _save_settings() -> void:
	if _loading:
		return
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("settings", "music_on", music_on)
	cfg.set_value("settings", "sfx_on", sfx_on)
	cfg.set_value("settings", "battery_saver", battery_saver)
	cfg.save(SETTINGS)


# MARK: Эффекты

## Играет случайный вариант эффекта (не тот же, что в прошлый раз). Один и тот же эффект не чаще своей паузы.
func play(sfx: String, volume := 1.0) -> void:
	if not sfx_on or _app_paused:
		return
	var list: Array = _bank.get(sfx, [])
	var count := list.size()
	if count == 0:
		return
	var now := _now()
	if now - float(_last_play.get(sfx, -10.0)) < _cooldown(sfx):
		return
	# Мелодии наград не накладываются друг на друга: при быстром сборе звучит одна.
	if sfx in JINGLES:
		if now - _last_jingle < 0.45:
			return
		_last_jingle = now
	_last_play[sfx] = now
	var index := randi() % count
	if count > 1 and index == int(_last_variant.get(sfx, -1)):
		index = (index + 1 + randi() % (count - 1)) % count
	_last_variant[sfx] = index
	var rate := 1.0 if sfx in STEADY else randf_range(0.94, 1.06)
	_play_voice(list[index], clampf(volume * _gain(sfx), 0.0, 1.0), rate)


## Свободный голос, а если все заняты, тот, что закончится раньше всех.
func _play_voice(stream: AudioStream, volume: float, rate: float) -> void:
	var now := _now()
	var pick := 0
	for i in _voices.size():
		if _ends_at[i] <= now:
			pick = i
			break
		if _ends_at[i] < _ends_at[pick]:
			pick = i
	var voice := _voices[pick]
	voice.stop()
	voice.stream = stream
	voice.volume_db = linear_to_db(maxf(volume, 0.0001))
	voice.pitch_scale = rate
	voice.play()
	_ends_at[pick] = now + stream.get_length() / rate


func _stop_all_effects() -> void:
	for i in _voices.size():
		_voices[i].stop()
		_ends_at[i] = 0.0


## Базовая громкость эффекта.
static func _gain(sfx: String) -> float:
	match sfx:
		"footstepGrass", "footstepSnow", "footstepStone", "footstepSand": return 0.35
		"tap", "open", "close": return 0.8
	return 1.0


## Как часто может звучать один и тот же эффект.
static func _cooldown(sfx: String) -> float:
	match sfx:
		"levelUp", "success", "treasure", "unlock", "purchase", "gateOpen", "tame", "luck": return 0.6
		"coinBig", "wildAppear": return 0.3
		"coin", "pickup", "deposit": return 0.07
		"tap", "open", "close": return 0.08
	return 0.05


## Удар инструментом по точке добычи (порт strike из GameScene).
func play_tool(tool: String) -> void:
	match tool:
		"axe": play("chop")
		"pickaxe": play("mine")
		"rod": play("splash", 0.7)
		"hand": play("pick")
		"sword", "armor", "helmet", "boots": play("chop")


## Шаги героя: ratio - доля от полной скорости. Звук по клетке под ногами (порт stepSound из GameScene).
func footsteps(dt: float, ratio: float, footstep: String, layout: MapLayout, at: Vector2) -> void:
	_step_timer -= dt * ratio
	if ratio <= 0.3 or _step_timer > 0.0:
		return
	_step_timer = 0.3
	var cr := layout.col_row(at)
	play(step_sound(footstep, layout.at(cr.x, cr.y)))


static func step_sound(footstep: String, cell: int) -> String:
	if cell == MapLayout.Cell.ICE:
		return "footstepSnow"
	if cell == MapLayout.Cell.PATH and footstep == "footstepGrass":
		return "footstepSand"
	return footstep


## Окно открылось или закрылось (порт onChange(of: sheet) из ContentView). Смена одного окна на другое
## в том же кадре звука не даёт.
func set_window_open(open: bool) -> void:
	_window_want = open


# MARK: Музыка и фон

## Плавно (около 1.2 с) переключает музыку. "" глушит. Тот же трек не перезапускается.
func play_music(track: String) -> void:
	_music.select("" if track == "" else "mus_" + track, music_on and not _app_paused)


## Плавно переключает фон окружения. "" выключает.
func play_ambience(track: String) -> void:
	_ambience.select("" if track == "" else "amb_" + track, sfx_on and not _app_paused)


func _process(delta: float) -> void:
	var id := Game.current
	if id != _location:
		_location = id
		var spec := Locations.spec(id)
		play_music(str(spec.get("music", "")))
		play_ambience(str(spec.get("ambience", "")))
	if _window_want != _window_open:
		_window_open = _window_want
		play("open" if _window_open else "close")
	_adapt_frame_rate(delta)


## 60 кадров, пока игрок касается экрана (и ещё 1.2 с после), и 30, когда всё стоит.
## Под окном почти ничего не движется: 20. В режиме экономии - не больше 30 (порт adaptFrameRate).
## Окна в Godot рисуются тем же кадром, что и сцена, поэтому при касании и под окном частота полная.
func _adapt_frame_rate(delta: float) -> void:
	if Input.is_anything_pressed():
		_active_time = 1.2
	else:
		_active_time -= delta
	var top := 30 if battery_saver else 60
	var want := top if _active_time > 0.0 else (20 if _window_open else 30)
	if Engine.max_fps != want:
		Engine.max_fps = want


# MARK: Фон приложения

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		pause_all()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		resume_all()


## Приложение уходит в фон.
func pause_all() -> void:
	_app_paused = true
	_music.pause_now()
	_ambience.pause_now()
	_stop_all_effects()


## Приложение вернулось.
func resume_all() -> void:
	if not _app_paused:
		return
	_app_paused = false
	if music_on:
		_music.resume(0.6)
	if sfx_on:
		_ambience.resume(0.6)


## Зацикленный канал (музыка или фон) с плавными переходами.
class LoopChannel:
	const DIR := "res://assets/audio/"

	var volume: float
	var name := ""
	var player: AudioStreamPlayer
	var _host: Node
	var _tween: Tween

	func _init(host: Node, base_volume: float) -> void:
		_host = host
		volume = base_volume

	## Файл звука или null, если его нет (в CI звуков может не быть).
	static func stream(file: String) -> AudioStream:
		var path := DIR + file + ".ogg"
		if not ResourceLoader.exists(path):
			return null
		return load(path) as AudioStream

	## Выбирает трек. active: можно ли ему звучать прямо сейчас.
	func select(new_name: String, active: bool, fade := 1.2) -> void:
		if new_name == name:
			if active:
				resume(fade)
			return
		name = new_name
		if player != null:
			_retire(player, fade)
		player = null
		if active:
			resume(fade)

	## Запускает или продолжает текущий трек с плавным нарастанием.
	func resume(fade := 1.2) -> void:
		if name == "":
			return
		if player == null:
			var s := stream(name)
			if s == null:
				return
			if s is AudioStreamOggVorbis:
				(s as AudioStreamOggVorbis).loop = true
			player = AudioStreamPlayer.new()
			player.stream = s
			player.volume_db = linear_to_db(0.0001)
			_host.add_child(player)
		if player.stream_paused:
			player.stream_paused = false
		elif not player.playing:
			player.play()
		_fade_current(volume, fade, false)

	## Плавно глушит и ставит на паузу, позиция в треке сохраняется.
	func suspend(fade := 0.8) -> void:
		if player == null or player.stream_paused or not player.playing:
			return
		_fade_current(0.0, fade, true)

	## Мгновенная пауза (уход приложения в фон).
	func pause_now() -> void:
		if _tween != null:
			_tween.kill()
		if player != null:
			player.stream_paused = true
		for c in _host.get_children():
			if c is AudioStreamPlayer and c.has_meta("retiring"):
				c.queue_free()

	func _fade_current(to: float, fade: float, pause_after: bool) -> void:
		if _tween != null:
			_tween.kill()
		var p := player
		_tween = _host.create_tween()
		_tween.tween_method(func(v: float) -> void: p.volume_db = linear_to_db(maxf(v, 0.0001)),
			db_to_linear(p.volume_db), to, fade)
		if pause_after:
			_tween.tween_callback(func() -> void: p.stream_paused = true)

	func _retire(old: AudioStreamPlayer, fade: float) -> void:
		if _tween != null:
			_tween.kill()
			_tween = null
		old.set_meta("retiring", true)
		if not old.playing or old.stream_paused:
			old.queue_free()
			return
		var tw := old.create_tween()
		tw.tween_method(func(v: float) -> void: old.volume_db = linear_to_db(maxf(v, 0.0001)),
			db_to_linear(old.volume_db), 0.0, fade)
		tw.tween_callback(old.queue_free)
