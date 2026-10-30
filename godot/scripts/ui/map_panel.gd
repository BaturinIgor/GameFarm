class_name MapPanel
extends Sheet
## Карта мира (порт MapView): выбор планеты, схема локаций и проходов, карточка локации с переходом
## и открытием проходов, ивент (EventsPanel.map_card), экспедиции по билетам и бесплатный билет, королевский сад
## (без покупки - кнопка в магазин).

const SMALL_BUTTON_HEIGHT := 34.0

static var _planet_tex: Dictionary = {}

## Выбранная на схеме локация ("" - текущая).
var selected := ""
var planet := "home"
var _ticket_ready := false


func _init() -> void:
	title_key = "hud.map"
	planet = Locations.planet(Game.current)


func _process(delta: float) -> void:
	# Бесплатный билет созрел, пока окно открыто: показать кнопку
	var ticket := Game.premium.free_ticket_ready()
	if ticket != _ticket_ready:
		_ticket_ready = ticket
		_dirty = true
	super(delta)


func build() -> void:
	_ticket_ready = Game.premium.free_ticket_ready()
	content.add_child(_planet_picker())
	if planet == "home":
		content.add_child(WorldGraphView.new(selected, _select))
		var id := selected if selected != "" else Game.current
		if Locations.kind(id) == "world" and Locations.planet(id) == "home":
			content.add_child(_location_card(id))
	else:
		content.add_child(_planet_card(planet))
		for id in WorldGraph.planet_locations(planet):
			content.add_child(_location_card(id))
	content.add_child(EventsPanel.map_card(close))
	content.add_child(_wild_card())
	content.add_child(_expeditions_card())
	content.add_child(_garden_card())


func _select(id: String) -> void:
	selected = id
	Sound.play("tap")
	_dirty = true


func _travel(id: String) -> void:
	if Game.world_map.travel(id):
		close()


# MARK: Планеты

func _planet_picker() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var any_locked := WorldGraph.PLANETS.any(func(p: String) -> bool: return not Game.world_map.planet_open(p))
	for p in WorldGraph.PLANETS:
		var open := Game.world_map.planet_open(p)
		var on: bool = p == planet
		var light: Color = WorldGraph.planet_colors(p)[0]
		var fill: Color = Color(light, 0.35) if on else UiKit.PARCHMENT_LIGHT
		var border: Color = UiKit.OUTLINE if on else Color(UiKit.WOOD_DARK, 0.35)
		var b := _plain_button(UiKit.box(fill, border, 14, 3 if on else 2, false))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 92 if any_locked else 76)
		var col := _fill_box(VBoxContainer.new(), b)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 4)
		var ball := _planet_ball(p, 40.0)
		if not open:
			ball.material = HousePanel.gray_material(0.1)
			ball.modulate.a = 0.6
		col.add_child(ball)
		var name_l := UiKit.label(WorldGraph.planet_name(p), 12)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.clip_text = true
		col.add_child(name_l)
		if not open:
			col.add_child(_locked_line(L.t("common.lvl", [WorldGraph.planet_level(p)]), 10, UiKit.INK_SOFT, true))
		b.pressed.connect(func() -> void:
			planet = p
			_dirty = true)
		row.add_child(b)
	return row


## Описание дальней планеты.
func _planet_card(p: String) -> PanelContainer:
	var dark: Color = WorldGraph.planet_colors(p)[1]
	var card := PanelContainer.new()
	var s := UiKit.box(Color(dark, 0.15), dark, 18, 3, false)
	s.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", s)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	var ball := _planet_ball(p, 64.0)
	ball.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ball)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	col.add_child(UiKit.label(WorldGraph.planet_name(p), 18))
	col.add_child(_wrap(WorldGraph.planet_blurb(p), 12, UiKit.INK_SOFT))
	if not Game.world_map.planet_open(p):
		col.add_child(_locked_line(L.t("common.needLevel", [WorldGraph.planet_level(p)]), 12, UiKit.TONES["orange"][2]))
	return card


## Нарисованная планета: шар с полосами и светом (PlanetBall).
static func _planet_ball(p: String, side: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = planet_texture(p)
	t.custom_minimum_size = Vector2(side, side)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	t.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


static func planet_texture(p: String) -> Texture2D:
	if _planet_tex.has(p):
		return _planet_tex[p]
	var n := 64
	var half := n / 2.0
	var colors: Array = WorldGraph.planet_colors(p)
	var light: Color = colors[0]
	var dark: Color = colors[1]
	var glow := Vector2(0.35, 0.3) * n
	var end_r := n * 0.7
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var q := Vector2(x + 0.5, y + 0.5)
			var d := q.distance_to(Vector2(half, half))
			var cover := clampf(half - d + 0.5, 0.0, 1.0)
			if cover <= 0.0:
				continue
			var c := light.lerp(dark, clampf((q.distance_to(glow) - 1.0) / (end_r - 1.0), 0.0, 1.0))
			# Полосы материков
			if _in_capsule(q, Vector2(half, half - n * 0.12), n * 0.7, n * 0.12):
				c = c.blend(Color(1, 1, 1, 0.18))
			if _in_capsule(q, Vector2(half + n * 0.08, half + n * 0.16), n * 0.5, n * 0.1):
				c = c.blend(Color(0, 0, 0, 0.12))
			if d > half - n * 0.05:
				c = UiKit.OUTLINE
			c.a = cover
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_planet_tex[p] = tex
	return tex


static func _in_capsule(q: Vector2, c: Vector2, w: float, h: float) -> bool:
	var dx := maxf(absf(q.x - c.x) - (w - h) / 2.0, 0.0)
	var dy := absf(q.y - c.y)
	return dx * dx + dy * dy <= h * h / 4.0


# MARK: Локация

func _location_card(id: String) -> PanelContainer:
	var wm := Game.world_map
	var spec := Locations.spec(id)
	var unlocked := wm.is_unlocked(id)
	var here := Game.current == id
	var card := PanelContainer.new()
	var border: Color = UiKit.TONES["green"][1] if here else spec["ground"]
	var s := UiKit.box(UiKit.PARCHMENT_LIGHT, border, 18, 3, false)
	s.set_content_margin_all(14)
	s.shadow_color = Color(UiKit.WOOD_DARK, 0.25)
	s.shadow_offset = Vector2(0, 3)
	s.shadow_size = 1
	card.add_theme_stylebox_override("panel", s)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	var ic := UiKit.icon(Locations.icon(id), 44)
	ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(ic)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(col)
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", 6)
	col.add_child(title)
	title.add_child(UiKit.label(Locations.name_of(id), 16))
	if not unlocked:
		var lock := UiKit.icon("key", 14)
		lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		title.add_child(lock)
	col.add_child(_wrap(Locations.blurb(id), 12, UiKit.INK_SOFT))

	# Что здесь добыть и кто живёт
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 5)
	flow.add_theme_constant_override("v_separation", 5)
	v.add_child(flow)
	for kind in location_resources(id):
		flow.add_child(_icon_chip(UiKit.icon(kind, 22), Color(UiKit.PARCHMENT_DEEP, 0.7)))
	for animal in spec["wild"]:
		var a := UiKit.icon("paw", 22)
		var tex := AnimalSheet.icon(animal)
		if tex != null:
			a.texture = tex
		var chip := _icon_chip(a, Color("f6d9e0"))
		if Game.animals.stars(animal) <= 0:
			chip.modulate.a = 0.55
		flow.add_child(chip)

	if here:
		v.add_child(UiKit.label(L.t("map.here"), 14, UiKit.GOOD))
	elif not unlocked and Locations.planet(id) != "home":
		v.add_child(_locked_line(L.t("common.needLevel", [spec["level"]]), 13, UiKit.TONES["orange"][2]))
	elif unlocked:
		var go := UiKit.button(L.t("map.go"), "green", 15)
		go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		go.disabled = Game.premium.expedition() != null or Game.dungeons.run != null
		go.pressed.connect(func() -> void: _travel(id))
		v.add_child(go)

	# Проходы этой локации
	for g in WorldGraph.gates_of(id):
		if not g["royal"]:
			_gate_row(v, g, id)
	return card


## Строка прохода: куда ведёт, открыт ли, сколько стоит (GateRow).
func _gate_row(v: VBoxContainer, g: Dictionary, from: String) -> void:
	var wm := Game.world_map
	var other := WorldGraph.other(g, from)
	var open := wm.is_gate_open(g["id"])
	var known := wm.is_reachable(g["a"]) or wm.is_reachable(g["b"])
	var line := ColorRect.new()
	line.color = Color(UiKit.WOOD_DARK, 0.18)
	line.custom_minimum_size = Vector2(0, 1.5)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(line)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	v.add_child(head)
	var ic := UiKit.icon("door" if open else "key", 18)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(ic)
	var to := UiKit.label(L.t("gate.to", [Locations.name_of(other)]), 14)
	to.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	to.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(to)
	var level := WorldGraph.level(g)
	if open:
		var done := UiKit.label(L.t("gate.open.done"), 12, UiKit.GOOD)
		done.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(done)
	else:
		head.add_child(HousePanel.level_tag(level, Game.level >= level))
	if not open and known:
		if str(g["group"]) != "":
			var names: Array = WorldGraph.bundle(g).map(func(b: Dictionary) -> String:
				return "%s - %s" % [Locations.name_of(b["a"]), Locations.name_of(b["b"])])
			v.add_child(_wrap(L.t("gate.bundle", ["  ".join(PackedStringArray(names))]), 12, UiKit.INK_SOFT))
		if wm.is_reachable(g["a"]) and wm.is_reachable(g["b"]):
			v.add_child(_wrap(L.t("gate.shortcut"), 12, UiKit.INK_SOFT))
		v.add_child(UiKit.cost_view(wm.gate_cost(g)))
		var text := L.t("gate.open") if Game.level >= level else L.t("common.needLevel", [level])
		var b := UiKit.button(text, "green", 15)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = not wm.can_open_gate(g)
		var gate_id: String = g["id"]
		b.pressed.connect(func() -> void:
			if Game.world_map.open_gate(gate_id):
				Input.vibrate_handheld(30))
		v.add_child(b)
	elif not open:
		v.add_child(_wrap(L.t("gate.far"), 12, UiKit.INK_SOFT))


## Какие ресурсы можно добыть в локации (по точкам на её карте).
static func location_resources(id: String) -> Array:
	var out: Array = []
	for t in MapLayout.load_layout(id).node_types():
		for y in Nodes.spec(t)["yields"]:
			if not y[0] in out:
				out.append(y[0])
	return out


# MARK: Дикие земли

## Карточка диких земель: отряды в пути и кнопка "Открыть" (с 15 уровня).
func _wild_card() -> Control:
	var parts := _ribbon_card(L.t("wild.title"), "green")
	var v: VBoxContainer = parts[1]
	var w := Game.wild
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	row.add_child(UiKit.icon("compass", 34))
	var text := ""
	if not w.open():
		text = L.t("wild.locked", [int(Wild.RINGS[0]["level"])])
	elif w.squads_total() == 0:
		text = L.t("wild.noCamp")
	else:
		text = L.t("wild.squads", [w.squads().size(), w.squads_total()])
		if w.ready_count() > 0:
			text += " · " + L.t("wild.back")
	var t := UiKit.label(text, 13, UiKit.INK_SOFT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(t)
	if w.open():
		var b := UiKit.button(L.t("where.open"), "green", 13, true)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func() -> void:
			close()
			WildPanel.open())
		row.add_child(b)
	return parts[0]


# MARK: Экспедиции

func _expeditions_card() -> Control:
	var parts := _ribbon_card(L.t("exp.title"), "blue")
	var v: VBoxContainer = parts[1]
	var p := Game.premium
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)
	var sub := _wrap(L.t("exp.subtitle2"), 12, UiKit.INK_SOFT)
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sub)
	var wallet := PanelContainer.new()
	var ws := UiKit.box(UiKit.PARCHMENT_DEEP, Color(UiKit.WOOD_DARK, 0.5), 14, 2, false)
	ws.content_margin_left = 10
	ws.content_margin_right = 10
	ws.content_margin_top = 4
	ws.content_margin_bottom = 4
	wallet.add_theme_stylebox_override("panel", ws)
	wallet.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(wallet)
	var wrow := HBoxContainer.new()
	wrow.add_theme_constant_override("separation", 4)
	wallet.add_child(wrow)
	wrow.add_child(UiKit.icon("ticket", 20))
	wrow.add_child(UiKit.label(str(p.tickets()), 16))
	var tmap := UiKit.icon("tmap", 20)
	wrow.add_child(tmap)
	wrow.add_child(UiKit.label(str(p.maps()), 16))

	if p.free_ticket_ready():
		var free := UiKit.button(L.t("exp.freeTicket"), "orange", 15)
		free.icon = Sprites.icon("ticket")
		free.add_theme_constant_override("icon_max_width", 20)
		free.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		free.pressed.connect(func() -> void: Game.premium.claim_free_ticket())
		v.add_child(free)
	elif p.next_free_ticket() != null:
		var next := float(p.next_free_ticket())
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		var clock := UiKit.icon("stopwatch", 14)
		clock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(clock)
		var left := func() -> String:
			return L.t("exp.nextTicket", [TraderPanel.countdown(next - Time.get_unix_time_from_system())])
		row.add_child(CombatCards.LiveLabel.new(left, 12, UiKit.INK_SOFT))
		v.add_child(row)

	var busy := p.expedition() != null or Game.dungeons.run != null
	for id in Expeditions.ids():
		v.add_child(_expedition_row(id, busy))
	return parts[0]


func _expedition_row(id: String, busy: bool) -> PanelContainer:
	var price := Expeditions.cost(id)
	var maps := Expeditions.maps(id)
	var box := PanelContainer.new()
	var s := UiKit.box(Color(UiKit.PARCHMENT_DEEP, 0.55), Color(UiKit.WOOD_DARK, 0.3), 14, 1, false)
	s.set_content_margin_all(10)
	box.add_theme_stylebox_override("panel", s)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var ic := UiKit.icon(Expeditions.icon(id), 36)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	col.add_child(_wrap(Locations.name_of(id), 14, UiKit.INK))
	col.add_child(_wrap(Expeditions.perk(id), 12, UiKit.INK_SOFT))
	col.add_child(UiKit.label(L.t("exp.minutes", [int(Expeditions.duration(id) / 60.0)]), 11, UiKit.INK_SOFT))
	# Не хватает инструментов: какие уровни нужны (красным), перед входом ещё и окно с вопросом
	var gear := Expeditions.gear(id)
	for m in gear["missing"]:
		var need := HBoxContainer.new()
		need.add_theme_constant_override("separation", 4)
		need.add_child(UiKit.icon(Tools.icon_name(str(m["tool"])), 14))
		var nl := UiKit.label(L.t("exp.gear.need", [L.t("tool." + str(m["tool"])), int(m["need"]), int(m["have"])]),
			11, UiKit.BAD)
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		need.add_child(nl)
		col.add_child(need)
	var parts: Array = [["t", L.t("exp.go")], ["t", str(price)], ["i", "ticket"]]
	if maps > 0:
		parts.append_array([["t", str(maps)], ["i", "tmap"]])
	var tone := "purple" if maps > 0 else ("orange" if price >= 3 else "green")
	var b := icon_button(parts, tone)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var p := Game.premium
	b.disabled = p.tickets() < price or p.maps() < maps or busy
	var go := func() -> void:
		if Game.premium.start_expedition(id):
			close()
	b.pressed.connect(func() -> void:
		var g := Expeditions.gear(id)
		if (g["missing"] as Array).is_empty():
			go.call()
			return
		var lines := PackedStringArray()
		for m in g["missing"]:
			lines.append(L.t("exp.gear.need", [L.t("tool." + str(m["tool"])), int(m["need"]), int(m["have"])]))
		var text := L.t("exp.gear.text", [int(g["blocked"]), int(g["total"])]) + "\n" + "\n".join(lines)
		ConfirmPopup.ask("px:" + Tools.icon_name(str(g["missing"][0]["tool"])), L.t("exp.gear.title"), text,
			L.t("exp.gear.go"), "orange", go, L.t("exp.gear.workshop"), func() -> void:
				if Hud.current != null:
					Hud.current.open_window(WorkshopPanel.new())))
	col.add_child(b)
	return box


# MARK: Королевский сад

## Сад: переход и королевский сундук. Без покупки - кнопка в магазин.
func _garden_card() -> Control:
	var parts := _ribbon_card(Locations.name_of("garden"), "gold")
	var v: VBoxContainer = parts[1]
	v.add_child(_wrap(Locations.blurb("garden"), 12, UiKit.INK_SOFT))
	if Game.premium.owns("garden"):
		var at = Game.save.get("gardenChestAt")
		var now := Time.get_unix_time_from_system()
		if not (at is float or at is int) or float(at) <= now:
			v.add_child(UiKit.label(L.t("garden.chestReady"), 12, UiKit.TONES["orange"][2]))
		else:
			var until := float(at)
			var left := func() -> String:
				return L.t("garden.chestIn", [TraderPanel.countdown(until - Time.get_unix_time_from_system())])
			v.add_child(CombatCards.LiveLabel.new(left, 12, UiKit.INK_SOFT))
		if Game.current == "garden":
			v.add_child(UiKit.label(L.t("map.here"), 14, UiKit.GOOD))
		else:
			var go := UiKit.button(L.t("map.go"), "orange", 15)
			go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			go.disabled = Game.premium.expedition() != null
			go.pressed.connect(func() -> void: _travel("garden"))
			v.add_child(go)
	else:
		var shop := UiKit.button(L.t("garden.more"), "orange", 15)
		shop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shop.pressed.connect(func() -> void:
			if Hud.current != null:
				Hud.current.open_window(ShopPanel.new()))
		v.add_child(shop)
	return parts[0]


# MARK: Общие элементы

## Карточка с цветной рамкой и лентой с названием (ShopCard): [вся карточка, столбец для содержимого].
static func _ribbon_card(title: String, tone: String) -> Array:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 14)
	var panel := PanelContainer.new()
	var s := UiKit.box(UiKit.PARCHMENT_LIGHT, UiKit.TONES[tone][1], 18, 4, false)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 16
	s.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", s)
	margin.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(holder)
	var ribbon := LevelUpOverlay.Ribbon.new()
	ribbon.tone = UiKit.TONES[tone]
	ribbon.label.label_settings.font_size = 17
	ribbon.label.label_settings.outline_color = ribbon.tone[2]
	ribbon.anchor_left = 0.5
	ribbon.anchor_right = 0.5
	ribbon.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ribbon.offset_top = -31
	ribbon.set_text(title)
	holder.add_child(ribbon)
	return [margin, v]


## Кнопка с подписями и иконками в ряд: parts = [["t", текст], ["i", иконка], ...]. Ширина - по содержимому.
static func icon_button(parts: Array, tone: String, font_size := 13) -> Button:
	var b := UiKit.button("", tone, font_size, true)
	var inner := HBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 3)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(inner)
	var width := 24.0 + 3.0 * (parts.size() - 1)
	for part in parts:
		if part[0] == "i":
			var ic := UiKit.icon(part[1], font_size + 1)
			ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			inner.add_child(ic)
			width += font_size + 1
		else:
			var l := UiKit.title(part[1], font_size)
			l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			inner.add_child(l)
			width += UiKit.font().get_string_size(part[1], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 6.0
	b.custom_minimum_size = Vector2(ceilf(width), SMALL_BUTTON_HEIGHT)
	return b


## Кнопка без своего текста: содержимое кладётся внутрь, нажатие - pressed.
static func _plain_button(style: StyleBoxFlat) -> Button:
	var b := Button.new()
	var pressed := style.duplicate() as StyleBoxFlat
	pressed.bg_color = pressed.bg_color.darkened(0.08)
	b.add_theme_stylebox_override("normal", style)
	b.add_theme_stylebox_override("hover", style)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", style)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.focus_mode = Control.FOCUS_NONE
	return b


## Растянуть контейнер на всю кнопку (содержимое не ловит касания).
static func _fill_box(box: BoxContainer, parent: Control) -> BoxContainer:
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)
	return box


static func _wrap(text: String, font_size: int, color: Color) -> Label:
	var l := UiKit.label(text, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(90, 0)
	return l


## Строка "замок + текст" (Label с lock.fill): вместо замка ключ.
static func _locked_line(text: String, font_size: int, color: Color, centered := false) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if centered:
		row.alignment = BoxContainer.ALIGNMENT_CENTER
	var ic := UiKit.icon("key", font_size + 2)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	row.add_child(UiKit.label(text, font_size, color))
	return row


static func _icon_chip(icon: Control, fill: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var s := UiKit.box(fill, Color(UiKit.WOOD_DARK, 0.3), 8, 1, false)
	s.set_content_margin_all(4)
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(icon)
	return p


# MARK: Схема мира

## Схема мира (WorldMapGraph): кружки локаций родной планеты и дорожки проходов между ними.
class WorldGraphView extends Control:
	const COLS := 3
	const ROWS := 4
	const GRAPH_HEIGHT := 440.0
	const PAD := 8.0
	const NODE_SIZE := Vector2(104, 82)
	const SQUARE := 58.0

	var _selected := ""
	var _on_select: Callable
	var _nodes: Dictionary = {}
	var _back := StyleBoxFlat.new()

	func _init(selected: String, on_select: Callable) -> void:
		_selected = selected
		_on_select = on_select
		custom_minimum_size = Vector2(0, GRAPH_HEIGHT + PAD * 2.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_back.bg_color = UiKit.PARCHMENT_DEEP
		_back.border_color = UiKit.OUTLINE
		_back.set_border_width_all(2)
		_back.set_corner_radius_all(18)
		_back.shadow_color = Color(UiKit.WOOD_DARK, 0.3)
		_back.shadow_offset = Vector2(0, 3)
		_back.shadow_size = 1
		_back.anti_aliasing = true
		for id in Locations.world():
			var n := _node(id)
			_nodes[id] = n
			add_child(n)
		resized.connect(_place_nodes)

	func _center(id: String) -> Vector2:
		var m: Vector2i = Locations.spec(id)["map"]
		var cw := size.x / COLS
		var rh := GRAPH_HEIGHT / ROWS
		return Vector2((m.x + 0.5) * cw, PAD + GRAPH_HEIGHT - (m.y + 0.5) * rh)

	func _place_nodes() -> void:
		for id in _nodes:
			var n: Control = _nodes[id]
			n.position = _center(id) - Vector2(NODE_SIZE.x / 2.0, SQUARE / 2.0)
		queue_redraw()

	func _draw() -> void:
		var wm := Game.world_map
		draw_style_box(_back, Rect2(Vector2.ZERO, size))
		_dashed_frame(Rect2(Vector2.ZERO, size).grow(-6.0), 14.0, Color(UiKit.WOOD_DARK, 0.35))
		var gates := WorldGraph.GATES.filter(func(g: Dictionary) -> bool: return not g["royal"])
		for g in gates:
			var a := _center(g["a"])
			var b := _center(g["b"])
			if wm.is_gate_open(g["id"]):
				_round_line(a, b, UiKit.OUTLINE, 9.0)
				_round_line(a, b, Color("e2b77a"), 5.0)
			else:
				var known := wm.is_reachable(g["a"]) or wm.is_reachable(g["b"])
				draw_dashed_line(a, b, Color(UiKit.WOOD_DARK, 0.5 if known else 0.18), 3.0, 6.0)
		# Замки на закрытых проходах, до которых уже можно дойти
		for g in gates:
			if wm.is_gate_open(g["id"]) or not (wm.is_reachable(g["a"]) or wm.is_reachable(g["b"])):
				continue
			var mid := (_center(g["a"]) + _center(g["b"])) / 2.0
			var can := wm.can_open_gate(g)
			draw_circle(mid, 12.0, UiKit.GOLD if can else UiKit.PARCHMENT_LIGHT)
			draw_arc(mid, 11.5, 0.0, TAU, 32, UiKit.OUTLINE, 1.5, true)
			var key := Sprites.icon("key")
			if key != null:
				draw_texture_rect(key, Rect2(mid - Vector2(7, 7), Vector2(14, 14)), false,
					Color.WHITE if can else Color(1, 1, 1, 0.75))

	func _round_line(a: Vector2, b: Vector2, color: Color, width: float) -> void:
		draw_line(a, b, color, width, true)
		draw_circle(a, width / 2.0, color)
		draw_circle(b, width / 2.0, color)

	## Пунктирная рамка со скруглёнными углами.
	func _dashed_frame(r: Rect2, radius: float, color: Color) -> void:
		var x0 := r.position.x
		var y0 := r.position.y
		var x1 := r.end.x
		var y1 := r.end.y
		draw_dashed_line(Vector2(x0 + radius, y0), Vector2(x1 - radius, y0), color, 1.5, 6.0)
		draw_dashed_line(Vector2(x0 + radius, y1), Vector2(x1 - radius, y1), color, 1.5, 6.0)
		draw_dashed_line(Vector2(x0, y0 + radius), Vector2(x0, y1 - radius), color, 1.5, 6.0)
		draw_dashed_line(Vector2(x1, y0 + radius), Vector2(x1, y1 - radius), color, 1.5, 6.0)
		draw_arc(Vector2(x0 + radius, y0 + radius), radius, PI, PI * 1.5, 8, color, 1.5, true)
		draw_arc(Vector2(x1 - radius, y0 + radius), radius, PI * 1.5, TAU, 8, color, 1.5, true)
		draw_arc(Vector2(x1 - radius, y1 - radius), radius, 0.0, PI * 0.5, 8, color, 1.5, true)
		draw_arc(Vector2(x0 + radius, y1 - radius), radius, PI * 0.5, PI, 8, color, 1.5, true)

	## Кружок локации: картинка карты, иконка, рамка, замок и герой, подпись.
	func _node(id: String) -> Button:
		var unlocked := Game.world_map.is_unlocked(id)
		var here := Game.current == id
		var picked := (_selected if _selected != "" else Game.current) == id
		var b := Button.new()
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = NODE_SIZE
		b.size = NODE_SIZE
		var col := VBoxContainer.new()
		col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		col.add_theme_constant_override("separation", 3)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(col)

		var square := Control.new()
		square.custom_minimum_size = Vector2(SQUARE, SQUARE)
		square.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		square.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(square)
		var shadow := StyleBoxFlat.new()
		shadow.bg_color = Color(UiKit.OUTLINE, 0.45)
		shadow.set_corner_radius_all(12)
		square.draw.connect(func() -> void: square.draw_style_box(shadow, Rect2(0, 3, SQUARE, SQUARE)))
		var pic := GateCard.location_thumb(id, SQUARE, 26.0, 1.0 if unlocked else 0.0, false, 1.0 if unlocked else 0.6)
		square.add_child(pic)
		var over := Control.new()
		over.size = Vector2(SQUARE, SQUARE)
		over.mouse_filter = Control.MOUSE_FILTER_IGNORE
		square.add_child(over)
		var ring := StyleBoxFlat.new()
		ring.draw_center = false
		ring.border_color = UiKit.GOLD if here else (Color.WHITE if picked else UiKit.OUTLINE)
		ring.set_border_width_all(4 if here or picked else 2)
		ring.set_corner_radius_all(12)
		ring.anti_aliasing = true
		var outer := StyleBoxFlat.new()
		outer.draw_center = false
		outer.border_color = UiKit.OUTLINE
		outer.set_border_width_all(2)
		outer.set_corner_radius_all(14)
		outer.anti_aliasing = true
		var face: Texture2D = LevelPanel.portrait(str(Game.save.get("skin", "farmer"))) if here else null
		var key := Sprites.icon("key")
		over.draw.connect(func() -> void:
			var r := Rect2(0, 0, SQUARE, SQUARE)
			over.draw_style_box(ring, r)
			if here or picked:
				over.draw_style_box(outer, r.grow(2.0))
			var c := r.get_center()
			if not unlocked:
				var lc := c + Vector2(24, 24)
				over.draw_circle(lc, 11.0, UiKit.WOOD_DARK)
				over.draw_arc(lc, 10.5, 0.0, TAU, 28, UiKit.OUTLINE, 1.5, true)
				if key != null:
					over.draw_texture_rect(key, Rect2(lc - Vector2(6, 6), Vector2(12, 12)), false)
			if here:
				var hc := c + Vector2(24, -26)
				over.draw_circle(hc, 15.0, UiKit.PARCHMENT_LIGHT)
				if face != null:
					over.draw_texture_rect(face, Rect2(hc - Vector2(10, 10), Vector2(20, 20)), false)
				over.draw_arc(hc, 14.0, 0.0, TAU, 32, UiKit.OUTLINE, 2.0, true))

		var tag := PanelContainer.new()
		var ts := UiKit.box(UiKit.PARCHMENT_LIGHT if unlocked else UiKit.PARCHMENT_DEEP, Color(UiKit.WOOD_DARK, 0.5), 9, 1, false)
		ts.content_margin_left = 6
		ts.content_margin_right = 6
		ts.content_margin_top = 1
		ts.content_margin_bottom = 1
		tag.add_theme_stylebox_override("panel", ts)
		tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var text := Locations.name_of(id)
		var font_size := 11
		var w := UiKit.font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if w > NODE_SIZE.x - 12.0:
			font_size = maxi(8, int(floor(font_size * maxf(0.7, (NODE_SIZE.x - 12.0) / w))))
		var l := UiKit.label(text, font_size, UiKit.INK if unlocked else UiKit.INK_SOFT)
		l.clip_text = true
		tag.add_child(l)
		col.add_child(tag)
		b.pressed.connect(func() -> void: _on_select.call(id))
		return b
