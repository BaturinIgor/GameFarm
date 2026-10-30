class_name HuntPanel
extends Sheet
## Центр сражений у стражника (порт HuntView и новое): заказы на охоту, подземелья, алхимик (зелья и расходники)
## и бестиарий (победы над каждым видом монстров, ступени с кристаллами и прибавкой к урону).
## Вкладки - в неподвижной полосе сверху, сила героя - карточкой во вкладке охоты.

const TABS := [["hunts", "sword", "hunt.tab"], ["dungeons", "skull", "dungeon.tab"],
	["alchemy", "potion", "alchemy.tab"], ["bestiary", "book", "bestiary.tab"]]

var tab := "hunts"


func _init(start_tab := "") -> void:
	title_key = "hunt.title"
	if start_tab != "":
		tab = start_tab


func build_top() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	top_bar.add_child(row)
	for t in TABS:
		row.add_child(_tab_button(t))


func _tab_button(t: Array) -> Button:
	var id: String = t[0]
	var on := id == tab
	var tone: Array = UiKit.TONES["orange" if on else "wood"]
	var b := Button.new()
	var s := UiKit.box(tone[1], UiKit.OUTLINE, 12, 2, false)
	s.set_content_margin_all(2)
	s.shadow_color = tone[2]
	s.shadow_offset = Vector2(0, 3)
	s.shadow_size = 1
	var down := s.duplicate() as StyleBoxFlat
	down.bg_color = tone[2].lerp(tone[1], 0.5)
	down.shadow_offset = Vector2(0, 1)
	for st in ["normal", "hover", "disabled"]:
		b.add_theme_stylebox_override(st, s)
	b.add_theme_stylebox_override("pressed", down)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 50)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	var ic := UiKit.icon(t[1], 22)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(ic)
	var l := UiKit.title(L.t(t[2]), 11)
	l.label_settings.outline_size = 4
	l.label_settings.outline_color = tone[2] if on else UiKit.OUTLINE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	UiKit.fit_label(l, 80.0, 11)
	col.add_child(l)
	var n := 0
	match id:
		"hunts": n = Game.combat.claimable_hunts()
		"bestiary": n = Game.combat.bestiary_ready_count()
	if n > 0:
		var badge := UiKit.count_badge(mini(n, 99))
		badge.position = Vector2(-4, -6)
		b.add_child(badge)
	b.pressed.connect(func() -> void:
		if tab != id:
			tab = id
			Sound.play("tap")
			scroll_to_top())
	return b


func build() -> void:
	Game.combat.ensure_hunts()
	match tab:
		"hunts":
			var hello := UiKit.label(L.t("hunt.hello"), 13)
			content.add_child(TraderPanel.hello_row("guard", [hello]))
			content.add_child(_hero_card())
			content.add_child(CombatCards.hunts_list())
		"dungeons":
			var hello := UiKit.label(L.t("dungeon.hello"), 13)
			content.add_child(TraderPanel.hello_row("guard", [hello]))
			DungeonPanel.build_list(content, close)
		"alchemy":
			_build_alchemy()
		"bestiary":
			_build_bestiary()


# MARK: Сила героя

## Карточка силы героя: урон, здоровье, защита, победы.
func _hero_card() -> Control:
	var c := Game.combat
	var p := PanelContainer.new()
	var tone: Array = UiKit.TONES["red"]
	var s := UiKit.box(tone[1], UiKit.OUTLINE, 16, 3, false)
	s.set_content_margin_all(10)
	s.shadow_color = tone[2]
	s.shadow_offset = Vector2(0, 4)
	s.shadow_size = 1
	p.add_theme_stylebox_override("panel", s)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	p.add_child(row)
	row.add_child(_power_stat("sword", Fmt.n(int(round(c.weapon_damage()))), L.t("gear.stat.damage")))
	row.add_child(_power_stat("heart", Fmt.n(int(c.max_hp())), L.t("gear.stat.hp")))
	row.add_child(_power_stat("shield", Fmt.pct(c.defense()), L.t("gear.stat.defense")))
	row.add_child(_power_stat("skull", Fmt.n(int(Game.save.get("kills", 0))), L.t("bestiary.kills")))
	return p


func _power_stat(icon_name: String, value: String, label: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := UiKit.icon(icon_name, 24)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(ic)
	var v := UiKit.title(value, 16)
	v.label_settings.outline_color = UiKit.TONES["red"][2]
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(v)
	var l := UiKit.label(label, 10, Color(1, 1, 1, 0.9))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	col.add_child(l)
	return col


# MARK: Алхимик

func _build_alchemy() -> void:
	var hello := UiKit.label(L.t("alchemy.hello"), 13)
	hello.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(TraderPanel.hello_row("guard", [hello]))
	content.add_child(CombatCards.potion_shop_card())
	content.add_child(CombatCards.section_title(L.t("alchemy.section")))
	var shown_locked := false
	for id in Consumables.IDS:
		if Game.combat.consumable_open(id):
			content.add_child(_item_row(id))
		elif not shown_locked:
			# Из закрытых показываем только ближайший: не перегружать
			shown_locked = true
			content.add_child(_locked_row(id))
	var hint := UiKit.label(L.t("alchemy.hint"), 11, UiKit.INK_SOFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(hint)


func _item_row(id: String) -> PanelContainer:
	var c := Game.combat
	var tone: Array = UiKit.TONES[str(Consumables.spec(id).get("tone", "wood"))]
	var p := PanelContainer.new()
	var s := UiKit.box(UiKit.PARCHMENT_LIGHT, Color(tone[1], 0.8), 16, 3, false)
	s.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", s)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	var ic := Consumables.icon(id, 40)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(ic)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(col)
	col.add_child(UiKit.label(L.t("alchemy.have", [Consumables.name_of(id), c.consumable_count(id)]), 14))
	var info := UiKit.label(Consumables.info(id), 11, UiKit.INK_SOFT)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(info)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	for n in [1, 5]:
		var price := c.consumable_price(id, n)
		var b := TraderPanel.coin_button("x%d " % n, price, str(Consumables.spec(id).get("tone", "wood")), 13)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = int(Game.save["coins"]) < price
		b.pressed.connect(func() -> void: Game.combat.buy_consumable(id, n))
		row.add_child(b)
	return p


func _locked_row(id: String) -> PanelContainer:
	var p := PanelContainer.new()
	var s := UiKit.box(Color(UiKit.PARCHMENT_DEEP, 0.6), Color(UiKit.WOOD_DARK, 0.3), 16, 2, false)
	s.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", s)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	p.add_child(row)
	var ic := Consumables.icon(id, 36)
	ic.modulate = Color(0.4, 0.35, 0.3, 0.6)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	col.add_child(UiKit.label(Consumables.name_of(id), 14, UiKit.INK_SOFT))
	col.add_child(UiKit.label(L.t("common.needLevel", [Consumables.level(id)]), 12, UiKit.TONES["orange"][2]))
	return p


# MARK: Бестиарий

func _build_bestiary() -> void:
	var c := Game.combat
	var met: Array = Monsters.KINDS.filter(func(k: String) -> bool: return c.kills_of(k) > 0)
	var head := UiKit.label(L.t("bestiary.hint", [met.size(), Monsters.KINDS.size()]), 12, UiKit.INK_SOFT)
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(head)
	if met.is_empty():
		var empty := UiKit.label(L.t("bestiary.empty"), 13, UiKit.INK_SOFT)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(empty)
		return
	# Готовые к награде - сверху
	met.sort_custom(func(a: String, b: String) -> bool:
		var ra := c.bestiary_ready(a) >= 0
		var rb := c.bestiary_ready(b) >= 0
		if ra != rb:
			return ra
		return c.kills_of(a) > c.kills_of(b))
	for kind in met:
		content.add_child(_beast_row(kind))


func _beast_row(kind: String) -> PanelContainer:
	var c := Game.combat
	var claimed := c.bestiary_claimed(kind)
	var ready := c.bestiary_ready(kind)
	var tiers: Array = Consumables.BESTIARY_TIERS
	var p := PanelContainer.new()
	var border: Color = UiKit.TONES["gold"][1] if ready >= 0 else Color(UiKit.WOOD_DARK, 0.4)
	var s := UiKit.box(UiKit.PARCHMENT_LIGHT, border, 14, 3 if ready >= 0 else 2, false)
	s.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", s)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	p.add_child(row)
	var frame := PanelContainer.new()
	var fs := UiKit.box(Color(UiKit.PARCHMENT_DEEP, 0.7), Color(UiKit.WOOD_DARK, 0.3), 12, 1, false)
	fs.set_content_margin_all(4)
	frame.add_theme_stylebox_override("panel", fs)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.add_child(CombatCards.monster_icon(kind, 40))
	row.add_child(frame)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", 6)
	col.add_child(title)
	var name_l := UiKit.label(Monsters.name_of(kind), 14)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.clip_text = true
	title.add_child(name_l)
	title.add_child(UiKit.stars(claimed, tiers.size(), 13.0))
	var kills := c.kills_of(kind)
	if claimed >= tiers.size():
		col.add_child(UiKit.label(L.t("bestiary.done", [Fmt.n(kills)]), 11, UiKit.GOOD))
	else:
		var goal := int(tiers[claimed])
		col.add_child(UiKit.bar(float(kills) / float(goal), "gold" if ready >= 0 else "orange", 150.0, 12.0,
			"%s / %s" % [Fmt.n(mini(kills, goal)), Fmt.n(goal)]))
	if claimed > 0:
		col.add_child(UiKit.label(L.t("bestiary.bonus", [Fmt.pct(Consumables.BESTIARY_DAMAGE * claimed)]), 10, UiKit.INK_SOFT))
	if ready >= 0:
		var b := MapPanel.icon_button([["t", L.t("bestiary.claim")], ["i", "gem"], ["t", str(Consumables.BESTIARY_CRYSTALS[ready])]],
			"green", 13)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func() -> void: Game.combat.claim_bestiary(kind))
		row.add_child(b)
	return p
