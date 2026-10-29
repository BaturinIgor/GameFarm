extends WorldFeature
## Дом в сцене (порт buildHome, syncDecor, updateHome и двери из updatePlaces в GameScene).
## Внутри дома: украшения на местах (сквозь поставленные не пройти, пустые места мерцают кружком),
## лестницы и дверь срабатывают вплотную, у остальных станций и мест - карточка "home".
## На лугу: у двери дома карточка "house" с кнопкой "Войти". Раз в 5 секунд - конец блюд и готовое с плиты.

## Лестница или дверь срабатывает ближе этого.
const PASSAGE_RADIUS := 26.0
## Отойти от лестницы дальше этого, чтобы она сработала снова.
const PASSAGE_REARM := 50.0
const STATION_RADIUS := 40.0
const SLOT_RADIUS := 26.0
const DOOR_RADIUS := 46.0

var _floor := ""
var _slot_nodes: Array = []
var _obstacles: Array = []       ## {center, radius}
var _decor_signature := ""
var _passage_armed := false
var _home_timer := 0.0
var _meal_timer := 0.0
var _prompt_key := ""
var _door_shown := false


func build(world: World) -> void:
	_floor = House.floor_of(world.loaded) if world.spec["kind"] == "home" else ""
	_slot_nodes.clear()
	_obstacles.clear()
	_decor_signature = ""
	_passage_armed = false
	_home_timer = 0.0
	if _floor != "":
		_sync_decor(world)


func clear(_w: World) -> void:
	_set_home_prompt({})
	_set_door(false)
	_slot_nodes.clear()
	_obstacles.clear()
	_decor_signature = ""
	_floor = ""


func process(world: World, dt: float) -> void:
	# Блюдо закончилось - убираем бонус; готовое с плиты - в запасы.
	_meal_timer -= dt
	if _meal_timer <= 0.0:
		_meal_timer = 5.0
		Game.house.refresh_meal()
	if _floor != "":
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

## Лестницы и дверь срабатывают, когда герой подходит вплотную; у остальных станций - карточка.
func _update_home(world: World, dt: float) -> void:
	_home_timer -= dt
	if _home_timer > 0.0:
		return
	_home_timer = 0.12
	_sync_decor(world)
	var p := world.player.position
	var best := {}
	var best_d := INF
	var near_passage := false
	for st in world.layout.stations:
		var kind: String = st["kind"]
		var d := p.distance_to(st["pos"])
		if House.is_passage(kind):
			if d < PASSAGE_REARM:
				near_passage = true
			if d >= PASSAGE_RADIUS:
				continue
			if kind == "exit":
				if _passage_armed:
					_passage_armed = false
					Game.house.leave_house()
					return
				continue
			var target := House.floor_up(_floor) if kind == "up" else House.floor_down(_floor)
			if target == "":
				continue
			if Game.house.is_built(target):
				if _passage_armed:
					_passage_armed = false
					Game.house.go_floor(target, kind)
					return
			elif d < best_d:
				best = {"type": "build", "floor": target}
				best_d = d
		elif d < STATION_RADIUS and d < best_d:
			best = {"type": "station", "kind": kind}
			best_d = d
	if not near_passage:
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
