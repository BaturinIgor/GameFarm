class_name WorkshopPanel
extends Sheet
## Мастерская: вкладки добычи, защиты и оружия, карточки инструментов с улучшением (порт WorkshopView).

## Разделы мастерской (GearTab).
const TABS := {
	"gathering": ["axe", "pickaxe", "rod"],
	"defense": ["helmet", "armor", "boots"],
	"weapons": ["sword"],
}

var tab := "gathering"


func _init() -> void:
	title_key = "hud.workshop"


func build() -> void:
	_tabs()
	content.add_child(_wrap(L.t("gear.hint." + tab), 12, UiKit.INK_SOFT))
	for tool in TABS[tab]:
		_tool_card(tool)


func _tabs() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	content.add_child(row)
	for t in TABS:
		var b := UiKit.button(L.t("gear.tab." + t), "orange" if t == tab else "wood", 13, true)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.pressed.connect(func() -> void:
			tab = t
			_dirty = true)
		row.add_child(b)
		var n := Game.workshop.upgradable_among(TABS[t])
		if n > 0:
			var badge := UiKit.count_badge(mini(n, 99))
			badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			badge.offset_left = -16
			badge.offset_right = 4
			badge.offset_top = -6
			badge.offset_bottom = 14
			b.add_child(badge)


func _tool_card(tool: String) -> void:
	var tier := Game.tier(tool)
	var next := tier + 1
	var color := Tools.tier_color(tier)
	var c := _card(color)

	# Иконка в рамке цвета ступени, название, сила и назначение
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	c.add_child(head)
	var frame := PanelContainer.new()
	var fs := UiKit.box(Color(color, 0.25), Color(UiKit.OUTLINE, 0.7), 14, 2, false)
	fs.set_content_margin_all(10)
	frame.add_theme_stylebox_override("panel", fs)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	frame.add_child(UiKit.icon(Tools.icon_name(tool), 36))
	head.add_child(frame)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 3)
	head.add_child(col)
	col.add_child(_wrap(Tools.tier_name(tool, tier), 16))
	col.add_child(_wrap(_power_text(tool, tier), 12, UiKit.INK_SOFT))
	col.add_child(_wrap(L.t("tool." + tool + ".purpose"), 12, UiKit.INK_SOFT))

	var available := _nodes(tool, tier, false)
	if not available.is_empty():
		c.add_child(UiKit.label(L.t("workshop.gathers"), 12, UiKit.INK_SOFT))
		c.add_child(_node_flow(available))

	_perk_list(c, tool, tier)

	c.add_child(_divider())
	var cost := Game.workshop.next_cost(tool)
	if next <= Tools.MAX_TIER and not cost.is_empty():
		var need := Tools.required_level(tool, next)
		var level_ok := Game.level >= need
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		c.add_child(row)
		var nt := _wrap(L.t("talents.next", [Tools.tier_name(tool, next)]), 14)
		nt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nt)
		row.add_child(_level_tag(need, level_ok))
		var opens := _nodes(tool, next, true)
		if not opens.is_empty():
			var orow := HBoxContainer.new()
			orow.add_theme_constant_override("separation", 6)
			c.add_child(orow)
			var ol := UiKit.label(L.t("workshop.opens"), 12, UiKit.INK_SOFT)
			ol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			orow.add_child(ol)
			var flow := _node_flow(opens)
			flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			orow.add_child(flow)
		c.add_child(UiKit.cost_view(cost))
		var b := UiKit.button(L.t("workshop.upgrade") if level_ok else L.t("common.needLevel", [need]), "green")
		b.disabled = not level_ok or not Game.can_afford(cost)
		b.pressed.connect(func() -> void: Game.workshop.upgrade(tool))
		c.add_child(b)
	else:
		c.add_child(UiKit.label(L.t("workshop.maxTier"), 14, UiKit.GOOD))


## Строка силы под названием: у снаряжения своя (здоровье, урон, защита, уворот).
func _power_text(tool: String, tier: int) -> String:
	var s := Game.stats
	match tool:
		"armor":
			return L.t("workshop.armor", [tier, Tools.MAX_TIER, int(Game.workshop.max_hp())])
		"sword":
			var dmg := ToolSystem.sword_damage(Game.level, tier) * s.damage_mult * s.sword_mult
			return L.t("workshop.sword", [tier, Tools.MAX_TIER, int(round(dmg))])
		"helmet":
			return L.t("workshop.helmet", [tier, Tools.MAX_TIER, Fmt.pct(ToolSystem.helmet_defense(tier))])
		"boots":
			return L.t("workshop.boots", [tier, Tools.MAX_TIER, Fmt.pct(ToolSystem.boots_dodge(tier)),
				Fmt.pct(ToolSystem.boots_speed(tier))])
	return L.t("workshop.tier", [tier, Tools.MAX_TIER, "%.1f" % Tools.power(tier)])


## Точки добычи этим инструментом: доступные на ступени (exact = false) или открываемые ровно на ней.
func _nodes(tool: String, tier: int, exact: bool) -> Array:
	var out: Array = []
	for type in Nodes.SPECS:
		var spec: Dictionary = Nodes.SPECS[type]
		if spec["tool"] != tool:
			continue
		var t := int(spec["tier"])
		if (exact and t == tier) or (not exact and t <= tier):
			out.append(type)
	return out


func _node_flow(types: Array) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for type in types:
		flow.add_child(_node_chip(type))
	return flow


## Плашка точки добычи (NodeChip): иконка ресурса и название.
func _node_chip(type: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _pill(UiKit.PARCHMENT_DEEP, Color(UiKit.WOOD_DARK, 0.35)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	p.add_child(row)
	row.add_child(UiKit.icon(Nodes.main_resource(type), 16))
	row.add_child(UiKit.label(Nodes.name_of(type), 12))
	return p


## Бонусы ступеней (PerkList): открытые подсвечены, следующие - серые.
func _perk_list(parent: Control, tool: String, tier: int) -> void:
	var perks := Tools.perks(tool)
	if perks.is_empty():
		return
	var box := PanelContainer.new()
	var bs := UiKit.box(UiKit.PARCHMENT_LIGHT, Color(UiKit.WOOD_DARK, 0.45), 10, 2, false)
	bs.set_content_margin_all(8)
	box.add_theme_stylebox_override("panel", bs)
	parent.add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	box.add_child(col)
	var on: Color = UiKit.TONES["green"][1]
	for perk in perks:
		var open := tier >= int(perk["tier"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		col.add_child(row)
		var tag := PanelContainer.new()
		var ts := _pill(on if open else UiKit.PARCHMENT_DEEP, Color(0, 0, 0, 0))
		ts.content_margin_left = 5
		ts.content_margin_right = 5
		tag.add_theme_stylebox_override("panel", ts)
		tag.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		tag.add_child(UiKit.label(L.t("common.lvl", [perk["tier"]]), 10, Color.WHITE if open else UiKit.INK_SOFT))
		row.add_child(tag)
		var text := _wrap(Tools.perk_text(perk), 11, UiKit.INK if open else Color(UiKit.INK_SOFT, 0.7))
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)


# MARK: Элементы

## Карточка с рамкой цвета (Card(tint:)).
func _card(border: Color) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.box(UiKit.PARCHMENT_LIGHT, border, 14, 3, false))
	content.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	return v


## Плашка "Ур. N": зелёная, если уровень достигнут (LevelTag).
func _level_tag(level: int, ok: bool) -> PanelContainer:
	var tone: Array = UiKit.TONES["green" if ok else "red"]
	var p := PanelContainer.new()
	var s := _pill(tone[1], UiKit.OUTLINE)
	s.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", s)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := UiKit.label(L.t("common.lvl", [level]), 12, Color.WHITE, 3)
	l.label_settings.outline_color = tone[2]
	p.add_child(l)
	return p


func _pill(fill: Color, border: Color) -> StyleBoxFlat:
	var s := UiKit.box(fill, border, 10, 1, false)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	return s


func _divider() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(UiKit.WOOD_DARK, 0.18)
	r.custom_minimum_size = Vector2(0, 2)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _wrap(text: String, size: int, color := UiKit.INK) -> Label:
	var l := UiKit.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
