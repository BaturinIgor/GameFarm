class_name ShopPanel
extends Sheet
## Магазин по вкладкам: акции (срочные наборы, предложение дня, наборы навсегда), MAX и Pro, кристаллы,
## лавка за кристаллы и бесплатное. В шапке - кристаллы. Подробности о наборе открываются поверх магазина.
## Здесь же общие части магазина: картинка набора (OfferArt), преимущества (Offers), кнопка покупки (BuyButton),
## карточка с лентой (ShopCard).

## Вкладки: [id, иконка, ключ подписи].
const TABS := [
	["offers", "tag", "shop.tab.offers"],
	["vip", "crown", "shop.tab.vip"],
	["crystals", "gem", "shop.tab.crystals"],
	["market", "basket", "shop.tab.market"],
	["free", "chest", "shop.tab.free"],
]

var tab := "offers"
## Открытые подробности набора ("" - закрыты).
var detail := ""
var _detail_node: Control
var _detail_fresh := false


func _init(start_tab := "") -> void:
	title_key = "shop.title"
	header_currency = "crystals"
	if start_tab != "":
		tab = start_tab


## Открыть магазин (на вкладке).
static func open(start_tab := "") -> void:
	if Hud.current != null:
		Hud.current.open_window(ShopPanel.new(start_tab))


## Что показать крупно в окне предложения: стартовый набор, набор по уровню, пропуск ивента, потом Pro и сад.
static func featured() -> String:
	var offers := Game.shop.current_offers()
	if not offers.is_empty():
		return offers[0]["product"]
	var p := Game.premium
	if not p.owns("pro"):
		return "pro"
	if not p.owns("garden"):
		return "garden"
	return ""


## Наборы навсегда (плитки во вкладке акций): купленные в конце.
static func bundles() -> Array:
	var list: Array = ["garden", "skins"]
	if Game.premium.owns("starter"):
		list.append("starter")
	return list.filter(func(x: String) -> bool: return not owned(x)) + list.filter(func(x: String) -> bool: return owned(x))


static func owned(product: String) -> bool:
	return Game.events.has_vip() if product == "eventPass" else Game.premium.owns(product)


func _set_tab(id: String) -> void:
	if tab == id:
		return
	tab = id
	detail = ""
	scroll_to_top()


# MARK: Вкладки

func build_top() -> void:
	var items: Array = []
	for t in TABS:
		items.append([t[0], L.t(t[2]), 1 if _tab_news(t[0]) else 0, t[1]])
	top_bar.add_child(UiKit.tabs(items, tab, func(id: String) -> void: _set_tab(id)))


## Точка на вкладке: там есть что-то новое или бесплатное.
func _tab_news(id: String) -> bool:
	var shop := Game.shop
	match id:
		"offers": return not shop.new_offers().is_empty() or shop.gift_ready() or not shop.flash_bought()
		"market": return Freebies.ready("market")
		"vip": return shop.max_daily_ready()
		"free": return shop.ad_crystals_left() > 0 or Game.premium.luck_ready() or Game.house.can_claim_login()
	return false


func build() -> void:
	match tab:
		"offers": _build_offers()
		"vip": _build_vip()
		"crystals": _build_crystals()
		"market": _build_market()
		"free": _build_free()
	_build_detail()


func _open_detail(product: String) -> void:
	detail = product
	_detail_fresh = true
	_dirty = true


func _close_detail() -> void:
	detail = ""
	_dirty = true


# MARK: Акции

func _build_offers() -> void:
	content.add_child(_gift_card())
	content.add_child(_flash_card())
	content.add_child(_steps_card())
	var offers := Game.shop.current_offers()
	for o in offers:
		content.add_child(_featured(o["product"]))
	if offers.is_empty():
		content.add_child(_note_card("px:tag", L.t("shop.noOffers")))
	content.add_child(EventsPanel.section(L.t("shop.section.deal")))
	content.add_child(_deal_card())
	content.add_child(EventsPanel.section(L.t("shop.section.forever")))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	content.add_child(grid)
	for product in bundles():
		grid.add_child(_tile(product))
	content.add_child(EventsPanel.section(L.t("shop.section.tickets")))
	content.add_child(_tickets_row())
	content.add_child(EventsPanel.section(L.t("shop.section.extras")))
	for product in ["aura", "rainbow", "glowMeadow", "petGlow", "builder", "energyPack", "attemptsPack"]:
		content.add_child(_extra_row(product))
	# Всё, что сейчас на витрине, игрок увидел
	Game.shop.mark_all_seen()


# MARK: Предложение дня, ступени, украшения

## Значок содержимого набора: [иконка, число или подпись].
static func pack_parts(p: Dictionary) -> Array:
	var out: Array = []
	if p.has("crystals"):
		out.append(["gem", Fmt.n(int(p["crystals"]))])
	if p.has("energy"):
		out.append(["bolt", Fmt.n(int(p["energy"]))])
	if p.has("infinite_hours"):
		out.append(["bolt", L.t("shop.infiniteHours", [int(p["infinite_hours"])])])
	if p.has("tickets"):
		out.append(["ticket", str(p["tickets"])])
	if p.has("maps"):
		out.append(["tmap", str(p["maps"])])
	if p.has("attempts"):
		out.append(["key", str(p["attempts"])])
	if p.has("cosmetic"):
		out.append(["star", Products.title(str(p["cosmetic"]))])
	return out


static func _parts_flow(parts: Array, size: int, color: Color) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 6)
	for part in parts:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 4)
		h.add_child(UiKit.icon(str(part[0]), size + 6))
		h.add_child(UiKit.label(str(part[1]), size, color, 4 if color == Color.WHITE else 0))
		flow.add_child(h)
	return flow


## Предложение дня: яркая карточка, "в N раз выгоднее", таймер до конца дня. Покупается раз в день.
func _flash_card() -> Control:
	var shop := Game.shop
	var variant := shop.flash_variant()
	var p := PanelContainer.new()
	var st := GameStyle.make(Color("e8463c"), Color("ffcf4a"), 18.0)
	st.outline_width = 4.0
	st.set_content_margin_all(14)
	p.add_theme_stylebox_override("panel", st)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(ribbon(L.t("shop.flash.title"), "gold", 16))
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	v.add_child(top)
	top.add_child(gem_pile(5, 64))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(col)
	var big := UiKit.title(L.t("shop.flash.ratio", [Products.flash_ratio(variant)]), 26)
	big.label_settings = big.label_settings.duplicate()
	big.label_settings.font_color = Color("fff3a0")
	col.add_child(big)
	col.add_child(UiKit.label(L.t("shop.flash.sub"), 12, Color.WHITE, 4))
	v.add_child(_parts_flow(pack_parts(variant), 15, Color.WHITE))
	var left := func() -> String: return L.t("shop.flash.ends", [House.countdown(ShopSystem.next_day_in())])
	var timer := CombatCards.LiveLabel.new(left, 13, Color.WHITE)
	timer.label_settings.outline_size = 4
	timer.label_settings.outline_color = Color("7a1a0e")
	timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(timer)
	if shop.flash_bought():
		v.add_child(UiKit.label(L.t("shop.flash.bought"), 13, Color.WHITE, 4))
	else:
		v.add_child(BuyButton.new("flash", "orange"))
	# Карточка мягко пульсирует, чтобы её заметили
	p.resized.connect(func() -> void: p.pivot_offset = p.size / 2.0)
	var tw := p.create_tween().set_loops()
	tw.tween_property(p, "scale", Vector2.ONE * 1.015, 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(p, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE)
	return p


## Ступенчатый набор: три ступени по очереди ($0.99, $1.99, $2.99) или все сразу за цену третьей.
func _steps_card() -> Control:
	var shop := Game.shop
	var parts := shop_card(L.t("shop.steps.title"), "green")
	var v: VBoxContainer = parts[1]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	var next := shop.next_step()
	for k in Products.STEP_KEYS:
		var cell := PanelContainer.new()
		var own := Game.premium.owns(k)
		var cur := k == next
		var cs := UiKit.box(Color("ddefc8") if own else (Color("fff3c4") if cur else UiKit.PARCHMENT_LIGHT),
			UiKit.TONES["gold"][1] if cur else Color(UiKit.WOOD_DARK, 0.35), 10, 3 if cur else 1, false)
		cs.set_content_margin_all(6)
		cell.add_theme_stylebox_override("panel", cs)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(cell)
		var c := VBoxContainer.new()
		c.add_theme_constant_override("separation", 3)
		cell.add_child(c)
		var price := UiKit.label(Products.price(k), 14)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(price)
		for part in pack_parts(Products.STEPS[k]):
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 3)
			h.alignment = BoxContainer.ALIGNMENT_CENTER
			h.add_child(UiKit.icon(str(part[0]), 16))
			h.add_child(UiKit.label(str(part[1]), 11))
			c.add_child(h)
		if own:
			var ok := HousePanel.check_mark(20)
			ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			c.add_child(ok)
	if next != "":
		v.add_child(BuyButton.new(next, "green", "shop.steps.buy"))
	if next == "step1":
		v.add_child(BuyButton.new("stepsAll", "orange", "shop.steps.all"))
	if next == "":
		v.add_child(UiKit.label(L.t("shop.owned"), 13, UiKit.INK_SOFT))
	return parts[0]


## Строка украшения или набора: значок, название, что даёт, кнопка с ценой.
func _extra_row(product: String) -> PanelContainer:
	var p := PanelContainer.new()
	var st := UiKit.box(UiKit.PARCHMENT_LIGHT, UiKit.TONES[Products.tone(product)][1], 14, 2, false)
	st.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", st)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	p.add_child(row)
	var icon := {"aura": "star", "rainbow": "rainbow", "glowMeadow": "spark", "petGlow": "paw", "builder": "hammer",
		"energyPack": "bolt", "attemptsPack": "key"}
	row.add_child(UiKit.icon(str(icon.get(product, "chest")), 34))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	col.add_child(UiKit.label(Products.title(product), 14))
	col.add_child(_wrap(L.t("product.%s.desc" % product), 11, UiKit.INK_SOFT))
	var b := BuyButton.new(product, Products.tone(product), "", true)
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.custom_minimum_size = Vector2(84, 36)
	row.add_child(b)
	return p


## Карточка с иконкой и текстом (когда показывать нечего).
func _note_card(icon: String, text: String) -> PanelContainer:
	var p := PanelContainer.new()
	var s := UiKit.box(Color(UiKit.PARCHMENT_DEEP, 0.6), Color(UiKit.WOOD_DARK, 0.35), 14, 2, false)
	s.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", s)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	p.add_child(row)
	var ic := UiKit.icon_any(icon, 30)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var l := _wrap(text, 13, UiKit.INK_SOFT)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	return p


# MARK: Предложение дня

func _deal_card() -> Control:
	var shop := Game.shop
	var item := shop.daily_deal()
	if item == "":
		return _note_card("px:gem", L.t("shop.deal.none"))
	var parts := shop_card(L.t("shop.deal.title"), "red")
	var v: VBoxContainer = parts[1]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var pic := PanelContainer.new()
	var ps := UiKit.box(Color(UiKit.PARCHMENT_DEEP, 0.7), Color(UiKit.WOOD_DARK, 0.35), 14, 2, false)
	ps.set_content_margin_all(8)
	pic.add_theme_stylebox_override("panel", ps)
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pic.add_child(market_icon(item, 48))
	row.add_child(pic)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	col.add_child(_wrap(market_name(item), 15))
	var prices := HBoxContainer.new()
	prices.add_theme_constant_override("separation", 6)
	col.add_child(prices)
	prices.add_child(_crossed_price(ShopSystem.base_price(item)))
	var off := _chip("-%d%%" % int(round(ShopSystem.DEAL_DISCOUNT * 100.0)), "red")
	prices.add_child(off)
	var left := func() -> String:
		return L.t("shop.deal.next", [House.countdown(House.start_of_day() + 86400.0 - Time.get_unix_time_from_system())])
	col.add_child(CombatCards.LiveLabel.new(left, 11, UiKit.INK_SOFT))
	if shop.deal_bought():
		var done := UiKit.label(L.t("shop.deal.bought"), 14, UiKit.GOOD)
		done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(done)
	else:
		var price := shop.deal_price(item)
		var b := crystal_button(price, "red")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			if not Game.shop.buy_market(item, true):
				_not_enough(price))
		v.add_child(b)
	return parts[0]


## Старая цена, зачёркнутая.
func _crossed_price(n: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(UiKit.icon("gem", 14))
	var l := UiKit.label(Fmt.n(n), 13, UiKit.INK_SOFT)
	row.add_child(l)
	row.draw.connect(func() -> void:
		row.draw_line(Vector2(0, row.size.y * 0.55), Vector2(row.size.x, row.size.y * 0.45), UiKit.BAD, 2.0, true))
	return row


static func _chip(text: String, tone: String) -> PanelContainer:
	var c: Array = UiKit.TONES[tone]
	var p := PanelContainer.new()
	var s := UiKit.box(c[1], UiKit.OUTLINE, 8, 2, false)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", s)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UiKit.title(text, 11)
	l.label_settings.outline_size = 3
	l.label_settings.outline_color = c[2]
	p.add_child(l)
	return p


## Не хватает кристаллов: тост и переход на вкладку кристаллов.
func _not_enough(price: int) -> void:
	Game.show_toast("px:gem", L.t("crystals.notEnough", [Fmt.n(price - Game.shop.crystals())]))
	Sound.play("error")
	_set_tab("crystals")


# MARK: MAX и Pro

func _build_vip() -> void:
	content.add_child(_max_card())
	content.add_child(EventsPanel.section(L.t("shop.section.pro")))
	content.add_child(_featured("pro"))
	var note := _wrap(L.t("max.note"), 11, UiKit.INK_SOFT)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(note)


func _max_card() -> Control:
	var shop := Game.shop
	var tone: Array = UiKit.TONES["gold"]
	var p := PanelContainer.new()
	var s := UiKit.box(Color("fff3c4"), UiKit.OUTLINE, 20, 3, false)
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
	var cs := UiKit.box(tone[1], UiKit.OUTLINE, 44, 3, false)
	cs.set_content_margin_all(10)
	circle.add_theme_stylebox_override("panel", cs)
	circle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	circle.add_child(art("max", 64.0))
	head.add_child(circle)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(col)
	var title := UiKit.title(Products.title("max"), 24)
	title.label_settings.font_color = tone[1]
	title.label_settings.outline_color = UiKit.OUTLINE
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(title)
	var tag := _wrap(tagline("max"), 12, UiKit.INK_SOFT)
	col.add_child(tag)
	if shop.max_active():
		col.add_child(_chip(L.t("max.daysLeft", [shop.max_days_left()]), "green"))

	var box := PanelContainer.new()
	var bs := UiKit.box(UiKit.PARCHMENT_LIGHT, Color(UiKit.OUTLINE, 0.5), 14, 2, false)
	bs.set_content_margin_all(12)
	box.add_theme_stylebox_override("panel", bs)
	v.add_child(box)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	box.add_child(list)
	for perk in perks("max"):
		list.add_child(_perk_row(perk))

	if shop.max_active():
		if shop.max_daily_ready():
			var claim := UiKit.button(L.t("max.claim", [ShopSystem.MAX_DAILY_CRYSTALS]), "green", 16)
			claim.icon = Sprites.icon("gem")
			claim.add_theme_constant_override("icon_max_width", 22)
			claim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			claim.pressed.connect(func() -> void: Game.shop.claim_max_daily())
			v.add_child(claim)
		else:
			var next := func() -> String:
				return L.t("max.nextDaily", [ShopSystem.MAX_DAILY_CRYSTALS,
					House.countdown(House.start_of_day() + 86400.0 - Time.get_unix_time_from_system())])
			var nl := CombatCards.LiveLabel.new(next, 12, UiKit.INK_SOFT)
			nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(nl)
	var buy := BuyButton.new("max", "orange", "max.extend" if shop.max_active() else "max.subscribe")
	v.add_child(buy)
	var terms := _wrap(L.t("max.terms", [Products.MAX_DAYS]), 10, UiKit.INK_SOFT)
	terms.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(terms)
	return p


# MARK: Кристаллы

func _build_crystals() -> void:
	content.add_child(_balance_card())
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	content.add_child(grid)
	var i := 0
	for key in Products.CRYSTAL_PACKS:
		grid.add_child(_pack_tile(key, i))
		i += 1
	grid.add_child(_free_crystals_tile())
	var hint := _wrap(L.t("crystals.hint"), 12, UiKit.INK_SOFT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(hint)


func _balance_card() -> PanelContainer:
	var p := PanelContainer.new()
	var tone: Array = UiKit.TONES["purple"]
	var s := UiKit.box(tone[1], UiKit.OUTLINE, 16, 3, false)
	s.set_content_margin_all(12)
	s.shadow_color = tone[2]
	s.shadow_offset = Vector2(0, 4)
	s.shadow_size = 1
	p.add_theme_stylebox_override("panel", s)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(row)
	row.add_child(UiKit.icon("gem", 34))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	var l := UiKit.label(L.t("crystals.have"), 12, Color.WHITE, 3)
	l.label_settings.outline_color = tone[2]
	col.add_child(l)
	var n := UiKit.title(Fmt.n(Game.shop.crystals()), 24)
	n.label_settings.outline_color = tone[2]
	col.add_child(n)
	return p


## Горка кристаллов: чем больше пачка, тем больше камней.
static func gem_pile(count: int, side: float) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(side, side)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var spots: Array = [[0.5, 0.5, 0.8]]
	match count:
		2: spots = [[0.36, 0.55, 0.62], [0.64, 0.45, 0.62]]
		3: spots = [[0.3, 0.6, 0.55], [0.7, 0.6, 0.55], [0.5, 0.36, 0.6]]
		4: spots = [[0.28, 0.66, 0.5], [0.72, 0.66, 0.5], [0.36, 0.34, 0.5], [0.64, 0.38, 0.55]]
		5, 6: spots = [[0.22, 0.7, 0.46], [0.5, 0.72, 0.5], [0.78, 0.7, 0.46], [0.36, 0.38, 0.5], [0.66, 0.36, 0.56]]
	for sp in spots:
		var k: float = sp[2]
		var g := UiKit.icon("gem", side * k)
		g.position = Vector2(sp[0] * side - side * k / 2.0, sp[1] * side - side * k / 2.0)
		g.size = Vector2(side * k, side * k)
		holder.add_child(g)
	return holder


func _pack_tile(key: String, index: int) -> PanelContainer:
	var pack: Dictionary = Products.CRYSTAL_PACKS[key]
	var first: bool = not key in Game.save.get("crystalFirst", [])
	var tone: Array = UiKit.TONES["purple"]
	var p := PanelContainer.new()
	var s := UiKit.box(UiKit.PARCHMENT_LIGHT, tone[1], 16, 3, false)
	s.set_content_margin_all(10)
	s.shadow_color = Color(UiKit.WOOD_DARK, 0.3)
	s.shadow_offset = Vector2(0, 3)
	s.shadow_size = 1
	p.add_theme_stylebox_override("panel", s)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	top.custom_minimum_size = Vector2(0, 20)
	v.add_child(top)
	if int(pack["bonus"]) > 0:
		top.add_child(_chip("+%d%%" % int(pack["bonus"]), "green"))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(gap)
	if first:
		top.add_child(_chip("x2", "red"))
	var pile := gem_pile(index + 1, 64.0)
	pile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(pile)
	var amount := UiKit.title(Fmt.n(int(pack["n"]) * (2 if first else 1)), 20)
	amount.label_settings.outline_color = tone[2]
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(amount)
	if first:
		var was := _wrap(L.t("crystals.firstX2", [Fmt.n(int(pack["n"]))]), 10, UiKit.INK_SOFT)
		was.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(was)
	var b := BuyButton.new(key, "purple", "", true)
	v.add_child(b)
	return p


func _free_crystals_tile() -> Button:
	var tone: Array = UiKit.TONES["green"]
	var b := Button.new()
	var s := UiKit.box(Color(tone[0], 0.35), tone[1], 16, 3, false)
	s.set_content_margin_all(10)
	var down := s.duplicate() as StyleBoxFlat
	down.bg_color = s.bg_color.darkened(0.1)
	for st in ["normal", "hover", "disabled"]:
		b.add_theme_stylebox_override(st, s)
	b.add_theme_stylebox_override("pressed", down)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func() -> void: _set_tab("free"))
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var pic := UiKit.icon("chest", 48)
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(pic)
	var l := _wrap(L.t("crystals.free"), 13)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	return b


# MARK: Лавка

## Подарок дня: 7 клеток серии, сегодняшняя подсвечена, кнопка "Забрать" или таймер до завтра.
func _gift_card() -> Control:
	var shop := Game.shop
	var parts := shop_card(L.t("gift.title"), "gold")
	var v: VBoxContainer = parts[1]
	var today := shop.gift_next_day()
	var claimed := not shop.gift_ready()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	v.add_child(row)
	for d in range(1, 8):
		var cell := PanelContainer.new()
		var done := d < today or (d == today and claimed)
		var cur := d == today and not claimed
		var st := UiKit.box(Color("ddefc8") if done else (Color("fff3c4") if cur else UiKit.PARCHMENT_LIGHT),
			UiKit.TONES["gold"][1] if cur else Color(UiKit.WOOD_DARK, 0.35), 8, 3 if cur else 1, false)
		st.set_content_margin_all(2)
		cell.add_theme_stylebox_override("panel", st)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(cell)
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 0)
		cell.add_child(col)
		var r := ShopSystem.gift_reward(d)
		var icon := "chest_gold" if d == 7 else ("gem" if r.has("crystals") else ("bolt" if r.has("energy") else "coins"))
		var ic := UiKit.icon(icon, 22)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(ic)
		var amount := "" if d == 7 else Fmt.compact(int(r.get("crystals", r.get("energy", r.get("coins", 0)))))
		var t := UiKit.label(amount if amount != "" else L.t("gift.day", [d]), 10, UiKit.INK)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(t)
	if claimed:
		var left := func() -> String: return L.t("free.in", [House.countdown(ShopSystem.next_day_in())])
		var l := CombatCards.LiveLabel.new(left, 13, UiKit.INK_SOFT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	else:
		var b := UiKit.button(L.t("gift.claim", [today]), "gold", 16)
		b.pressed.connect(func() -> void:
			var got := Game.shop.claim_gift()
			for k in got:
				var icon2: String = str({"coins": "coins", "energy": "bolt", "crystals": "gem", "tickets": "ticket"}.get(k, "chest"))
				Game.show_toast("px:" + str(icon2), "+%s" % Fmt.n(int(got[k]))))
		v.add_child(b)
	var hint := _wrap(L.t("gift.hint"), 11, UiKit.INK_SOFT)
	v.add_child(hint)
	return parts[0]


## Бесплатный товар лавки раз в сутки (меняется по дням).
func _free_market_card() -> Control:
	var parts := shop_card(L.t("free.market.title"), "green")
	var v: VBoxContainer = parts[1]
	var item := Freebies.market_item()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	row.add_child(UiKit.icon(str(ShopSystem.MARKET[item]["icon"]), 34))
	var t := _wrap(market_name(item), 14)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	v.add_child(FreeButton.new("market", "", func() -> void: Game.shop.give_market_free(item)))
	return parts[0]


func _build_market() -> void:
	content.add_child(_hint_row(L.t("market.hint")))
	content.add_child(_free_market_card())
	content.add_child(_deal_card())
	content.add_child(EventsPanel.section(L.t("market.section.goods")))
	for item in ShopSystem.MARKET:
		content.add_child(_market_row(item))
	var skins: Array = Skins.collection().filter(func(sk: String) -> bool: return not Skins.is_unlocked(sk))
	content.add_child(EventsPanel.section(L.t("market.section.skins")))
	if skins.is_empty():
		content.add_child(_note_card("px:wardrobe", L.t("market.skins.all")))
		return
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	content.add_child(grid)
	for skin in skins:
		grid.add_child(_skin_cell(skin))


func _hint_row(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var ic := UiKit.icon("gem", 20)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	row.add_child(_wrap(text, 12, UiKit.INK_SOFT))
	return row


## Иконка товара лавки.
static func market_icon(item: String, side: float) -> Control:
	if item.begins_with("skin:"):
		return WardrobePanel.skin_icon(item.substr(5), side)
	if item == "ticket5":
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(side, side)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for i in 3:
			var t := UiKit.icon("ticket", side * 0.7)
			t.position = Vector2(side * 0.15 * i, side * 0.3 - side * 0.12 * i)
			t.size = Vector2(side * 0.7, side * 0.7)
			holder.add_child(t)
		return holder
	return UiKit.icon(str(ShopSystem.MARKET.get(item, {}).get("icon", "gem")), side)


static func market_name(item: String) -> String:
	if item.begins_with("skin:"):
		return L.t("market.item.skin", [Skins.name_of(item.substr(5))])
	if item == "coins":
		return L.t("market.item.coins", [Fmt.n(Game.shop.market_coins())])
	return L.t("market.item." + item)


func _market_row(item: String) -> PanelContainer:
	var p := PanelContainer.new()
	var s := UiKit.box(UiKit.PARCHMENT_LIGHT, Color(UiKit.WOOD_DARK, 0.45), 14, 2, false)
	s.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", s)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	p.add_child(row)
	var ic := market_icon(item, 40)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	col.add_child(_wrap(market_name(item), 14))
	col.add_child(_wrap(L.t("market.desc." + item), 11, UiKit.INK_SOFT))
	var price := ShopSystem.base_price(item)
	var b := crystal_button(price, "purple", true)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void:
		if not Game.shop.buy_market(item):
			_not_enough(price))
	row.add_child(b)
	return p


func _skin_cell(skin: String) -> PanelContainer:
	var p := PanelContainer.new()
	var s := UiKit.box(UiKit.PARCHMENT_LIGHT, Color(UiKit.WOOD_DARK, 0.45), 14, 2, false)
	s.set_content_margin_all(8)
	p.add_theme_stylebox_override("panel", s)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	var face := WardrobePanel.skin_icon(skin, 52)
	face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(face)
	var name_l := UiKit.label(Skins.name_of(skin), 11)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.clip_text = true
	v.add_child(name_l)
	var item := "skin:" + skin
	var b := crystal_button(ShopSystem.SKIN_PRICE, "purple", true)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func() -> void:
		if not Game.shop.buy_market(item):
			_not_enough(ShopSystem.SKIN_PRICE))
	v.add_child(b)
	return p


## Кнопка с ценой в кристаллах. Не хватает - кнопка нажимается (подскажет, сколько не хватает), но серее.
static func crystal_button(price: int, tone := "purple", small := false) -> Button:
	var enough := Game.shop.crystals() >= price
	var b := MapPanel.icon_button([["i", "gem"], ["t", Fmt.n(price)]], tone if enough else "gray", 15 if not small else 13)
	if not small:
		b.custom_minimum_size.y = 44
	return b


# MARK: Бесплатно

func _build_free() -> void:
	var shop := Game.shop
	if shop.max_active() and shop.max_daily_ready():
		var claim := UiKit.button(L.t("max.claim", [ShopSystem.MAX_DAILY_CRYSTALS]), "gold", 16)
		claim.icon = Sprites.icon("crown")
		claim.add_theme_constant_override("icon_max_width", 22)
		claim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		claim.pressed.connect(func() -> void: Game.shop.claim_max_daily())
		content.add_child(claim)
	# Кристаллы за ролик
	var parts := shop_card(L.t("free.crystals.title"), "purple")
	var v: VBoxContainer = parts[1]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var pile := gem_pile(2, 48.0)
	pile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pile)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	col.add_child(_wrap(L.t("free.crystals.text", [ShopSystem.AD_CRYSTALS]), 13))
	col.add_child(UiKit.label(L.t("free.crystals.left", [shop.ad_crystals_left(), ShopSystem.AD_CRYSTALS_PER_DAY]),
		11, UiKit.INK_SOFT))
	if shop.ad_crystals_left() > 0:
		var b := Ads.reward_button(L.t("free.crystals.watch", [ShopSystem.AD_CRYSTALS]), "purple", 15)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			Ads.show_rewarded(func() -> void: Game.shop.claim_ad_crystals()))
		v.add_child(b)
	else:
		var next := func() -> String:
			return L.t("free.crystals.tomorrow", [House.countdown(House.start_of_day() + 86400.0 - Time.get_unix_time_from_system())])
		var nl := CombatCards.LiveLabel.new(next, 12, UiKit.INK_SOFT)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(nl)
	content.add_child(parts[0])

	# Удача
	content.add_child(EventsPanel.section(L.t("free.title")))
	content.add_child(_wrap(L.t("free.subtitle.pro") if Game.premium.has_pro() else L.t("free.subtitle"), 12,
		UiKit.INK_SOFT))
	content.add_child(LuckButton.new("wide"))

	# Награды за вход
	content.add_child(EventsPanel.section(L.t("house.calendar")))
	var cal := UiKit.button(L.t("free.calendar"), "orange" if Game.house.can_claim_login() else "wood", 15)
	cal.icon = Sprites.icon("calendar")
	cal.add_theme_constant_override("icon_max_width", 22)
	cal.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cal.pressed.connect(func() -> void:
		if Hud.current != null:
			Hud.current.open_window(CalendarPanel.new()))
	content.add_child(cal)

	var restore := UiKit.button(L.t("shop.restore"), "wood", 14, true)
	restore.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restore.pressed.connect(func() -> void: Store.restore())
	content.add_child(restore)
	var footer := _wrap(L.t("shop.footer"), 11, UiKit.INK_SOFT)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(footer)


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
		"max":
			return [["px:crown", L.t("max.perk.pro")],
				["px:gem", L.t("max.perk.daily", [ShopSystem.MAX_DAILY_CRYSTALS])],
				["px:star", L.t("max.perk.vip")],
				["px:wardrobe", L.t("max.perk.skin")],
				["px:bag", L.t("max.perk.backpack", [ShopSystem.MAX_BACKPACK])],
				["px:clover", L.t("max.perk.luck")]]
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
	if Products.is_level_bundle(product):
		var b: Dictionary = Products.LEVEL_BUNDLES[product]
		var out: Array = [["px:gem", L.t("bundle.crystals", [Fmt.n(int(b["crystals"]))])],
			["px:coins", L.t("starter.coins", [Fmt.n(int(b["coins"]))])],
			["px:ticket", L.t("bundle.tickets", [int(b["tickets"])])]]
		if int(b["maps"]) > 0:
			out.append(["px:tmap", L.t("bundle.maps", [int(b["maps"])])])
		if bool(b["skin"]):
			out.append(["px:wardrobe", L.t("bundle.skin")])
		return out
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
		"max":
			main = "px:crown"
			main_k = 0.85
			badge = "px:gem"
			badge_k = 0.45
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
		"traveler":
			main = "px:compass"
			main_k = 0.85
			badge = "px:gem"
		"explorer":
			main = "px:telescope"
			main_k = 0.85
			badge = "px:gem"
		"master":
			main = "px:trophy"
			main_k = 0.85
			badge = "px:gem"
	if main == "":
		return holder
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
	## Ключ подписи с ценой {0} ("" - "Купить за {0}" или просто цена у маленькой кнопки).
	var label_key := ""
	var small := false
	var _state := ""

	func _init(p: String, t: String, key := "", is_small := false) -> void:
		product = p
		tone = t
		label_key = key
		small = is_small
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
		var own := Game.premium.owns(product) and not Products.consumable(product)
		var busy := Store.busy == Products.key(product)
		var state := "busy" if busy else ("own" if own else "buy")
		if state + Store.busy == _state:
			return
		_state = state + Store.busy
		var fs := 14 if small else 15
		var proto := UiKit.button("", "green" if own else tone, fs, small)
		for s in ["normal", "hover", "pressed", "disabled", "focus"]:
			add_theme_stylebox_override(s, proto.get_theme_stylebox(s))
		if own:
			add_theme_stylebox_override("disabled", proto.get_theme_stylebox("normal"))
		add_theme_font_override("font", UiKit.font())
		add_theme_font_size_override("font_size", fs)
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
		elif small and label_key == "":
			text = Store.price(product)
			icon = null
		else:
			text = L.t(label_key if label_key != "" else "shop.buyFor", [Store.price(product)])
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


## Значок над названием: сколько осталось у срочного набора и пропуска, иначе "Выгодно".
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
	var ends := offer_ends(product)
	if ends > 0.0:
		row.add_child(UiKit.icon("stopwatch", 12))
		var left := func() -> String:
			return L.t("shop.endsIn", [EventsPanel.long_countdown(ends - Time.get_unix_time_from_system())])
		row.add_child(CombatCards.LiveLabel.new(left, 11, UiKit.INK))
	else:
		row.add_child(UiKit.icon("star", 12))
		row.add_child(UiKit.label(L.t("shop.bestValue"), 11))
	return chip


## Когда кончается срочное предложение (unix) или 0.
static func offer_ends(product: String) -> float:
	if product == "starter":
		var until = Game.save.get("starterOfferUntil")
		return float(until) if (until is float or until is int) else 0.0
	if product == "eventPass":
		return float(Events.current()["end"])
	if Products.is_level_bundle(product):
		return Game.shop.bundle_until(product)
	return 0.0


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
