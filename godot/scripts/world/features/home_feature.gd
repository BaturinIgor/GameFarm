extends WorldFeature
## Дом в сцене (порт buildHome, syncDecor, updateHome и двери из updatePlaces в GameScene).
## Все этажи стоят одной картой друг над другом (MapLayout.house): пол и стены каждого этажа,
## лестницы - сквозные пролёты, по ним герой просто поднимается и спускается. Непостроенный этаж
## затемнён, у лестницы к нему карточка "построить". На каком этаже герой - решает высота, где он стоит.
## Украшения на местах (сквозь поставленные не пройти, пустые места мерцают кружком), у станций и
## мест - карточка "home", дверь срабатывает вплотную.
## На лугу: у двери дома карточка "house" с кнопкой "Войти". Раз в 5 секунд - конец блюд и готовое с плиты.

## Дверь срабатывает ближе этого.
const PASSAGE_RADIUS := 26.0
## Отойти от двери дальше этого, чтобы она сработала снова.
const PASSAGE_REARM := 50.0
const STATION_RADIUS := 40.0
const SLOT_RADIUS := 26.0
const DOOR_RADIUS := 46.0
## Пролёт лестницы (tools/make_stairs.py): 32x84 пикселя, верх - на ряд выше этажа.
const FLIGHT := "hm_stair_flight"
const BOARDS := "hm_stair_boards"

var _in_house := false
var _slot_nodes: Array = []
var _obstacles: Array = []       ## {center, radius}
var _decor_signature := ""
var _floors_signature := ""
var _passage_armed := false
var _home_timer := 0.0
var _meal_timer := 0.0
var _prompt_key := ""
var _door_shown := false
var _trophy_nodes: Array = []
var _trophy_signature := ""


func build(world: World) -> void:
	_in_house = world.spec["kind"] == "home"
	_slot_nodes.clear()
	_obstacles.clear()
	_decor_signature = ""
	_passage_armed = false
	_home_timer = 0.0
	_trophy_nodes.clear()
	_trophy_signature = ""
	_floors_signature = _built_signature()
	if _in_house:
		_build_floors(world)
		_build_stairs(world)
		_sync_decor(world)
		_sync_trophies(world)


func clear(_w: World) -> void:
	_set_home_prompt({})
	_set_door(false)
	_slot_nodes.clear()
	_obstacles.clear()
	_decor_signature = ""
	_trophy_nodes.clear()
	_trophy_signature = ""
	_in_house = false


func process(world: World, dt: float) -> void:
	# Блюдо закончилось - убираем бонус; готовое с плиты - в запасы.
	_meal_timer -= dt
	if _meal_timer <= 0.0:
		_meal_timer = 5.0
		Game.house.refresh_meal()
	if _in_house:
		_update_home(world, dt)
	elif world.door_point != null:
		_set_door(world.player.position.distance_to(world.door_point) < DOOR_RADIUS)


## Сквозь поставленное украшение не пройти.
func resolve(_w: World, p: Vector2, radius: float) -> Vector2:
	var q := p
	for o in _obstacles:
		var c: Vector2 = o["center"]
		var min_d := float(o["radius"]) + radius
		var d := q.distance_to(c)
		if d >= min_d:
			continue
		q = c + Vector2(0, min_d) if d < 0.01 else c + (q - c) * (min_d / d)
	return q


func _built_signature() -> String:
	var parts: Array[String] = []
	for f in House.FLOORS:
		if Game.house.is_built(f):
			parts.append(f)
	return ",".join(parts)


# MARK: Этажи и лестницы

## Пол и стены каждого этажа. Непостроенный - тёмный силуэт с названием и уровнем.
func _build_floors(world: World) -> void:
	for f in House.FLOORS:
		var rect: Rect2 = world.layout.floor_rects[f]
		var built := Game.house.is_built(f)
		var loc := House.floor_location(f)
		var tex := Sprites.ground(loc)
		var node: CanvasItem
		if tex != null:
			var sprite := Sprite2D.new()
			sprite.texture = tex
			sprite.centered = false
			sprite.scale = rect.size / Vector2(tex.get_width(), tex.get_height())
			node = sprite
		else:
			# Без спрайтов пака: пол цветом этажа, стены темнее
			var box := ColorRect.new()
			box.size = rect.size
			box.color = Color(0.29, 0.17, 0.1)
			var floor_rect := ColorRect.new()
			floor_rect.position = Vector2(world.layout.cell, world.layout.cell * House.WALL_ROWS)
			floor_rect.size = rect.size - Vector2(world.layout.cell * 2, world.layout.cell * (House.WALL_ROWS + 1))
			floor_rect.color = Locations.spec(loc)["ground"]
			box.add_child(floor_rect)
			box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			floor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			node = box
		node.position = rect.position
		node.z_index = -10
		if not built:
			node.modulate = Color(0.2, 0.19, 0.24)
		world.flat.add_child(node)
		if not built:
			_locked_label(world, f, rect)


## Подпись на непостроенном этаже: молоток, название и с какого уровня.
func _locked_label(world: World, f: String, rect: Rect2) -> void:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size = Vector2(rect.size.x, 120)
	box.position = rect.get_center() - box.size / 2.0 + Vector2(0, 30)
	var lock := TextureRect.new()
	lock.texture = Sprites.icon("hammer")
	lock.custom_minimum_size = Vector2(36, 36)
	lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lock.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	lock.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(lock)
	var title := Label.new()
	title.text = House.floor_title(f)
	title.label_settings = Fx.label_settings(18, Color(1, 0.93, 0.75))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)
	var level := Label.new()
	level.text = L.t("common.needLevel", [House.floor_level(f)])
	level.label_settings = Fx.label_settings(13, Color(0.85, 0.8, 0.7))
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(level)
	box.z_index = -5
	world.flat.add_child(box)


## Пролёты лестниц: с ряда над этажом через его заднюю стену до пола. Если этаж выше или ниже не
## построен, пролёт заколочен досками (клетки там закрыты, см. MapLayout.house).
func _build_stairs(world: World) -> void:
	var cell := world.layout.cell
	for f in House.STAIRS:
		var up := House.floor_up(f)
		var lower := Game.house.is_built(f)
		var upper := Game.house.is_built(up)
		if not lower and not upper:
			continue
		var cols: Array = House.STAIRS[f]
		var top: float = world.layout.floor_rects[f].position.y - cell
		var pos := Vector2(float(cols[0]) * cell, top)
		var flight := Sprites.texture(FLIGHT)
		if flight != null:
			var s := Sprite2D.new()
			s.texture = flight
			s.centered = false
			s.scale = Vector2.ONE * Sprites.SCALE
			s.position = pos
			s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			if not (lower and upper):
				s.modulate = Color(0.55, 0.5, 0.5)
			world.flat.add_child(s)
		if lower and upper:
			continue
		var boards := Sprites.texture(BOARDS)
		if boards != null:
			var b := Sprite2D.new()
			b.texture = boards
			b.centered = false
			b.scale = Vector2.ONE * Sprites.SCALE
			b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			# Доски закрывают пролёт со стороны построенного этажа
			b.position = pos + Vector2(0, cell * (House.WALL_ROWS - 1.5) if lower else 0.0)
			world.flat.add_child(b)


# MARK: Украшения

## Украшения на местах: поставленные видны, пустые места отмечены кружком.
func _sync_decor(world: World) -> void:
	var parts: Array[String] = []
	for slot in world.layout.slots:
		var id := Game.house.decor_at(slot["id"])
		parts.append(id if id != "" else "-")
	var signature := ",".join(parts)
	if signature == _decor_signature:
		return
	_decor_signature = signature
	for n in _slot_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_slot_nodes.clear()
	_obstacles.clear()
	for slot in world.layout.slots:
		var pos: Vector2 = slot["pos"]
		var decor := Game.house.decor_at(slot["id"])
		var node: Node2D = Sprites.make(House.decor_sprite(decor), pos) if decor != "" else null
		if node != null:
			var flat := "rug" in House.decor_sprite(decor)
			(world.flat if flat else world.entities).add_child(node)
			_slot_nodes.append(node)
			if not flat:
				_obstacles.append({"center": pos + Vector2(0, -6), "radius": 13.0})
		else:
			_slot_nodes.append(_slot_mark(world, pos))


## Мерцающий кружок на пустом месте.
func _slot_mark(world: World, pos: Vector2) -> Node2D:
	var mark := RingFx.new()
	mark.radius = 13.0
	mark.width = 1.4
	mark.color = Color.WHITE
	mark.scale = Vector2(1.0, 0.5)
	mark.position = pos
	mark.modulate.a = 0.35
	world.flat.add_child(mark)
	var tw := mark.create_tween().set_loops()
	tw.tween_property(mark, "modulate:a", 0.15, 1.2)
	tw.tween_property(mark, "modulate:a", 0.4, 1.2)
	return mark


# MARK: Станции

## Этаж под героем становится текущим (без затемнения: карта одна). Дверь срабатывает вплотную,
## у лестницы к непостроенному этажу - карточка постройки, у остальных станций и мест - карточка.
func _update_home(world: World, dt: float) -> void:
	_home_timer -= dt
	if _home_timer > 0.0:
		return
	_home_timer = 0.12
	if _built_signature() != _floors_signature:
		_floors_signature = _built_signature()
		world.rebuild_here.call_deferred()
		return
	_sync_decor(world)
	_sync_trophies(world)
	var p := world.player.position
	var here := world.layout.floor_at(p)
	if here != "" and Game.house.is_built(here) and House.floor_location(here) != Game.current:
		Game.save["current"] = House.floor_location(here)
		Game.mark_dirty()
	var best := {}
	var best_d := INF
	var near_door := false
	for st in world.layout.stations:
		var kind: String = st["kind"]
		var d := p.distance_to(st["pos"])
		if kind == "exit":
			if d < PASSAGE_REARM:
				near_door = true
			if d < PASSAGE_RADIUS and _passage_armed:
				_passage_armed = false
				Game.house.leave_house()
				return
		elif kind == "up" or kind == "down":
			var target := House.floor_up(st["floor"]) if kind == "up" else House.floor_down(st["floor"])
			if target != "" and not Game.house.is_built(target) and d < STATION_RADIUS and d < best_d:
				best = {"type": "build", "floor": target}
				best_d = d
		elif d < STATION_RADIUS and d < best_d:
			best = {"type": "station", "kind": kind}
			best_d = d
	if not near_door:
		_passage_armed = true
	for slot in world.layout.slots:
		var d := p.distance_to(slot["pos"])
		if d < SLOT_RADIUS and d < best_d:
			best = {"type": "slot", "id": slot["id"]}
			best_d = d
	_set_home_prompt(best)


func _set_home_prompt(prompt: Dictionary) -> void:
	var key := HomeCard.key_of(prompt)
	if key == _prompt_key or Hud.current == null:
		return
	_prompt_key = key
	Hud.current.set_prompt("home", null if prompt.is_empty() else HomeCard.new(prompt))


## Карточка у двери дома на лугу.
func _set_door(on: bool) -> void:
	if on == _door_shown or Hud.current == null:
		return
	_door_shown = on
	Hud.current.set_prompt("house", HomeCard.new({"type": "door"}) if on else null)


## Трофеи висят на доске в гостиной: два ряда по три (порт syncTrophies).
func _sync_trophies(world: World) -> void:
	var board: Variant = null
	for p in world.layout.props:
		if p["name"] == "hm_trophy_board":
			board = p["pos"]
			break
	if board == null:
		return
	var earned: Array[String] = []
	for id in Trophies.IDS:
		if Trophies.is_earned(id):
			earned.append(id)
	var signature := ",".join(earned)
	if signature == _trophy_signature:
		return
	_trophy_signature = signature
	for n in _trophy_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_trophy_nodes.clear()
	var bp: Vector2 = board
	for i in Trophies.IDS.size():
		var id: String = Trophies.IDS[i]
		if not id in earned:
			continue
		# Сортируется сразу за доской, вверх поднят смещением кадра
		var node := Sprites.make(Trophies.sprite(id), Vector2(bp.x + float(i % 3 - 1) * 36.0, bp.y + 0.5))
		if node == null:
			continue
		node.offset.y -= (42.0 if i < 3 else 10.0) / Sprites.SCALE
		world.entities.add_child(node)
		_trophy_nodes.append(node)
