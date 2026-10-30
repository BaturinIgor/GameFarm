class_name TraderPanel
extends Sheet
## Лавка у дома (порт TraderView): семена и обмены дня. Здесь же общие элементы окон торговцев.

const SEEDS_PILL := Color("ddefc8")

var tab := "seeds"
var _countdown: Label
var _tick := 0.0


func _init() -> void:
	title_key = "trader.title"


func build() -> void:
	content.add_child(hello_row("merchant", [UiKit.label(L.t("trader.hello"), 13)]))
	if tab == "seeds":
		for crop in Farming.CROP_IDS:
			_seed_row(crop)
	else:
		_deals()


func _process(delta: float) -> void:
	super(delta)
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 1.0
	if _countdown != null and is_instance_valid(_countdown):
		_countdown.text = _refresh_text()


func _refresh_text() -> String:
	return L.t("trader.deals.refresh", [countdown(GardenSystem.next_deals_at() - GardenSystem.now())])


## Вкладки закреплены под шапкой: прокручивается только содержимое.
func build_top() -> void:
	_tabs()


func _tabs() -> void:
	var items: Array = []
	for t in ["seeds", "deals"]:
		items.append([t, L.t("trader.tab." + t)])
	top_bar.add_child(UiKit.tabs(items, tab, func(id: String) -> void:
		tab = id
		scroll_to_top()))


## Семена одной культуры (SeedRow): сколько растёт, сколько даёт, цена.
func _seed_row(crop: String) -> void:
	var spec := Farming.spec(crop)
	var unlocked := Game.level >= int(spec["level"])
	var c := card_box(content)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	c.add_child(row)
	var frame := icon_frame(Farming.seed_icon(crop), 34, Color(UiKit.PARCHMENT_DEEP, 0.7), Color(UiKit.WOOD_DARK, 0.4))
	if not unlocked:
		frame.modulate.a = 0.5
	row.add_child(frame)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 3)
	row.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	col.add_child(head)
	head.add_child(UiKit.label(Farming.name_of(crop), 15))
	var have := Game.garden.seeds(crop)
	if have > 0:
		head.add_child(pill("x%d" % have, SEEDS_PILL, Color(UiKit.GOOD, 0.5)))
	var info := HBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	col.add_child(info)
	info.add_child(UiKit.icon("hourglass", 14))
	info.add_child(UiKit.label(Fmt.seconds(float(spec["grow_time"])), 11, UiKit.INK_SOFT))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(4, 0)
	info.add_child(gap)
	info.add_child(UiKit.icon(spec["produce"], 14))
	info.add_child(UiKit.label("x%d" % int(spec["yield"]), 11, UiKit.INK_SOFT))
	if unlocked:
		var buys := VBoxContainer.new()
		buys.add_theme_constant_override("separation", 4)
		buys.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(buys)
		for count in [1, 5]:
			var cost := Game.garden.seed_cost(crop, count)
			var b := coin_button("+%d" % count, cost, "green")
			b.disabled = int(Game.save["coins"]) < cost
			b.pressed.connect(func() -> void: Game.garden.buy_seeds(crop, count))
			buys.add_child(b)
	else:
		var tag := level_tag(int(spec["level"]), false)
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(tag)


func _deals() -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	content.add_child(line)
	line.add_child(UiKit.icon("hourglass", 16))
	_countdown = UiKit.label(_refresh_text(), 12, UiKit.INK_SOFT)
	line.add_child(_countdown)
	for deal in Game.garden.daily_deals():
		_deal_row(deal)


## Обмен дня (DealRow): отдать ресурсы (и монеты) и получить награду.
func _deal_row(deal: Dictionary) -> void:
	var g := Game.garden
	var bought := g.deal_bought(deal)
	var c := card_box(content, Color(UiKit.WOOD_DARK, 0.45) if bought else Color(UiKit.TONES["orange"][1], 0.6),
		2 if bought else 3)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	c.add_child(row)
	var give := VBoxContainer.new()
	give.add_theme_constant_override("separation", 6)
	give.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(give)
	give.add_child(UiKit.label(L.t("trader.give"), 11, UiKit.INK_SOFT))
	give.add_child(UiKit.cost_view({"coins": int(deal["coins_price"]), "items": deal["give"]}))
	var arrow := UiKit.label(">", 16, UiKit.WOOD_DARK)
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(arrow)
	var get_col := VBoxContainer.new()
	get_col.add_theme_constant_override("separation", 6)
	get_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(get_col)
	get_col.add_child(UiKit.label(L.t("trader.get"), 11, UiKit.INK_SOFT))
	var chip := _reward_chip(deal["reward"])
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	get_col.add_child(chip)
	if bought:
		var done := HBoxContainer.new()
		done.add_theme_constant_override("separation", 6)
		c.add_child(done)
		done.add_child(check_mark(18))
		done.add_child(UiKit.label(L.t("trader.bought"), 13, UiKit.GOOD))
	else:
		var b := UiKit.button(L.t("trader.trade"), "orange", 13, true)
		b.disabled = not g.can_trade(deal)
		b.pressed.connect(func() -> void: Game.garden.trade(deal))
		c.add_child(b)


## Награда "+N" с иконкой в светлой капсуле (RewardView).
func _reward_chip(reward: Dictionary) -> PanelContainer:
	var icon_name := "coins"
	var text := "1"
	match str(reward["type"]):
		"coins": text = Fmt.n(int(reward["n"]))
		"ticket": icon_name = "ticket"
		"seeds":
			icon_name = Farming.seed_icon(str(reward["crop"]))
			text = str(int(reward["n"]))
	var p := PanelContainer.new()
	var s := UiKit.box(UiKit.PARCHMENT_LIGHT, Color(UiKit.WOOD_DARK, 0.5), 14, 2, false)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 5
	s.content_margin_bottom = 5
	p.add_theme_stylebox_override("panel", s)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	p.add_child(h)
	h.add_child(UiKit.icon(icon_name, 18))
	h.add_child(UiKit.label(text, 16))
	return p


# MARK: Общие элементы окон торговцев и огорода

## Время до события: м:сс или ч:мм:сс (Countdown.text).
static func countdown(seconds: float) -> String:
	var s := maxi(0, int(seconds))
	var h := s / 3600
	var m := (s % 3600) / 60
	var sec := s % 60
	if h > 0:
		return "%d:%02d:%02d" % [h, m, sec]
	return "%d:%02d" % [m, sec]


## Портрет торговца из листа персонажа (NPCPortrait).
static func portrait(npc: String, side := 56.0) -> PanelContainer:
	var p := PanelContainer.new()
	var s := UiKit.box(UiKit.PARCHMENT_DEEP, UiKit.OUTLINE, 14, 2, false)
	s.set_content_margin_all(6)
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size = Vector2(side, side)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex := Sprites.texture("pl_" + npc)
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tex != null:
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2(20, 14, 24, 26)
		t.texture = a
	else:
		t.texture = Sprites.icon("bag")
	p.add_child(t)
	return p


## Портрет и реплика торговца в светлой рамке.
static func hello_row(npc: String, lines: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var face := portrait(npc)
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(face)
	var box := PanelContainer.new()
	var s := UiKit.box(UiKit.PARCHMENT_LIGHT, Color(UiKit.WOOD_DARK, 0.45), 12, 2, false)
	s.set_content_margin_all(10)
	box.add_theme_stylebox_override("panel", s)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	box.add_child(col)
	for l in lines:
		if l is Label:
			(l as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(l)
	return row


## Карточка (Card): светлая плашка, рамка цвета border.
static func card_box(parent: Control, border := Color(UiKit.WOOD_DARK, 0.45), width := 2) -> VBoxContainer:
	var p := PanelContainer.new()
	var s := UiKit.box(UiKit.PARCHMENT_LIGHT, border, 16, width, false)
	s.set_content_margin_all(14)
	s.shadow_color = Color(UiKit.WOOD_DARK, 0.25)
	s.shadow_offset = Vector2(0, 3)
	s.shadow_size = 1
	p.add_theme_stylebox_override("panel", s)
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	return v


## Иконка в скруглённой рамке 50x50.
static func icon_frame(icon_name: String, icon_size: float, fill: Color, border: Color, width := 2) -> PanelContainer:
	var frame := PanelContainer.new()
	var s := UiKit.box(fill, border, 12, width, false)
	s.set_content_margin_all(0)
	frame.add_theme_stylebox_override("panel", s)
	frame.custom_minimum_size = Vector2(50, 50)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := UiKit.icon(icon_name, icon_size)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.add_child(ic)
	return frame


## Маленькая капсула с текстом.
static func pill(text: String, fill: Color, border: Color, font_size := 11) -> PanelContainer:
	var p := PanelContainer.new()
	var s := UiKit.box(fill, border, 9, 1, false)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", s)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(UiKit.label(text, font_size))
	return p


## Плашка "Ур. N": зелёная, если уровень достигнут (LevelTag).
static func level_tag(level: int, ok: bool) -> PanelContainer:
	var tone: Array = UiKit.TONES["green" if ok else "red"]
	var p := PanelContainer.new()
	var s := UiKit.box(tone[1], UiKit.OUTLINE, 12, 2, false)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(UiKit.label(L.t("common.lvl", [level]), 12, Color.WHITE, 3))
	return p


## Кнопка "текст, монета, цена" (монета иконкой вместо 🪙).
static func coin_button(prefix: String, price: int, tone: String, font_size := 13) -> Button:
	var b := UiKit.button("", tone, font_size, true)
	var amount := Fmt.n(price)
	var font := UiKit.font()
	var width := font.get_string_size(prefix, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x \
		+ font.get_string_size(amount, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + font_size + 4.0 + 8.0
	b.custom_minimum_size = Vector2(width + 26.0, font_size + 18.0)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	if prefix != "":
		var l := UiKit.label(prefix, font_size, Color.WHITE, 5)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)
	var coin := UiKit.icon("coin", font_size + 2.0)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(coin)
	var p := UiKit.label(amount, font_size, Color.WHITE, 5)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(p)
	return b


## Зелёная галочка в кружке (checkmark.seal.fill).
static func check_mark(side := 20.0) -> Control:
	var c := CheckMark.new()
	c.custom_minimum_size = Vector2(side, side)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


class CheckMark:
	extends Control

	func _draw() -> void:
		var r := minf(size.x, size.y) / 2.0
		var c := size / 2.0
		draw_circle(c, r, UiKit.GOOD)
		var pts := PackedVector2Array([c + Vector2(-0.45, 0.0) * r, c + Vector2(-0.12, 0.33) * r,
			c + Vector2(0.45, -0.3) * r])
		draw_polyline(pts, Color.WHITE, maxf(2.0, r * 0.28), true)
