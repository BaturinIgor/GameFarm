class_name EventFeature
extends WorldFeature
## Карта ивента (порт checkEvent, updateEventStage, spawnEventBoss, makePortal и ивентовой части buildMonsters,
## updateMonsters, damageMonster и faint из GameScene): монстры праздника с силой по этапу, босс этапа, портал
## на следующий этап и выбор усиления, новая карта при смене этапа, конец ивента и возврат домой.
## Монстров ведёт MonstersFeature, поэтому в World.FEATURES эта фича идёт после неё: логова ивента лежат
## в MonstersFeature.slots, но появляются здесь (свойства монстров зависят от этапа).

## Пауза между проверками, не кончился ли ивент.
const CHECK_INTERVAL := 1.0

var _world: World
## Логова ивента: те же словари, что в MonstersFeature.slots. Пока монстра нет, respawn там бесконечный,
## а своё ожидание - в event_respawn.
var _slots: Array = []
var _boss: MonsterNode
var _portal: Node2D
var _picker: Control
var _built_version := 0
var _rebuilding := false
var _check_timer := 0.0
var _was_event := false
var _was_fainting := false


func _init() -> void:
	Game.event.connect(_on_game_event)


func build(world: World) -> void:
	_world = world
	_slots.clear()
	_boss = null
	_portal = null
	_built_version = Game.events.map_version
	_rebuilding = false
	_was_fainting = false
	var is_event: bool = world.spec["kind"] == "event"
	# Усиления ивента включаются и выключаются вместе с его картой
	if is_event != _was_event:
		_was_event = is_event
		Game.recalc()
	if is_event:
		_build_monsters(world)


func clear(_w: World) -> void:
	_slots.clear()
	_boss = null
	_portal = null


func process(world: World, dt: float) -> void:
	_check_event(world, dt)
	if world.spec["kind"] != "event":
		_built_version = Game.events.map_version
		return
	var monsters := MonstersFeature.current
	if monsters == null or world.loaded != Game.current:
		return
	# Следующий этап: карта строится заново
	if _built_version != Game.events.map_version:
		if not _rebuilding:
			_rebuilding = true
			if world.joystick != null:
				world.joystick.end()
			ScreenFade.run(world, func() -> void: world.build(world.loaded))
		return
	# Упал без сил на этапе: теряется четверть прогресса
	if monsters.fainting and not _was_fainting:
		Game.events.event_faint()
	_was_fainting = monsters.fainting
	_respawn(world, dt)
	_update_stage(world, monsters)
	_update_picker()


# MARK: Конец ивента

## Ивент закончился, пока герой на его карте: возвращаемся домой.
func _check_event(world: World, dt: float) -> void:
	_check_timer -= dt
	if _check_timer > 0.0:
		return
	_check_timer = CHECK_INTERVAL
	Game.events.sync_event()
	if world.spec["kind"] == "event" and not Game.events.is_unlocked(world.loaded):
		Game.show_toast("px:hourglass", L.t("toast.eventOver"))
		Game.events.leave_event()


# MARK: Монстры

## Логова праздника в дальних частях карты: больше и сильнее с каждым этапом.
func _build_monsters(world: World) -> void:
	var monsters := MonstersFeature.current
	var event := Events.event_of_location(world.loaded)
	if monsters == null or event == "":
		return
	var stage := Game.events.event_stage()
	var level := Events.monster_level(Game.level, stage)
	for e in Events.monsters(event):
		for _i in Events.monster_count(int(e[1]), stage):
			var p = monsters._far_point(world)
			if p == null:
				continue
			var slot := {"kind": e[0], "level": level, "point": p, "node": null, "respawn": INF,
				"event_respawn": randf_range(0.5, 4.0)}
			monsters.slots.append(slot)
			_slots.append(slot)


## Монстры ивента появляются снова с особыми свойствами по этапу.
func _respawn(world: World, dt: float) -> void:
	var hero := world.player.position
	for s in _slots:
		if s["node"] != null:
			continue
		# Монстра только что победили: MonstersFeature назначила ожидание, забираем его себе
		if float(s["respawn"]) != INF:
			s["event_respawn"] = s["respawn"]
			s["respawn"] = INF
		s["event_respawn"] = float(s["event_respawn"]) - dt
		var point: Vector2 = s["point"]
		if float(s["event_respawn"]) > 0.0 or point.distance_to(hero) <= 260.0:
			continue
		var traits := Monsters.pick_traits(Events.traits(Game.events.event_stage()))
		var m := MonsterNode.new(s["kind"], int(s["level"]), point, traits)
		world.entities.add_child(m)
		s["node"] = m


## Очки за монстра над ним (как в damageMonster): победа уже учтена в Game.events.on_event.
func _on_game_event(name: String, data: Dictionary) -> void:
	if name != "kill" or _world == null or not is_instance_valid(_world) or _world.spec["kind"] != "event":
		return
	var monsters := MonstersFeature.current
	if monsters == null:
		return
	var boss := bool(data.get("boss", false))
	var base := Game.events.event_points_for_monster(str(data.get("monster", "")), boss)
	var shown := base if boss else int(round(float(base) * (1.0 + Game.events.boon_value("points"))))
	# Побеждённый ещё лежит в своём логове: MonstersFeature освобождает его после награды
	for s in monsters.slots:
		var m = s["node"]
		if m != null and is_instance_valid(m) and not m.alive:
			Fx.text(_world.fx, "+%d" % shown, m.position - Vector2(0, 80), Color(1, 0.95, 0.6), 16, 0.2)
			return


# MARK: Этапы

## Босс этапа и портал на следующий этап.
func _update_stage(world: World, monsters: MonstersFeature) -> void:
	var event := Events.event_of_location(world.loaded)
	if monsters.fainting or event == "":
		return
	var ev := Game.events
	if ev.event_boss_due() and (_boss == null or not is_instance_valid(_boss) or not _boss.alive):
		_spawn_boss(world, monsters, event)
	if not ev.event_stage_cleared():
		return
	if _portal == null:
		_portal = _make_portal(world, world.layout.base - Vector2(0, 60))
	if Game.save.get("eventChoice", []).is_empty() and _portal.position.distance_to(world.player.position) < 34.0:
		ev.enter_event_portal()


func _spawn_boss(world: World, monsters: MonstersFeature, event: String) -> void:
	var stage := Game.events.event_stage()
	var level := Events.monster_level(Game.level, stage) + 2
	var p = monsters._far_point(world)
	var point: Vector2 = p if p is Vector2 else Vector2(world.layout.size.x / 2.0, world.layout.size.y * 0.4)
	var kind := Events.boss(event)
	_boss = monsters.spawn(kind, level, point, Monsters.pick_traits(Events.boss_traits(stage)), true, Events.COLORS[event][1])
	Fx.puff(world.fx, point, Color(0.85, 0.85, 0.85), 80.0)
	Game.show_toast("px:crown", L.t("toast.stageBoss", [Monsters.name_of(kind)]))
	world.shake = maxf(world.shake, 6.0)


## Портал: картинка с подземелий и фиолетовое свечение.
func _make_portal(world: World, point: Vector2) -> Node2D:
	var portal := Node2D.new()
	portal.position = point
	world.flat.add_child(portal)
	var art := Sprites.make("dg_portal")
	if art != null:
		var fs := Vector2(art.texture.get_width() / float(art.hframes), art.texture.get_height() / float(art.vframes))
		art.offset = Sprites.anchor_offset(Vector2(0.5, 0.5), fs)
		portal.add_child(art)
		var base := art.scale
		var pulse := art.create_tween().set_loops()
		pulse.tween_property(art, "scale", base * 1.12, 0.6)
		pulse.tween_property(art, "scale", base * 0.95, 0.6)
	portal.add_child(Fx.glow(Color(0.7, 0.45, 1), 120.0, 0.0, 0.5))
	Fx.scatter(world.fx, point, 14, Color.WHITE, null, 5.0, 70.0, 40.0)
	return portal


## После этапа: окно выбора усиления поверх игры (EventBoonPicker).
func _update_picker() -> void:
	if Game.save.get("eventChoice", []).is_empty() or Hud.current == null:
		return
	if _picker != null and is_instance_valid(_picker):
		return
	_picker = EventsPanel.BoonPicker.new()
	Hud.current.show_overlay(_picker)
