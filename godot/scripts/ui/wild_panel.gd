class_name WildPanel
extends Sheet
## Дикие земли: вкладки колец, сверху отряды лагеря. В секторе - что там и что можно сделать:
## отправить отряд зверей, пойти в логово, в руины за билеты или разведать тайник.

var ring := 0
## Выбранные звери для отряда по секторам.
var _pick: Dictionary = {}


func _init(start_ring := "0") -> void:
	title_key = "wild.title"
	ring = clampi(int(start_ring), 0, Wild.RINGS.size() - 1)


static func open() -> void:
	if Hud.current != null:
		Hud.current.open_window(WildPanel.new())


func build_top() -> void:
	var items: Array = []
	for i in Wild.RINGS.size():
		var spec: Dictionary = Wild.RINGS[i]
		items.append([str(i), L.t("wild.ring", [i + 1]), 0, str(spec["rare"])])
	top_bar.add_child(UiKit.tabs(items, str(ring), func(id: String) -> void:
		ring = int(id)
		scroll_to_top()))


func build() -> void:
	var w := Game.wild
	_squads_card()
	var spec: Dictionary = Wild.RINGS[ring]
	if not w.ring_open(ring):
		var c := card()
		var t := UiKit.label(L.t("wild.locked", [int(spec["level"])]), 14, UiKit.INK_SOFT)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c.add_child(t)
		return
	var head := UiKit.label(L.t("wild.ringInfo", [Res.name_of(spec["rare"])]), 13, UiKit.INK_SOFT)
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(head)
	for sec in Wild.sectors(ring):
		_sector_card(sec)
	var hint := UiKit.label(L.t("wild.hint"), 12, UiKit.INK_SOFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(hint)


## Отряды лагеря: сколько в пути, кто вернулся, кнопка "Забрать". Карточка сама встаёт в content.
func _squads_card() -> Control:
	var w := Game.wild
	var c := card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	c.add_child(row)
	row.add_child(HousePanel.sprite_rect("tent", 2.0, Vector2(48, 48)))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	var total := w.squads_total()
	col.add_child(UiKit.label(L.t("wild.squads", [w.squads().size(), total]), 15))
	var sub := UiKit.label(L.t("wild.noCamp") if total == 0 else L.t("wild.squadsHint"), 12, UiKit.INK_SOFT)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(sub)
	if total == 0:
		var b := UiKit.button(L.t("where.open"), "wood", 13, true)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func() -> void: EstatePanel.open())
		row.add_child(b)
	elif w.ready_count() > 0:
		var b := UiKit.button(L.t("wild.collect"), "green", 14, true)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func() -> void:
			var got := w.collect()
			for k in got:
				Game.show_toast("px:" + str(k), "+%s %s" % [Fmt.n(int(got[k])), Res.name_of(k)]))
		row.add_child(b)
	return c


func _sector_card(sec: Dictionary) -> Control:
	var w := Game.wild
	var id: String = sec["id"]
	var kind: String = sec["kind"]
	var done := w.done(id)
	var squad := w.squad_at(id)
	var c := card(UiKit.PARCHMENT_LIGHT if not (done and squad.is_empty()) else Color(UiKit.PARCHMENT_DEEP, 0.6))
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	c.add_child(top)
	var ic := UiKit.icon_any(Wild.kind_icon(kind), 32)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(ic)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	top.add_child(col)
	col.add_child(UiKit.label(L.t("wild.kind." + kind), 15))
	var spec: Dictionary = Wild.RINGS[int(sec["ring"])]
	var info := ""
	match kind:
		"deposit":
			info = L.t("wild.deposit.info", [_hours(float(sec["hours"])), Res.name_of(spec["rare"])])
		"lair":
			info = L.t("wild.lair.info", [L.t("dungeon." + str(spec["dungeon"])), int(spec["floor"])])
		"ruins":
			info = L.t("wild.ruins.info", [Locations.name_of(sec["expedition"]), Expeditions.cost(sec["expedition"])])
		"cache":
			info = L.t("wild.cache.info")
	var t := UiKit.label(info, 12, UiKit.INK_SOFT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(t)
	# Что можно сделать
	match kind:
		"deposit":
			_deposit_body(c, sec, squad, done)
		"lair":
			if done:
				c.add_child(UiKit.label(L.t("wild.empty"), 12, UiKit.INK_SOFT))
			else:
				var r := Wild.lair_reward(int(sec["ring"]))
				c.add_child(_reward_row([["essence", r["essence"]], ["gem", r["crystals"]]]))
				var b := UiKit.button(L.t("wild.fight"), "orange", 14)
				var dungeon: String = spec["dungeon"]
				b.disabled = not Game.dungeons.can_enter(dungeon, clampi(int(spec["floor"]), 1, Game.dungeons.dungeon_best(dungeon) + 1), true)
				b.pressed.connect(func() -> void:
					if w.start_lair(id):
						close())
				c.add_child(b)
		"ruins":
			var exp_id: String = sec["expedition"]
			var b := UiKit.button(L.t("wild.go"), "blue", 14)
			b.disabled = not Game.premium.can_start_expedition(exp_id)
			b.pressed.connect(func() -> void:
				if w.start_ruins(id):
					close())
			c.add_child(b)
		"cache":
			if done:
				c.add_child(UiKit.label(L.t("wild.empty"), 12, UiKit.INK_SOFT))
			else:
				var r := Wild.cache_reward(int(sec["ring"]))
				c.add_child(_reward_row([["coins", r["coins"]], [r["rare"], r["n"]]]))
				var b := UiKit.button(L.t("wild.scout"), "green", 14)
				b.pressed.connect(func() -> void:
					var got := w.open_cache(id)
					if not got.is_empty():
						Game.show_toast("px:chest_gold", L.t("wild.cacheDone", [Fmt.n(int(got["coins"])), int(got["n"]),
							Res.name_of(got["rare"])])))
				c.add_child(b)
	return c


## Месторождение: отряд в пути, вернулся или выбор зверей и "Отправить".
func _deposit_body(c: VBoxContainer, sec: Dictionary, squad: Dictionary, done: bool) -> void:
	var w := Game.wild
	var id: String = sec["id"]
	if not squad.is_empty():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		c.add_child(row)
		for a in squad["animals"]:
			row.add_child(UiKit.icon_any("an:" + str(a), 26))
		var s := squad
		var left := func() -> String:
			var l := w.squad_left(s)
			return L.t("wild.back") if l <= 0.0 else L.t("wild.away", [House.countdown(l)])
		var live := CombatCards.LiveLabel.new(left, 13, UiKit.INK)
		live.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(live)
		var loot: Array = []
		for k in squad["loot"]:
			loot.append([k, squad["loot"][k]])
		c.add_child(_reward_row(loot))
		return
	if done:
		c.add_child(UiKit.label(L.t("wild.empty"), 12, UiKit.INK_SOFT))
		return
	var picked: Array = _pick.get(id, [])
	var stars := 0
	for a in picked:
		stars += Game.animals.stars(a)
	var preview := Wild.deposit_loot(int(sec["ring"]), float(sec["hours"]), stars)
	var loot: Array = []
	for k in preview:
		loot.append([k, preview[k]])
	c.add_child(_reward_row(loot))
	var pool := w.free_animals()
	if pool.is_empty():
		c.add_child(UiKit.label(L.t("wild.noAnimals"), 12, UiKit.INK_SOFT))
		return
	c.add_child(UiKit.label(L.t("wild.pick", [Wild.SQUAD_SIZE]), 12, UiKit.INK_SOFT))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	c.add_child(flow)
	for a in pool:
		flow.add_child(_animal_chip(id, a, a in picked))
	var send := UiKit.button(L.t("wild.send"), "green", 14)
	send.disabled = picked.is_empty() or w.squads_free() <= 0
	send.pressed.connect(func() -> void:
		if w.send(id, picked):
			_pick.erase(id)
			Sound.play("tap"))
	c.add_child(send)


func _animal_chip(sector_id: String, animal: String, on: bool) -> Control:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.toggle_mode = true
	b.button_pressed = on
	var st := UiKit.box(Color("ddefc8") if on else UiKit.PARCHMENT_LIGHT,
		UiKit.TONES["green"][1] if on else Color(UiKit.WOOD_DARK, 0.4), 12, 2, false)
	st.set_content_margin_all(4)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		b.add_theme_stylebox_override(state, st)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(UiKit.icon_any("an:" + animal, 26))
	row.add_child(UiKit.label("%d★" % Game.animals.stars(animal), 12))
	b.add_child(row)
	b.custom_minimum_size = Vector2(62, 36)
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	b.pressed.connect(func() -> void:
		var list: Array = _pick.get(sector_id, []).duplicate()
		if animal in list:
			list.erase(animal)
		elif list.size() < Wild.SQUAD_SIZE:
			list.append(animal)
		_pick[sector_id] = list
		_dirty = true)
	return b


func _reward_row(parts: Array) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 4)
	for p in parts:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 3)
		h.add_child(UiKit.icon(str(p[0]), 16))
		h.add_child(UiKit.label(Fmt.n(int(p[1])), 13))
		flow.add_child(h)
	return flow


static func _hours(h: float) -> String:
	var m := int(round(h * 60.0))
	if m < 60:
		return L.t("time.min", [m])
	if m % 60 == 0:
		return L.t("time.hour", [m / 60])
	return L.t("time.hourMin", [m / 60, m % 60])
