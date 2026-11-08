class_name BattleScene
extends Control
## Живой бой за клетку войны во весь экран (правила - WarBattle). Сверху цель, волна и шанс, посередине поле боя,
## снизу умения. Нажатие на врага - отряд бьёт его; по воротам нажатия - таран. Выиграл волны - решающая схватка,
## исход приходит с сервера (Game.war.battle). Отступление и разбитый отряд - поражение, атака тратится.

var node_id := 0
var battle := WarBattle.new()
var _field: BattleField
var _top := VBoxContainer.new()
var _bottom := VBoxContainer.new()
var _skill_buttons := {}
var _wave_label: Label
var _chance_label: Label
var _overlay: Control
var _sent := false
var _result: Dictionary = {}
var _start := 1.2


func _init(n: int) -> void:
	node_id = n


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var w := Game.war
	var d := w.node(node_id)
	var owner := int(d["owner"])
	var lvl := maxi(1, War.level(node_id))
	var guard := w.guard(node_id)
	var mode := "siege" if owner > 0 else "camp"
	battle.setup(mode, lvl, w.power(), w.defense(node_id), squad(), War.CAMP_MONSTERS[lvl], str(guard[0]) if not guard.is_empty() else "")
	var bg := ColorRect.new()
	bg.color = Color("24331f")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_field = BattleField.new()
	_field.scene = self
	_field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_field)
	var insets := UiKit.safe_insets(get_viewport())
	var top_holder := MarginContainer.new()
	top_holder.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	for side in ["left", "right"]:
		top_holder.add_theme_constant_override("margin_" + side, 10)
	top_holder.add_theme_constant_override("margin_top", int(insets["top"]) + 8)
	top_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_holder)
	_top.add_theme_constant_override("separation", 6)
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_holder.add_child(_top)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	_top.add_child(head)
	var back := UiKit.button("‹", "wood", 18, true)
	back.custom_minimum_size = Vector2(44, 40)
	back.pressed.connect(_ask_retreat)
	head.add_child(back)
	var title_text := L.t("battle.camp", [lvl]) if mode == "camp" else L.t("battle.siege", [AlliancePanel._node_name(node_id)])
	var title := _pill(title_text, 15)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tl: Label = title.get_child(0)
	tl.clip_text = true
	tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(title)
	var info := HBoxContainer.new()
	info.add_theme_constant_override("separation", 6)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_child(info)
	var wp := _pill("", 13)
	_wave_label = wp.get_child(0)
	info.add_child(wp)
	var cp := _pill("", 13)
	_chance_label = cp.get_child(0)
	info.add_child(cp)
	# Умения и подсказка
	var bottom_holder := MarginContainer.new()
	bottom_holder.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_holder.grow_vertical = Control.GROW_DIRECTION_BEGIN
	for side in ["left", "right"]:
		bottom_holder.add_theme_constant_override("margin_" + side, 10)
	bottom_holder.add_theme_constant_override("margin_bottom", int(insets["bottom"]) + 10)
	bottom_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom_holder)
	_bottom.add_theme_constant_override("separation", 6)
	_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_holder.add_child(_bottom)
	var hint := UiKit.label(L.t("battle.hint." + mode), 12, Color.WHITE, 3)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bottom.add_child(hint)
	var skills := HBoxContainer.new()
	skills.add_theme_constant_override("separation", 8)
	_bottom.add_child(skills)
	for s in [["volley", "bolt", "orange"], ["shield", "shield", "blue"], ["rage", "fist", "red"]]:
		var b := UiKit.button(L.t("battle.skill." + s[0]), s[2], 14)
		b.icon = UiKit.icon(s[1], 20).texture
		b.add_theme_constant_override("icon_max_width", 20)
		b.custom_minimum_size = Vector2(0, 52)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id: String = s[0]
		b.pressed.connect(func() -> void: battle.use(id))
		skills.add_child(b)
		_skill_buttons[id] = b
	_refresh_hud()


## Отряд: герой и четыре самых сильных зверя.
static func squad() -> Array:
	var list: Array = Game.animals.owned().duplicate()
	list.sort_custom(func(a: String, b: String) -> bool: return Power.animal(a) > Power.animal(b))
	return ["hero"] + list.slice(0, 4)


func _process(delta: float) -> void:
	if _start > 0.0:
		_start -= delta
	elif battle.state == "fight":
		battle.step(minf(delta, 0.05))
	for e in battle.events:
		_field.on_event(e)
		match str(e[0]):
			"won":
				_clash()
			"lost":
				_finish(-1.0)
	battle.events.clear()
	_refresh_hud()


func _refresh_hud() -> void:
	_wave_label.text = L.t("battle.wave", [battle.wave, battle.wave_total])
	var t := maxf(0.0, battle.tactic()) if battle.state != "lost" else 0.0
	_chance_label.text = L.t("battle.chance", [int(round(Game.war.battle_chance(node_id, t) * 100.0))])
	for id in _skill_buttons:
		var b: Button = _skill_buttons[id]
		var cd := float(battle.cds[id])
		b.disabled = not battle.can_use(id)
		b.text = L.t("battle.skill." + id) if cd <= 0.0 else "%d" % int(ceil(cd))


func _ask_retreat() -> void:
	if _overlay != null:
		close()
		return
	if battle.state != "fight":
		return
	ConfirmPopup.ask("px:swords", L.t("battle.retreat"), L.t("battle.retreatText"), L.t("battle.retreat"), "red",
		func() -> void: battle.retreat())


## Волны позади: решающая схватка с вожаком (или сердцем базы), исход решает сервер.
func _clash() -> void:
	_field.clash = true
	_finish(battle.tactic())


func _finish(tactic: float) -> void:
	if _sent:
		return
	_sent = true
	for b in _skill_buttons.values():
		(b as Button).disabled = true
	var res: Dictionary = await Game.war.battle(node_id, tactic)
	if not is_inside_tree():
		return
	# Даём схватке полторы секунды на экране
	if tactic >= 0.0:
		await get_tree().create_timer(1.4).timeout
	_result = res
	var r := str(res.get("result", ""))
	_field.outcome = "won" if r in ["win", "capture"] else "lost"
	_show_result(tactic)


func _show_result(tactic: float) -> void:
	var r := str(_result.get("result", ""))
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.box(UiKit.PARCHMENT, UiKit.OUTLINE, 18, 3, true))
	card.custom_minimum_size = Vector2(300, 0)
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	card.add_child(col)
	var won := r in ["win", "capture"]
	var key := "battle.result." + (r if r in ["capture", "win", "cut"] else ("retreat" if tactic < 0.0 else "lose"))
	if _result.is_empty():
		key = "battle.result.error"
	var icon := UiKit.icon("trophy" if won else "swords", 48)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(icon)
	var t := UiKit.title(L.t(key), 20)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	if tactic >= 0.0:
		var tl := UiKit.label(L.t("battle.tactic", [int(round(tactic * 100.0)), int(round(tactic * War.TACTIC_MAX * 100.0))]), 13, UiKit.INK_SOFT)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(tl)
	if won:
		var rl := UiKit.label(L.t("battle.reward", [Fmt.n(int(_result.get("coins", 0))), int(_result.get("trophies", 0))]), 14, UiKit.GOOD)
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(rl)
	var ok := UiKit.button(L.t("battle.toMap"), "green", 15)
	ok.pressed.connect(close)
	col.add_child(ok)


func close() -> void:
	if Hud.current != null:
		Hud.current.open_window(WarScene.new())


func _pill(text: String, size: int) -> PanelContainer:
	var p := PanelContainer.new()
	var st := UiKit.box(Color(0, 0, 0, 0.45), Color(0, 0, 0, 0), 12, 0, false)
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", st)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UiKit.label(text, size, Color.WHITE, 3)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


## Поле боя: местность, враги с полосками здоровья, отряд внизу, выстрелы, замахи, щит и всплывающий урон.
class BattleField extends Control:
	var scene: BattleScene
	var clash := false
	var outcome := ""
	var _t := 0.0
	var _clash_t := 0.0
	var _shake := 0.0
	var _flash := 0.0
	var _shots: Array = []
	var _floats: Array = []
	var _texs := {}
	var _deco: Array = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var rng := RandomNumberGenerator.new()
		rng.seed = 4242
		for i in 18:
			var left := i % 2 == 0
			_deco.append([Vector2(rng.randf_range(0.0, 0.12) if left else rng.randf_range(0.88, 1.0), rng.randf_range(0.05, 0.95)),
				["tree_oak", "tree_spruce", "bush", "tree_birch", "rock1"][i % 5], rng.randf_range(0.8, 1.2)])
		_deco.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as Vector2).y < (b[0] as Vector2).y)

	func _tex(name: String) -> Texture2D:
		if not _texs.has(name):
			_texs[name] = Sprites.texture(name)
		return _texs[name]

	func _sprite(name: String, foot: Vector2, h: float, c := Color.WHITE) -> bool:
		var t := _tex(name)
		if t == null:
			return false
		var i := Sprites.info(name)
		var fw := float(i.get("frame", t.get_width()))
		var fh := float(i.get("h", t.get_height() if not i.has("frame") else fw))
		var k := h / fh
		var a := Sprites.anchor(name)
		draw_texture_rect_region(t, Rect2(foot - Vector2(a.x * fw * k, (1.0 - a.y) * fh * k), Vector2(fw, fh) * k), Rect2(0, 0, fw, fh), c)
		return true

	## Игровое поле между шапкой и умениями.
	func _area() -> Rect2:
		return Rect2(Vector2(0, 120), Vector2(size.x, maxf(200.0, size.y - 120 - 170)))

	func _foe_pos(f: Dictionary) -> Vector2:
		var a := _area()
		return a.position + Vector2(a.size.x * (0.12 + 0.76 * float(f["x"])), a.size.y * float(f["y"]) * 1.15)

	func _unit_pos(i: int) -> Vector2:
		var a := _area()
		var u: Dictionary = scene.battle.units[i]
		return a.position + Vector2(a.size.x * (0.1 + 0.8 * float(u["x"])), a.size.y * 0.86 + (i % 2) * 14.0)

	func on_event(e: Array) -> void:
		var b := scene.battle
		match str(e[0]):
			"shot":
				if int(e[2]) < b.foes.size():
					_shots.append([_unit_pos(int(e[1])), _foe_pos(b.foes[int(e[2])]), 0.0])
			"hit":
				if int(e[1]) < b.foes.size() and float(e[2]) >= 1.0:
					var c := Color("ffe08a") if str(e[3]) != "volley" else Color("ffb347")
					_floats.append([_foe_pos(b.foes[int(e[1])]) + Vector2(randf_range(-14, 14), -50), str(int(e[2])), c, 0.0])
			"hurt":
				if int(e[1]) >= 0 and float(e[2]) >= 1.0:
					_floats.append([_unit_pos(int(e[1])) + Vector2(0, -44), "-%d" % int(e[2]), Color("ff7a6a"), 0.0])
			"slam":
				_shake = 0.35
				_flash = 0.3
				Sound.play("crit")
			"blocked":
				_floats.append([_area().position + Vector2(size.x / 2.0, _area().size.y * 0.7), L.t("battle.blocked"), Color("9fd8ff"), 0.0])
				Sound.play("success")
			"wave":
				if int(e[1]) > 1:
					_floats.append([_area().get_center(), L.t("battle.wave", [int(e[1]), b.wave_total]), Color.WHITE, 0.0])
			"dead":
				Sound.play("pop")

	func _process(delta: float) -> void:
		_t += delta
		if clash:
			_clash_t += delta
		_shake = maxf(0.0, _shake - delta)
		_flash = maxf(0.0, _flash - delta)
		for s in _shots:
			s[2] = float(s[2]) + delta * 3.5
		_shots = _shots.filter(func(s: Array) -> bool: return float(s[2]) < 1.0)
		for f in _floats:
			f[3] = float(f[3]) + delta
		_floats = _floats.filter(func(f: Array) -> bool: return float(f[3]) < 1.0)
		queue_redraw()

	func _draw() -> void:
		var b := scene.battle
		var a := _area()
		var off := Vector2(randf_range(-4, 4), randf_range(-4, 4)) if _shake > 0.0 else Vector2.ZERO
		draw_set_transform(off)
		# Земля
		draw_rect(Rect2(Vector2.ZERO, size), Color("5d8f42"))
		draw_circle(a.get_center(), a.size.x * 0.55, Color("679b49"))
		draw_rect(Rect2(Vector2(0, a.position.y + a.size.y * 0.62), Vector2(size.x, a.size.y * 0.5)), Color(0.55, 0.42, 0.25, 0.25))
		for d in _deco:
			var p := Vector2(size.x * (d[0] as Vector2).x, a.position.y - 60 + (a.size.y + 140) * (d[0] as Vector2).y)
			if not _sprite(str(d[1]), p, 60.0 * float(d[2])):
				draw_circle(p - Vector2(0, 16), 16.0 * float(d[2]), Color("2f6b2c"))
		# Задник: лагерь или стена базы
		if b.mode == "camp":
			_sprite("tent", a.position + Vector2(a.size.x * 0.22, a.size.y * 0.16), 70.0)
			_sprite("tent", a.position + Vector2(a.size.x * 0.8, a.size.y * 0.14), 60.0)
			_sprite("campfire_anim", a.position + Vector2(a.size.x * 0.5, a.size.y * 0.14), 40.0)
		else:
			var wy := a.position.y + a.size.y * 0.44
			var x := 0.0
			while x < size.x:
				if absf(x + 18.0 - size.x / 2.0) > 50.0:
					if not _sprite("palisade", Vector2(x + 18.0, wy), 46.0):
						draw_rect(Rect2(Vector2(x + 2, wy - 40), Vector2(32, 40)), Color("8a6a40"))
				x += 34.0
			_sprite("house_red", a.position + Vector2(a.size.x * 0.5, a.size.y * 0.12), 80.0)
		# Враги
		var font := UiKit.font()
		for i in b.foes.size():
			_draw_foe(i, font)
		# Решающая схватка: вожак (или сердце базы) в центре
		if clash:
			var bp := a.position + Vector2(a.size.x * 0.5, a.size.y * 0.42)
			var k := clampf(_clash_t * 2.0, 0.0, 1.0)
			var alpha := 1.0 if outcome != "won" else maxf(0.0, 1.0 - (_clash_t - 1.4) * 2.0)
			var boss := str(War.CAMP_BOSS[b.level]) if b.mode == "camp" else ""
			var tex: Texture2D = Monsters.icon(boss) if boss != "" else _tex("house_red")
			if tex != null:
				var h := 140.0 * k
				var w := h * tex.get_width() / float(tex.get_height())
				draw_texture_rect(tex, Rect2(bp - Vector2(w / 2.0, h), Vector2(w, h)), false, Color(1, 1, 1, alpha))
			else:
				draw_circle(bp - Vector2(0, 60), 50.0 * k, Color(0.7, 0.2, 0.2, alpha))
			if outcome == "":
				_text(font, bp + Vector2(0, 30), L.t("battle.clash"), 18, Color.WHITE)
				for j in 3:
					var ang := _t * 6.0 + j * TAU / 3.0
					draw_circle(bp - Vector2(0, 60) + Vector2(cos(ang), sin(ang)) * 70.0, 6.0, Color(1, 0.9, 0.5, 0.9))
		# Отряд
		for i in b.units.size():
			_draw_unit(i, font)
		# Щит над отрядом
		if b.shield_t > 0.0:
			var c := Vector2(size.x / 2.0, a.position.y + a.size.y * 0.93)
			draw_arc(c, size.x * 0.48, PI, TAU, 40, Color(0.55, 0.8, 1.0, 0.85), 5.0, true)
			draw_arc(c, size.x * 0.46, PI, TAU, 40, Color(0.55, 0.8, 1.0, 0.3), 12.0, true)
		# Выстрелы
		for s in _shots:
			var p0: Vector2 = s[0]
			var p1: Vector2 = s[1]
			var at := p0.lerp(p1 - Vector2(0, 24), float(s[2])) - Vector2(0, 20)
			draw_circle(at, 4.0, Color("fff1b0") if b.rage_t <= 0.0 else Color("ff8a5a"))
		for f in _floats:
			var k := float(f[3])
			_text(font, (f[0] as Vector2) - Vector2(0, 30.0 * k), str(f[1]), 16, Color(f[2], 1.0 - k * 0.8))
		if _flash > 0.0:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.9, 0.1, 0.1, _flash))
		if scene._start > 0.0:
			_text(font, a.get_center(), L.t("battle.start"), 34, Color.WHITE)
		draw_set_transform(Vector2.ZERO)

	func _draw_foe(i: int, font: Font) -> void:
		var b := scene.battle
		var f: Dictionary = b.foes[i]
		var p := _foe_pos(f)
		var dead := float(f["hp"]) <= 0.0
		var role := str(f["role"])
		var h := 64.0 if role == "mob" else 84.0
		if role == "gate":
			var r := Rect2(p - Vector2(46, 70), Vector2(92, 70))
			if dead:
				draw_rect(Rect2(p - Vector2(46, 14), Vector2(92, 14)), Color("6b5034"))
			else:
				draw_rect(r, Color("7a5530"))
				for k in 4:
					draw_line(r.position + Vector2(8 + k * 25, 0), r.position + Vector2(8 + k * 25, 70), Color("5a3a1e"), 3.0)
				draw_rect(Rect2(r.position + Vector2(0, 20), Vector2(92, 8)), Color("3a3a3a"))
				draw_rect(Rect2(r.position + Vector2(0, 48), Vector2(92, 8)), Color("3a3a3a"))
				draw_rect(r, UiKit.OUTLINE, false, 2.0)
		elif role == "tower":
			if dead:
				draw_circle(p - Vector2(0, 8), 22.0, Color("8d877a"))
			elif not _sprite("tower", p, 110.0):
				draw_rect(Rect2(p - Vector2(22, 100), Vector2(44, 100)), Color("a89a80"))
			h = 110.0
		elif not dead:
			var tex: Texture2D = AnimalSheet.icon(str(f["kind"])) if role == "guard" else Monsters.icon(str(f["kind"]))
			var bob := sin(_t * 5.0 + i) * 2.0
			if tex != null:
				var w := h * tex.get_width() / float(tex.get_height())
				draw_texture_rect(tex, Rect2(p - Vector2(w / 2.0, h + bob), Vector2(w, h)), false)
			else:
				draw_circle(p - Vector2(0, h / 2.0 + bob), h * 0.4, Color("7a3a8a") if role != "mob" else Color("4a8a3a"))
		if dead:
			return
		# Цель отряда
		if i == b.target():
			draw_arc(p + Vector2(0, 2), 30.0, 0, TAU, 28, Color(1, 0.9, 0.3, 0.9), 3.0, true)
		# Замах тяжёлого удара
		if float(f["wind"]) > 0.0:
			var k := 1.0 - float(f["wind"]) / WarBattle.HEAVY_WIND
			draw_arc(p - Vector2(0, h * 0.5), 40.0 + 8.0 * sin(_t * 20.0), 0, TAU * k, 32, Color(1, 0.2, 0.15, 0.95), 5.0, true)
			_text(font, p - Vector2(0, h + 18), "!", 26, Color("ff5a4a"))
		# Полоска здоровья
		var bw := 70.0
		var bp := p - Vector2(bw / 2.0, h + 12)
		draw_rect(Rect2(bp, Vector2(bw, 8)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(bp + Vector2(1, 1), Vector2((bw - 2) * float(f["hp"]) / float(f["max"]), 6)), Color("e0503a") if role != "gate" else Color("d9a441"))

	func _draw_unit(i: int, font: Font) -> void:
		var b := scene.battle
		var u: Dictionary = b.units[i]
		var p := _unit_pos(i)
		var dead := float(u["hp"]) <= 0.0
		var id := str(u["id"])
		var tex: Texture2D = LevelPanel.portrait(Skins.current()) if id == "hero" else AnimalSheet.icon(id)
		var h := 58.0 if id == "hero" else 50.0
		var c := Color(1, 1, 1, 0.35) if dead else (Color(1, 0.7, 0.6) if b.rage_t > 0.0 else Color.WHITE)
		if outcome == "lost" and not dead:
			c.a = 0.6
		draw_circle(p + Vector2(0, 2), 20.0, Color(0, 0, 0, 0.25))
		if tex != null:
			var w := h * tex.get_width() / float(tex.get_height())
			var bob := 0.0 if dead else absf(sin(_t * 8.0 + i)) * 3.0
			draw_texture_rect(tex, Rect2(p - Vector2(w / 2.0, h + bob), Vector2(w, h)), false, c)
		else:
			draw_circle(p - Vector2(0, h / 2.0), 22.0, Color("3a8ee0", c.a) if id == "hero" else Color("e0a03a", c.a))
		if dead:
			return
		var bw := 50.0
		var bp := p + Vector2(-bw / 2.0, 6)
		draw_rect(Rect2(bp, Vector2(bw, 7)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(bp + Vector2(1, 1), Vector2((bw - 2) * float(u["hp"]) / float(u["max"]), 5)), Color("4cbf4a"))

	func _text(font: Font, at: Vector2, text: String, size_px: int, color: Color) -> void:
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		draw_string_outline(font, at - Vector2(tw / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 5, Color(UiKit.OUTLINE, color.a))
		draw_string(font, at - Vector2(tw / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)

	func _gui_input(e: InputEvent) -> void:
		var pressed: bool = (e is InputEventScreenTouch and e.pressed) or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT \
			and not DisplayServer.is_touchscreen_available())
		if not pressed:
			return
		var b := scene.battle
		var best := -1
		var dist := 1e9
		for i in b.foes.size():
			if not b.alive(i):
				continue
			var f: Dictionary = b.foes[i]
			var d := (e.position as Vector2).distance_to(_foe_pos(f) - Vector2(0, 40))
			if d < dist:
				dist = d
				best = i
		if best >= 0 and dist < 80.0:
			b.pick(best)
			accept_event()
