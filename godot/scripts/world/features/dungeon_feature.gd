class_name DungeonFeature
extends WorldFeature
## Забег по подземелью (порт updateDungeon, spawnWave, spawnDungeonRewards и openChest из GameScene):
## волны монстров и босс, сундук и портал на арене, спуск на следующий этаж. Монстров ведёт MonstersFeature,
## поэтому в World.FEATURES эта фича идёт после неё. Итог забега после выхода показывает DungeonReport.

## Пауза перед следующей волной.
const WAVE_DELAY := 1.6

var _wave_timer := WAVE_DELAY
var _chest: Node2D
var _chest_box: Sprite2D
var _portal: Node2D
var _built_version := 0
var _rebuilding := false


func build(_w: World) -> void:
	_wave_timer = WAVE_DELAY
	_chest = null
	_chest_box = null
	_portal = null
	_built_version = Game.dungeons.map_version
	_rebuilding = false


func clear(_w: World) -> void:
	_chest = null
	_chest_box = null
	_portal = null


## Волны монстров, сундук и портал на арене.
func process(world: World, dt: float) -> void:
	DungeonReport.present_pending()
	var run = Game.dungeons.run
	var monsters := MonstersFeature.current
	if world.spec["kind"] != "dungeon" or run == null or monsters == null or monsters.fainting:
		return
	# Спуск на следующий этаж: арена строится заново
	if _built_version != Game.dungeons.map_version:
		if not _rebuilding:
			_rebuilding = true
			if world.joystick != null:
				world.joystick.end()
			ScreenFade.run(world, func() -> void: world.build(world.loaded))
		return
	var hero := world.player.position
	if run["cleared"]:
		if _chest != null and not run["chest_opened"] and _chest.position.distance_to(hero) < 44.0:
			_open_chest(world)
		if _portal != null and _portal.position.distance_to(hero) < 34.0:
			if not run["chest_opened"] and _chest != null:
				_open_chest(world)
			Game.dungeons.leave_dungeon()
		return
	if monsters.any_alive():
		return
	if int(run["wave"]) >= int(run["waves"]):
		Game.dungeons.dungeon_cleared()
		_spawn_rewards(world)
		return
	_wave_timer -= dt
	if _wave_timer > 0.0:
		return
	_wave_timer = WAVE_DELAY
	var next := int(run["wave"]) + 1
	_spawn_wave(world, monsters, next, run)
	Game.dungeons.set_dungeon_wave(next)


func _spawn_wave(world: World, monsters: MonstersFeature, n: int, run: Dictionary) -> void:
	monsters.clear_empty()
	var id: String = run["dungeon"]
	var floor_n := int(run["floor"])
	var level := Dungeons.monster_level(id, floor_n)
	var boss_wave := Dungeons.is_boss_floor(floor_n) and n == int(run["waves"])
	var hero := world.player.position
	var all: Array = world.layout.slots.map(func(s: Dictionary) -> Vector2: return s["pos"])
	var points := all.filter(func(p: Vector2) -> bool: return p.distance_to(hero) > 150.0)
	if points.is_empty():
		points = all.duplicate()
	points.shuffle()
	var mobs := Dungeons.mobs(id)
	if boss_wave:
		var top := Vector2(world.layout.size.x / 2.0, world.layout.cell * 7.0)
		_add(world, monsters, Dungeons.boss(id), level, top, true, Monsters.pick_traits(Dungeons.boss_traits(floor_n)),
			Dungeons.boss_tint(id))
		for p in points.slice(0, 2):
			_add(world, monsters, mobs.pick_random(), level, p, false, [], null)
		Game.show_toast("px:crown", L.t("toast.bossWave", [Dungeons.boss_name(id)]))
		Sound.play("wildAppear")
		world.shake = maxf(world.shake, 6.0)
	else:
		for p in points.slice(0, Dungeons.monsters_per_wave(floor_n)):
			_add(world, monsters, mobs.pick_random(), level, p, false, Monsters.pick_traits(Dungeons.traits(floor_n)), null)
		Game.show_toast("px:sword", L.t("toast.wave", [n, run["waves"]]))


func _add(world: World, monsters: MonstersFeature, kind: String, level: int, p: Vector2, boss: bool, traits: Array,
		tint) -> void:
	monsters.spawn(kind, level, p, traits, boss, tint)
	Fx.puff(world.fx, p, Color(0.85, 0.85, 0.85), 80.0 if boss else 40.0)


## Сундук в середине арены и портал наверху.
func _spawn_rewards(world: World) -> void:
	var size := world.layout.size
	var center := Vector2(size.x / 2.0, size.y * 0.52)
	_chest = Node2D.new()
	_chest.position = center
	_chest.scale = Vector2.ONE * 0.2
	world.entities.add_child(_chest)
	_chest.add_child(Fx.glow(Color(1, 0.85, 0.3), 110.0, 14.0, 0.45))
	_chest_box = Sprites.make("chest_gold_anim")
	if _chest_box != null:
		_chest.add_child(_chest_box)
	_chest.create_tween().tween_property(_chest, "scale", Vector2.ONE * 1.4, 0.3)
	_portal = Node2D.new()
	_portal.position = Vector2(size.x / 2.0, world.layout.cell * 4.6)
	world.flat.add_child(_portal)
	var art := Sprites.make("dg_portal")
	if art != null:
		var fs := Vector2(art.texture.get_width() / float(art.hframes), art.texture.get_height() / float(art.vframes))
		art.offset = Sprites.anchor_offset(Vector2(0.5, 0.5), fs)
		_portal.add_child(art)
		var base := art.scale
		var pulse := art.create_tween().set_loops()
		pulse.tween_property(art, "scale", base * 1.12, 0.6)
		pulse.tween_property(art, "scale", base * 0.95, 0.6)
	_portal.add_child(Fx.glow(Color(0.7, 0.45, 1), 120.0, 0.0, 0.5))
	Fx.scatter(world.fx, center, 14, Color.WHITE, null, 5.0, 70.0, 40.0)


func _open_chest(world: World) -> void:
	Game.dungeons.open_dungeon_chest()
	if _chest_box != null and _chest_box.hframes > 1:
		var box := _chest_box
		var last := box.hframes - 1
		box.create_tween().tween_method(func(v: float) -> void: box.frame = int(round(v)), 0.0, float(last), 0.06 * last)
	var at := _chest.position
	Fx.scatter(world.fx, at - Vector2(0, 20), 14, Color.WHITE, Sprites.icon("coin"), 18.0, 70.0, 40.0, 0.8)
	var chest = Game.dungeons.last_chest
	if chest != null:
		MonstersFeature.coins_fx(world.fx, int(chest["coins"]), at - Vector2(0, 70), 18.0)
