class_name RaceScene
extends Control
## Поле гонки к Сердцу долины во весь экран (поверх фермы, ферма в это время стоит).
## Карта 3x3: свой угол, перешеек, ядро с Сердцем. Герой ходит джойстиком и сам бьёт ближайшую точку,
## у торговца, ворот и старца снизу появляется карточка с действиями. Странники идут по своим углам.
## Правила - RaceRun (Game.race.run()), карта - Race. Закрыть поле можно в любой момент: время идёт.

const R := 11.0
const SPEED := 150.0
const REACH := 46.0
## Насколько близко подойти к торговцу, воротам, старцу, чтобы появилась карточка.
const TALK := 96.0
const FIGHT := 92.0

var run: RaceRun
var seat := 0

var _world := Node2D.new()
var _ground := Node2D.new()
var _flat := Node2D.new()
var _entities := Node2D.new()
var _fx := Node2D.new()
var _player := Player.new()
var _joy := Joystick.new()
var _cam := Vector2.ZERO
var _vel := Vector2.ZERO

## Точки добычи: [{spot, def (Race.spots), node (ключ Race.NODES или vein0/vein1)}].
var _spots: Array = []
## Ворота всех мест: [[GateArt, GateArt, GateArt], ...] по месту.
var _gates: Array = []
var _guards: Array = []
var _rivals: Dictionary = {}
var _heart: HeartArt
var _hit_cd := 0.0
var _hint_cd := 0.0
var _save_cd := 0.0
var _ui_cd := 0.0
## Бой со стражем: номер ворот (-1 - нет боя), здоровье героя, перезарядки.
var _fight := -1
var _hp := 20.0
var _guard_cd := 0.0
var _down := 0.0
## Какая карточка открыта снизу ("" - никакой): trader0..2, gate, elder.
var _card_key := ""
var _over := false

var _top := VBoxContainer.new()
var _timer_label: Label
var _board := VBoxContainer.new()
var _bottom := VBoxContainer.new()
var _card := PanelContainer.new()
var _card_col := VBoxContainer.new()
var _bag_row := HFlowContainer.new()
var _stat_label: Label
var _hp_bar: GameBar
var _end_layer := CenterContainer.new()


static func launch() -> RaceScene:
	if Hud.current == null or Game.race.run() == null:
		return null
	var s := RaceScene.new()
	Hud.current.show_overlay(s)
	return s


func _ready() -> void:
	run = Game.race.run()
	seat = run.seat
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color("2c3b25")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	add_child(_world)
	_world.add_child(_ground)
	_flat.z_index = -5
	_world.add_child(_flat)
	_entities.y_sort_enabled = true
	_world.add_child(_entities)
	_fx.z_index = 100
	_world.add_child(_fx)
	_build_map()
	_hp = run.hero_hp()
	_player.position = _spawn_point()
	_entities.add_child(_player)
	_cam = _player.position
	add_child(_joy)
	_build_ui()
	if run.decided(Clock.now()):
		_show_end()


# MARK: Карта

func _build_map() -> void:
	# Земля: в каждой клетке кусок земли локации фермы (углы - свои биомы, перешейки и ядро - общие)
	for x in 3:
		for y in 3:
			var c := Vector2i(x, y)
			_ground_cell(c, _cell_ground(c))
	_ground.add_child(WallArt.new())
	_build_walls()
	for s in Race.SEATS:
		var row: Array = []
		for g in 3:
			var art := GateArt.new(Race.gate_pos(s, g), Race.gate_vertical(s, g), g == 2)
			_entities.add_child(art)
			row.append(art)
		_gates.append(row)
	_heart = HeartArt.new()
	_heart.position = Race.heart_center()
	_flat.add_child(_heart)
	for def in Race.spots(seat):
		_add_spot(def, str(def["node"]))
	for i in 2:
		if not bool(run.d["shards"][i]):
			_add_spot({"id": "vein%d" % i, "type": "rubyOre", "kind": "", "pos": Race.vein_pos(seat, i)}, "vein%d" % i)
	for z in 3:
		var t := TraderNode.new("stall" if z == 0 else "wanderer", L.t("race.trader"), "coins")
		t.position = Race.trader_pos(seat, z)
		_entities.add_child(t)
	var elder := Player.new()
	elder.position = Race.elder_pos(seat)
	_entities.add_child(elder)
	elder.set_skin("wizard")
	_entities.add_child(_npc_label(Race.elder_pos(seat), L.t("race.elder")))
	for g in 3:
		if not run.gate_open(g):
			var guard := GuardArt.new(g)
			guard.position = _guard_pos(g)
			_entities.add_child(guard)
			_guards.append(guard)
		else:
			_guards.append(null)
	for b in run.d["bots"]:
		var p := Player.new()
		p.modulate = Color(1, 1, 1, 0.85)
		p.position = _bot_target(b, 0.0)
		_entities.add_child(p)
		p.set_skin(str(b["skin"]))
		var tag := _npc_label(Vector2.ZERO, "%s · %s" % [b["name"], L.t("race.wanderer")], 11)
		p.add_child(tag)
		_rivals[int(b["seat"])] = p
	_sync_gates()


func _cell_ground(c: Vector2i) -> String:
	for corner in Race.CORNERS:
		if corner["cell"] == c:
			return str(corner["biome"])
	return Race.CORE_GROUND if c == Race.CORE else Race.ARM_GROUND


## Кусок земли локации на клетку: цвет земли и, если есть, картинка середины локации.
func _ground_cell(c: Vector2i, loc: String) -> void:
	var rect := Race.cell_rect(c)
	var spec := Locations.spec(loc)
	var fill := ColorRect.new()
	fill.color = spec["ground"]
	fill.position = rect.position
	fill.size = rect.size
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ground.add_child(fill)
	var tex := Sprites.ground(loc)
	if tex == null:
		return
	var lay := MapLayout.load_layout(loc)
	var k := lay.size.x / float(tex.get_width())
	var px := Race.TILE / k
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.region_enabled = true
	s.region_rect = Rect2((tex.get_width() - px) / 2.0, (tex.get_height() - px) / 2.0, px, px)
	s.scale = Vector2.ONE * k
	s.position = rect.position
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ground.add_child(s)


## Стены между клетками: валуны и деревья, в проходах ворот - пусто.
func _build_walls() -> void:
	var gaps: Array = []
	for s in Race.SEATS:
		for g in 2:
			gaps.append(Race.gate_pos(s, g))
	var names := ["boulder", "boulder2", "boulder3", "boulder4"]
	var step := 30.0
	var i := 0
	for line in [1, 2]:
		var v := float(line) * Race.TILE
		var t := step / 2.0
		while t < Race.SIZE:
			for p: Vector2 in [Vector2(v, t), Vector2(t, v)]:
				var skip := false
				for gp: Vector2 in gaps:
					if p.distance_to(gp) < Race.GAP / 2.0 + 12.0:
						skip = true
				# Внутри ядра стен нет: клетка ядра открыта со всех сторон ворот перешейков
				if skip:
					continue
				var spr := Sprites.make(names[i % names.size()], p + Vector2(0, 10))
				if spr != null:
					_entities.add_child(spr)
				i += 1
			t += step


func _add_spot(def: Dictionary, node: String) -> void:
	var spot := ResourceSpot.new(str(def["type"]))
	spot.position = def["pos"]
	var hp := float(Race.VEINS[int(node.right(1))]["hp"]) if node.begins_with("vein") else float(Race.NODES[node]["hp"])
	spot.spec = spot.spec.duplicate()
	spot.spec["hp"] = hp
	spot.hp = hp
	if node.begins_with("vein"):
		spot.modulate = Color(1.0, 0.85, 0.5)
		spot.add_child(Fx.glow(Color(1, 0.85, 0.4), 90.0, 20.0, 0.5))
	_entities.add_child(spot)
	_spots.append({"spot": spot, "def": def, "node": node})


func _npc_label(pos: Vector2, text: String, size := 13) -> Label:
	var l := Label.new()
	l.text = text
	l.label_settings = Fx.label_settings(size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(200, 20)
	l.position = pos + Vector2(-100, -78)
	l.z_index = 40
	return l


## Где встаёт страж ворот: перед воротами со стороны игрока.
func _guard_pos(g: int) -> Vector2:
	if g == 2:
		var dir := (Race.cell_center(Race.CORNERS[seat]["arm"]) - Race.heart_center()).normalized()
		return Race.gate_pos(seat, 2) + dir * 70.0
	var cells := Race.gate_cells(seat, g)
	var from: Vector2 = Race.cell_center(cells[0])
	return Race.gate_pos(seat, g) + (from - Race.gate_pos(seat, g)).normalized() * 70.0


## Где появляется герой: в лагере или у последних открытых ворот.
func _spawn_point() -> Vector2:
	var g := run.gates_open()
	if g == 0:
		return Race.camp_pos(seat) + Vector2(0, 40)
	if g == 1:
		var cells := Race.gate_cells(seat, 0)
		return Race.gate_pos(seat, 0) + (Race.cell_center(cells[1]) - Race.gate_pos(seat, 0)).normalized() * 60.0
	var cells2 := Race.gate_cells(seat, 1)
	return Race.gate_pos(seat, 1) + (Race.cell_center(cells2[1]) - Race.gate_pos(seat, 1)).normalized() * 60.0


func _sync_gates() -> void:
	var t := run.elapsed(Clock.now())
	for s in Race.SEATS:
		var open := run.gates_open() if s == seat else -1
		if s != seat:
			for b in run.d["bots"]:
				if int(b["seat"]) == s:
					open = RaceRun.bot_gates(b, t)
		for g in 3:
			(_gates[s][g] as GateArt).set_open(g < open)


# MARK: Цикл

func _process(delta: float) -> void:
	var dt := minf(delta, 1.0 / 20.0)
	var now := Clock.now()
	if _over:
		return
	if run.decided(now):
		_show_end()
		return
	_move(dt)
	_gather(dt, now)
	_fight_tick(dt, now)
	_check_heart(now)
	for sp in _spots:
		(sp["spot"] as ResourceSpot).tick(dt)
	_move_rivals(dt, now)
	_cam = _cam.lerp(_player.position, 1.0 - exp(-dt * 6.0))
	var view := get_viewport_rect().size
	_cam.x = clampf(_cam.x, view.x / 2.0, Race.SIZE - view.x / 2.0)
	_cam.y = clampf(_cam.y, view.y / 2.0 - 60.0, Race.SIZE - view.y / 2.0 + 120.0)
	_world.position = (view / 2.0 - _cam).round()
	_ui_cd -= dt
	if _ui_cd <= 0.0:
		_ui_cd = 0.25
		_refresh_top(now)
		_refresh_card()
		_sync_gates()
	_save_cd -= dt
	if _save_cd <= 0.0:
		_save_cd = 3.0
		Game.race.touch()
		Game.save_if_needed()


func _move(dt: float) -> void:
	if _down > 0.0:
		_down -= dt
		_player.animate(Vector2.ZERO, 0.0, dt)
		return
	var target := _joy.vector * SPEED
	_vel += (target - _vel) * (1.0 - exp(-dt * 12.0))
	if _vel.length() < 2.0:
		_vel = Vector2.ZERO
	var p := _resolve(_player.position, _player.position + _vel * dt)
	_player.position = p
	_player.animate(_vel, minf(1.0, _vel.length() / SPEED), dt)


## Куда можно встать: своя клетка (минус радиус), проходы открытых ворот, вокруг препятствий.
func _resolve(from: Vector2, to: Vector2) -> Vector2:
	var p := _in_zones(from, to)
	for sp in _spots:
		var spot: ResourceSpot = sp["spot"]
		if spot.is_solid and absf(spot.position.x - p.x) < 60.0 and absf(spot.position.y - p.y) < 60.0:
			p = _push(p, spot.position, spot.radius + R)
	for g in _guards:
		if g != null and is_instance_valid(g):
			p = _push(p, (g as Node2D).position, 18.0 + R)
	if not run.can_finish():
		p = _push(p, Race.heart_center(), Race.HEART_R + R)
	return p


func _push(p: Vector2, c: Vector2, d: float) -> Vector2:
	var dist := p.distance_to(c)
	if dist >= d:
		return p
	if dist < 0.01:
		return c + Vector2(0, d)
	return c + (p - c) * (d / dist)


func _in_zones(from: Vector2, to: Vector2) -> Vector2:
	var zones := _rects()
	for r: Rect2 in zones:
		if r.has_point(to):
			return to
	# Не пускаем: двигаемся по одной оси, если так можно
	for cand: Vector2 in [Vector2(to.x, from.y), Vector2(from.x, to.y)]:
		for r: Rect2 in zones:
			if r.has_point(cand):
				return cand
	return from


## Прямоугольники, по которым можно ходить: свои клетки (внутри стен) и проходы открытых ворот.
func _rects() -> Array:
	var out: Array = []
	var c: Dictionary = Race.CORNERS[seat]
	var cells: Array = [c["cell"]]
	if run.gate_open(0):
		cells.append(c["arm"])
	if run.gate_open(1):
		cells.append(Race.CORE)
	for cell: Vector2i in cells:
		out.append(Race.cell_rect(cell).grow(-(R + 12.0)))
	for g in 2:
		if run.gate_open(g):
			var p := Race.gate_pos(seat, g)
			var half := Race.GAP / 2.0 - R
			if Race.gate_vertical(seat, g):
				out.append(Rect2(p.x - 50.0, p.y - half, 100.0, half * 2.0))
			else:
				out.append(Rect2(p.x - half, p.y - 50.0, half * 2.0, 100.0))
	return out


# MARK: Добыча

func _gather(dt: float, now: float) -> void:
	_hit_cd -= dt
	_hint_cd -= dt
	if _hit_cd > 0.0 or _fight >= 0 or _down > 0.0:
		return
	var best = null
	var best_d := INF
	var locked = null
	for sp in _spots:
		var spot: ResourceSpot = sp["spot"]
		if not spot.alive:
			continue
		var d := spot.position.distance_to(_player.position) - spot.radius
		if d > REACH:
			continue
		if _can_mine(str(sp["node"])):
			if d < best_d:
				best = sp
				best_d = d
		else:
			locked = sp
	if best == null:
		if locked != null and _hint_cd <= 0.0:
			_hint_cd = 2.5
			var tier := _tier_of(str(locked["node"]))
			Fx.text(_fx, L.t("race.needTool", [tier]), (locked["spot"] as Node2D).position - Vector2(0, 70), Color(1, 0.85, 0.4), 15)
		return
	_hit_cd = Race.HIT_EVERY
	var spot: ResourceSpot = best["spot"]
	_player.swing(str(spot.spec["tool"]), spot.position, Race.HIT_EVERY)
	Sound.play_tool(str(spot.spec["tool"]))
	spot.hp -= run.power()
	spot.play_hit(false)
	Fx.chips(_fx, spot.position, spot.spec["chip"], 5)
	if spot.hp > 0.001:
		spot.show_hp()
		return
	var node := str(best["node"])
	var top := spot.position - Vector2(0, minf(70.0, float(spot.spec["bar"])))
	var ups := 0
	if node.begins_with("vein"):
		var i := int(node.right(1))
		run.take_vein(i)
		spot.deplete(1.0e9, _player.position)
		Fx.text(_fx, L.t("race.shard"), top - Vector2(0, 20), Color(1, 0.9, 0.4), 20)
		Fx.scatter(_fx, spot.position - Vector2(0, 20), 14, Color(1, 0.85, 0.4), Sprites.icon("spark"), 10.0, 60, 30)
		Sound.play("unlock")
	else:
		var n: Dictionary = Race.NODES[node]
		var kind := str(best["def"]["kind"])
		var got := run.gather(kind, randi_range(int(n["min"]), int(n["max"])), now)
		ups = run.add_xp(int(n["xp"]))
		Fx.gain(_fx, kind, got, top)
		spot.deplete(float(n["respawn"]), _player.position)
	if ups > 0:
		_level_up()
	Input.vibrate_handheld(15)
	_ui_cd = 0.0
	Game.race.touch()


func _can_mine(node: String) -> bool:
	return run.tool() >= _tier_of(node)


func _tier_of(node: String) -> int:
	if node.begins_with("vein"):
		return int(Race.VEINS[int(node.right(1))]["tier"])
	return int(Race.NODES[node]["tier"])


func _level_up() -> void:
	_hp = run.hero_hp()
	Fx.text(_fx, L.t("race.levelUp", [run.level()]), _player.position - Vector2(0, 90), Color(0.6, 1, 0.6), 20)
	Fx.ring(_fx, _player.position, Color(0.6, 1, 0.6, 0.8), 40.0)
	Sound.play("levelUp")


# MARK: Стражи

func _fight_tick(dt: float, now: float) -> void:
	if _fight < 0:
		_hp = minf(run.hero_hp(), _hp + run.hero_hp() / Race.HEAL_TIME * dt)
		return
	var guard: GuardArt = _guards[_fight]
	if guard == null or _player.position.distance_to(guard.position) > FIGHT + 30.0:
		# Отошёл: бой сброшен, страж лечится
		if guard != null:
			guard.heal()
		_fight = -1
		return
	_hit_cd -= dt
	_guard_cd -= dt
	if _hit_cd <= 0.0:
		_hit_cd = Race.HIT_EVERY
		_player.swing("axe", guard.position, Race.HIT_EVERY)
		Sound.play_tool("axe")
		if guard.hurt(run.hero_hit()):
			_win_guard(_fight)
			return
	if _guard_cd <= 0.0:
		_guard_cd = Race.GUARD_EVERY
		var dmg := float(Race.GUARDS[_fight]["dps"]) * Race.GUARD_EVERY
		_hp -= dmg
		guard.strike()
		Fx.text(_fx, "-%d" % int(round(dmg)), _player.position - Vector2(0, 60), Color(1, 0.4, 0.35), 15)
		if _hp <= 0.0:
			_lose_guard()


func _start_fight(g: int) -> void:
	var guard: GuardArt = _guards[g]
	if guard == null:
		return
	if _player.position.distance_to(guard.position) > FIGHT + 30.0:
		return
	_fight = g
	_hit_cd = 0.0
	_guard_cd = Race.GUARD_EVERY
	_ui_cd = 0.0


func _win_guard(g: int) -> void:
	var guard: GuardArt = _guards[g]
	var before := run.level()
	run.open_gate(g, "guard")
	_fight = -1
	Fx.puff(_flat, guard.position, Color(1, 1, 1, 0.8), 40.0, 6)
	Fx.text(_fx, L.t("race.victory"), guard.position - Vector2(0, 80), Color(1, 0.95, 0.5), 19)
	guard.queue_free()
	_guards[g] = null
	if run.level() > before:
		_level_up()
	_gate_opened(g)


func _lose_guard() -> void:
	var guard: GuardArt = _guards[_fight]
	guard.heal()
	_fight = -1
	_down = 1.2
	_hp = run.hero_hp()
	Fx.text(_fx, L.t("race.defeated"), _player.position - Vector2(0, 80), Color(1, 0.5, 0.4), 18)
	Fx.puff(_flat, _player.position, Color(1, 1, 1, 0.8), 30.0, 6)
	_player.position = _spawn_point()
	_vel = Vector2.ZERO
	Sound.play("error")


func _gate_opened(g: int) -> void:
	if _guards[g] != null:
		(_guards[g] as Node2D).queue_free()
		_guards[g] = null
	_sync_gates()
	var p := Race.gate_pos(seat, g)
	Fx.text(_fx, L.t("race.gateOpen"), p - Vector2(0, 90), Color(0.7, 1, 0.7), 20)
	Fx.scatter(_fx, p - Vector2(0, 20), 16, Color(1, 0.95, 0.6), Sprites.icon("spark"), 10.0, 70, 30)
	Sound.play("unlock")
	Game.race.touch()
	Game.save_now()
	_ui_cd = 0.0


# MARK: Сердце и итог

func _check_heart(now: float) -> void:
	if not run.can_finish():
		return
	if _player.position.distance_to(Race.heart_center()) < Race.HEART_R - 30.0:
		if run.finish(now):
			_player.celebrate()
			Fx.scatter(_fx, Race.heart_center(), 30, Color(1, 0.9, 0.5), Sprites.icon("star"), 12.0, 120, 50)
			Sound.play("levelUp")
			Game.race.touch()
			Game.save_now()
			get_tree().create_timer(1.0).timeout.connect(_show_end)


func _show_end() -> void:
	if _over:
		return
	_over = true
	_joy.enabled = false
	_card.visible = false
	var now := Clock.now()
	var place := run.place(now)
	_end_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_end_layer.z_index = 200
	add_child(_end_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_end_layer.add_child(dim)
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(320, 0)
	box.add_theme_stylebox_override("panel", UiKit.box(UiKit.PARCHMENT, UiKit.OUTLINE, 18, 3, true))
	_end_layer.add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	box.add_child(col)
	var title := UiKit.title(L.t("race.finish") if run.finished() else L.t("race.timeUp"), 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var big := UiKit.label(L.t("race.place", [place]), 30, UiKit.INK)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(big)
	if run.finished():
		var tl := UiKit.label(L.t("race.finishedAt", [Race.clock(float(run.d["finish"]))]), 13, UiKit.INK_SOFT)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(tl)
	var at := now if not run.finished() else float(run.d["start"]) + float(run.d["finish"])
	var rows := run.standings(at)
	for i in rows.size():
		col.add_child(_standing_row(i + 1, rows[i]))
	var rw := RaceSystem.reward_for(place)
	var rew := HFlowContainer.new()
	rew.add_theme_constant_override("h_separation", 10)
	rew.add_child(_chip_icon("trophy", "+%d" % int(rw["trophies"])))
	rew.add_child(_chip_icon("gem", "+%d" % int(rw["crystals"])))
	if str(rw["key"]) != "":
		rew.add_child(_chip_icon("key", Chests.key_name(str(rw["key"]))))
	col.add_child(rew)
	var btn := UiKit.button(L.t("race.claim"), "green")
	btn.pressed.connect(_claim)
	col.add_child(btn)


func _claim() -> void:
	var got := Game.race.claim()
	queue_free()
	if not got.is_empty() and int(got.get("league", -1)) >= 0:
		Game.show_toast("px:trophy", L.t("race.leagueUp", [Race.league_name(int(got["league"]))]))
	if Hud.current != null:
		Hud.current.open_window(RacePanel.new())


func _close() -> void:
	Game.race.touch()
	Game.save_now()
	queue_free()
	if Hud.current != null:
		Hud.current.open_window(RacePanel.new())


# MARK: Странники

## Куда идёт странник при доле пути f: по углу, по перешейку к воротам 2, вокруг Сердца, в Сердце.
func _bot_target(b: Dictionary, t: float) -> Vector2:
	var s := int(b["seat"])
	var f := RaceRun.bot_fraction(b, t)
	var steps: Array = Race.BOT_STEPS
	var wob := sin(t * 0.7 + float(s)) * 60.0
	if f < float(steps[0]):
		var a := t * 0.12 + float(s) * 1.7
		return Race.camp_pos(s) + Vector2(cos(a), sin(a)) * (150.0 + wob * 0.5)
	if f < float(steps[3]):
		var k := (f - float(steps[0])) / (float(steps[3]) - float(steps[0]))
		var a0 := Race.gate_pos(s, 0)
		var a1 := Race.gate_pos(s, 1)
		var mid := Race.cell_center(Race.CORNERS[s]["arm"])
		var p := a0.lerp(mid, k * 2.0) if k < 0.5 else mid.lerp(a1, (k - 0.5) * 2.0)
		return p + (a1 - a0).normalized().orthogonal() * wob * 0.6
	if f < 1.0:
		var dir := (Race.cell_center(Race.CORNERS[s]["arm"]) - Race.heart_center()).normalized()
		if f >= float(steps[5]):
			return Race.gate_pos(s, 2) + dir * 30.0
		return Race.heart_center() + dir.rotated(sin(t * 0.3 + float(s)) * 0.9) * 230.0
	return Race.heart_center() + Vector2(cos(float(s)), sin(float(s))) * 50.0


func _move_rivals(dt: float, now: float) -> void:
	var t := run.elapsed(now)
	for b in run.d["bots"]:
		var p: Player = _rivals[int(b["seat"])]
		var target := _bot_target(b, t)
		var v := (target - p.position) / maxf(dt, 0.001)
		v = v.limit_length(SPEED * 0.9)
		p.position += v * dt
		p.animate(v, minf(1.0, v.length() / SPEED), dt)


# MARK: Интерфейс

func _build_ui() -> void:
	var insets := UiKit.safe_insets(get_viewport())
	var top_holder := MarginContainer.new()
	top_holder.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_holder.add_theme_constant_override("margin_left", 10)
	top_holder.add_theme_constant_override("margin_right", 10)
	top_holder.add_theme_constant_override("margin_top", int(insets["top"]) + 6)
	top_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_holder.z_index = 150
	add_child(top_holder)
	_top.add_theme_constant_override("separation", 4)
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_holder.add_child(_top)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_child(head)
	var back := UiKit.button("×", "red", 18, true)
	back.custom_minimum_size = Vector2(40, 40)
	back.pressed.connect(_close)
	head.add_child(back)
	_timer_label = UiKit.label("", 22, Color.WHITE, 5)
	_timer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(_timer_label)
	_stat_label = UiKit.label("", 13, Color.WHITE, 4)
	_stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_stat_label)
	_hp_bar = UiKit.bar(1.0, "red", 120.0, 8.0)
	_hp_bar.visible = false
	_top.add_child(_hp_bar)
	var board_bg := PanelContainer.new()
	board_bg.add_theme_stylebox_override("panel", UiKit.box(Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), 12, 0, false))
	board_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_child(board_bg)
	_board.add_theme_constant_override("separation", 2)
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_bg.add_child(_board)

	var bottom_holder := MarginContainer.new()
	bottom_holder.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_holder.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom_holder.add_theme_constant_override("margin_left", 8)
	bottom_holder.add_theme_constant_override("margin_right", 8)
	bottom_holder.add_theme_constant_override("margin_bottom", int(insets["bottom"]) + 8)
	bottom_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_holder.z_index = 150
	add_child(bottom_holder)
	_bottom.add_theme_constant_override("separation", 6)
	_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_holder.add_child(_bottom)
	_card.add_theme_stylebox_override("panel", UiKit.box(UiKit.PARCHMENT, UiKit.OUTLINE, 16, 3, true))
	_card.visible = false
	_bottom.add_child(_card)
	_card_col.add_theme_constant_override("separation", 6)
	_card.add_child(_card_col)
	var bag_bg := PanelContainer.new()
	bag_bg.add_theme_stylebox_override("panel", UiKit.box(Color(0, 0, 0, 0.4), Color(0, 0, 0, 0), 12, 0, false))
	bag_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom.add_child(bag_bg)
	_bag_row.add_theme_constant_override("h_separation", 8)
	_bag_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bag_bg.add_child(_bag_row)
	_refresh_top(Clock.now())
	_refresh_card()


func _refresh_top(now: float) -> void:
	_timer_label.text = Race.clock(ceilf(run.left(now)))
	_stat_label.text = "%s\n%s" % [L.t("race.level", [run.level()]), L.t("race.tool", [run.tool()])]
	_hp_bar.visible = _fight >= 0 or _hp < run.hero_hp() - 0.5
	_hp_bar.value = clampf(_hp / run.hero_hp(), 0.0, 1.0)
	UiKit.clear(_board)
	var rows := run.standings(now)
	for i in rows.size():
		_board.add_child(_board_row(i + 1, rows[i]))
	UiKit.clear(_bag_row)
	_bag_row.add_child(_chip_icon("coins", Fmt.n(run.coins()), Color.WHITE))
	_bag_row.add_child(_chip_icon("key", "%d/3" % run.shards(), Color.WHITE))
	var kinds: Array = run.d["bag"].keys()
	kinds.sort()
	for k in kinds:
		_bag_row.add_child(_chip_icon(k, Fmt.n(run.have(k)), Color.WHITE))


func _board_row(n: int, r: Dictionary) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var color := Color(1, 0.95, 0.6) if bool(r["me"]) else Color.WHITE
	var name := L.t("race.you") if bool(r["me"]) else str(r["name"])
	var place := UiKit.label("%d" % n, 13, color, 4)
	place.custom_minimum_size = Vector2(16, 0)
	h.add_child(place)
	var nl := UiKit.label(name, 12, color, 4)
	nl.custom_minimum_size = Vector2(120, 0)
	nl.clip_text = true
	h.add_child(nl)
	var steps := float(int(r["steps"])) / 7.0
	h.add_child(UiKit.bar(steps, "gold" if bool(r["me"]) else "green", 140.0, 8.0))
	if float(r["finish"]) >= 0.0:
		h.add_child(UiKit.label(Race.clock(float(r["finish"])), 11, color, 4))
	return h


func _standing_row(n: int, r: Dictionary) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var me := bool(r["me"])
	var name := L.t("race.you") if me else "%s · %s" % [r["name"], L.t("race.wanderer")]
	var pl := UiKit.label("%d." % n, 15, UiKit.INK)
	pl.custom_minimum_size = Vector2(24, 0)
	h.add_child(pl)
	var nl := UiKit.label(name, 14, UiKit.INK if me else UiKit.INK_SOFT)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(nl)
	var right := Race.clock(float(r["finish"])) if float(r["finish"]) >= 0.0 else L.t("race.steps", [int(r["steps"])])
	h.add_child(UiKit.label(right, 12, UiKit.INK_SOFT))
	return h


func _chip_icon(icon: String, text: String, color := UiKit.INK) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(UiKit.icon_any("px:" + icon if not Res.KINDS.has(icon) else "res:" + icon, 18))
	h.add_child(UiKit.label(text, 13, color, 4 if color == Color.WHITE else 0))
	return h


# MARK: Карточка снизу

## Что рядом с героем: торговец, ворота, старец.
func _near_key() -> String:
	var p := _player.position
	for z in 3:
		if p.distance_to(Race.trader_pos(seat, z)) < TALK:
			return "trader"
	var g := run.next_gate()
	if g >= 0 and (p.distance_to(Race.gate_pos(seat, g)) < TALK + 40.0 or (_guards[g] != null and p.distance_to(_guard_pos(g)) < TALK)):
		return "gate%d" % g
	if p.distance_to(Race.elder_pos(seat)) < TALK:
		return "elder"
	if run.gate_open(2) and run.shards() < 3 and p.distance_to(Race.gate_pos(seat, 2)) < TALK:
		return "heart"
	return ""


func _refresh_card() -> void:
	var key := _near_key()
	var sig := "%s|%d|%d|%s|%d|%d" % [key, run.coins(), run.tool(), str(run.d["bag"]), run.shards(), _fight]
	if sig == _card_key:
		return
	_card_key = sig
	UiKit.clear(_card_col)
	_card.visible = key != ""
	match key:
		"trader": _trader_card()
		"elder": _elder_card()
		"heart":
			_card_col.add_child(UiKit.label(L.t("race.heartLocked"), 15, UiKit.INK))
		"":
			pass
		_:
			_gate_card(int(key.right(1)))


func _trader_card() -> void:
	_card_col.add_child(UiKit.title(L.t("race.trader"), 16))
	var spare: bool = run.d["bag"].size() > 0
	var sell := UiKit.button(L.t("race.sellSpare"), "gold", 15)
	sell.disabled = not spare
	sell.pressed.connect(func() -> void:
		var got := run.sell_spare(Clock.now())
		if got > 0:
			Fx.text(_fx, "+%d" % got, _player.position - Vector2(0, 80), Color(1, 0.9, 0.4), 18)
			Sound.play("coin")
		else:
			Fx.text(_fx, L.t("race.nothingToSell"), _player.position - Vector2(0, 80), Color(1, 0.8, 0.6), 15)
		_card_key = ""
		Game.race.touch())
	_card_col.add_child(sell)
	if run.tool() < Race.TOOL_POWER.size():
		var up := UiKit.button(L.t("race.upgrade", [run.tool() + 1, run.upgrade_price()]), "green", 15)
		up.disabled = not run.can_upgrade()
		up.pressed.connect(func() -> void:
			if run.upgrade():
				Fx.text(_fx, L.t("race.tool", [run.tool()]), _player.position - Vector2(0, 80), Color(0.7, 1, 0.7), 18)
				Sound.play("unlock")
			_card_key = ""
			Game.race.touch())
		_card_col.add_child(up)
	else:
		_card_col.add_child(UiKit.label(L.t("race.toolMax"), 13, UiKit.INK_SOFT))


func _gate_card(g: int) -> void:
	_card_col.add_child(UiKit.title(L.t("race.gate", [g + 1]), 16))
	var items := Race.gate_items(seat, g)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 6)
	for it in items:
		flow.add_child(UiKit._chip(it[0], "%d/%d" % [run.have(it[0]), int(it[1])], run.have(it[0]) >= int(it[1]), 13))
	row.add_child(flow)
	var pay := UiKit.button(L.t("race.payItems"), "green", 14, true)
	pay.disabled = not run.can_open(g, "items")
	pay.pressed.connect(func() -> void:
		if run.open_gate(g, "items"):
			_gate_opened(g))
	row.add_child(pay)
	_card_col.add_child(row)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	var c := UiKit._chip("coins", "%d/%d" % [run.coins(), int(Race.GATES[g]["coins"])], run.coins() >= int(Race.GATES[g]["coins"]), 13)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(c)
	var pay2 := UiKit.button(L.t("race.payCoins"), "gold", 14, true)
	pay2.disabled = not run.can_open(g, "coins")
	pay2.pressed.connect(func() -> void:
		if run.open_gate(g, "coins"):
			_gate_opened(g))
	row2.add_child(pay2)
	_card_col.add_child(row2)
	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 8)
	var need := int(Race.GATES[g]["guard"])
	var gl := UiKit.label(L.t("race.guardLevel", [need]), 13, UiKit.INK if run.level() >= need else Color(0.7, 0.25, 0.2))
	gl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row3.add_child(gl)
	var fight := UiKit.button(L.t("race.fight"), "red", 14, true)
	fight.disabled = _fight >= 0
	fight.pressed.connect(func() -> void: _start_fight(g))
	row3.add_child(fight)
	_card_col.add_child(row3)
	if g == 2:
		_card_col.add_child(UiKit.label(L.t("race.needShards", [run.shards()]), 12, UiKit.INK_SOFT))


func _elder_card() -> void:
	_card_col.add_child(UiKit.title(L.t("race.elder"), 16))
	if bool(run.d["shards"][2]):
		_card_col.add_child(UiKit.label(L.t("race.elderDone"), 13, UiKit.INK_SOFT))
		return
	var ask := UiKit.label(L.t("race.elderAsk"), 13, UiKit.INK_SOFT)
	ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_col.add_child(ask)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for it in Race.ELDER:
		flow.add_child(UiKit._chip(it[0], "%d/%d" % [run.have(it[0]), int(it[1])], run.have(it[0]) >= int(it[1]), 13))
	row.add_child(flow)
	var give := UiKit.button(L.t("race.give"), "green", 14, true)
	give.disabled = not run.can_elder()
	give.pressed.connect(func() -> void:
		if run.give_elder():
			Fx.text(_fx, L.t("race.shard"), Race.elder_pos(seat) - Vector2(0, 90), Color(1, 0.9, 0.4), 20)
			Sound.play("unlock")
			_card_key = ""
			Game.race.touch())
	row.add_child(give)
	_card_col.add_child(row)


# MARK: Рисунки

## Ворота гонки: преграда из ворот фермы, открытые - распахнуты.
class GateArt extends Node2D:
	var is_open := false
	var _bar: Sprite2D

	func _init(pos: Vector2, vertical: bool, heart: bool) -> void:
		position = pos
		_bar = Sprites.make("gate_v_anim" if vertical else ("gate_gold_anim" if heart else "gate_stone_anim"))
		if _bar != null:
			var fs := Vector2(_bar.texture.get_width() / float(_bar.hframes), _bar.texture.get_height() / float(_bar.vframes))
			_bar.offset = Sprites.anchor_offset(Vector2(0.5, 0.5) if vertical else Vector2(0.5, 0.3), fs)
			if heart and vertical:
				_bar.modulate = Color(1, 0.85, 0.4)
			add_child(_bar)

	func set_open(open: bool) -> void:
		if open == is_open:
			return
		is_open = open
		if _bar != null and _bar.hframes > 1:
			var last := _bar.hframes - 1
			var tw := create_tween()
			var from := 0.0 if open else float(last)
			var dest := float(last) if open else 0.0
			tw.tween_method(func(v: float) -> void: _bar.frame = int(round(v)), from, dest, 0.08 * last)


## Страж ворот: монстр с полоской здоровья.
class GuardArt extends Node2D:
	var gate := 0
	var hp := 1.0
	var _body := Sprite2D.new()
	var _bar := HPBar.new()
	var _frames := PackedInt32Array()
	var _t := 0.0

	func _init(g: int) -> void:
		gate = g
		hp = float(Race.GUARDS[g]["hp"])
		var kind := str(Race.GUARDS[g]["kind"])
		var sh := Monsters.sheet(kind)
		var cell: float = sh["cell"]
		var tex := Sprites.texture(Monsters.sprite(kind))
		_body.centered = false
		if tex != null:
			_body.texture = tex
			_body.hframes = maxi(1, int(tex.get_width() / cell))
			_body.vframes = maxi(1, int(tex.get_height() / cell))
			var span: Array = sh["idle"]["frames"]
			for f in range(int(span[0]), int(span[1])):
				_frames.append(int(sh["idle"]["row"]) * int(sh["cols"]) + f)
			_body.offset = Sprites.anchor_offset(Sprites.anchor(Monsters.sprite(kind)), Vector2(cell, cell))
			_body.scale = Vector2.ONE * Sprites.SCALE * 1.4
		add_child(_body)
		_bar.position = Vector2(0, -float(sh["bar"]) * 1.4)
		_bar.z_index = 5
		add_child(_bar)

	func _process(dt: float) -> void:
		_t += dt
		if not _frames.is_empty():
			_body.frame = _frames[int(_t * 6.0) % _frames.size()]

	## Удар героя. Возвращает true, если страж побеждён.
	func hurt(d: float) -> bool:
		hp -= d
		_bar.set_fraction(hp / float(Race.GUARDS[gate]["hp"]))
		var tw := create_tween()
		tw.tween_property(_body, "modulate", Color(1, 0.5, 0.5), 0.05)
		tw.tween_property(_body, "modulate", Color.WHITE, 0.1)
		return hp <= 0.0

	func strike() -> void:
		var tw := create_tween()
		tw.tween_property(_body, "position:y", -6.0, 0.08)
		tw.tween_property(_body, "position:y", 0.0, 0.1)

	func heal() -> void:
		hp = float(Race.GUARDS[gate]["hp"])
		_bar.set_fraction(1.0)


## Сердце долины: светящийся круг в центре ядра.
class HeartArt extends Node2D:
	var _t := 0.0

	func _process(dt: float) -> void:
		_t += dt
		queue_redraw()

	func _draw() -> void:
		var pulse := 0.5 + 0.5 * sin(_t * 2.0)
		draw_circle(Vector2.ZERO, Race.HEART_R, Color(1, 0.85, 0.45, 0.18 + 0.08 * pulse))
		draw_arc(Vector2.ZERO, Race.HEART_R, 0.0, TAU, 64, Color(1, 0.9, 0.5, 0.8), 4.0)
		draw_circle(Vector2.ZERO, 28.0 + 4.0 * pulse, Color(1, 0.95, 0.7, 0.8))


## Тени стен между клетками (под валунами), чтобы граница читалась и без картинок.
class WallArt extends Node2D:
	func _draw() -> void:
		for line in [1, 2]:
			var v := float(line) * Race.TILE
			draw_line(Vector2(v, 0), Vector2(v, Race.SIZE), Color(0, 0, 0, 0.25), 18.0)
			draw_line(Vector2(0, v), Vector2(Race.SIZE, v), Color(0, 0, 0, 0.25), 18.0)
