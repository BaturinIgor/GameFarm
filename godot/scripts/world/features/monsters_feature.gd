class_name MonstersFeature
extends WorldFeature
## Бой на карте (порт части GameScene: buildMonsters, nearestMonster, strikeMonster, damageMonster, updateMonsters,
## bitten, updatePets, faint): логова монстров в дальних частях локации, удары героя и питомцев, укусы,
## яд и замедление на герое, восстановление здоровья, обморок. Стражник у доски заказов и его карточка.
## Подземелье добавляет монстров волнами через spawn() (DungeonFeature).

const HUNT_PANEL := "res://scripts/ui/hunt_panel.gd"
const DUNGEON_PANEL := "res://scripts/ui/dungeon_panel.gd"

## Фича сцены: через неё подземелье добавляет монстров.
static var current: MonstersFeature
## Замедление героя от укуса: сколько ещё секунд.
static var hero_slow_left := 0.0

var slots: Array = []        ## {kind, level, point, node: MonsterNode или null, respawn}
var fainting := false

var _world: World
var _pet_cooldowns: Dictionary = {}
var _regen_timer := 0.0
var _since_hurt := 99.0
var _titan_hits := 0
var _poison_left := 0.0
var _poison_dps := 0.0
var _poison_tick := 0.0
var _guard_point = null      ## Vector2 или null
var _hunter_card: Control
var _hunter_badge := -1
var _hunter_lang := ""


func _init() -> void:
	current = self


## Во сколько раз медленнее идёт герой (укус с замедлением).
static func hero_speed_mult() -> float:
	return 0.65 if hero_slow_left > 0.0 else 1.0


func build(world: World) -> void:
	current = self
	_world = world
	slots.clear()
	_pet_cooldowns.clear()
	# Обморок мог прерваться сменой локации: начинаем с чистого листа
	fainting = false
	hero_slow_left = 0.0
	_poison_left = 0.0
	_guard_point = null
	Game.combat.set_in_combat(false)
	Game.combat.set_boss_info(null)
	var kind: String = world.spec["kind"]
	if kind != "home" and kind != "dungeon" and world.layout.board is Vector2:
		var hunter := HunterNode.new()
		hunter.position = world.layout.board
		world.entities.add_child(hunter)
		_guard_point = world.layout.board
	# Логова монстров в дальних частях локации. В подземелье монстры приходят волнами.
	if kind != "world":
		return
	var level := Monsters.level_in(world.loaded)
	for e in Monsters.in_location(world.loaded):
		for _i in int(e[1]):
			var p = _far_point(world)
			if p == null:
				continue
			slots.append({"kind": e[0], "level": level, "point": p, "node": null, "respawn": randf_range(0.5, 4.0)})


func clear(_w: World) -> void:
	slots.clear()
	_guard_point = null
	_set_hunter_card(false)


func process(world: World, dt: float) -> void:
	_update_monsters(world, dt, Game.stats)
	var near := false
	if _guard_point is Vector2:
		var gp: Vector2 = _guard_point
		near = gp.distance_to(world.player.position) < 90.0
	_set_hunter_card(near)


## Сквозь доску заказов не пройти.
func resolve(_w: World, p: Vector2, radius: float) -> Vector2:
	if not (_guard_point is Vector2):
		return p
	var gp: Vector2 = _guard_point
	var c := gp + HunterNode.OBSTACLE_OFFSET
	var min_d := HunterNode.OBSTACLE_RADIUS + radius
	var d := p.distance_to(c)
	if d >= min_d:
		return p
	if d < 0.01:
		return c + Vector2(0, min_d)
	return c + (p - c) * (min_d / d)


## Монстр рядом: сначала бой, потом добыча.
func try_strike(world: World, stats: Stats) -> bool:
	var foe := nearest_monster(stats.reach + 26.0, world.player.position)
	if foe == null:
		return false
	_strike_monster(world, foe, stats)
	return true


# MARK: Монстры

## Случайная точка суши далеко от склада и проходов (null - не нашлось).
func _far_point(world: World) -> Variant:
	var layout := world.layout
	for _i in 120:
		var c := randi_range(3, maxi(4, layout.cols - 3) - 1)
		var r := randi_range(3, maxi(4, layout.rows - 3) - 1)
		var cell := layout.at(c, r)
		if cell != MapLayout.Cell.LAND and cell != MapLayout.Cell.PATH:
			continue
		if not (layout.walkable_cell(c - 1, r) and layout.walkable_cell(c + 1, r)
				and layout.walkable_cell(c, r - 1) and layout.walkable_cell(c, r + 1)):
			continue
		var p := layout.center(c, r)
		if p.distance_to(layout.base) < 520.0:
			continue
		if world.gates.any(func(g: GateNode) -> bool: return p.distance_to(g.position) < 200.0):
			continue
		if world.spots.any(func(s: ResourceSpot) -> bool: return p.distance_to(s.position) < 50.0):
			continue
		if slots.any(func(s: Dictionary) -> bool: return p.distance_to(s["point"]) < 90.0):
			continue
		return p
	return null


## Монстр волны (подземелье): видит героя через всю арену, не возвращается домой и не появляется снова.
func spawn(kind: String, level: int, point: Vector2, monster_traits: Array, boss := false, tint = null) -> MonsterNode:
	var node := MonsterNode.new(kind, level, point, monster_traits, boss, tint)
	node.aggro_range = 900.0
	node.leash_range = 5000.0
	_world.entities.add_child(node)
	slots.append({"kind": kind, "level": level, "point": point, "node": node, "respawn": INF})
	return node


func any_alive() -> bool:
	for s in slots:
		var m = s["node"]
		if m != null and is_instance_valid(m) and m.alive:
			return true
	return false


## Убрать логова побеждённых (перед новой волной).
func clear_empty() -> void:
	slots = slots.filter(func(s: Dictionary) -> bool: return s["node"] != null)


func nearest_monster(reach: float, origin: Vector2) -> MonsterNode:
	var best: MonsterNode = null
	var best_d := INF
	for s in slots:
		var m: MonsterNode = s["node"]
		if m == null or not m.alive:
			continue
		var d := m.position.distance_to(origin)
		if d < reach and d < best_d:
			best = m
			best_d = d
	return best


func _strike_monster(world: World, foe: MonsterNode, stats: Stats) -> void:
	world.player.swing("sword", foe.position, stats.hit_interval)
	Sound.play("chop", 0.8)
	var damage: float = Game.combat.weapon_damage(foe.boss)
	var crit := false
	if stats.titan:
		_titan_hits += 1
	if (stats.titan and _titan_hits % 4 == 0) or randf() < stats.crit_chance:
		damage *= stats.crit_mult
		crit = true
		world.shake = maxf(world.shake, 4.0)
		Fx.text(world.fx, L.t("scene.crit"), foe.position + Vector2(16, -50), Color(1, 0.6, 0.2), 16)
	var weapon := str(Game.save.get("weapon", "forged"))
	var gear: Dictionary = Game.combat.gear
	var result := damage_monster(foe, damage, world.player.position, crit)
	if result == MonsterNode.Hit.DODGED:
		return
	# Свойства оружия
	match weapon:
		"slimeBlade":
			if randf() < 0.3:
				foe.apply_poison(damage * 0.4, 3.0)
		"frostBrand":
			foe.apply_slow(0.6, 2.0)
		"flameSword":
			foe.apply_poison(damage * 0.3, 2.0)
	if randf() < _perk(gear, "stun"):
		foe.stun(1.0)
	# Вампиризм не больше 12%, и один удар лечит не больше 3% здоровья
	var lifesteal := minf(0.12, _perk(gear, "lifesteal") + stats.lifesteal + (0.05 if weapon == "royalSword" else 0.0))
	if lifesteal > 0.0:
		Game.combat.heal_amount(minf(damage * lifesteal, Game.combat.max_hp() * 0.03))
	# Шипы монстра ранят героя, но не больше 5% здоровья за удар
	if "thorns" in foe.traits and not fainting:
		_hurt_hero(world, minf(damage * 0.15, Game.combat.max_hp() * 0.05), true)
	# Удар по области: орочий тесак или меч 7 ступени
	var cleave := maxf(_perk(gear, "sword_cleave"), 0.6 if weapon == "orcCleaver" else 0.0)
	if cleave > 0.0:
		for s in slots:
			var other: MonsterNode = s["node"]
			if other == null or other == foe or not other.alive or other.position.distance_to(foe.position) >= 70.0:
				continue
			damage_monster(other, damage * cleave, world.player.position, false)


## Урон монстру. Если он погиб - награда.
func damage_monster(foe: MonsterNode, damage: float, from: Vector2, strong: bool, quiet := false) -> MonsterNode.Hit:
	var w := _world
	var result := foe.hit(damage, from, not quiet)
	if result == MonsterNode.Hit.DODGED:
		Fx.text(w.fx, L.t("scene.dodge"), foe.position - Vector2(0, 48), Color(0.8, 0.9, 1), 14)
		return result
	if quiet:
		Fx.text(w.fx, "-%d" % int(round(damage)), foe.position + Vector2(14, -36), Color(0.6, 1, 0.5), 12)
	else:
		Fx.chips(w.fx, foe.position, Color(0.5, 0.85, 0.4) if Monsters.is_slime(foe.kind) else Color.WHITE, 7 if strong else 4)
	if result != MonsterNode.Hit.KILLED:
		return result
	# Событие kill для заданий и коллекции шлёт note_kill
	var reward: Dictionary = Game.combat.note_kill(foe.kind, foe.level, foe.boss)
	coins_fx(w.fx, int(reward.get("coins", 0)), foe.position - Vector2(0, 58), 15.0)
	var loot := int(reward.get("loot", 0))
	if loot > 0:
		Fx.gain(w.fx, Monsters.loot(foe.kind), loot, foe.position - Vector2(0, 34), 0.15)
	if foe.boss:
		w.shake = maxf(w.shake, 10.0)
		Fx.scatter(w.fx, foe.position - Vector2(0, 30), 16, Color(1, 0.85, 0.3), null, 6.0, 80.0, 50.0)
		Game.combat.set_boss_info(null)
	Sound.play("rockBreak", 0.7)
	Sound.play("coin", 0.6)
	for s in slots:
		if s["node"] == foe:
			s["node"] = null
			s["respawn"] = INF if w.spec["kind"] == "dungeon" or foe.boss else randf_range(35.0, 55.0)
	return result


func _update_monsters(world: World, dt: float, stats: Stats) -> void:
	_since_hurt += dt
	var combat := false
	var boss: MonsterNode = null
	var walk := world.layout.walkable
	var view := world.get_viewport_rect().size
	var cam := world.camera.position
	var hero := world.player.position
	for s in slots:
		var m: MonsterNode = s["node"]
		if m == null:
			s["respawn"] = float(s["respawn"]) - dt
			var point: Vector2 = s["point"]
			if float(s["respawn"]) <= 0.0 and point.distance_to(hero) > 260.0:
				m = MonsterNode.new(s["kind"], int(s["level"]), point, Monsters.roll_traits(int(s["level"])))
				world.entities.add_child(m)
				s["node"] = m
			continue
		# Далеко от камеры монстры стоят на месте.
		if absf(m.position.x - cam.x) >= view.x or absf(m.position.y - cam.y) >= view.y:
			continue
		var dot := m.tick_effects(dt)
		if dot > 0.0:
			damage_monster(m, dot, m.position, false, true)
		if not m.alive:
			continue
		if m.boss:
			boss = m
		var bite = m.update(dt, hero, walk)
		if m.position.distance_to(hero) < minf(m.aggro_range, 300.0):
			combat = true
		if bite != null and not fainting:
			_bitten(world, m, bite)
	if boss != null:
		var dungeon := Dungeons.of_location(world.loaded)
		var title := Dungeons.boss_name(dungeon) if world.spec["kind"] == "dungeon" and dungeon != "" \
			else Monsters.name_of(boss.kind)
		Game.combat.set_boss_info({"name": title, "fraction": boss.hp_fraction()})
	Game.combat.set_in_combat(combat)
	_update_pets(world, dt, stats)
	_update_hero_effects(world, dt)
	# Здоровье: понемногу восстанавливается, у склада быстро.
	_regen_timer -= dt
	if _regen_timer <= 0.0:
		_regen_timer = 1.0
		var regen := _perk(Game.combat.gear, "combat_regen") + stats.regen
		if world.spec["kind"] != "dungeon" and hero.distance_to(world.layout.base) < stats.deposit_radius:
			Game.combat.heal(0.15)
		elif _since_hurt > 6.0:
			Game.combat.heal(0.03)
		elif regen > 0.0:
			Game.combat.heal(regen)
	if float(Game.combat.hp) <= 0.0 and not fainting:
		_faint(world)


# MARK: Герой

## Монстр укусил: уклонение, шлем, яд, замедление, вампиризм, шипы брони.
func _bitten(world: World, m: MonsterNode, bite: Dictionary) -> void:
	var hero := world.player.position
	if randf() < Game.combat.dodge_chance():
		Fx.text(world.fx, L.t("scene.dodge"), hero - Vector2(0, 66), Color(0.8, 0.9, 1), 14)
		return
	var gear: Dictionary = Game.combat.gear
	var raw := float(bite["damage"])
	var crit := bool(bite["crit"]) and not _flag(gear, "crit_immune")
	var damage := raw if crit else (raw / 2.0 if bool(bite["crit"]) else raw)
	var dealt := _hurt_hero(world, damage, false, crit)
	var bite_traits: Array = bite["traits"]
	if "vampire" in bite_traits:
		m.heal(dealt * 0.5)
	if "slow" in bite_traits and not _flag(gear, "slow_immune"):
		hero_slow_left = 2.0
		var body := world.player.body
		var tw := body.create_tween()
		tw.tween_property(body, "modulate", Color(0.75, 0.875, 1.0), 0.1)
		tw.tween_interval(1.8)
		tw.tween_property(body, "modulate", Color.WHITE, 0.1)
	if "poison" in bite_traits and not _flag(gear, "poison_immune"):
		_poison_left = 3.0
		_poison_dps = raw * 0.15
	var thorns := _perk(gear, "thorns")
	if thorns > 0.0:
		damage_monster(m, raw * thorns, hero, false, true)


## Яд и замедление на герое.
func _update_hero_effects(world: World, dt: float) -> void:
	hero_slow_left = maxf(0.0, hero_slow_left - dt)
	if _poison_left <= 0.0 or fainting:
		return
	_poison_left -= dt
	_poison_tick -= dt
	if _poison_tick > 0.0:
		return
	_poison_tick = 0.5
	_hurt_hero(world, _poison_dps * 0.5, true)


## Урон герою: надпись, тряска и мигание. Возвращает, сколько здоровья ушло.
func _hurt_hero(world: World, amount: float, quiet := false, crit := false) -> float:
	_since_hurt = 0.0
	var dealt: float = Game.combat.hurt_hero(amount)
	var shown := int(round(dealt))
	Fx.text(world.fx, L.t("scene.critHit", [shown]) if crit else "-%d" % shown, world.player.position - Vector2(0, 64),
		Color(0.7, 1, 0.5) if quiet else Color(1, 0.35, 0.3), 18 if crit else 15)
	if quiet:
		return dealt
	world.shake = maxf(world.shake, 6.0 if crit else 3.0)
	Sound.play("crit", 0.5)
	var p := world.player
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 0.45, 0.05)
	tw.tween_property(p, "modulate:a", 1.0, 0.18)
	return dealt


## Питомцы рядом с героем тоже бьют монстров.
func _update_pets(world: World, dt: float, stats: Stats) -> void:
	var pets := _companions(world)
	if pets.is_empty() or not Game.combat.in_combat:
		return
	for node in pets:
		var c := node as CompanionNode
		if c == null or not is_instance_valid(c):
			continue
		var key := c.get_instance_id()
		var left := float(_pet_cooldowns.get(key, 0.0)) - dt
		_pet_cooldowns[key] = left
		if left > 0.0:
			continue
		var foe := nearest_monster(170.0, c.position)
		if foe == null:
			continue
		_pet_cooldowns[key] = 1.3
		var stars := Game.animals.stars(c.animal)
		var damage := 3.0 * stats.star_multiplier(maxi(1, stars)) * stats.animal_mult * (1.0 + 0.04 * float(Game.level)) \
			* Game.animals.boost(c.animal)
		_burst(world.fx, foe.position - Vector2(0, 16))
		damage_monster(foe, damage, c.position, false)


## Спутники героя из фичи зверей.
func _companions(world: World) -> Array:
	for f in world.features:
		if f == self:
			continue
		var list = f.get("companions")
		if list is Array:
			return list
	return []


## Здоровье кончилось: герой просыпается у склада. В подземелье забег заканчивается.
func _faint(world: World) -> void:
	fainting = true
	if world.joystick != null:
		world.joystick.end()
	var in_dungeon: bool = world.spec["kind"] == "dungeon"
	var middle := func() -> void:
		if in_dungeon:
			Game.combat.heal_full()
			Game.show_toast("px:spark", L.t("toast.dungeonLost"))
			Game.dungeons.leave_dungeon()
			return
		var lost: int = Game.combat.faint()
		world.player.position = world.layout.base + Vector2(0, 56)
		world.velocity = Vector2.ZERO
		world.camera.position = _clamped_camera(world, world.player.position)
		world.camera.reset_smoothing()
		Game.show_toast("px:spark", L.t("toast.fainted", [lost]) if lost > 0 else L.t("toast.faintedNoLoss"))
	ScreenFade.run(world, middle, 0.5, 0.3, 0.5, func() -> void: fainting = false)


static func _clamped_camera(world: World, target: Vector2) -> Vector2:
	var view := world.get_viewport_rect().size
	var half := view / 2.0
	var size := world.layout.size
	var p := target
	p.x = clampf(p.x, half.x, size.x - half.x) if size.x > view.x else size.x / 2.0
	p.y = clampf(p.y, half.y - 40.0, size.y - half.y + 40.0) if size.y > view.y else size.y / 2.0
	return p


# MARK: Стражник

## Карточка у стражника (PlaceCard для охоты): заказы и счётчик готовых.
func _set_hunter_card(on: bool) -> void:
	if Hud.current == null:
		return
	if not on:
		if _hunter_card != null:
			_hunter_card = null
			Hud.current.set_prompt("hunter", null)
		return
	var badge := int(Game.combat.claimable_hunts())
	if _hunter_card != null and is_instance_valid(_hunter_card) and badge == _hunter_badge and L.code == _hunter_lang:
		return
	_hunter_badge = badge
	_hunter_lang = L.code
	_hunter_card = _make_hunter_card(badge)
	Hud.current.set_prompt("hunter", _hunter_card)


func _make_hunter_card(badge: int) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.panel_style(18))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	p.add_child(row)
	var face := TraderPanel.portrait("guard", 52)
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(face)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	col.add_child(UiKit.label(L.t("hunt.guard"), 15))
	var sub := UiKit.label(L.t("hunt.hint"), 12, UiKit.INK_SOFT)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(sub)
	var b := UiKit.button(L.t("hunt.open"), "red")
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void: MonstersFeature.open_hunt())
	row.add_child(b)
	if badge > 0:
		var count := UiKit.count_badge(badge)
		count.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		count.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		count.offset_left = -14
		count.offset_right = 6
		count.offset_top = -8
		count.offset_bottom = 12
		b.add_child(count)
	return p


## Окно стражника: заказы и подземелья. Пока окна охоты нет - сразу окно подземелий.
static func open_hunt() -> void:
	if Hud.current == null:
		return
	var path := HUNT_PANEL if ResourceLoader.exists(HUNT_PANEL) else DUNGEON_PANEL
	if ResourceLoader.exists(path):
		Hud.current.open_window(load(path).new())


# MARK: Помощники

## Бонус снаряжения (поля GearPerks в snake_case).
static func _perk(gear: Dictionary, key: String) -> float:
	return float(gear.get(key, 0.0))


static func _flag(gear: Dictionary, key: String) -> bool:
	return bool(gear.get(key, false))


## "+12" и монета (Effects.coins).
static func coins_fx(parent: Node, amount: int, pos: Vector2, size := 15.0, delay := 0.0) -> void:
	if parent == null:
		return
	var holder := Node2D.new()
	holder.position = pos
	holder.z_index = 50
	holder.modulate.a = 0.0
	holder.scale = Vector2.ONE * 0.6
	parent.add_child(holder)
	var label := Label.new()
	label.text = "+%d" % amount
	label.label_settings = Fx.label_settings(int(size), Color(1, 0.88, 0.35))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(160, size * 1.6)
	label.position = Vector2(2.0 - 160.0, -size * 0.8)
	holder.add_child(label)
	var tex := Sprites.icon("coin")
	if tex != null:
		var icon := Sprite2D.new()
		icon.texture = tex
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.scale = Vector2.ONE * size * 1.3 / float(maxi(1, tex.get_width()))
		icon.position = Vector2(4.0 + size * 0.65, 0)
		holder.add_child(icon)
	var tw := holder.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(holder, "modulate:a", 1.0, 0.08)
	tw.parallel().tween_property(holder, "scale", Vector2.ONE, 0.12)
	tw.parallel().tween_property(holder, "position:y", pos.y - 42.0, 0.9)
	tw.tween_property(holder, "modulate:a", 0.0, 0.25)
	tw.tween_callback(holder.queue_free)


## Вспышка удара питомца (Effects.burst): шесть искр во все стороны.
static func _burst(parent: Node, pos: Vector2) -> void:
	var tex := Sprites.icon("spark")
	for i in 6:
		var s := Sprite2D.new()
		s.texture = tex if tex != null else Fx.dot_texture()
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var k := 18.0 / float(maxi(1, s.texture.get_width()))
		s.scale = Vector2.ONE * k
		s.modulate = Color(1, 0.75, 0.3)
		s.position = pos
		s.z_index = 50
		parent.add_child(s)
		var a := float(i) / 6.0 * TAU + 0.3
		var tw := s.create_tween().set_parallel()
		tw.tween_property(s, "position", pos + Vector2(cos(a), -sin(a)) * 40.0, 0.45)
		tw.tween_property(s, "modulate:a", 0.0, 0.5)
		tw.tween_property(s, "scale", Vector2.ONE * k * 0.5, 0.5)
		tw.chain().tween_callback(s.queue_free)
