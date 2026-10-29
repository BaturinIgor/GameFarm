class_name GardenPanel
extends Sheet
## Огородная мастерская (порт GardenShedView): лейка и удобрения.


func _init() -> void:
	title_key = "garden.title"


func build() -> void:
	_can_card()
	_section(L.t("fert.title"))
	for id in Farming.FERTILIZER_IDS:
		_fertilizer_row(id)
	if Game.house.is_built("greenhouse"):
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 4)
		content.add_child(row)
		row.add_child(UiKit.icon("sprout", 16))
		row.add_child(UiKit.label(L.t("garden.greenhouse"), 12, UiKit.GOOD))
	else:
		var l := UiKit.label(L.t("garden.greenhouse.locked", [Farming.GREENHOUSE_LEVEL]), 11, UiKit.INK_SOFT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(l)


## Лейка: уровень, сила полива и улучшение.
func _can_card() -> void:
	var g := Game.garden
	var level := g.can_level()
	var c := TraderPanel.card_box(content, Color(UiKit.TONES["blue"][1], 0.7), 3)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	c.add_child(head)
	var ic := UiKit.icon("watering_can", 44)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(ic)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 3)
	head.add_child(col)
	col.add_child(UiKit.label(L.t("can.title", [level, Farming.CAN_MAX_LEVEL]), 15))
	col.add_child(_wrap(L.t("can.effect", [Fmt.pct(Farming.can_boost(level))]), 12, UiKit.INK_SOFT))
	if Farming.can_waters_all(level):
		col.add_child(_wrap(L.t("can.all"), 11, UiKit.GOOD))
	var cost := g.next_can_cost()
	if cost.is_empty():
		return
	var next := level + 1
	var need := Farming.can_required_level(next)
	var text := L.t("can.next", [Fmt.pct(Farming.can_boost(next))])
	if Farming.can_waters_all(next) and not Farming.can_waters_all(level):
		text += " " + L.t("can.next.all")
	c.add_child(_wrap(text, 11, UiKit.INK_SOFT))
	c.add_child(UiKit.cost_view(cost))
	var b := UiKit.button(L.t("common.upgrade") if Game.level >= need else L.t("common.needLevel", [need]), "blue", 13, true)
	b.disabled = not g.can_upgrade_can()
	b.pressed.connect(func() -> void: Game.garden.upgrade_can())
	c.add_child(b)


## Удобрение (FertilizerRow): сколько есть, что делает, рецепт и кнопки "сделать".
func _fertilizer_row(id: String) -> void:
	var g := Game.garden
	var f: Dictionary = Farming.FERTILIZERS[id]
	var open := Game.level >= int(f["level"])
	var c := TraderPanel.card_box(content)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	c.add_child(head)
	var ic := UiKit.icon(Farming.fert_icon(id), 40)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not open:
		ic.modulate.a = 0.4
	head.add_child(ic)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 3)
	head.add_child(col)
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", 6)
	col.add_child(title)
	title.add_child(UiKit.label(Farming.fert_name(id), 15))
	var count := UiKit.label("x%d" % g.fertilizers(id), 13, UiKit.INK_SOFT)
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.add_child(count)
	col.add_child(_wrap(Farming.fert_effect_text(id), 11, UiKit.GOOD))
	if not open:
		c.add_child(UiKit.label(L.t("common.needLevel", [int(f["level"])]), 12, UiKit.INK_SOFT))
		return
	c.add_child(UiKit.cost_view(f["recipe"]))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	c.add_child(row)
	for n in [1, 5]:
		var b := UiKit.button(L.t("fert.make", [n]), "green", 13, true)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = not g.can_craft(id, n)
		b.pressed.connect(func() -> void: Game.garden.craft(id, n))
		row.add_child(b)


## Заголовок раздела с линиями по бокам (SectionTitle).
func _section(text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	content.add_child(row)
	for i in 3:
		if i == 1:
			row.add_child(UiKit.label(text.to_upper(), 14, UiKit.INK_SOFT))
			continue
		var line := ColorRect.new()
		line.color = Color(UiKit.WOOD_DARK, 0.35)
		line.custom_minimum_size = Vector2(0, 2)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(line)


func _wrap(text: String, font_size: int, color: Color) -> Label:
	var l := UiKit.label(text, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
