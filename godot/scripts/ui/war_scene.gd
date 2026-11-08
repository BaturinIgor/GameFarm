class_name WarScene
extends Control
## Война альянсов во весь экран: живая карта лиги (местность, территории, туман, отряды в пути, сборы),
## сверху счёт и атаки, снизу карточка выбранной точки с действиями. Карту можно двигать и приближать.
## Данные и действия - Game.war (war_map / war_march / war_rally из docs/supabase/alliance_war_march.sql).

var _map: WarField
var _top := VBoxContainer.new()
var _bottom := PanelContainer.new()
var _bottom_col := VBoxContainer.new()
var _dirty := true
var _poll := 0.0
var _tick := 0.0
## Зверь, выбранный для гарнизона (укрепление).
var _animal := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color("1d2a1a")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_map = WarField.new()
	_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map.on_pick = func(n: int) -> void:
		Game.war.selected = n
		_animal = ""
		_dirty = true
	add_child(_map)
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
	_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bottom.offset_left = 8
	_bottom.offset_right = -8
	_bottom.offset_bottom = -insets["bottom"] - 8
	_bottom.add_theme_stylebox_override("panel", UiKit.box(UiKit.PARCHMENT, UiKit.OUTLINE, 18, 3, true))
	add_child(_bottom)
	_bottom_col.add_theme_constant_override("separation", 6)
	_bottom.add_child(_bottom_col)
	Game.changed.connect(func() -> void: _dirty = true)
	Game.war.fetch()


func _process(delta: float) -> void:
	_poll += delta
	_tick += delta
	var w := Game.war
	# Обновляем карту каждые 20 с и сразу, как только мой отряд должен дойти
	var due := w.my_marches().any(func(m: Dictionary) -> bool: return float(m.get("at", 0)) + 2.0 < w.now()) \
		or w.rallies().any(func(r: Dictionary) -> bool: return bool(r.get("mine", false)) and float(r.get("fires", 0)) + 2.0 < w.now())
	if (_poll > 20.0 or (due and _poll > 4.0)) and not w.busy:
		_poll = 0.0
		w.fetch()
	if _tick >= 1.0:
		_tick = 0.0
		_dirty = true
	if _dirty and is_inside_tree():
		_dirty = false
		_build()


func close() -> void:
	if Hud.current != null:
		Hud.current.open_window(AlliancePanel.new("war"))


func _build() -> void:
	UiKit.clear(_top)
	UiKit.clear(_bottom_col)
	var w := Game.war
	# Шапка: назад, название, время до конца
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	_top.add_child(head)
	var back := UiKit.button("‹", "wood", 18, true)
	back.custom_minimum_size = Vector2(44, 40)
	back.pressed.connect(close)
	head.add_child(back)
	var title := _pill(L.t("war.title") + " · " + War.league_name(w.league()), 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var left := float(w.state.get("ends", 0)) - w.now()
	head.add_child(_chip("px:hourglass", EventsPanel.long_countdown(maxf(0.0, left))))
	# Счёт лиги: цветные плашки альянсов
	var score := HFlowContainer.new()
	score.add_theme_constant_override("h_separation", 4)
	score.add_theme_constant_override("v_separation", 4)
	score.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_child(score)
	for t in w.teams():
		score.add_child(_team_chip(t))
	# Мои ресурсы: атаки, отряды, буст казны
	var mine := HBoxContainer.new()
	mine.add_theme_constant_override("separation", 6)
	mine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_child(mine)
	mine.add_child(_chip("px:swords", "%d/%d" % [w.attacks_left(), int(w.state.get("max", War.ATTACKS))]))
	mine.add_child(_chip("px:boots", "%d/%d" % [w.my_marches().size(), War.MAX_MARCHES]))
	mine.add_child(_chip("px:coins", "+%d%%" % int(round(War.boost(w.chest()) * 100.0))))
	mine.add_child(_chip("px:fist", Fmt.n(w.power())))
	if w.error != "":
		_bottom_col.add_child(_err(w.error))
	if not w.joined():
		_bottom_col.add_child(_label_wrap(L.t("alliance.loading") if w.error == "" else "", 13))
		return
	# Мои отряды в пути
	for m in w.my_marches():
		_bottom_col.add_child(_march_row(m))
	for r in w.rallies():
		if bool(r.get("mine", false)):
			_bottom_col.add_child(_rally_row(r))
	_node_card()


func _pill(text: String, size: int) -> Control:
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


func _chip(icon: String, text: String) -> Control:
	var p := PanelContainer.new()
	var st := UiKit.box(Color(0, 0, 0, 0.45), Color(0, 0, 0, 0), 10, 0, false)
	st.content_margin_left = 6
	st.content_margin_right = 8
	st.content_margin_top = 2
	st.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", st)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	p.add_child(h)
	var ic := UiKit.icon_any(icon, 16)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	h.add_child(UiKit.label(text, 12, Color.WHITE, 3))
	return p


func _team_chip(t: Dictionary) -> Control:
	var slot := int(t.get("slot", 0))
	var p := PanelContainer.new()
	var col: Color = War.COLORS[clampi(slot, 0, War.COLORS.size() - 1)]
	var st := UiKit.box(col.darkened(0.15), Color.WHITE if bool(t.get("me", false)) else UiKit.OUTLINE, 8, 2, false)
	st.content_margin_left = 6
	st.content_margin_right = 6
	st.content_margin_top = 1
	st.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", st)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(UiKit.label("%s %s" % [str(t.get("tag", "?")), Fmt.n(int(t.get("points", 0)))], 11, Color.WHITE, 3))
	return p


func _label_wrap(text: String, size: int, color := UiKit.INK) -> Label:
	var l := UiKit.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _err(code: String) -> Label:
	var key := "war.err." + code.replace(" ", "_")
	var l := _label_wrap(L.t(key) if L.has(key) else L.t("alliance.err." + code.replace(" ", "_")), 12, UiKit.BAD)
	return l


func _march_row(m: Dictionary) -> Control:
	var w := Game.war
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(UiKit.icon("swords" if str(m.get("kind", "")) == "attack" else "shield", 20))
	var left := maxf(0.0, float(m.get("at", 0)) - w.now())
	var l := UiKit.label(L.t("war.marchRow", [WarSystem._short_name(int(m.get("node", 0)))]), 13)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var total := maxf(1.0, float(m.get("at", 0)) - float(m.get("from", 0)))
	row.add_child(UiKit.bar(1.0 - left / total, "orange", 90, 14, Fmt.seconds(left) if left > 0 else "..."))
	return row


func _rally_row(r: Dictionary) -> Control:
	var w := Game.war
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 4)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	c.add_child(row)
	row.add_child(UiKit.icon("crown", 22))
	var left := maxf(0.0, float(r.get("fires", 0)) - w.now())
	var l := _label_wrap(L.t("war.rallyRow", [str(r.get("leader", "")), WarSystem._short_name(int(r.get("node", 0))),
		int(r.get("members", 0)), Fmt.n(int(r.get("power", 0)))]), 13)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	row.add_child(UiKit.label(Fmt.seconds(left) if left > 0 else "...", 14, UiKit.BAD))
	if w.can_join(r):
		var b := UiKit.button(L.t("war.rallyJoin"), "red", 14)
		b.disabled = w.busy
		b.pressed.connect(func() -> void: w.join_rally(r))
		UiKit.attention(b)
		c.add_child(b)
	return c


## Карточка выбранной точки: кто владеет, щиты, гарнизон и зверь, шанс, время похода и кнопки.
func _node_card() -> void:
	var w := Game.war
	var n := w.selected
	if n < 0:
		var hint := _label_wrap(L.t("war.scenePick"), 13, UiKit.INK_SOFT)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_bottom_col.add_child(hint)
		return
	var d := w.node(n)
	var t := War.tier(n)
	var owner := int(d["owner"])
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	_bottom_col.add_child(head)
	var flag := ColorRect.new()
	flag.color = War.COLORS[clampi(owner, 0, War.COLORS.size() - 1)]
	flag.custom_minimum_size = Vector2(10, 30)
	head.add_child(flag)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	head.add_child(col)
	col.add_child(UiKit.label(AlliancePanel._node_name(n), 16))
	var ot := w.team(owner)
	col.add_child(UiKit.label(L.t("war.owner", [str(ot.get("name", ""))]) if owner > 0 else L.t("war.neutral"), 12, UiKit.INK_SOFT))
	var x := UiKit.button("x", "wood", 12, true)
	x.custom_minimum_size = Vector2(32, 30)
	x.pressed.connect(func() -> void:
		w.selected = -1
		_dirty = true)
	head.add_child(x)
	if War.is_base(n):
		_bottom_col.add_child(_label_wrap(L.t("war.baseHint"), 12, UiKit.INK_SOFT))
		return
	if not w.visible(n):
		_bottom_col.add_child(_label_wrap(L.t("war.fog"), 12, UiKit.INK_SOFT))
		return
	# Показатели значками
	var stats := HFlowContainer.new()
	stats.add_theme_constant_override("h_separation", 12)
	_bottom_col.add_child(stats)
	stats.add_child(AllianceUi.stat("px:star", L.t("war.level", [War.level(n)]), UiKit.INK, 13))
	stats.add_child(AllianceUi.stat("px:shield", "%d/%d" % [int(d["shields"]), War.max_shields(t)], UiKit.INK, 13))
	stats.add_child(AllianceUi.stat("px:fist", Fmt.n(w.defense(n)), UiKit.INK, 13))
	stats.add_child(AllianceUi.stat("px:trophy", L.t("war.perHour", [War.rate(t)]), UiKit.INK, 13))
	var lk := War.land_kind(n)
	if lk != "":
		var lr := HBoxContainer.new()
		lr.add_theme_constant_override("separation", 4)
		lr.add_child(UiKit.icon(str(War.LAND_ICONS.get(lk, "star")), 18))
		lr.add_child(UiKit.label(L.t("war.landLine", [L.t("effect.yield." + lk, [Fmt.pct(War.land_value(n))])]), 12, UiKit.GOOD))
		_bottom_col.add_child(lr)
	var g := w.guard(n)
	if not g.is_empty():
		var gr := HBoxContainer.new()
		gr.add_theme_constant_override("separation", 4)
		gr.add_child(AnimalsPanel.animal_icon(g[0], 20))
		gr.add_child(UiKit.label(L.t("war.guard", [Animals.name_of(g[0]), g[1]]), 12, UiKit.INK_SOFT))
		stats.add_child(gr)
	var rally := {}
	for r in w.rallies():
		if int(r.get("node", -1)) == n and bool(r.get("mine", false)):
			rally = r
	if owner == w.my_slot():
		_guard_block(n)
		return
	var lo := int(round(w.battle_chance(n, 0.0) * 100.0))
	var hi := int(round(w.battle_chance(n, 1.0) * 100.0))
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 6)
	_bottom_col.add_child(crow)
	crow.add_child(UiKit.label(L.t("war.chanceRange", [lo, hi]) if t != 4 else L.t("war.chance", [int(round(w.chance(n) * 100.0))]), 13,
		UiKit.GOOD if hi >= 50 else UiKit.BAD))
	if owner == 0 and t != 4 and w.power() < w.defense(n) * 0.5:
		crow.add_child(UiKit.label(L.t("war.tooStrong"), 12, UiKit.BAD))
	if not bool(d["reach"]):
		_bottom_col.add_child(_label_wrap(L.t("war.far"), 12, UiKit.INK_SOFT))
		return
	if w.attacks_left() <= 0:
		_bottom_col.add_child(_label_wrap(L.t("war.noAttacks"), 12, UiKit.INK_SOFT))
		if w.bought() < War.BUY_ATTACKS:
			var bb := MapPanel.icon_button([["t", L.t("war.buyAttack", [War.BUY_ATTACKS - w.bought()])], ["i", "gem"], ["t", str(War.ATTACK_CRYSTALS)]], "green")
			bb.disabled = w.busy
			bb.pressed.connect(func() -> void: w.buy_attack())
			_bottom_col.add_child(bb)
		return
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 6)
	_bottom_col.add_child(btns)
	if t != 4 or not w.live:
		var ab := UiKit.button(L.t("war.fight"), "red", 15)
		ab.icon = UiKit.icon("swords", 20).texture
		ab.add_theme_constant_override("icon_max_width", 20)
		ab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ab.disabled = w.busy or not w.can_battle(n)
		ab.pressed.connect(func() -> void:
			if Hud.current != null:
				Hud.current.open_window(BattleScene.new(n)))
		btns.add_child(ab)
		if not ab.disabled:
			UiKit.attention(ab)
	if w.live and rally.is_empty():
		var rb := UiKit.button(L.t("war.rally"), "orange", 14)
		rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rb.disabled = w.busy or not w.can_rally(n)
		rb.pressed.connect(func() -> void:
			ConfirmPopup.ask("px:crown", L.t("war.rally"), L.t("war.rallyText", [Fmt.seconds(War.RALLY_SECS), War.RALLY_STRIP]),
				L.t("war.rally"), "orange", func() -> void: w.rally(n)))
		btns.add_child(rb)
		if t == 4 and not rb.disabled:
			UiKit.attention(rb)
	if t == 4 and w.live:
		_bottom_col.add_child(_label_wrap(L.t("war.castleRally"), 12, UiKit.INK_SOFT))


## Своя точка: укрепить отрядом (+1 щит) и оставить зверя в гарнизоне - его мощь добавится к защите.
func _guard_block(n: int) -> void:
	var w := Game.war
	var d := w.node(n)
	if not w.live:
		if w.can_reinforce(n):
			var rb := UiKit.button(L.t("war.reinforce"), "blue", 14)
			rb.disabled = w.busy
			rb.pressed.connect(func() -> void: w.attack(n, true))
			_bottom_col.add_child(rb)
		return
	var animals: Array = Game.animals.owned().duplicate()
	animals.sort_custom(func(a: String, b: String) -> bool: return Power.animal(a) > Power.animal(b))
	animals = animals.slice(0, 5)
	if not animals.is_empty():
		_bottom_col.add_child(UiKit.label(L.t("war.pickGuard"), 12, UiKit.INK_SOFT))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_bottom_col.add_child(row)
		for a in animals:
			var b := UiKit.button("", "green" if a == _animal else "wood", 11, true)
			b.icon = AnimalsPanel.animal_icon(a, 30).texture
			b.expand_icon = true
			b.custom_minimum_size = Vector2(52, 50)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var aa: String = a
			b.pressed.connect(func() -> void:
				_animal = "" if _animal == aa else aa
				_dirty = true)
			row.add_child(b)
		if _animal != "":
			_bottom_col.add_child(UiKit.label(L.t("war.guardPower", [Animals.name_of(_animal), Fmt.n(mini(War.ANIMAL_CAP, Power.animal(_animal)))]), 12))
	var full := int(d["shields"]) >= War.max_shields(War.tier(n))
	var rb2 := UiKit.button(L.t("war.reinforceTroops", [Fmt.seconds(War.march_secs(War.tier(n)))]), "blue", 14)
	rb2.disabled = w.busy or not w.can_guard(n) or (full and _animal == "")
	rb2.pressed.connect(func() -> void:
		w.march(n, true, _animal)
		_animal = "")
	_bottom_col.add_child(rb2)


## Флаг альянса: древко и полотнище одного из узоров War.FLAGS (узор покупает лидер).
static func draw_flag(ci: CanvasItem, top: Vector2, r: float, col: Color, pattern: int, wave := 0.0) -> void:
	var h := r * 1.0
	ci.draw_line(top, top + Vector2(0, -h), UiKit.OUTLINE, 2.0)
	var a := top + Vector2(0, -h)
	var w := r * 0.9
	var fh := r * 0.5
	var dark := col.darkened(0.35)
	var light := col.lightened(0.45)
	var tip := a + Vector2(w, fh * 0.5 + wave)
	match pattern:
		1: # прямоугольник с полосой
			var q := PackedVector2Array([a, a + Vector2(w, wave), a + Vector2(w, fh + wave), a + Vector2(0, fh)])
			ci.draw_colored_polygon(q, col)
			ci.draw_colored_polygon(PackedVector2Array([a + Vector2(0, fh * 0.38), a + Vector2(w, fh * 0.38 + wave),
				a + Vector2(w, fh * 0.62 + wave), a + Vector2(0, fh * 0.62)]), light)
			ci.draw_polyline(q + PackedVector2Array([a]), dark, 1.0)
		2: # ласточкин хвост
			var q := PackedVector2Array([a, a + Vector2(w, wave), a + Vector2(w * 0.65, fh * 0.5 + wave), a + Vector2(w, fh + wave), a + Vector2(0, fh)])
			ci.draw_colored_polygon(q, col)
			ci.draw_polyline(q + PackedVector2Array([a]), dark, 1.0)
		3: # крест
			var q := PackedVector2Array([a, a + Vector2(w, wave), a + Vector2(w, fh + wave), a + Vector2(0, fh)])
			ci.draw_colored_polygon(q, col)
			ci.draw_line(a + Vector2(w * 0.4, wave * 0.4), a + Vector2(w * 0.4, fh + wave * 0.4), light, maxf(1.5, fh * 0.18))
			ci.draw_line(a + Vector2(0, fh * 0.5), a + Vector2(w, fh * 0.5 + wave), light, maxf(1.5, fh * 0.18))
			ci.draw_polyline(q + PackedVector2Array([a]), dark, 1.0)
		4: # звезда на полотнище
			var q := PackedVector2Array([a, a + Vector2(w, wave), a + Vector2(w, fh + wave), a + Vector2(0, fh)])
			ci.draw_colored_polygon(q, col)
			var c := a + Vector2(w * 0.5, fh * 0.5 + wave * 0.5)
			var star := PackedVector2Array()
			for i in 10:
				var ang := -PI / 2.0 + PI * i / 5.0
				star.append(c + Vector2(cos(ang), sin(ang)) * (fh * 0.36 if i % 2 == 0 else fh * 0.15))
			ci.draw_colored_polygon(star, Color("ffe27a"))
			ci.draw_polyline(q + PackedVector2Array([a]), dark, 1.0)
		5: # двойной вымпел
			var q1 := PackedVector2Array([a, tip, a + Vector2(0, fh)])
			ci.draw_colored_polygon(q1, col)
			ci.draw_colored_polygon(PackedVector2Array([a + Vector2(0, fh * 0.25), a + Vector2(w * 0.55, fh * 0.5 + wave * 0.6),
				a + Vector2(0, fh * 0.75)]), light)
			ci.draw_polyline(q1 + PackedVector2Array([a]), dark, 1.0)
		_: # простой вымпел
			var q := PackedVector2Array([a, tip, a + Vector2(0, fh)])
			ci.draw_colored_polygon(q, col)
			ci.draw_polyline(q + PackedVector2Array([a]), dark, 1.0)


## Картинка флага для выбора узора.
class FlagPic extends Control:
	var pattern := 0
	var color := Color.RED

	func _draw() -> void:
		var r := minf(size.x, size.y) * 0.62
		WarScene.draw_flag(self, Vector2(size.x * 0.5 - r * 0.42, size.y * 0.5 + r * 0.5), r, color, pattern)


## Само поле боя: местность, территории, дороги, точки, туман, отряды. Двигается пальцем, приближается щипком или колесом.
class WarField extends Control:
	var on_pick: Callable
	var zoom := 1.0
	var offset := Vector2.ZERO
	var _fitted := false
	var _press := Vector2.ZERO
	var _moved := 0.0
	var _touches := {}
	var _pinch := 0.0
	var _t := 0.0
	var _terrain: Array = []
	var _seed := -1
	var _texs := {}

	const TREES := ["tree_oak", "tree_spruce", "tree_birch", "tree_oak_big", "tree_spruce_big", "tree_autumn"]
	const ROCKS := ["rock1", "rock2", "rock3", "rock_mossy", "rock_big"]
	const BUSHES := ["bush", "bush_leafy", "bush_berry"]

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		clip_contents = true
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _tex(name: String) -> Texture2D:
		if not _texs.has(name):
			_texs[name] = Sprites.texture(name)
		return _texs[name]

	## Рисунок из пака стоит на земле в точке p, высота h пикселей экрана (первый кадр ленты). false - рисунка нет.
	func _sprite(name: String, p: Vector2, h: float, modulate_c := Color.WHITE) -> bool:
		var t := _tex(name)
		if t == null:
			return false
		var i := Sprites.info(name)
		var fw := float(i.get("frame", t.get_width()))
		var fh := float(i.get("h", t.get_height() if not i.has("frame") else fw))
		var k := h / fh
		var a := Sprites.anchor(name)
		var dst := Rect2(p - Vector2(a.x * fw * k, (1.0 - a.y) * fh * k), Vector2(fw, fh) * k)
		draw_texture_rect_region(t, dst, Rect2(0, 0, fw, fh), modulate_c)
		return true

	## Монстр лагеря (портрет без краёв) стоит в точке p.
	func _monster(kind: String, p: Vector2, h: float) -> bool:
		var t := Monsters.icon(kind)
		if t == null:
			return false
		var k := h / float(t.get_height())
		draw_texture_rect(t, Rect2(p - Vector2(t.get_width() * k / 2.0, h), Vector2(t.get_width(), t.get_height()) * k), false)
		return true

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _base() -> float:
		return minf(size.x, size.y) / float(War.SIZE)

	## Наименьшее приближение: карта закрывает экран по высоте.
	func _min_zoom() -> float:
		return maxf(1.0, size.y / (_base() * War.SIZE) * 0.85)

	func _fit() -> void:
		zoom = _min_zoom() * 1.1
		var s := _base() * zoom
		var mine := Game.war.my_slot()
		var focus := Vector2(60, 60)
		if mine >= 1 and mine <= War.TEAMS:
			var b: Array = War.NODES[mine]
			focus = Vector2(60, 60).lerp(Vector2(float(b[0]), float(b[1])), 0.45)
		offset = Vector2(size.x / 2.0, size.y * 0.42) - focus * s
		_fitted = true
		_clamp()

	func to_screen(p: Vector2) -> Vector2:
		return p * _base() * zoom + offset

	func world(n: int) -> Vector2:
		var p: Array = War.NODES[n]
		return Vector2(float(p[0]), float(p[1]))

	func _clamp() -> void:
		var s := _base() * zoom * War.SIZE
		# Сверху место под счёт, снизу - под карточку точки
		offset.x = clampf(offset.x, size.x - s - 40.0, 40.0) if s + 80.0 > size.x else (size.x - s) / 2.0
		offset.y = clampf(offset.y, size.y - s - 260.0, 150.0)

	func _gen_terrain() -> void:
		var lg := int(Game.war.state.get("league", 1))
		if lg == _seed:
			return
		_seed = lg
		_terrain.clear()
		var rng := RandomNumberGenerator.new()
		rng.seed = lg * 7919 + 17
		var tries := 0
		while _terrain.size() < 70 and tries < 900:
			tries += 1
			var p := Vector2(rng.randf_range(2, 118), rng.randf_range(2, 118))
			var near := false
			for n in War.NODES.size():
				if p.distance_to(world(n)) < 7.0:
					near = true
					break
			if near:
				continue
			# Дороги не застраиваем
			for l in War.LINKS:
				if Geometry2D.get_closest_point_to_segment(p, world(int(l[0])), world(int(l[1]))).distance_to(p) < 3.0:
					near = true
					break
			if near:
				continue
			var roll := rng.randf()
			var kind := "tree" if roll < 0.55 else ("bush" if roll < 0.7 else ("rock" if roll < 0.88 else "lake"))
			_terrain.append([kind, p, rng.randf_range(1.6, 3.2), rng.randi_range(3, 6), rng.randi()])
		# Сверху вниз, чтобы ближние деревья закрывали дальние
		_terrain.sort_custom(func(a: Array, b: Array) -> bool: return (a[1] as Vector2).y < (b[1] as Vector2).y)

	func _draw() -> void:
		if not _fitted and size.x > 0:
			_fit()
		_gen_terrain()
		var w := Game.war
		var s := _base() * zoom
		var R := Rect2(to_screen(Vector2.ZERO), Vector2.ONE * War.SIZE * s)
		# Земля: трава, светлее к центру
		draw_rect(R, Color("5d8f42"))
		draw_circle(to_screen(Vector2(60, 60)), 52.0 * s, Color("679b49"))
		draw_circle(to_screen(Vector2(60, 60)), 34.0 * s, Color("72a651"))
		draw_circle(to_screen(Vector2(60, 60)), 16.0 * s, Color("85b35e"))
		# Территории альянсов: мягкие пятна цвета владельца вокруг точек
		for n in War.NODES.size():
			var o := int(w.node(n)["owner"])
			if o > 0 and w.visible(n):
				draw_circle(to_screen(world(n)), (14.0 if War.is_base(n) else 11.0) * s, Color(War.COLORS[o], 0.22))
		# Местность
		for x in _terrain:
			var p := to_screen(x[1])
			var r: float = float(x[2]) * s
			var rnd := int(x[4])
			match str(x[0]):
				"tree":
					if _tex(TREES[0]) != null:
						var spots: Array = []
						for i in int(x[3]):
							spots.append(p + Vector2(cos(i * 2.1), sin(i * 2.1) * 0.6) * r * 0.8)
						spots.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y)
						for i in spots.size():
							_sprite(TREES[(rnd + i) % TREES.size()], spots[i], r * (1.5 + 0.25 * ((rnd >> i) & 1)))
						continue
					for i in int(x[3]):
						var off := Vector2(cos(i * 2.1), sin(i * 2.1)) * r * 0.7
						draw_circle(p + off + Vector2(0, r * 0.25), r * 0.55, Color(0, 0, 0, 0.18))
						draw_circle(p + off, r * 0.55, Color("2f6b2c"))
						draw_circle(p + off - Vector2(r * 0.15, r * 0.15), r * 0.3, Color("3f8a38"))
				"bush":
					if _tex(BUSHES[0]) != null:
						for i in mini(3, int(x[3])):
							_sprite(BUSHES[(rnd + i) % BUSHES.size()], p + Vector2((i - 1) * r * 0.6, (i % 2) * r * 0.3), r * 0.6)
						continue
					draw_circle(p, r * 0.5, Color("3f8a38"))
				"rock":
					if _sprite(ROCKS[rnd % ROCKS.size()], p + Vector2(0, r * 0.4), r * 0.9):
						continue
					var pts := PackedVector2Array([p + Vector2(-r, r * 0.6), p + Vector2(0, -r), p + Vector2(r, r * 0.6)])
					draw_colored_polygon(pts, Color("8a8a80"))
					draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.3, -r * 0.45), p + Vector2(0, -r), p + Vector2(r * 0.3, -r * 0.45)]), Color("eeeeea"))
				"lake":
					draw_circle(p, r, Color("4a90c8"))
					draw_circle(p - Vector2(r * 0.3, r * 0.3), r * 0.35, Color(1, 1, 1, 0.25))
		# Дороги
		for l in War.LINKS:
			var a := int(l[0])
			var b := int(l[1])
			var oa := int(w.node(a)["owner"])
			var ob := int(w.node(b)["owner"])
			var pa := to_screen(world(a))
			var pb := to_screen(world(b))
			draw_line(pa, pb, Color("8a6a40"), maxf(2.0, s * 1.6), true)
			var mid := Color("c9a46a")
			if oa > 0 and oa == ob and w.visible(a):
				mid = War.COLORS[oa]
			draw_line(pa, pb, mid, maxf(1.0, s * 0.6), true)
		# Точки
		var font := UiKit.font()
		for n in War.NODES.size():
			_draw_node(n, font, s)
		# Сборы: кольцо с таймером над целью
		for r in w.rallies():
			var p := to_screen(world(int(r.get("node", 0))))
			var col: Color = War.COLORS[clampi(int(r.get("slot", 0)), 0, 8)]
			var rr := (8.0 + sin(_t * 4.0) * 1.0) * s
			draw_arc(p, rr, 0, TAU, 32, col, maxf(2.0, s * 0.8), true)
			if bool(r.get("mine", false)):
				_text(font, p + Vector2(0, -rr - 4), Fmt.seconds(maxf(0.0, float(r.get("fires", 0)) - w.now())), 12, Color.WHITE)
		# Отряды в пути
		for m in w.marches():
			var slot := int(m.get("slot", 0))
			var target := int(m.get("node", 0))
			if not bool(m.get("me", false)) and not w.visible(target):
				continue
			var from := w.origin(target, slot)
			var a0 := to_screen(world(from))
			var b0 := to_screen(world(target))
			var total := maxf(1.0, float(m.get("at", 0)) - float(m.get("from", 0)))
			var k := clampf((w.now() - float(m.get("from", 0))) / total, 0.0, 1.0)
			var col: Color = War.COLORS[clampi(slot, 0, 8)]
			# Пунктир пути
			var segs := 10
			for i in segs:
				if i % 2 == 0:
					draw_line(a0.lerp(b0, float(i) / segs), a0.lerp(b0, float(i + 1) / segs), Color(col, 0.8), maxf(1.5, s * 0.5), true)
			var at := a0.lerp(b0, k) + Vector2(0, sin(_t * 10.0) * 1.0)
			draw_circle(at + Vector2(0, 2), 5.5 * maxf(1.0, s * 0.4), Color(0, 0, 0, 0.3))
			draw_circle(at, 5.0 * maxf(1.0, s * 0.4), col)
			draw_arc(at, 5.0 * maxf(1.0, s * 0.4), 0, TAU, 16, UiKit.OUTLINE, 1.5, true)
			# Флажок отряда
			draw_line(at, at + Vector2(0, -12), UiKit.OUTLINE, 1.5)
			draw_colored_polygon(PackedVector2Array([at + Vector2(0, -12), at + Vector2(8, -9), at + Vector2(0, -6)]), col)
			if bool(m.get("me", false)):
				_text(font, at + Vector2(0, -16), Fmt.seconds(maxf(0.0, float(m.get("at", 0)) - w.now())), 11, Color.WHITE)
		# Туман войны поверх далёких точек
		for n in War.NODES.size():
			if w.visible(n):
				continue
			var p := to_screen(world(n))
			for i in 3:
				var off := Vector2(cos(i * 2.1 + n), sin(i * 1.7 + n)) * 2.5 * s
				draw_circle(p + off, (4.0 + (i % 2)) * s, Color(0.88, 0.9, 0.93, 0.42))

	func _draw_node(n: int, font: Font, s: float) -> void:
		var w := Game.war
		var d := w.node(n)
		var seen := w.visible(n)
		var owner := int(d["owner"]) if seen else 0
		var p := to_screen(world(n))
		var t := War.tier(n)
		var col: Color = War.COLORS[clampi(owner, 0, War.COLORS.size() - 1)]
		var r := (2.6 + 0.5 * t) * s if t > 0 else 4.2 * s
		if t == 4:
			r = 6.0 * s
		if n == w.selected:
			draw_circle(p, r + 4.0 * s * 0.5 + 4.0, Color(1, 1, 1, 0.7))
		if seen and (w.can_march(n) or (t == 4 and w.can_rally(n))):
			draw_arc(p, r + 5.0 + sin(_t * 5.0) * 1.5, 0, TAU, 28, Color(1, 0.92, 0.4, 0.95), 2.5, true)
		# Тень
		draw_circle(p + Vector2(0, r * 0.5), r, Color(0, 0, 0, 0.25))
		if War.is_base(n):
			var tm := w.team(n)
			var bc: Color = War.COLORS[n] if not tm.is_empty() else Color("9a9080")
			if not _node_art(n, p, r, bc, true):
				_plain_node(n, p, r, t, col)
			if not tm.is_empty():
				_text(font, p + Vector2(0, r * 1.6), str(tm.get("tag", "")), 11, Color.WHITE)
			return
		if not _node_art(n, p, r, col, seen):
			_plain_node(n, p, r, t, col)
		if not seen:
			return
		# Щиты - светлые точки под точкой
		var sh := int(d["shields"])
		for i in sh:
			var off := (float(i) - (sh - 1) / 2.0) * 6.0
			draw_circle(p + Vector2(off, r + 6.0), 2.4, Color("f7f0d0"))
			draw_arc(p + Vector2(off, r + 6.0), 2.4, 0, TAU, 10, UiKit.OUTLINE, 1.0, true)
		# Зверь в гарнизоне
		var g := w.guard(n)
		if not g.is_empty():
			var tex := AnimalSheet.icon(g[0])
			if tex != null:
				var side := maxf(14.0, r * 1.3)
				draw_texture_rect(tex, Rect2(p + Vector2(r * 0.4, -r * 1.4), Vector2(side, side)), false)

	## Точка рисунками пака: лагерь, частокол, башни, дом. Флаг цвета владельца. false - рисунков нет.
	func _node_art(n: int, p: Vector2, r: float, col: Color, seen: bool) -> bool:
		if _tex("tent") == null and _tex("tower") == null:
			return false
		var w := Game.war
		var lvl := War.level(n)
		var owner := int(w.node(n)["owner"]) if seen else 0
		var u := r / 3.0
		var top := p
		if War.is_base(n):
			_sprite("house", p + Vector2(0, u * 1.5), r * 2.4)
			_sprite("tent", p + Vector2(-r * 1.3, u * 2.5), r * 1.2)
			_sprite("campfire_anim", p + Vector2(r * 1.2, u * 2.5), r * 0.8)
			top = p - Vector2(0, r * 2.0)
		elif lvl == 5:
			for i in 3:
				_sprite("palisade", p + Vector2((i - 1) * r * 0.9, u * 2.0), r * 1.0)
			_sprite("tower", p + Vector2(-r * 1.1, u * 1.5), r * 2.2)
			_sprite("tower", p + Vector2(r * 1.1, u * 1.5), r * 2.2)
			_sprite("house_red", p + Vector2(0, u * 2.5), r * 2.0)
			top = p - Vector2(0, r * 1.6)
		elif lvl == 4:
			_sprite("tower", p + Vector2(-r * 0.5, u * 2.0), r * 2.2)
			_sprite("house_red", p + Vector2(r * 0.6, u * 2.5), r * 1.6)
			_sprite("palisade", p + Vector2(-r * 1.2, u * 3.0), r * 0.9)
			_sprite("palisade", p + Vector2(r * 1.3, u * 3.0), r * 0.9)
			top = p - Vector2(r * 0.5, r * 2.2)
		elif lvl == 3:
			_sprite("tower", p + Vector2(0, u * 2.0), r * 2.1)
			_sprite("palisade", p + Vector2(-r * 0.9, u * 3.0), r * 0.9)
			_sprite("palisade", p + Vector2(r * 0.9, u * 3.0), r * 0.9)
			top = p - Vector2(0, r * 2.2)
		elif lvl == 2:
			_sprite("palisade", p + Vector2(-r * 0.8, u * 1.5), r * 1.1)
			_sprite("tent", p + Vector2(r * 0.2, u * 2.5), r * 1.6)
			top = p - Vector2(0, r * 1.2)
		else:
			_sprite("tent", p + Vector2(-r * 0.2, u * 2.0), r * 1.5)
			_sprite("campfire_anim", p + Vector2(r * 0.9, u * 2.5), r * 0.7)
			top = p - Vector2(0, r * 1.1)
		# Ничья клетка: лагерь монстров - видно, кто в нём стоит
		if seen and owner == 0 and not War.is_base(n) and lvl > 0:
			var kinds: Array = War.CAMP_MONSTERS[lvl]
			_monster(str(kinds[n % kinds.size()]), p + Vector2(-r * 0.9, u * 3.5), r * 1.2)
		# Флаг владельца
		if owner > 0 or War.is_base(n):
			var fs := owner if owner > 0 else n
			WarScene.draw_flag(self, top, r, col, w.flag(fs), sin(_t * 4.0 + n) * r * 0.08)
		# Уровень клетки - кружок с цифрой
		if lvl > 0 and seen:
			var lp := p + Vector2(r * 1.3, -r * 0.2)
			draw_circle(lp, maxf(7.0, r * 0.45), UiKit.OUTLINE)
			draw_circle(lp, maxf(6.0, r * 0.45) - 1.5, Color("f0c75e") if lvl < 5 else Color("e05a3a"))
			_text(UiKit.font(), lp + Vector2(0, 4), str(lvl), 11, Color.WHITE)
		return true

	## Точка без рисунков пака (их нет без ключа): простые фигуры.
	func _plain_node(n: int, p: Vector2, r: float, t: int, col: Color) -> void:
		var w := Game.war
		if War.is_base(n):
			# База: шатёр с флагом
			var tm := w.team(n)
			var bc: Color = War.COLORS[n] if not tm.is_empty() else Color("9a9080")
			draw_rect(Rect2(p - Vector2(r, r * 0.6), Vector2(r * 2, r * 1.4)), Color("c9a46a"))
			draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 1.2, -r * 0.6), p + Vector2(0, -r * 1.5), p + Vector2(r * 1.2, -r * 0.6)]), bc)
			draw_line(p + Vector2(0, -r * 1.5), p + Vector2(0, -r * 2.4), UiKit.OUTLINE, 2.0)
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r * 2.4), p + Vector2(r * 0.9, -r * 2.1), p + Vector2(0, -r * 1.8)]), bc)
			return
		if t == 4:
			# Замок: стена с башнями
			var wall := Rect2(p - Vector2(r, r * 0.5), Vector2(r * 2, r * 1.2))
			draw_rect(wall, Color("a8a090"))
			for i in 3:
				var tx := p.x + (i - 1) * r * 0.9
				draw_rect(Rect2(tx - r * 0.28, p.y - r * 1.1, r * 0.56, r * 0.9), Color("bdb5a3"))
				draw_colored_polygon(PackedVector2Array([Vector2(tx - r * 0.35, p.y - r * 1.1), Vector2(tx, p.y - r * 1.6), Vector2(tx + r * 0.35, p.y - r * 1.1)]), col)
			draw_rect(Rect2(p.x - r * 0.2, p.y + r * 0.1, r * 0.4, r * 0.6), UiKit.WOOD_DARK)
			draw_rect(wall, UiKit.OUTLINE, false, 1.5)
		elif t == 3:
			# Крепость
			draw_rect(Rect2(p - Vector2(r, r * 0.8), Vector2(r * 2, r * 1.6)), Color("b0a68f"))
			for i in 4:
				draw_rect(Rect2(p.x - r + i * r * 0.55, p.y - r * 1.1, r * 0.35, r * 0.35), Color("b0a68f"))
			draw_rect(Rect2(p - Vector2(r * 0.5, r * 0.3), Vector2(r, r * 0.7)), col)
			draw_rect(Rect2(p - Vector2(r, r * 0.8), Vector2(r * 2, r * 1.6)), UiKit.OUTLINE, false, 1.5)
		elif t == 2:
			# Башня
			draw_rect(Rect2(p - Vector2(r * 0.6, r * 0.7), Vector2(r * 1.2, r * 1.6)), Color("a89a80"))
			draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.85, -r * 0.7), p + Vector2(0, -r * 1.6), p + Vector2(r * 0.85, -r * 0.7)]), col)
			draw_rect(Rect2(p - Vector2(r * 0.6, r * 0.7), Vector2(r * 1.2, r * 1.6)), UiKit.OUTLINE, false, 1.5)
		else:
			# Аванпост: частокол и флаг
			draw_circle(p, r, Color("9b7a4a"))
			draw_circle(p, r * 0.65, col)
			draw_arc(p, r, 0, TAU, 20, UiKit.OUTLINE, 1.5, true)

	func _text(font: Font, at: Vector2, text: String, size: int, color: Color) -> void:
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_string_outline(font, at - Vector2(tw / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, UiKit.OUTLINE)
		draw_string(font, at - Vector2(tw / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventScreenTouch:
			if e.pressed:
				_touches[e.index] = e.position
				if _touches.size() == 1:
					_press = e.position
					_moved = 0.0
				elif _touches.size() == 2:
					var v: Array = _touches.values()
					_pinch = (v[0] as Vector2).distance_to(v[1])
			else:
				_touches.erase(e.index)
				if _touches.is_empty() and _moved < 10.0:
					_tap(e.position)
			accept_event()
		elif e is InputEventScreenDrag:
			_touches[e.index] = e.position
			if _touches.size() >= 2:
				var v: Array = _touches.values()
				var dist := (v[0] as Vector2).distance_to(v[1])
				if _pinch > 0.0:
					_zoom_at(((v[0] as Vector2) + (v[1] as Vector2)) / 2.0, dist / _pinch)
				_pinch = dist
				_moved += 20.0
			else:
				offset += e.relative
				_moved += e.relative.length()
				_clamp()
			accept_event()
		elif e is InputEventMouseButton:
			if e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
				_zoom_at(e.position, 1.1)
			elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
				_zoom_at(e.position, 1.0 / 1.1)
			elif e.button_index == MOUSE_BUTTON_LEFT and not DisplayServer.is_touchscreen_available():
				if e.pressed:
					_press = e.position
					_moved = 0.0
				elif _moved < 10.0:
					_tap(e.position)
			accept_event()
		elif e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT) and not DisplayServer.is_touchscreen_available():
			offset += e.relative
			_moved += e.relative.length()
			_clamp()
			accept_event()
		elif e is InputEventMagnifyGesture:
			_zoom_at(e.position, e.factor)
			accept_event()

	func _zoom_at(at: Vector2, k: float) -> void:
		var nz := clampf(zoom * k, _min_zoom(), _min_zoom() * 3.0)
		var real := nz / zoom
		offset = at - (at - offset) * real
		zoom = nz
		_clamp()

	func _tap(at: Vector2) -> void:
		var best := -1
		var dist := 1e9
		for n in War.NODES.size():
			var d := at.distance_to(to_screen(world(n)))
			if d < dist:
				dist = d
				best = n
		if best >= 0 and dist <= 6.0 * _base() * zoom + 16.0:
			on_pick.call(best)
		else:
			on_pick.call(-1)
