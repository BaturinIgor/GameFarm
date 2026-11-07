extends Node
## Запись роликов для соцсетей: запуск с "-- --clip <сценарий> [--lang en]" вместе с
## Godot Movie Maker ("--write-movie out.avi --fixed-fps 30"). Сценарий играет сам и закрывает игру.
## Склейку, подписи и формат 9:16 делает marketing/make_clips.py, запись в CI - .github/workflows/clips.yml.
## Сценарии меняют сохранение, поэтому запускать только на чистой копии (в CI), не на своём телефоне.

const ORIGIN := Vector2(195, 620)
const SCENARIOS := ["walk", "chests", "hatch", "mine", "tour"]
## Прогулка с добычей по другим локациям: сценарий называется как локация (-- --clip desert)
const PLACES := ["hills", "lake", "swamp", "desert", "snow", "caves", "island", "volcano", "sky", "garden"]
## Окна для обзора "tour": по 2,5 секунды на каждое
const TOUR := ["animals", "garden", "wardrobe", "events", "talents", "estate", "collection:zoo"]

var main: Node
var scenario := "walk"
var _time := 0.0
var _total := 0.0
var _step := 0
var _sub := -1
var _game: MineGame


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--clip")
	if i >= 0 and i + 1 < args.size():
		scenario = args[i + 1]
	if not scenario in SCENARIOS and not scenario in PLACES:
		push_error("clip: unknown scenario %s, known: %s" % [scenario, SCENARIOS])
		get_tree().quit(2)
		return
	var li := args.find("--lang")
	L.set_language(args[li + 1] if li >= 0 and li + 1 < args.size() else "en", false)
	# Музыку и фон окружения в записи глушим: потоковые треки в Movie Maker заикаются.
	# Чистую музыку из исходного файла накладывает make_clips.py, из игры остаются только эффекты.
	Sound._music.volume = 0.0
	Sound._ambience.volume = 0.0
	print("clip: ", scenario, " lang=", L.code)


func _process(delta: float) -> void:
	_time += minf(delta, 0.05)
	# Страховка: ролик длиннее минуты не нужен, а зависший сценарий не должен писать файл бесконечно
	_total += delta
	if _total > 60.0:
		push_error("clip: %s timed out" % scenario)
		_done()
		return
	# Первые полсекунды мир грузится: закрываем заставки при входе (календарь, доход без игры)
	if _step == 0:
		if _time < 0.5:
			return
		for _i in 6:
			if not main.hud.is_blocking() or not main.hud.back():
				break
		_prepare()
		_step = 1
		_time = 0.0
		return
	call("_visit" if scenario in PLACES else "_" + scenario)


func _done() -> void:
	print("clip done: ", scenario)
	get_tree().quit()


## Прокачанный герой, чтобы в кадре были окна с содержимым, а не пустые списки.
func _prepare() -> void:
	Game.save["starterOffers"] = 2
	Game.save["offerPopupDay"] = ShopSystem.day_index()
	if scenario == "walk":
		return
	Game.save["level"] = 20
	Game.save["coins"] = 25000
	Game.save["crystals"] = 1200
	for k in ["wood", "stone", "clay", "coal", "iron", "berries", "fish", "apples"]:
		Game.save["storage"][k] = 300
	for a in ["chicken", "cow", "sheep", "horse", "swan"]:
		Game.save["animals"][a] = 3
	Game.save["active"] = ["cow", "chicken"]
	if scenario in PLACES:
		Game.save["level"] = 60
		for t in ["axe", "pickaxe", "rod", "sword", "armor"]:
			Game.save["tools"][t] = 8
		Game.save["current"] = scenario
		if not scenario in Game.world_map.reachable:
			Game.world_map.reachable.append(scenario)
	Game.recalc()
	Game.mark_dirty()


## Другая локация: мир перестраивается, герой бегает от ресурса к ресурсу и добывает.
func _visit() -> void:
	var world: World = main.world
	match _step:
		1:
			if _time > 1.2 and world.loaded == scenario:
				_touch(ORIGIN, true)
				_step = 2
		2:
			var target := _nearest(world)
			if target != null:
				var d := target.position - world.player.position
				_drag(ORIGIN + (d.normalized() * 50.0 if d.length() > 40.0 else Vector2.ZERO))
			if _time > 19.0:
				_touch(ORIGIN, false)
				_done()


## Прогулка: герой идёт к ближайшим ресурсам, добывает и несёт добычу на склад.
func _walk() -> void:
	var world: World = main.world
	match _step:
		1:
			_touch(ORIGIN, true)
			_step = 2
		2:
			var target := _nearest(world)
			if target != null:
				var d := target.position - world.player.position
				_drag(ORIGIN + (d.normalized() * 50.0 if d.length() > 40.0 else Vector2.ZERO))
			if Game.backpack_count >= 8 or _time > 16.0:
				_step = 3
		3:
			var d := world.layout.base - world.player.position
			_drag(ORIGIN + (d.normalized() * 50.0 if d.length() > 30.0 else Vector2.ZERO))
			if Game.backpack_count == 0 or _time > 26.0:
				_touch(ORIGIN, false)
				main.hud.open_window(StoragePanel.new())
				_step = 4
				_time = 100.0
		4:
			if _time > 103.0:
				_done()


## Сундуки: окно с ключами, открытие десяти сундуков, затем древний сундук с радужной наградой.
func _chests() -> void:
	match _step:
		1:
			Game.chests.add_keys("copper", 12, false)
			Game.chests.add_keys("silver", 1, false)
			main.hud.open_window(ChestsPanel.new())
			_step = 2
		2:
			if _time > 1.5:
				var list: Array = []
				for r in Chests.RARITIES:
					list.append(ChestSystem.make_reward(r, 1 + list.size() % 3, Game.level))
				list.append(ChestSystem.make_reward("gold", 3, Game.level))
				list.append(ChestSystem.make_reward("blue", 2, Game.level))
				list.append(ChestSystem.make_reward("green", 1, Game.level))
				for r in list:
					Game.chests.give(r)
				ChestOverlay.show_rewards("wood", list)
				_step = 3
		3:
			if _time > 10.0:
				_free(ChestOverlay)
				var top := ChestSystem.make_reward("rainbow", 3, Game.level)
				Game.chests.give(top)
				ChestOverlay.show_rewards("ancient", [top])
				_step = 4
		4:
			if _time > 17.0:
				_done()


## Инкубатор: яйца всех цветов, золотое яйцо готово, яйцо трясётся и вылупляется пегас.
func _hatch() -> void:
	match _step:
		1:
			Game.save["incubator"]["eggs"] = []
			for r in Incubator.RARITIES:
				Game.incubator.add_egg(r, "", 0.0, false)
			Game.incubator.add_egg("gold", "pegasus", 0.25, false)
			Game.incubator.incubate(1)
			main.hud.open_window(IncubatorPanel.new())
			_step = 2
		2:
			if _time > 2.5:
				Game.save["incubator"]["slot"]["egg"] = {"r": "gold", "a": "pegasus", "s": 1.0}
				Game.save["incubator"]["slot"]["until"] = Clock.now() - 1.0
				Game.changed.emit()
				_step = 3
		3:
			if _time > 4.0:
				HatchOverlay.show_result(Game.incubator.hatch())
				_step = 4
		4:
			if _time > 14.5:
				_done()


## Шахта Глубин: поле руды, ход раз в 1,3 секунды по самой большой группе.
func _mine() -> void:
	match _step:
		1:
			if Game.level < Mine.MIN_LEVEL:
				Game.save["level"] = Mine.MIN_LEVEL
				Game.recalc()
			Game.mine.start()
			_game = MineGame.launch(Game.mine.floor_n(), 7)
			_step = 2
		2:
			var k := int(_time / 1.3)
			if k != _sub and _time > 1.5:
				_sub = k
				if not _tap_best():
					_step = 3
					_time = 100.0
			if _time > 24.0:
				_step = 3
				_time = 100.0
		3:
			if _time > 102.0:
				_done()


func _tap_best() -> bool:
	if _game == null or not is_instance_valid(_game) or not _game.settled():
		return true
	var best := -1
	var size := 1
	for i in _game.board.cells.size():
		var g: int = _game.board.group(i).size()
		if g > size:
			size = g
			best = i
	if best < 0:
		return false
	_game.tap_cell(best)
	return true


## Обзор: несколько окон подряд (звери, сад, гардероб, ивенты, таланты, усадьба, коллекция).
func _tour() -> void:
	var k := int(_time / 2.5)
	if k == _sub:
		return
	_sub = k
	if k >= TOUR.size():
		main.hud.close_window()
		_done()
		return
	var w: String = TOUR[k]
	if ":" in w:
		var parts := w.split(":")
		main.hud.open_window(load("res://scripts/ui/%s_panel.gd" % parts[0]).new(parts[1]))
	else:
		var path := "res://scripts/ui/%s_panel.gd" % w
		if ResourceLoader.exists(path):
			main.hud.open_window(load(path).new())


func _free(type: Variant) -> void:
	for n in main.hud.find_children("*", "", true, false):
		if is_instance_of(n, type):
			n.queue_free()


## Точка касания в координатах игры -> в координаты окна: ролик пишется в 1080x1920, а не 390x844.
func _win(p: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * p


func _touch(p: Vector2, pressed: bool) -> void:
	p = _win(p)
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = p
	e.global_position = p
	Input.parse_input_event(e)


func _drag(p: Vector2) -> void:
	p = _win(p)
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
