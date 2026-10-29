class_name AnimalsPanel
extends Sheet
## Звери (порт AnimalsView): места с собой, вкладки "Мои", "Лавка", "Дикие".

const TABS := ["mine", "shop", "wild"]
const ACTIVE_FILL := Color("ddefc8")

var tab := "mine"


func _init() -> void:
	title_key = "hud.animals"


func build() -> void:
	_slots()
	_tabs()
	match tab:
		"mine":
			var mine := Game.animals.owned()
			if mine.is_empty():
				var c := _card()
				c.add_child(UiKit.label(L.t("animals.empty"), 16))
				c.add_child(_wrap(UiKit.label(L.t("animals.empty.hint"), 14, UiKit.INK_SOFT)))
			for id in mine:
				_row(id, "mine")
		"shop":
			for id in Animals.IDS:
				if Animals.shop_level(id) >= 0:
					_row(id, "shop")
		"wild":
			content.add_child(_wrap(UiKit.label(L.t("animals.wild.hint"), 14, UiKit.INK_SOFT)))
			for id in Animals.IDS:
				if Animals.wild_location(id) != "":
					_row(id, "wild")


# MARK: Общие элементы (карточка приручения тоже ими пользуется)

## Иконка зверя: первый кадр листа (или лапка, если спрайта нет).
static func animal_icon(id: String, size := 32.0) -> TextureRect:
	var t := UiKit.icon("paw", size)
	var tex := AnimalSheet.icon(id)
	if tex != null:
		t.texture = tex
	return t


## Подпись в "таблетке" (роль зверя, ступень пробуждения, редкий).
static func pill(text: String, fill: Color, color := UiKit.INK, size := 10,
		border := Color(UiKit.WOOD_DARK, 0.35)) -> PanelContainer:
	var p := PanelContainer.new()
	var s := UiKit.box(fill, border, 9, 1, false)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", s)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(UiKit.label(text, size, color, 3 if color == Color.WHITE else 0))
	return p


## Строка эффекта: пиксельные иконки продукта или инструментов и текст.
static func effect_line(e: Dictionary, m: float, size := 12) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ic in Animals.effect_icons(e):
		if Sprites.icon(ic) != null:
			var t := UiKit.icon(ic, size + 4)
			t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(t)
	var l := UiKit.label(Animals.effect_text(e, m), size, UiKit.INK_SOFT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(l)
	return row


# MARK: Места с собой

func _slots() -> void:
	var a := Game.animals
	var team := a.active()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	content.add_child(box)
	box.add_child(UiKit.label(L.t("animals.withYou", [team.size(), a.max_active()]), 14))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	for i in a.max_active():
		var id: String = team[i] if i < team.size() else ""
		row.add_child(_slot(id))
	box.add_child(_wrap(UiKit.label(L.t("animals.slots.hint"), 12, UiKit.INK_SOFT)))


func _slot(id: String) -> Button:
	var b := Button.new()
	var filled := id != ""
	var style := UiKit.box(ACTIVE_FILL if filled else Color(UiKit.PARCHMENT_DEEP, 0.6),
		UiKit.OUTLINE if filled else Color(UiKit.WOOD_DARK, 0.4), 16, 2 if filled else 1, false)
	style.set_content_margin_all(2)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var s := style.duplicate() as StyleBoxFlat
		if state == "pressed":
			s.bg_color = s.bg_color.darkened(0.12)
		b.add_theme_stylebox_override(state, s)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 58)
	b.disabled = not filled
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(center)
	if filled:
		center.add_child(animal_icon(id, 40))
		# Красный крестик в углу
		var x := PanelContainer.new()
		var xs := UiKit.box(UiKit.TONES["red"][1], UiKit.OUTLINE, 8, 1, false)
		xs.set_content_margin_all(0)
		x.add_theme_stylebox_override("panel", xs)
		x.custom_minimum_size = Vector2(16, 16)
		x.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var xl := UiKit.label("×", 12, Color.WHITE, 2)
		xl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		xl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		x.add_child(xl)
		x.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		x.offset_left = -20
		x.offset_right = -4
		x.offset_top = 4
		x.offset_bottom = 20
		b.add_child(x)
		b.pressed.connect(func() -> void: Game.animals.toggle_active(id))
	else:
		center.add_child(UiKit.label("+", 16, Color(UiKit.WOOD_DARK, 0.5)))
	return b


func _tabs() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	content.add_child(row)
	for t in TABS:
		var b := UiKit.button(L.t("animals.tab." + t), "orange" if t == tab else "wood", 13, true)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.pressed.connect(func() -> void:
			tab = t
			_dirty = true)
		row.add_child(b)


# MARK: Строка зверя (AnimalRow)

func _card(border := Color(UiKit.WOOD_DARK, 0.45), width := 2) -> VBoxContainer:
	var p := PanelContainer.new()
	var s := UiKit.box(UiKit.PARCHMENT_LIGHT, border, 16, width, false)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	s.shadow_color = Color(UiKit.WOOD_DARK, 0.25)
	s.shadow_offset = Vector2(0, 3)
	s.shadow_size = 1
	p.add_theme_stylebox_override("panel", s)
	content.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	return v


func _row(id: String, mode: String) -> void:
	var a := Game.animals
	var stars := a.stars(id)
	var m := a.multiplier(id)
	var c := _card(UiKit.TONES["green"][1], 3) if a.is_active(id) else _card()

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	c.add_child(top)
	var frame := PanelContainer.new()
	var fs := UiKit.box(Color(UiKit.PARCHMENT_DEEP, 0.7), Color(UiKit.WOOD_DARK, 0.4), 14, 2, false)
	fs.set_content_margin_all(6)
	frame.add_theme_stylebox_override("panel", fs)
	frame.custom_minimum_size = Vector2(58, 58)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := animal_icon(id, 46)
	frame.add_child(ic)
	if stars == 0 and mode == "wild":
		frame.modulate.a = 0.6
	top.add_child(frame)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	top.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	col.add_child(head)
	head.add_child(UiKit.label(Animals.name_of(id), 16))
	if a.is_shiny(id):
		var rb := UiKit.icon("rainbow", 16)
		rb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(rb)
	head.add_child(pill(Animals.role(id), UiKit.PARCHMENT_DEEP))
	if stars > 0:
		var srow := HBoxContainer.new()
		srow.add_theme_constant_override("separation", 6)
		col.add_child(srow)
		srow.add_child(UiKit.stars(stars, Animals.MAX_STARS, 12))
		var lvl := a.awaken_level(id)
		if lvl > 0:
			srow.add_child(pill(Animals.awaken_title(lvl), Animals.awaken_color(lvl), UiKit.INK, 10, UiKit.OUTLINE))
	for e in Animals.effects(id):
		col.add_child(effect_line(e, m))
	var where := Animals.wild_location(id)
	if where != "":
		var unlocked: bool = where in Game.save.get("unlocked", [])
		var wl := UiKit.label(L.t("animals.where", ["", Locations.name_of(where)]).replace("  ", " "), 12,
			UiKit.INK if unlocked else UiKit.TONES["orange"][2])
		col.add_child(_wrap(wl))

	match mode:
		"mine": _mine_actions(c, id)
		"shop": _shop_actions(c, id, stars)
		"wild": _wild_actions(c, id, stars)


func _mine_actions(c: VBoxContainer, id: String) -> void:
	var a := Game.animals
	var cost := a.awaken_cost(id)
	if not cost.is_empty():
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		c.add_child(box)
		box.add_child(UiKit.label(L.t("awaken.next", [Animals.awaken_title(a.awaken_level(id) + 1)]), 12,
			UiKit.TONES["purple"][2]))
		box.add_child(UiKit.cost_view(cost))
		var ab := UiKit.button(L.t("awaken.action"), "purple", 15, true)
		ab.disabled = not a.can_awaken(id)
		ab.pressed.connect(func() -> void: Game.animals.awaken(id))
		box.add_child(ab)
	var active := a.is_active(id)
	var full := a.active().size() >= a.max_active()
	var text := L.t("animals.remove") if active else (L.t("animals.full") if full else L.t("animals.take"))
	var b := UiKit.button(text, "red" if active else "green", 15, true)
	b.disabled = not active and full
	b.pressed.connect(func() -> void: Game.animals.toggle_active(id))
	c.add_child(b)


func _shop_actions(c: VBoxContainer, id: String, stars: int) -> void:
	var level := Animals.shop_level(id)
	if level < 0:
		return
	if stars >= Animals.MAX_STARS:
		c.add_child(UiKit.label(L.t("animals.maxStars"), 14, UiKit.GOOD))
		return
	var price := Game.animals.shop_price(id)
	if price < 0:
		return
	var level_ok := Game.level >= level
	var text := L.t("common.needLevel", [level]) if not level_ok \
		else (L.t("animals.moreStar") if stars > 0 else L.t("common.buy"))
	var b := UiKit.button("", "green")
	b.custom_minimum_size = Vector2(0, 46)
	b.disabled = not level_ok or int(Game.save["coins"]) < price
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14
	row.offset_right = -14
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var t := UiKit.title(text, 15)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.size_flags_vertical = Control.SIZE_FILL
	row.add_child(t)
	var coin := UiKit.icon("coins", 18)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(coin)
	var p := UiKit.title(Fmt.n(price), 15)
	p.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.size_flags_vertical = Control.SIZE_FILL
	row.add_child(p)
	b.pressed.connect(func() -> void:
		if Game.animals.buy(id):
			Input.vibrate_handheld(20))
	c.add_child(b)


func _wild_actions(c: VBoxContainer, id: String, stars: int) -> void:
	if stars >= Animals.MAX_STARS:
		c.add_child(UiKit.label(L.t("animals.maxStars"), 14, UiKit.GOOD))
		return
	var cost := Game.animals.tame_cost(id)
	if cost.is_empty():
		return
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	c.add_child(box)
	box.add_child(UiKit.label(L.t("animals.nextStarCost") if stars > 0 else L.t("animals.tameCost"), 12, UiKit.INK_SOFT))
	box.add_child(UiKit.cost_view(cost))


func _wrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l
