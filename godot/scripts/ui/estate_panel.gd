class_name EstatePanel
extends Sheet
## Усадьба: здания (стройка, производство, улучшение) и доска заказов. Вкладки закреплены под шапкой.
## Чтобы не перегружать, из закрытых зданий показывается только ближайшее.

var tab := "buildings"
var _tick := 0.0


func _init(start_tab := "") -> void:
	title_key = "estate.title"
	if start_tab != "":
		tab = start_tab


static func open(start_tab := "") -> void:
	if Hud.current != null:
		Hud.current.open_window(EstatePanel.new(start_tab))


func _process(delta: float) -> void:
	super._process(delta)
	_tick -= delta
	if _tick <= 0.0:
		Game.estate.tick()
		# Идёт стройка - полоски и таймеры каждую секунду, иначе изредка (копится товар)
		_tick = 1.0 if Game.estate.builders_busy() > 0 else 5.0
		_dirty = true


func build_top() -> void:
	var e := Game.estate
	var items := [["buildings", L.t("estate.tab.buildings"), e.ready_count(), "hammer"]]
	if e.orders_open():
		items.append(["orders", L.t("estate.tab.orders"), e.ready_orders(), "quest"])
	top_bar.add_child(UiKit.tabs(items, tab, func(id: String) -> void:
		tab = id
		scroll_to_top()))


func build() -> void:
	Game.estate.tick()
	if tab == "orders" and Game.estate.orders_open():
		_build_orders()
	else:
		_build_buildings()


# MARK: Здания

func _build_buildings() -> void:
	var e := Game.estate
	content.add_child(_status_row())
	if e.ready_count() > 0:
		var all := UiKit.button(L.t("estate.collectAll"), "green", 15)
		all.icon = Sprites.icon("basket")
		all.add_theme_constant_override("icon_max_width", 22)
		all.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		all.pressed.connect(func() -> void: Game.estate.collect_all())
		content.add_child(all)
	var locked_shown := false
	for id in Estate.IDS:
		if e.is_open(id):
			content.add_child(_card(id))
		elif not locked_shown:
			locked_shown = true
			content.add_child(_locked_card(id))


## Строители и склад одной строкой (на узком экране переносится).
func _status_row() -> HFlowContainer:
	var e := Game.estate
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 6)
	var free := e.builders_total() - e.builders_busy()
	row.add_child(_chip("hammer", L.t("estate.builders", [free, e.builders_total()]), "green" if free > 0 else "orange"))
	row.add_child(_chip("chest", "%s/%s" % [Fmt.n(e.stored("storage")), Fmt.n(e.capacity("storage"))], "wood"))
	row.add_child(_chip("wheat", "%s/%s" % [Fmt.n(e.stored("barn")), Fmt.n(e.capacity("barn"))], "wood"))
	if not bool(Game.save.get("builder3", false)):
		var b := MapPanel.icon_button([["t", "+"], ["i", "hammer"], ["i", "gem"], ["t", str(Estate.BUILDER_CRYSTALS)]], "purple", 12)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func() -> void:
			if not Game.estate.buy_builder():
				Game.show_toast("px:gem", L.t("crystals.notEnough", [Fmt.n(Estate.BUILDER_CRYSTALS - Game.shop.crystals())])))
		row.add_child(b)
	return row


static func _chip(icon_name: String, text: String, tone: String) -> PanelContainer:
	var c: Array = UiKit.TONES[tone]
	var p := PanelContainer.new()
	var s := UiKit.box(Color(c[0], 0.35), c[1], 12, 2, false)
	s.content_margin_left = 6
	s.content_margin_right = 8
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", s)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	p.add_child(row)
	row.add_child(UiKit.icon(icon_name, 18))
	row.add_child(UiKit.label(text, 12))
	return p


func _card(id: String) -> PanelContainer:
	var e := Game.estate
	var lvl := e.level(id)
	var p := PanelContainer.new()
	var border: Color = UiKit.TONES["gold"][1] if e.ready(id) > 0 else Color(UiKit.WOOD_DARK, 0.45)
	var s := UiKit.box(UiKit.PARCHMENT_LIGHT, border, 16, 3 if e.ready(id) > 0 else 2, false)
	s.set_content_margin_all(12)
	s.shadow_color = Color(UiKit.WOOD_DARK, 0.25)
	s.shadow_offset = Vector2(0, 3)
	s.shadow_size = 1
	p.add_theme_stylebox_override("panel", s)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	var pic := PanelContainer.new()
	var ps := UiKit.box(Color("cfe7a8"), Color(UiKit.WOOD_DARK, 0.35), 14, 2, false)
	ps.set_content_margin_all(4)
	pic.add_theme_stylebox_override("panel", ps)
	pic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var art := HousePanel.sprite_rect(str(Estate.spec(id)["sprite"]), 2.0, Vector2(64, 64))
	if lvl == 0:
		art.modulate = Color(1, 1, 1, 0.45)
	pic.add_child(art)
	head.add_child(pic)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(col)
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", 6)
	col.add_child(title)
	var name_l := UiKit.label(Estate.name_of(id), 16)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(name_l)
	if lvl > 0:
		title.add_child(HousePanel.level_tag(lvl, true))
	col.add_child(_wrap(_effect_text(id), 12, UiKit.INK_SOFT))
	if lvl > 0 and e.working_level(id) < lvl and Estate.produces(id):
		col.add_child(_wrap(L.t("estate.working", [e.working_level(id)]), 11, UiKit.TONES["orange"][2]))

	if e.building(id):
		v.add_child(_build_progress(id))
	elif Estate.produces(id) and lvl > 0:
		v.add_child(_production(id))
	v.add_child(_upgrade_row(id))
	return p


## Что даёт здание сейчас (и на следующем уровне).
func _effect_text(id: String) -> String:
	var e := Game.estate
	var lvl := e.level(id)
	match id:
		"main":
			return L.t("estate.main.effect", [lvl])
		"storage", "barn":
			return L.t("estate.store.effect", [Fmt.n(e.stored(id)), Fmt.n(Estate.capacity(id, lvl)),
				Fmt.n(Estate.capacity(id, lvl + 1))])
		"board":
			return L.t("estate.board.effect", [e.orders_slots()]) if lvl > 0 else Estate.info(id)
		"tower":
			if lvl == 0:
				return Estate.info(id)
			var t := e.working_level(id)
			return L.t("estate.tower.effect", [Raids.tower_count(lvl), Fmt.n(int(Raids.tower_damage(t))),
				Raids.tower_count(lvl + 1)])
		"camp":
			return L.t("estate.camp.effect", [Wild.squads(lvl), Wild.squads(lvl + 1)]) if lvl > 0 else Estate.info(id)
		"wall":
			if lvl == 0:
				return Estate.info(id)
			return L.t("estate.wall.effect", [int(round((1.0 - Raids.wall_slow(lvl)) * 100.0)),
				int(round((1.0 - Raids.wall_slow(lvl + 1)) * 100.0))])
	if lvl == 0:
		return Estate.info(id)
	var good := e.recipe(id)
	return L.t("estate.prod.effect", [Res.name_of(good), "%.1f" % Estate.per_hour(good, e.working_level(id))])


func _build_progress(id: String) -> VBoxContainer:
	var e := Game.estate
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var total := Estate.build_seconds(id, e.level(id) + 1)
	var bar := UiKit.bar(1.0 - e.build_left(id) / maxf(1.0, total), "blue", 200.0, 16.0,
		L.t("estate.building", [House.countdown(e.build_left(id))]))
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var price := e.speedup_cost(id)
	var fast := ShopPanel.crystal_button(price, "purple", true)
	fast.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fast.pressed.connect(func() -> void:
		if not Game.estate.speed_up(id):
			Game.show_toast("px:gem", L.t("crystals.notEnough", [Fmt.n(price - Game.shop.crystals())])))
	row.add_child(fast)
	if e.ad_speedups_left() > 0:
		var ad := Ads.reward_button(L.t("estate.adSpeed"), "blue", 13, true)
		ad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ad.pressed.connect(func() -> void: Ads.show_rewarded(func() -> void: Game.estate.ad_speed_up(id)))
		row.add_child(ad)
	return v


func _production(id: String) -> VBoxContainer:
	var e := Game.estate
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	# Рецепты: что делать
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	for g in Estate.recipes(id):
		row.add_child(_recipe_chip(id, g))
	# Накоплено и кнопка "Забрать"
	var good := e.recipe(id)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	v.add_child(line)
	var ic := UiKit.icon(good, 26)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(ic)
	var text := ""
	var color := UiKit.INK
	if e.affordable(id) <= 0:
		text = L.t("estate.noInput")
		color = UiKit.BAD
	elif e.storage_room(good) <= 0:
		text = L.t("estate.storageFull")
		color = UiKit.BAD
	else:
		text = L.t("estate.ready", [e.ready(id), Res.name_of(good)])
		if e.full(id):
			text += " " + L.t("estate.capped")
	var l := _wrap(text, 13, color)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(l)
	var take := UiKit.button(L.t("estate.collect"), "green", 13, true)
	take.disabled = e.ready(id) <= 0
	take.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	take.pressed.connect(func() -> void:
		var n := Game.estate.collect(id)
		if n > 0:
			Sound.play("coin")
			Game.show_toast("res:" + good, "+%d %s" % [n, Res.name_of(good)]))
	line.add_child(take)
	return v


func _recipe_chip(id: String, good: String) -> Button:
	var e := Game.estate
	var on := e.recipe(id) == good
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st := UiKit.box(Color(UiKit.TONES["green"][0], 0.4) if on else Color(UiKit.PARCHMENT_DEEP, 0.6),
		UiKit.TONES["green"][2] if on else Color(UiKit.WOOD_DARK, 0.3), 10, 2 if on else 1, false)
	st.set_content_margin_all(4)
	for k in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(k, st)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	# Рецепт: входы -> товар
	for it in Estate.RECIPES[good]:
		row.add_child(UiKit.icon(it[0], 16))
		row.add_child(UiKit.label("%d" % int(it[1]), 11))
	row.add_child(UiKit.label(">", 11, UiKit.INK_SOFT))
	row.add_child(UiKit.icon(good, 18))
	b.custom_minimum_size = Vector2(0, 30)
	b.pressed.connect(func() -> void: Game.estate.set_recipe(id, good))
	return b


func _upgrade_row(id: String) -> VBoxContainer:
	var e := Game.estate
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var block := e.upgrade_block(id)
	var next := e.level(id) + 1
	if block.size() > 0 and block[0] == "estate.block.max":
		v.add_child(UiKit.label(L.t("estate.block.max"), 12, UiKit.GOOD))
		return v
	if e.building(id):
		return v
	var line := ColorRect.new()
	line.color = Color(UiKit.WOOD_DARK, 0.18)
	line.custom_minimum_size = Vector2(0, 1.5)
	v.add_child(line)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	v.add_child(head)
	var t := UiKit.label(L.t("estate.next", [next]) if e.level(id) > 0 else L.t("estate.build"), 13)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var clock := UiKit.icon("hourglass", 14)
	clock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(clock)
	head.add_child(UiKit.label(EventsPanel.long_countdown(Estate.build_seconds(id, next)), 12, UiKit.INK_SOFT))
	v.add_child(UiKit.cost_view(Estate.build_cost(id, next)))
	if block.is_empty():
		var b := UiKit.button(L.t("estate.upgrade") if e.level(id) > 0 else L.t("estate.build"), "green", 15)
		b.disabled = not e.can_afford(id)
		b.pressed.connect(func() -> void: Game.estate.start_upgrade(id))
		v.add_child(b)
	else:
		var why := HBoxContainer.new()
		why.add_theme_constant_override("separation", 8)
		v.add_child(why)
		why.add_child(_wrap(L.t(block[0], block[1]), 12, UiKit.TONES["orange"][2]))
		# Причина с кнопкой: к главному дому (он первый в списке)
		if block[0] == "estate.block.main":
			var go := UiKit.button(L.t("estate.toMain"), "wood", 12, true)
			go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			go.pressed.connect(scroll_to_top)
			why.add_child(go)
	return v


func _locked_card(id: String) -> PanelContainer:
	var p := PanelContainer.new()
	var s := UiKit.box(Color(UiKit.PARCHMENT_DEEP, 0.6), Color(UiKit.WOOD_DARK, 0.3), 16, 2, false)
	s.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", s)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	p.add_child(row)
	var art := HousePanel.sprite_rect(str(Estate.spec(id)["sprite"]), 2.0, Vector2(52, 52))
	art.modulate = Color(0.3, 0.25, 0.2, 0.5)
	row.add_child(art)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	col.add_child(UiKit.label(Estate.name_of(id), 15, UiKit.INK_SOFT))
	col.add_child(_wrap(Estate.info(id), 11, UiKit.INK_SOFT))
	col.add_child(UiKit.label(L.t("common.needLevel", [Estate.hero_level(id)]), 12, UiKit.TONES["orange"][2]))
	return p


# MARK: Заказы

func _build_orders() -> void:
	var e := Game.estate
	var hint := _wrap(L.t("orders.hint"), 12, UiKit.INK_SOFT)
	content.add_child(hint)
	var list := e.orders()
	# Повозка - первой
	var sorted: Array = list.filter(func(o: Dictionary) -> bool: return o["cart"]) + \
		list.filter(func(o: Dictionary) -> bool: return not o["cart"])
	for o in sorted:
		content.add_child(_order_card(o))
	if not list.any(func(o: Dictionary) -> bool: return o["cart"]):
		var at := float(Game.save.get("cartAt", 0.0))
		var left := func() -> String:
			return L.t("orders.cartIn", [House.countdown(at - Time.get_unix_time_from_system())])
		var l := CombatCards.LiveLabel.new(left, 12, UiKit.INK_SOFT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(l)


func _order_card(o: Dictionary) -> PanelContainer:
	var e := Game.estate
	var cart: bool = o["cart"]
	var empty := (o["items"] as Array).is_empty()
	var ok := e.can_complete(o)
	var p := PanelContainer.new()
	var border: Color = UiKit.TONES["gold"][1] if cart else (UiKit.TONES["green"][1] if ok else Color(UiKit.WOOD_DARK, 0.45))
	var s := UiKit.box(Color("fff3c4") if cart else UiKit.PARCHMENT_LIGHT, border, 16, 3 if (cart or ok) else 2, false)
	s.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", s)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	if empty:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		v.add_child(row)
		row.add_child(UiKit.icon("hourglass", 20))
		var until := float(o["wait"])
		var left := func() -> String:
			return L.t("orders.next", [House.countdown(until - Time.get_unix_time_from_system())])
		row.add_child(CombatCards.LiveLabel.new(left, 13, UiKit.INK_SOFT))
		return p
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	v.add_child(head)
	var from := str(o.get("from", ""))
	if from != "":
		var face := TraderPanel.portrait(Residents.sheet(from), 30)
		face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(face)
	var title := UiKit.label(L.t("orders.cart") if cart else (Residents.name_of(from) if from != "" else L.t("orders.order")), 15)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.clip_text = true
	head.add_child(title)
	# Награда
	head.add_child(_reward("coin", Fmt.n(int(o["coins"]))))
	head.add_child(_reward("star", Fmt.n(int(o["xp"]))))
	if int(o["crystals"]) > 0:
		head.add_child(_reward("gem", str(o["crystals"])))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	v.add_child(flow)
	for it in o["items"]:
		var have := Game.storage_of(it[0])
		var chip := _need_chip(it[0], have, int(it[1]))
		WherePopup.tap_to_open(chip, str(it[0]))
		flow.add_child(chip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var skip := UiKit.button(L.t("orders.skip"), "wood", 13, true)
	var oid: String = o["id"]
	skip.pressed.connect(func() -> void: Game.estate.skip_order(oid))
	row.add_child(skip)
	var done := UiKit.button(L.t("orders.complete"), "green", 14, true)
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	done.disabled = not ok
	done.pressed.connect(func() -> void: Game.estate.complete_order(oid))
	row.add_child(done)
	return p


static func _reward(icon_name: String, text: String) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 2)
	r.add_child(UiKit.icon(icon_name, 16))
	r.add_child(UiKit.label(text, 13))
	return r


static func _need_chip(kind: String, have: int, need: int) -> PanelContainer:
	var ok := have >= need
	var p := PanelContainer.new()
	var s := UiKit.box(Color(1, 1, 1, 0.55) if ok else Color(UiKit.BAD, 0.12), Color(UiKit.OUTLINE, 0.3), 10, 1, false)
	s.content_margin_left = 5
	s.content_margin_right = 7
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", s)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	p.add_child(row)
	row.add_child(UiKit.icon(kind, 22))
	row.add_child(UiKit.label("%s/%s" % [Fmt.n(mini(have, need)), Fmt.n(need)], 13, UiKit.INK if ok else UiKit.BAD))
	return p


static func _wrap(text: String, font_size: int, color := UiKit.INK) -> Label:
	var l := UiKit.label(text, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(80, 0)
	return l
