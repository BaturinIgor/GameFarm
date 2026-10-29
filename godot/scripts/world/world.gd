class_name World
extends Node2D
## Игровая сцена: карта локации, герой, точки добычи, склад и камера (порт GameScene).

const PLAYER_RADIUS := 11.0

## Части сцены из других систем (звери, монстры, огород, дом...). Порядок важен: так их вызывает World.
const FEATURES: Array[String] = [
	"res://scripts/world/features/animals_feature.gd",
	"res://scripts/world/features/treasure_feature.gd",
	"res://scripts/world/features/home_feature.gd",
]

@export var joystick: Joystick

var layout: MapLayout
var spec: Dictionary = {}
var loaded := ""

var ground := Sprite2D.new()
var flat := Node2D.new()        ## Лежит на земле: ковры, кувшинки, рыбные места
var entities := Node2D.new()    ## Всё, что сортируется по высоте
var fx := Node2D.new()          ## Эффекты поверх
var camera := Camera2D.new()
var player := Player.new()

var spots: Array[ResourceSpot] = []
var obstacles: Array = []       ## {center, radius}
var gates: Array[GateNode] = []
var house_rect := Rect2()
## Дверь дома на лугу (null, если дома нет): у неё карточка "войти".
var door_point = null
var chest: Node2D
var chest_box: Sprite2D

var velocity := Vector2.ZERO
var shake := 0.0
var _hit_timer := 0.0
var _hint_timer := 0.0
var _deposit_cooldown := 0.0
var _save_timer := 0.0
var _dust_timer := 0.0
var _loot: Array = []           ## {node, velocity, age}
var _transitioning := false
var _fader: ColorRect
var features: Array[WorldFeature] = []
var _titan_hits := 0
var _cornucopia_count := 0


func _ready() -> void:
	ground.centered = false
	ground.z_index = -20
	add_child(ground)
	flat.z_index = -10
	add_child(flat)
	entities.y_sort_enabled = true
	add_child(entities)
	fx.z_index = 100
	add_child(fx)
	add_child(camera)
	camera.make_current()
	for path in FEATURES:
		features.append(load(path).new())
	build(Game.current)


func set_fader(rect: ColorRect) -> void:
	_fader = rect


# MARK: Построение локации

func build(id: String) -> void:
	loaded = id
	spec = Locations.spec(id)
	layout = MapLayout.load_layout(id)
	for f in features:
		f.clear(self)
	# Героя сначала снимаем с карты, иначе он уйдёт вместе со старыми узлами
	if player.get_parent() != null:
		player.get_parent().remove_child(player)
	for n in [flat, entities, fx]:
		for c in n.get_children():
			c.queue_free()
	spots.clear()
	obstacles.clear()
	gates.clear()
	_loot.clear()
	house_rect = Rect2()
	door_point = null
	chest = null

	var bg: Color = spec["ground"]
	match layout.edge:
		"sea", "lava": bg = spec["water"]
		"void": bg = Color(0.03, 0.03, 0.03) if spec["dark"] else Color(0.66, 0.83, 1)
	if spec["kind"] == "home":
		bg = Color(0.09, 0.06, 0.04)
	RenderingServer.set_default_clear_color(bg)

	var tex := Sprites.ground(id)
	ground.texture = tex
	if tex != null:
		ground.scale = layout.size / Vector2(tex.get_width(), tex.get_height())

	_build_border()
	_build_props()
	if spec["kind"] != "home" and spec["kind"] != "dungeon":
		_build_base()
		_build_gates()

	for s in layout.spots:
		var spot := ResourceSpot.new(s["type"])
		spot.position = s["pos"]
		if Nodes.spec(s["type"])["tool"] == "rod":
			flat.add_child(spot)
		else:
			entities.add_child(spot)
		spots.append(spot)

	player.position = layout.base + Vector2(0, 56)
	if spec["kind"] == "home":
		# С улицы - у двери, чуть внутри комнаты; при смене этажа - у лестницы или в середине
		player.position = layout.base
		for st in layout.stations:
			if st["kind"] == Game.arrival_station:
				player.position = st["pos"] + Vector2(0, -52 if st["kind"] == "exit" else 0)
	elif spec["kind"] == "dungeon":
		player.position = layout.base
	elif Game.arrive_at_door and door_point != null:
		player.position = door_point + Vector2(0, 30)
	elif Game.arrival_gate != "":
		for g in layout.gates:
			if g["id"] == Game.arrival_gate:
				player.position = g["inner"]
	Game.arrival_gate = ""
	Game.arrival_station = ""
	Game.arrive_at_door = false
	velocity = Vector2.ZERO
	entities.add_child(player)
	for f in features:
		f.build(self)
	camera.position = _clamped_camera(player.position)
	camera.reset_smoothing()


func _build_border() -> void:
	for item in layout.border:
		var s := Sprites.make(item["name"], item["pos"])
		if s != null:
			entities.add_child(s)


const SOLID_PREFIXES := ["rock", "boulder", "log", "stump", "crystal_", "barrel", "hay_"]


func _build_props() -> void:
	var indoor: bool = spec["kind"] == "home"
	for item in layout.props:
		var name: String = item["name"]
		var s: Sprite2D = Sprites.make(name, item["pos"]) if indoor else Sprites.animated(name, 8.0, item["pos"])
		if s == null:
			continue
		var is_flat := name.begins_with("lily") or "rug" in name or name == "hm_doormat" or name == "hm_stairs_down"
		(flat if is_flat else entities).add_child(s)
		if item["fixed"]:
			obstacles.append({"center": item["pos"], "radius": 30.0})
		elif not indoor and _solid_prop(name):
			# Камни, брёвна и пни: сквозь них не пройти
			var w: float = s.texture.get_width() / float(s.hframes) * Sprites.SCALE
			var r := maxf(10.0, w * 0.32)
			obstacles.append({"center": item["pos"] - Vector2(0, r * 0.35), "radius": r})


func _solid_prop(name: String) -> bool:
	for p in SOLID_PREFIXES:
		if name.begins_with(p):
			return true
	return false


func _build_base() -> void:
	var base := layout.base
	var ring := RingFx.new()
	ring.position = base
	ring.radius = Game.stats.deposit_radius
	ring.dashed = true
	ring.color = Color(1, 1, 1, 0.5)
	ring.fill_alpha = 0.07
	flat.add_child(ring)

	# Дом стоит слева сверху от площадки склада. В экспедиции и на ивенте вместо дома палатка.
	var house_name := "tent" if spec["kind"] in ["expedition", "event"] else "house"
	var foot := base + Vector2(-60, -34)
	var house := Sprites.make(house_name, foot)
	if house != null:
		entities.add_child(house)
		var w := house.texture.get_width() * Sprites.SCALE * 0.84
		var hh := minf(46.0, house.texture.get_height() * Sprites.SCALE * 0.3)
		house_rect = Rect2(foot.x - w / 2.0, foot.y - hh, w, hh)
		if house_name == "house" and loaded == "meadow":
			door_point = foot + Vector2(0, 12)
		if house_name == "house":
			var smoke := Sprites.animated("smoke_anim", 6.0, foot + Vector2(house.texture.get_width() * Sprites.SCALE * 0.17,
				-house.texture.get_height() * Sprites.SCALE * 0.86))
			if smoke != null:
				smoke.modulate.a = 0.8
				fx.add_child(smoke)

	chest = Node2D.new()
	chest.position = base + Vector2(40, 4)
	entities.add_child(chest)
	chest_box = Sprites.make("chest_anim")
	if chest_box != null:
		chest.add_child(chest_box)
	var title := Label.new()
	title.text = L.t("scene.storage")
	title.label_settings = Fx.label_settings(13)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(160, 20)
	title.position = Vector2(-80, -58)
	chest.add_child(title)
	var tw := title.create_tween().set_loops()
	tw.tween_property(title, "position:y", -61.0, 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(title, "position:y", -58.0, 1.2).set_trans(Tween.TRANS_SINE)


func _build_gates() -> void:
	var stone: bool = spec["dark"] or layout.edge == "void" or spec["lava"] or loaded == "snow"
	for g in layout.gates:
		var node := GateNode.new()
		node.setup(g, _gate_open(g["id"]), layout.cell, stone)
		entities.add_child(node)
		gates.append(node)


func _gate_open(id: String) -> bool:
	return id in Game.save.get("openGates", [])


# MARK: Цикл

func _process(delta: float) -> void:
	var dt := minf(delta, 1.0 / 20.0)
	if not _transitioning and loaded != Game.current:
		_transition(Game.current)
	var stats := Game.stats
	if not _transitioning:
		_move_player(dt, stats)
		_gather(dt, stats)
		_check_base(dt, stats)
		_check_gates()
		for f in features:
			f.process(self, dt)
	for spot in spots:
		if spot.tick(dt) and spot.position.distance_to(player.position) < 500.0:
			Fx.scatter(fx, spot.position - Vector2(0, 20), 4, Color.WHITE, null, 4.0, 26, 16, 0.5)
	_update_loot(dt)
	_update_camera(dt)
	_save_timer += dt
	if _save_timer > 5.0:
		_save_timer = 0.0
		Game.save_if_needed()


func _transition(id: String) -> void:
	_transitioning = true
	if joystick:
		joystick.end()
	if _fader == null:
		build(id)
		_transitioning = false
		return
	_fader.visible = true
	var tw := create_tween()
	tw.tween_property(_fader, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_IN)
	tw.tween_callback(build.bind(id))
	tw.tween_interval(0.1)
	tw.tween_property(_fader, "modulate:a", 0.0, 0.45).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		_transitioning = false
		_fader.visible = false)


# MARK: Движение

func _move_player(dt: float, stats: Stats) -> void:
	var v: Vector2 = joystick.vector if joystick else Vector2.ZERO
	var max_speed := stats.speed
	var target := v * max_speed
	var accel := 1.0 - exp(-dt * (12.0 if v.length() > 0.05 else 16.0))
	velocity += (target - velocity) * accel
	var speed := velocity.length()
	if speed < 2.0:
		velocity = Vector2.ZERO
	if speed > 0.0:
		var p := player.position + velocity * dt
		var resolved := _resolve(p, PLAYER_RADIUS)
		# Упёрлись в препятствие: гасим скорость, чтобы не дрожать
		if resolved.distance_to(p) > 0.5:
			velocity = (resolved - player.position) / dt
		player.position = resolved
	var ratio := minf(1.0, speed / maxf(1.0, max_speed))
	player.animate(velocity, ratio, dt)
	_dust_timer -= dt
	if ratio > 0.55 and _dust_timer <= 0.0:
		_dust_timer = 0.17
		var dust: Color = Color(0.7, 0.7, 0.7) if spec["dark"] else spec["path"]
		Fx.puff(flat, player.position - Vector2(velocity.x * 0.04, 2), dust, 16.0, 5)


func _push_from(p: Vector2, c: Vector2, min_d: float) -> Vector2:
	var d := p.distance_to(c)
	if d >= min_d:
		return p
	if d < 0.01:
		return c + Vector2(0, min_d)
	return c + (p - c) * (min_d / d)


## Выталкивает круг из прямоугольника.
func _push_out(p: Vector2, r: Rect2, radius: float) -> Vector2:
	if r.size == Vector2.ZERO:
		return p
	var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
	var d := p.distance_to(q)
	if d >= radius:
		return p
	if d > 0.01:
		return q + (p - q) / d * radius
	# Центр внутри прямоугольника: выходим через ближайшую сторону
	var left := p.x - r.position.x
	var right := r.end.x - p.x
	var top := p.y - r.position.y
	var bottom := r.end.y - p.y
	var m := minf(minf(left, right), minf(top, bottom))
	if m == left:
		return Vector2(r.position.x - radius, p.y)
	if m == right:
		return Vector2(r.end.x + radius, p.y)
	if m == top:
		return Vector2(p.x, r.position.y - radius)
	return Vector2(p.x, r.end.y + radius)


func _resolve(point: Vector2, radius: float) -> Vector2:
	var p := point
	for _i in 2:
		var cr := layout.col_row(p)
		for dr in range(-1, 2):
			for dc in range(-1, 2):
				if not layout.walkable_cell(cr.x + dc, cr.y + dr):
					p = _push_out(p, layout.rect(cr.x + dc, cr.y + dr), radius)
	for spot in spots:
		if not spot.is_solid:
			continue
		if absf(spot.position.x - p.x) > 60.0 or absf(spot.position.y - p.y) > 60.0:
			continue
		p = _push_from(p, spot.position, spot.radius + radius)
	for g in gates:
		if not g.is_open:
			p = _push_out(p, g.block_rect, radius)
	for o in obstacles:
		var c: Vector2 = o["center"]
		if absf(c.x - p.x) > 80.0 or absf(c.y - p.y) > 80.0:
			continue
		p = _push_from(p, c, float(o["radius"]) + radius)
	p = _push_out(p, house_rect, radius)
	for f in features:
		p = f.resolve(self, p, radius)
	p.x = clampf(p.x, radius, layout.size.x - radius)
	p.y = clampf(p.y, radius, layout.size.y - radius)
	return p


func _clamped_camera(target: Vector2) -> Vector2:
	var view := get_viewport_rect().size
	var half := view / 2.0
	var world := layout.size
	var p := target
	p.x = clampf(p.x, half.x, world.x - half.x) if world.x > view.x else world.x / 2.0
	p.y = clampf(p.y, half.y - 40.0, world.y - half.y + 40.0) if world.y > view.y else world.y / 2.0
	return p


func _update_camera(dt: float) -> void:
	var target := _clamped_camera(player.position + velocity * 0.25)
	var k := 1.0 - exp(-dt * 5.5)
	var p := camera.position + (target - camera.position) * k
	if shake > 0.1:
		camera.offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
		shake *= exp(-dt * 14.0)
	else:
		shake = 0.0
		camera.offset = Vector2.ZERO
	camera.position = p


# MARK: Проходы

func _check_gates() -> void:
	for g in gates:
		var open := _gate_open(g.gate_id)
		if open != g.is_open:
			g.set_open(open)
		if g.is_open and g.passed(player.position):
			Game.travel(g.to, g.gate_id)
			return


# MARK: Добыча

func _gather(dt: float, stats: Stats) -> void:
	_hit_timer -= dt
	_hint_timer -= dt
	var full := not stats.auto_deposit and not Game.premium.in_expedition() and Game.backpack_free <= 0
	if _hit_timer > 0.0:
		return
	# Монстр рядом: сначала бой, потом добыча
	for f in features:
		if f.try_strike(self, stats):
			_hit_timer = stats.hit_interval
			return
	var best: ResourceSpot = null
	var best_d := INF
	var locked: ResourceSpot = null
	var locked_d := INF
	var reach := stats.reach
	for spot in spots:
		if not spot.alive:
			continue
		if absf(spot.position.x - player.position.x) > 140.0 or absf(spot.position.y - player.position.y) > 140.0:
			continue
		var d := spot.position.distance_to(player.position) - spot.radius
		if d > reach:
			continue
		if Game.can_harvest(spot.spec):
			if d < best_d:
				best = spot
				best_d = d
		elif d < locked_d:
			locked = spot
			locked_d = d
	if best != null:
		if full:
			if _hint_timer <= 0.0:
				_hint_timer = 2.5
				Fx.text(fx, L.t("scene.backpackFullHint"), player.position - Vector2(0, 70), Color(1, 0.45, 0.4), 15)
			return
		_strike(best, stats)
		_hit_timer = stats.hit_interval
	elif locked != null and _hint_timer <= 0.0:
		_hint_timer = 2.5
		Fx.text(fx, L.t("scene.needTool", [Tools.EMOJI.get(locked.spec["tool"], ""), locked.spec["tier"]]),
			locked.position - Vector2(0, float(locked.spec["bar"]) + 10), Color(1, 0.85, 0.4), 15)


func _strike(spot: ResourceSpot, stats: Stats) -> void:
	player.swing(spot.spec["tool"], spot.position, stats.hit_interval)
	_hit_once(spot, stats)
	# Топор и кирка высоких ступеней задевают соседний ресурс
	var gear: Dictionary = Game.combat.gear
	var tool: String = spot.spec["tool"]
	var cleave := float(gear.get("chopCleave", 0.0)) if tool == "axe" else (float(gear.get("mineCleave", 0.0)) if tool == "pickaxe" else 0.0)
	if cleave > 0.0 and randf() < cleave:
		var other: ResourceSpot = null
		var od := INF
		for o in spots:
			if o != spot and o.alive and o.spec["tool"] == tool and Game.can_harvest(o.spec):
				var d := o.position.distance_to(spot.position)
				if d < od:
					od = d
					other = o
		if other != null and od < 90.0:
			_apply(Game.damage_against(other.spec), other, false, false)
	if spot.alive and randf() < stats.double_strike_chance:
		get_tree().create_timer(0.12).timeout.connect(func() -> void:
			if is_instance_valid(spot) and spot.alive:
				Fx.text(fx, L.t("scene.doubleStrike"), spot.position + Vector2(-20, -56), Color(0.8, 0.9, 1), 13)
				_hit_once(spot, Game.stats))


func _hit_once(spot: ResourceSpot, stats: Stats) -> void:
	var damage := Game.damage_against(spot.spec)
	var crit := false
	if stats.titan:
		_titan_hits += 1
	if (stats.titan and _titan_hits % 4 == 0) or randf() < stats.crit_chance:
		damage *= stats.crit_mult
		crit = true
	if randf() < stats.shatter_chance:
		damage = maxf(damage, spot.hp)
		Fx.text(fx, L.t("scene.shatter"), spot.position - Vector2(0, 46), Color(0.6, 0.9, 1), 16)
	if crit:
		shake = maxf(shake, 5.0)
		Fx.text(fx, L.t("scene.crit"), spot.position + Vector2(18, -52), Color(1, 0.6, 0.2), 17)
		Input.vibrate_handheld(30)
	_apply(damage, spot, false, crit)
	if stats.quake:
		var shook := false
		for other in spots:
			if other == spot or not other.alive or not Game.can_harvest(other.spec):
				continue
			# С полным рюкзаком сотрясение не ломает соседние точки впустую
			if not (stats.auto_deposit or Game.premium.in_expedition() or Game.backpack_free > 0):
				break
			if other.position.distance_to(spot.position) < stats.quake_radius:
				_apply(damage * stats.quake_power, other, false, false)
				shook = true
		if shook:
			Fx.ring(fx, spot.position - Vector2(0, 6), Color(1, 1, 1, 0.6), stats.quake_radius * 0.7)


func _apply(damage: float, spot: ResourceSpot, by_helper: bool, strong: bool) -> void:
	if not spot.alive:
		return
	spot.hp -= damage
	var stats := Game.stats
	if stats.execute_threshold > 0.0 and spot.hp > 0.0 and spot.hp < float(spot.spec["hp"]) * stats.execute_threshold:
		spot.hp = 0.0
	spot.play_hit(strong)
	Fx.chips(fx, spot.position, spot.spec["chip"], 3 if by_helper else (8 if strong else 5))
	if spot.hp <= 0.0001:
		_harvest(spot, by_helper)
	else:
		spot.show_hp()


## Удар помощника (зверя) по точке.
func helper_hit(spot: ResourceSpot, damage: float) -> void:
	_apply(damage, spot, true, false)


func _harvest(spot: ResourceSpot, by_helper := false) -> void:
	var stats := Game.stats
	var roll := randf()
	var multiplier := 3 if roll < stats.triple_chance else (2 if roll < stats.triple_chance + stats.double_chance else 1)
	if stats.cornucopia and not by_helper:
		_cornucopia_count += 1
		if _cornucopia_count % 10 == 0:
			multiplier = 3
	var luck := 2 if Game.premium.luck_active() else 1
	var direct := Game.premium.in_expedition()
	var bonus := Game.premium.expedition_yield_bonus(loaded) if direct else 1.0
	var gained: Array = []
	for y in spot.spec["yields"]:
		if randf() >= float(y[3]):
			continue
		var raw := float(randi_range(int(y[1]), int(y[2]))) * stats.yield_multiplier(y[0]) * bonus
		if by_helper:
			raw *= stats.helper_yield
		var n := int(raw)
		if randf() < raw - n:
			n += 1
		n *= multiplier * luck
		if n > 0:
			gained.append([y[0], n])
	if spot.spec["tool"] == "pickaxe" and randf() < stats.gem_chance:
		gained.append(["diamond", 1])
	if randf() < stats.finder_chance:
		var here := _location_resources()
		if not here.is_empty():
			gained.append([here.pick_random(), randi_range(1, 3)])
	# Бонусы ступеней инструмента
	var bonus_coins := 0
	if not by_helper:
		var g: Dictionary = Game.combat.gear
		var chance := func(key: String) -> bool:
			var p := float(g.get(key, 0.0))
			return p > 0.0 and randf() < p
		match spot.spec["tool"]:
			"axe":
				if chance.call("honey"):
					gained.append(["honey", 1])
				if chance.call("goldenApple"):
					gained.append(["goldenApple", 1])
			"pickaxe":
				if chance.call("ruby"):
					gained.append(["ruby", 1])
				if chance.call("stardust"):
					gained.append(["stardust", 1])
			"rod":
				if chance.call("doubleCatch"):
					for it in gained:
						it[1] *= 2
				if chance.call("pearl"):
					gained.append(["pearl", 1])
				if chance.call("coinChest"):
					bonus_coins += 30 + Game.level * 8
					Game.show_toast("px:chest", L.t("toast.coinChest"))
				if chance.call("giantFish"):
					gained.append(["fish", 50])
					bonus_coins += 500 + Game.level * 40
					Game.show_toast("px:fish", L.t("toast.giantFish"))
					shake = maxf(shake, 8.0)
	if bonus_coins > 0:
		Game.add_coins(bonus_coins)
		Fx.text(fx, "+%s 🪙" % Fmt.n(bonus_coins), spot.position + Vector2(-30, -90), Color(1, 0.9, 0.4), 17)

	var shown: Array = []
	for g in gained:
		var added := Game.add_to_storage(g[0], g[1]) if (by_helper or direct) else Game.add_to_backpack(g[0], g[1])
		if added > 0:
			shown.append([g[0], added])
			if not by_helper:
				Game.collection.roll_card(g[0])
	var coins := Game.register_harvest(int(spot.spec["xp"]))
	var top := spot.position - Vector2(0, minf(70.0, float(spot.spec["bar"])))
	if spec["kind"] == "event":
		var pts := Game.events.points_for_node(spot.type)
		if pts > 0:
			var added_pts := Game.events.add_points(pts * multiplier)
			Fx.text(fx, "+%d" % added_pts, top + Vector2(-30, -26), Color(1, 0.95, 0.6), 13 if by_helper else 16, 0.1)
	if spot.type == "treasureChest":
		var chest_coins := 40 + Game.level * 12
		Game.add_coins(chest_coins)
		Game.premium.note_expedition_coins(chest_coins)
		Fx.text(fx, "+%s 🪙" % Fmt.n(chest_coins), spot.position - Vector2(0, 70), Color(1, 0.9, 0.4), 17)
	for i in shown.size():
		Fx.gain(fx, shown[i][0], shown[i][1], top - Vector2(0, i * 24), i * 0.1, by_helper)
		if not by_helper:
			_spawn_loot(shown[i][0], mini(shown[i][1], 4), top)
	if not by_helper and shown.is_empty() and not gained.is_empty():
		Fx.text(fx, L.t("scene.backpackFull"), top, Color(1, 0.45, 0.4), 15)
	if multiplier > 1 and not shown.is_empty():
		Fx.text(fx, "x%d!" % multiplier, top + Vector2(-36, -6), Color(0.5, 1, 0.5), 18)
	if coins > 0:
		Game.premium.note_expedition_coins(coins)
		Fx.text(fx, "+%d 🪙" % coins, top + Vector2(38, 4), Color(1, 0.9, 0.4), 14, 0.15)
	var respawn: float = float(spot.spec["respawn"]) * stats.respawn_mult
	if direct:
		respawn *= Game.premium.expedition_respawn_mult()
	if randf() < stats.regrow_chance:
		respawn = 1.2
	spot.deplete(respawn, player.position)
	_depletion_effects(spot)
	if not by_helper:
		Input.vibrate_handheld(15)


## Какие ресурсы можно добыть в этой локации (для "Находчивости").
func _location_resources() -> Array:
	var out: Array = []
	for t in layout.node_types():
		for y in Nodes.spec(t)["yields"]:
			if not y[0] in out:
				out.append(y[0])
	return out


func _depletion_effects(spot: ResourceSpot) -> void:
	var p := spot.position
	match spot.style:
		"fall":
			var side := 30.0 if spot.position.x >= player.position.x else -30.0
			var leaf := "fx_needle" if spot.type in ["snowPine", "pine"] else ("fx_leaf_birch" if spot.type == "skyTree" else "fx_leaf")
			var t := get_tree().create_timer(0.42)
			t.timeout.connect(func() -> void:
				Fx.scatter(fx, p + Vector2(side, -10), 6, Color.WHITE, Sprites.texture(leaf), 12.0, 46, 12)
				Fx.puff(flat, p + Vector2(side, 0), spec["path"], 36.0, 5)
				shake = maxf(shake, 2.5))
		"crumble":
			Fx.scatter(fx, p - Vector2(0, 16), 8, spot.spec["chip"], null, 6.0, 44, 20)
			Fx.puff(flat, p, Color(0.8, 0.8, 0.8), 40.0, 5)
		"splash":
			Fx.scatter(fx, p, 9, spot.spec["chip"], null, 5.0, 30, 26, 0.5)
			Fx.ring(flat, p, Color(1, 1, 1, 0.7), 20.0)
		_:
			Fx.scatter(fx, p - Vector2(0, 14), 5, Color.WHITE, null, 4.0, 30, 18, 0.45)


# MARK: Добыча летит к персонажу

func _spawn_loot(kind: String, count: int, from: Vector2) -> void:
	var tex := Res.icon(kind)
	if tex == null:
		return
	for i in count:
		var s := Sprite2D.new()
		s.texture = tex
		s.scale = Vector2.ONE * 18.0 / float(tex.get_width())
		s.position = from + Vector2(randf_range(-8, 8), 10)
		s.z_index = 60
		fx.add_child(s)
		var a := randf_range(0.3, PI - 0.3)
		var v := randf_range(110, 190)
		_loot.append({"node": s, "v": Vector2(cos(a) * v, -sin(a) * v), "age": 0.0})


func _update_loot(dt: float) -> void:
	if _loot.is_empty():
		return
	var target := player.position - Vector2(0, 22)
	var finished := false
	for item in _loot:
		item["age"] += dt
		var node: Sprite2D = item["node"]
		var v: Vector2 = item["v"]
		if item["age"] < 0.22:
			v.y += 600.0 * dt
			v.x *= exp(-dt * 3.0)
		else:
			var d := target - node.position
			var dist := maxf(1.0, d.length())
			var pull := 2400.0 * dt * minf(3.0, item["age"] * 2.0)
			v = v * exp(-dt * 6.0) + d / dist * pull
			if dist < 16.0 or item["age"] > 1.6:
				node.queue_free()
				item["age"] = -1.0
				finished = true
				continue
		item["v"] = v
		node.position += v * dt
	if finished:
		_loot = _loot.filter(func(it: Dictionary) -> bool: return it["age"] >= 0.0)


# MARK: Склад

func _check_base(dt: float, stats: Stats) -> void:
	_deposit_cooldown -= dt
	if _deposit_cooldown > 0.0 or Game.backpack_count <= 0 or chest == null:
		return
	if player.position.distance_to(layout.base) >= stats.deposit_radius:
		return
	var moved := Game.deposit_backpack()
	if moved <= 0:
		return
	_deposit_cooldown = 0.6
	Fx.text(fx, L.t("scene.deposited", [moved]), chest.position - Vector2(0, 64), Color(1, 0.9, 0.5), 16, 0.3)
	if chest_box is Sprite2D and chest_box.hframes > 1:
		var tw := create_tween()
		var last := chest_box.hframes - 1
		tw.tween_method(func(v: float) -> void: chest_box.frame = int(round(v)), 0.0, float(last), 0.05 * last)
		tw.tween_interval(0.4)
		tw.tween_method(func(v: float) -> void: chest_box.frame = int(round(v)), float(last), 0.0, 0.05 * last)
	var squash := create_tween()
	squash.tween_interval(0.4)
	squash.tween_property(chest, "scale", Vector2(1.2, 0.88), 0.07)
	squash.tween_property(chest, "scale", Vector2(0.94, 1.1), 0.08)
	squash.tween_property(chest, "scale", Vector2.ONE, 0.1)
	Fx.scatter(fx, chest.position - Vector2(0, 26), 6, Color(1, 0.9, 0.4), null, 5.0, 34, 24)
	Input.vibrate_handheld(25)
	Game.save_now()
