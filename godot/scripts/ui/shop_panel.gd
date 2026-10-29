class_name ShopPanel
extends Sheet
## Магазин (порт ShopView): одно главное предложение крупно, остальные наборы плитками, билеты и бесплатная удача.
## Подробности о наборе открываются по нажатию на плитку поверх магазина, чтобы экран не был перегружен текстом.
## Здесь же общие части магазина: картинка набора (OfferArt), преимущества (Offers), кнопка покупки (BuyButton),
## карточка с лентой (ShopCard).

## Открытые подробности набора ("" - закрыты).
var detail := ""
var _detail_node: Control
var _detail_fresh := false


func _init() -> void:
	title_key = "shop.title"


## Что показать крупно: стартовый набор, пока действует, потом пропуск ивента, Pro и сад.
static func featured() -> String:
	var p := Game.premium
	if p.starter_available() and not p.owns("starter"):
		return "starter"
	if Game.events.events_open() and not Game.events.has_vip():
		return "eventPass"
	if not p.owns("pro"):
		return "pro"
	if not p.owns("garden"):
		return "garden"
	return ""


static func bundles() -> Array:
	var p := Game.premium
	var list: Array = ["pro", "garden", "skins"]
	if p.starter_available() or p.owns("starter"):
		list.insert(0, "starter")
	if Game.events.events_open():
		list.append("eventPass")
	var top := featured()
	var rest := list.filter(func(x: String) -> bool: return x != top)
	# купленное уходит в конец
	return rest.filter(func(x: String) -> bool: return not owned(x)) + rest.filter(func(x: String) -> bool: return owned(x))


static func owned(product: String) -> bool:
	return Game.events.has_vip() if product == "eventPass" else Game.premium.owns(product)


func build() -> void:
	var top := featured()
	if top != "":
		content.add_child(_featured(top))
	content.add_child(EventsPanel.section(L.t("shop.section.bundles")))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	content.add_child(grid)
	for product in bundles():
		grid.add_child(_tile(product))
	content.add_child(EventsPanel.section(L.t("shop.section.tickets")))
	content.add_child(_tickets_row())
	content.add_child(EventsPanel.section(L.t("free.title")))
	content.add_child(_wrap(L.t("free.subtitle.pro") if Game.premium.has_pro() else L.t("free.subtitle"), 12,
		UiKit.INK_SOFT))
	content.add_child(LuckButton.new("wide"))
	var restore := UiKit.button(L.t("shop.restore"), "wood", 14, true)
	restore.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restore.pressed.connect(func() -> void: Store.restore())
	content.add_child(restore)
	var footer := _wrap(L.t("shop.footer"), 11, UiKit.INK_SOFT)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(footer)
	_build_detail()


func _open_detail(product: String) -> void:
	detail = product
	_detail_fresh = true
	_dirty = true


func _close_detail() -> void:
	detail = ""
	_dirty = true


# MARK: Описание наборов (Offers)

static func tagline(product: String) -> String:
	match product:
		"skins": return L.t("offer.tag.skins", [Skins.collection().size()])
		"tickets": return L.t("offer.tag.tickets", [Expeditions.TICKET_PACK])
	return L.t("offer.tag." + product)


## Преимущества набора: [[иконка, текст], ...] (иконки как IconView: px:, an:, skin:).
static func perks(product: String) -> Array:
	match product:
		"starter":
			return [["an:duckHat", L.t("starter.duck")],
				["px:coins", L.t("starter.coins", [Fmt.n(PremiumSystem.STARTER_COINS)])],
				["px:bag", L.t("starter.backpack", [PremiumSystem.STARTER_BACKPACK])],
				["skin:robot", L.t("starter.skin")]]
		"pro":
			return [["px:no_ads", L.t("pro.noAds")],
				["px:moon", L.t("pro.offline", [int(PremiumSystem.PRO_OFFLINE_HOURS)])],
				["px:portal", L.t("pro.autoDeposit")],
				["px:quest", L.t("pro.quest")],
				["px:chest", L.t("pro.treasure")],
				["px:ticket", L.t("pro.tickets")],
				["skin:genie", L.t("pro.skin")]]
		"garden":
			return [["px:apples", L.t("garden.trees")],
				["px:honey", L.t("garden.bees")],
				["px:chest_gold", L.t("garden.chest")],
				["px:basket", L.t("garden.capybara", [Fmt.pct(PremiumSystem.CAPYBARA_YIELD)])],
				["skin:knight", L.t("garden.skin")]]
		"skins":
			return [["px:wardrobe", L.t("skins.subtitle", [Skins.collection().size()])]]
		"tickets":
			return [["px:ticket", L.t("tickets.subtitle", [Expeditions.TICKET_PACK])]]
		"eventPass":
			var skin := Events.skin_of(Events.current()["event"])
			return [["skin:" + skin, L.t("event.vip.desc", [Skins.name_of(skin)])]]
	return []


## Крупная картинка набора (OfferArt): основная картинка и значок в правом нижнем углу.
static func art(product: String, side: float) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(side, side)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var main := ""
	var main_k := 1.0
	var badge := ""
	var badge_k := 0.42
	var shift := Vector2(0.08, 0.04)
	match product:
		"starter":
			main = "px:chest_gold"
			main_k = 0.9
			badge = "an:duckHat"
			badge_k = 0.5
			shift = Vector2(0.1, 0.05)
		"pro":
			main = "skin:genie"
			badge = "px:crown"
		"garden":
			main = "skin:knight"
			badge = "px:goldenApple"
		"skins":
			main = "skin:wizard"
			badge = "px:wardrobe"
		"tickets":
			main = "px:ticket"
			main_k = 0.85
		"eventPass":
			main = "skin:" + Events.skin_of(Events.current()["event"])
			badge = "px:star"
	var m := UiKit.icon_any(main, side * main_k)
	m.position = Vector2.ONE * side * (1.0 - main_k)
	holder.add_child(m)
	if badge != "":
		var b := UiKit.icon_any(badge, side * badge_k)
		b.position = Vector2.ONE * side * (1.0 - badge_k) + shift * side
		holder.add_child(b)
	return holder


## Лента с названием (RibbonTitle).
static func ribbon(text: String, tone: String, font_size: int) -> Control:
	var r := LevelUpOverlay.Ribbon.new()
	r.tone = UiKit.TONES[tone]
	r.label.label_settings.font_size = font_size
	r.label.label_settings.outline_color = r.tone[2]
	r.set_text(text)
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return r


## Карточка товара (ShopCard): цветная рамка и лента с названием. [вся карточка, столбец для содержимого].
static func shop_card(title: String, tone: String) -> Array:
	return MapPanel._ribbon_card(title, tone)


## Кнопка покупки с ценой и часами, пока идёт покупка (BuyButton).
static func buy_button(product: String, tone := "orange") -> Button:
	return BuyButton.new(product, "orange" if tone == "gold" else tone)


class BuyButton extends Button:
	var product := ""
	var tone := "orange"
	var _state := ""

	func _init(p: String, t: String) -> void:
		product = p
		tone = t
		focus_mode = Control.FOCUS_NONE
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_theme_constant_override("icon_max_width", 22)
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pressed.connect(func() -> void: Store.buy(product))
		refresh()

	func _ready() -> void:
		Game.changed.connect(refresh)

	func refresh() -> void:
		var own := Game.premium.owns(product)
		var busy := Store.busy == product
		var state := "busy" if busy else ("own" if own else "buy")
		if state + Store.busy == _state:
			return
		_state = state + Store.busy
		var proto := UiKit.button("", "green" if own else tone, 15)
		for s in ["normal", "hover", "pressed", "disabled", "focus"]:
			add_theme_stylebox_override(s, proto.get_theme_stylebox(s))
		if own:
			add_theme_stylebox_override("disabled", proto.get_theme_stylebox("normal"))
		add_theme_font_override("font", UiKit.font())
		add_theme_font_size_override("font_size", 15)
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_outline_color"]:
			add_theme_color_override(c, proto.get_theme_color(c))
		add_theme_color_override("font_disabled_color", Color.WHITE if own else Color(1, 1, 1, 0.7))
		add_theme_constant_override("outline_size", 5)
		proto.free()
		if busy:
			text = ""
			icon = Sprites.icon("hourglass")
		elif own:
			text = L.t("shop.owned")
			icon = null
		else:
			text = L.t("shop.buyFor", [Store.price(product)])
			icon = null
		disabled = own or Store.busy != ""


# MARK: Главное предложение

func _featured(product: String) -> Control:
	var tone: Array = UiKit.TONES[Products.tone(product)]
	var p := PanelContainer.new()
	var s := UiKit.box(tone[1], UiKit.OUTLINE, 20, 3, false)
	s.set_content_margin_all(16)
	s.shadow_color = tone[2]
	s.shadow_offset = Vector2(0, 5)
	s.shadow_size = 1
	p.add_theme_stylebox_override("panel", s)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	v.add_child(head)
	var circle := PanelContainer.new()
	var cs := UiKit.box(Color(1, 1, 1, 0.85), UiKit.OUTLINE, 46, 3, false)
	cs.set_content_margin_all(8)
	circle.add_theme_stylebox_override("panel", cs)
	circle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	circle.add_child(art(product, 76.0))
	head.add_child(circle)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(col)
	col.add_child(_badge(product))
	var title := UiKit.title(Products.title(product), 21)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 2
	col.add_child(title)
	var tag := UiKit.label(tagline(product), 12, Color.WHITE, 3)
	tag.label_settings.outline_color = tone[2]
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag.max_lines_visible = 2
	col.add_child(tag)

	var all := perks(product)
	var box := PanelContainer.new()
	var bs := UiKit.box(UiKit.PARCHMENT_LIGHT, Color(UiKit.OUTLINE, 0.6), 14, 2, false)
	bs.set_content_margin_all(12)
	box.add_theme_stylebox_override("panel", bs)
	v.add_child(box)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 7)
	box.add_child(list)
	for i in mini(4, all.size()):
		list.add_child(_perk_row(all[i]))
	if all.size() > 4:
		var more := Button.new()
		more.text = L.t("shop.morePerks", [all.size() - 4])
		more.flat = true
		more.focus_mode = Control.FOCUS_NONE
		more.alignment = HORIZONTAL_ALIGNMENT_LEFT
		more.add_theme_font_override("font", UiKit.font())
		more.add_theme_font_size_override("font_size", 12)
		for c in ["font_color", "font_hover_color", "font_pressed_color"]:
			more.add_theme_color_override(c, tone[2])
		for st in ["normal", "hover", "pressed", "focus"]:
			more.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		more.pressed.connect(func() -> void: _open_detail(product))
		list.add_child(more)
	v.add_child(buy_button(product, Products.tone(product)))
	return p


## Значок над названием: сколько осталось у стартового набора и пропуска, иначе "Выгодно".
func _badge(product: String) -> Control:
	var chip := PanelContainer.new()
	var s := UiKit.box(UiKit.GOLD, UiKit.OUTLINE, 10, 2, false)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	chip.add_theme_stylebox_override("panel", s)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)
	var until = Game.save.get("starterOfferUntil")
	if product == "starter" and (until is float or until is int):
		row.add_child(UiKit.icon("stopwatch", 12))
		var at := float(until)
		var left := func() -> String:
			return L.t("shop.endsIn", [House.countdown(at - Time.get_unix_time_from_system())])
		row.add_child(CombatCards.LiveLabel.new(left, 11, UiKit.INK))
	elif product == "eventPass":
		row.add_child(UiKit.icon("stopwatch", 12))
		var ends := float(Events.current()["end"])
		var left_long := func() -> String:
			return L.t("shop.endsIn", [EventsPanel.long_countdown(ends - Time.get_unix_time_from_system())])
		row.add_child(CombatCards.LiveLabel.new(left_long, 11, UiKit.INK))
	else:
		row.add_child(UiKit.icon("star", 12))
		row.add_child(UiKit.label(L.t("shop.bestValue"), 11))
	return chip


func _perk_row(perk: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := UiKit.icon_any(perk[0], 24)
	ic.custom_minimum_size = Vector2(28, 24)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var t := _wrap(perk[1], 13)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(t)
	return row


# MARK: Плитка набора

## Плитка (OfferTile): картинка, название, одна строка и цена. Нажатие открывает подробности.
func _tile(product: String) -> Button:
	var own := owned(product)
	var tone: Array = UiKit.TONES[Products.tone(product)]
	var b := Button.new()
	var s := UiKit.box(UiKit.PARCHMENT_LIGHT, UiKit.OUTLINE, 16, 2, false)
	s.set_content_margin_all(0)
	s.shadow_color = Color(UiKit.WOOD_DARK, 0.3)
	s.shadow_offset = Vector2(0, 3)
	s.shadow_size = 1
	var down := s.duplicate() as StyleBoxFlat
	down.bg_color = s.bg_color.darkened(0.08)
	for st in ["normal", "hover", "disabled"]:
		b.add_theme_stylebox_override(st, s)
	b.add_theme_stylebox_override("pressed", down)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 200)
	if own:
		b.modulate.a = 0.75
	b.pressed.connect(func() -> void: _open_detail(product))

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 2
	col.offset_right = -2
	col.offset_top = 2
	col.offset_bottom = -2
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	var band := PanelContainer.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = tone[1]
	bs.corner_radius_top_left = 14
	bs.corner_radius_top_right = 14
	bs.content_margin_top = 8
	bs.content_margin_bottom = 8
	band.add_theme_stylebox_override("panel", bs)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(band)
	var pic := art(product, 54.0)
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	band.add_child(pic)
	var title := _wrap(Products.title(product), 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.max_lines_visible = 2
	col.add_child(title)
	var tag := _wrap(tagline(product), 11, UiKit.INK_SOFT)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.max_lines_visible = 2
	col.add_child(tag)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(gap)
	var strip := PanelContainer.new()
	var ss := StyleBoxFlat.new()
	ss.bg_color = UiKit.PARCHMENT_DEEP if own else tone[1]
	ss.corner_radius_bottom_left = 14
	ss.corner_radius_bottom_right = 14
	ss.content_margin_top = 7
	ss.content_margin_bottom = 7
	strip.add_theme_stylebox_override("panel", ss)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(strip)
	var srow := HBoxContainer.new()
	srow.alignment = BoxContainer.ALIGNMENT_CENTER
	srow.add_theme_constant_override("separation", 4)
	srow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(srow)
	if own:
		srow.add_child(HousePanel.check_mark(14))
		srow.add_child(UiKit.label(L.t("shop.owned"), 13, UiKit.GOOD))
	else:
		var price := UiKit.label(Store.price(product), 13, Color.WHITE, 3)
		price.label_settings.outline_color = tone[2]
		srow.add_child(price)
	return b


# MARK: Билеты

## Билеты в экспедиции: сколько есть и покупка пачки (TicketsRow).
func _tickets_row() -> PanelContainer:
	var p := PanelContainer.new()
	var s := UiKit.box(UiKit.PARCHMENT_LIGHT, Color(UiKit.WOOD_DARK, 0.45), 14, 2, false)
	s.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", s)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	p.add_child(row)
	var ic := UiKit.icon("ticket", 40)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	col.add_child(_wrap(L.t("offer.tag.tickets", [Expeditions.TICKET_PACK]), 15))
	col.add_child(UiKit.label(L.t("tickets.have", [Game.premium.tickets()]), 12, UiKit.INK_SOFT))
	var b := UiKit.button(Store.price("tickets"), "blue", 14, true)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if Store.busy == "tickets":
		b.text = ""
		b.icon = Sprites.icon("hourglass")
		b.add_theme_constant_override("icon_max_width", 20)
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.custom_minimum_size = Vector2(64, 0)
	b.disabled = Store.busy != ""
	b.pressed.connect(func() -> void: Store.buy("tickets"))
	row.add_child(b)
	return p


# MARK: Подробности набора

## Подробности поверх магазина (OfferDetail): картинка, строка, все преимущества (или образы), покупка.
func _build_detail() -> void:
	if _detail_node != null and is_instance_valid(_detail_node):
		_detail_node.queue_free()
	_detail_node = null
	if detail == "":
		return
	var product := detail
	var tone := Products.tone(product)
	var o := Control.new()
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = UiKit.DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_close_detail())
	o.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o.add_child(center)
	var panel := PanelContainer.new()
	var ps := UiKit.box(UiKit.PARCHMENT_LIGHT, UiKit.TONES[tone][1], 22, 4)
	ps.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", ps)
	panel.custom_minimum_size = Vector2(minf(380.0, get_viewport_rect().size.x - 48.0), 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	v.add_child(ribbon(Products.title(product), tone, 19))
	var pic := art(product, 70.0)
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(pic)
	var tag := _wrap(tagline(product), 13, UiKit.INK_SOFT)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tag)
	if product == "skins":
		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		v.add_child(grid)
		for skin in Skins.collection():
			var cell := PanelContainer.new()
			var cst := UiKit.box(Color(UiKit.PARCHMENT_DEEP, 0.7), Color(0, 0, 0, 0), 10, 0, false)
			cst.set_content_margin_all(0)
			cell.add_theme_stylebox_override("panel", cst)
			cell.custom_minimum_size = Vector2(0, 46)
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var face := WardrobePanel.skin_icon(skin, 34)
			face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			cell.add_child(face)
			grid.add_child(cell)
	else:
		var list := VBoxContainer.new()
		list.add_theme_constant_override("separation", 8)
		v.add_child(list)
		for perk in perks(product):
			list.add_child(_perk_row(perk))
	v.add_child(buy_button(product, tone))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 8)
	v.add_child(buttons)
	if product == "skins":
		var wardrobe := UiKit.button(L.t("wardrobe.open"), "wood", 14, true)
		wardrobe.pressed.connect(func() -> void:
			if Hud.current != null:
				Hud.current.open_window(WardrobePanel.new()))
		buttons.add_child(wardrobe)
	var close_b := UiKit.button(L.t("common.close"), "wood", 14, true)
	close_b.pressed.connect(_close_detail)
	buttons.add_child(close_b)
	add_child(o)
	_detail_node = o
	if _detail_fresh:
		_detail_fresh = false
		panel.resized.connect(func() -> void: panel.pivot_offset = panel.size / 2.0)
		panel.scale = Vector2.ONE * 0.85
		o.modulate.a = 0.0
		var tw := o.create_tween().set_parallel()
		tw.tween_property(o, "modulate:a", 1.0, 0.15)
		tw.tween_property(panel, "scale", Vector2.ONE, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


static func _wrap(text: String, font_size: int, color := UiKit.INK) -> Label:
	var l := UiKit.label(text, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l
