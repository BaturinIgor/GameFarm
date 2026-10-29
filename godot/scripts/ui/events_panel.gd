class_name EventsPanel
extends Sheet
## Окно ивентов (порт EventsView): баннер текущего праздника, забег по этапам, очки и ступень пропуска,
## бесплатная и VIP-линия наград, бонусный сундук и анонсы следующих ивентов.
## Здесь же общие части: карточка ивента для карты мира (EventMapCard), расписание для календаря
## (EventSchedule), выбор усиления после этапа (EventBoonPicker) и портрет образа (SkinIcon).
## Пока пропуска нет - предложение купить его (EventVipCard).


func _init() -> void:
	title_key = "event.title"


func _ready() -> void:
	super._ready()
	Game.events.sync_event()
	Game.events.mark_event_seen()


func build() -> void:
	var run := Events.current()
	var event: String = run["event"]
	content.add_child(EventsPanel.banner(run, close))
	if Game.events.events_open():
		content.add_child(_run_card())
		content.add_child(_progress_card(event))
		if not Game.events.has_vip():
			content.add_child(_vip_card(event))
		_tier_list(event)
	else:
		var c := _card(Color(UiKit.WOOD_DARK, 0.45), 2)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_body(c).add_child(row)
		row.add_child(UiKit.icon("key", 18))
		row.add_child(UiKit.label(L.t("event.locked", [Events.MIN_LEVEL]), 14))
		content.add_child(c)
	content.add_child(EventsPanel.section(L.t("event.upcoming")))
	for r in Events.upcoming():
		content.add_child(EventsPanel.upcoming_card(r))
	var tip := HousePanel.wrapped(L.t("event.tip"), 11, UiKit.INK_SOFT)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(tip)


## Купить VIP-пропуск (EventVipCard): образ ивента, описание и кнопка покупки.
func _vip_card(event: String) -> Control:
	var parts := ShopPanel.shop_card(Products.title("eventPass"), "gold")
	var v: VBoxContainer = parts[1]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var frame := PanelContainer.new()
	var fs := UiKit.box(Color(UiKit.PARCHMENT_DEEP, 0.7), Color(UiKit.OUTLINE, 0.6), 12, 2, false)
	fs.set_content_margin_all(4)
	frame.add_theme_stylebox_override("panel", fs)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.add_child(EventsPanel.skin_icon(Events.skin_of(event), 52))
	row.add_child(frame)
	var skin := Events.skin_of(event)
	var text := HousePanel.wrapped(L.t("event.vip.desc", [Skins.name_of(skin)]), 12)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text)
	v.add_child(ShopPanel.buy_button("eventPass", "orange"))
	return parts[0]


# MARK: Время

## Долгий отсчёт: дни и часы, меньше суток - часы, минуты и секунды.
static func long_countdown(seconds: float) -> String:
	var s := maxi(0, int(seconds))
	var d := s / 86400
	if d > 0:
		return L.t("time.dayHour", [d, (s % 86400) / 3600])
	return House.countdown(seconds)


## Совсем короткий отсчёт для плашки: дни, часы или минуты.
static func short_countdown(seconds: float) -> String:
	var s := maxi(0, int(seconds))
	if s >= 86400:
		return L.t("time.dayShort", [s / 86400])
	if s >= 3600:
		return L.t("time.hour", [s / 3600])
	return L.t("time.min", [maxi(1, s / 60)])


## Подпись с отсчётом до until (unix-секунды), обновляется сама раз в секунду.
## key - строка с {0} для времени ("" - только время).
static func countdown_label(key: String, until: float, size: int, color: Color, outline := 0, short := false) -> Label:
	var l := CountdownLabel.new()
	var proto := UiKit.label("", size, color, outline)
	l.label_settings = proto.label_settings
	proto.free()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.key = key
	l.until = until
	l.short = short
	l.refresh()
	return l


class CountdownLabel extends Label:
	var key := ""
	var until := 0.0
	var short := false
	var _tick := 1.0

	func _process(delta: float) -> void:
		_tick -= delta
		if _tick <= 0.0:
			_tick = 1.0
			refresh()

	func refresh() -> void:
		var left := until - Time.get_unix_time_from_system()
		var t := EventsPanel.short_countdown(left) if short else EventsPanel.long_countdown(left)
		text = L.t(key, [t]) if key != "" else t


# MARK: Общие элементы

## Карточка (Card): светлый пергамент, рамка (тёмное дерево или цвет), тень снизу.
static func _card(border: Color, width: int) -> PanelContainer:
	var p := PanelContainer.new()
	var s := UiKit.box(UiKit.PARCHMENT_LIGHT, border, 16, width, false)
	s.set_content_margin_all(14)
	s.shadow_color = Color(UiKit.WOOD_DARK, 0.25)
	s.shadow_offset = Vector2(0, 3)
	s.shadow_size = 1
	p.add_theme_stylebox_override("panel", s)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	return p


static func _body(card: PanelContainer) -> VBoxContainer:
	return card.get_child(0) as VBoxContainer


## Заголовок раздела (SectionTitle): черта, текст, черта.
static func section(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 2:
		var line := ColorRect.new()
		line.color = Color(UiKit.WOOD_DARK, 0.35)
		line.custom_minimum_size = Vector2(0, 2)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(line)
		if i == 0:
			row.add_child(UiKit.label(text.to_upper(), 14, UiKit.INK_SOFT))
	return row


## Портрет образа (SkinIcon): голова с первого кадра листа pl_<образ>.
static func skin_icon(skin: String, side: float) -> TextureRect:
	var t := UiKit.icon("wardrobe", side)
	var tex := Sprites.texture("pl_" + skin)
	if tex != null:
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2(20, 14, 24, 26)
		t.texture = a
	return t


## Картинка карты ивента в скруглённой рамке (вместо MiniMap.image - земля карты этапа).
static func map_picture(event: String, box: Vector2, radius: int, border: Color, width: int) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = box
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var clip := Panel.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color = UiKit.OUTLINE
	cs.set_corner_radius_all(radius)
	clip.add_theme_stylebox_override("panel", cs)
	clip.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(clip)
	var loc := Events.location(event)
	var tex := Sprites.ground(Game.events.resource_name(loc))
	if tex == null:
		tex = Sprites.ground(loc)
	var pic := TextureRect.new()
	pic.texture = tex
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip.add_child(pic)
	var frame := Panel.new()
	var fs := StyleBoxFlat.new()
	fs.draw_center = false
	fs.border_color = border
	fs.set_border_width_all(width)
	fs.set_corner_radius_all(radius)
	fs.anti_aliasing = true
	frame.add_theme_stylebox_override("panel", fs)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(frame)
	return holder


## Капсула с текстом (белые буквы с обводкой).
static func _capsule(text: String, fill: Color, lip: Color, font_size: int) -> PanelContainer:
	var p := PanelContainer.new()
	var s := UiKit.box(fill, UiKit.OUTLINE, 12, 2, false)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := UiKit.label(text, font_size, Color.WHITE, 3)
	l.label_settings.outline_color = lip
	p.add_child(l)
	return p


# MARK: Баннер

## Баннер текущего ивента: название, таймер, карта, главные награды и переход. on_travel - после перехода.
static func banner(run: Dictionary, on_travel: Callable) -> Control:
	var event: String = run["event"]
	var colors: Array = Events.COLORS[event]
	var card := DungeonPanel.GradientPanel.new(colors[0], colors[1])
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	v.add_child(top)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	top.add_child(left)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	left.add_child(head)
	head.add_child(UiKit.icon(Events.ICON[event], 30))
	var title := UiKit.title(Events.name_of(event), 21)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var blurb := UiKit.label(Events.blurb(event), 12, Color.WHITE, 3)
	blurb.label_settings.outline_color = Color(UiKit.OUTLINE, 0.8)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(blurb)
	var timer := PanelContainer.new()
	var ts := StyleBoxFlat.new()
	ts.bg_color = Color(UiKit.OUTLINE, 0.45)
	ts.set_corner_radius_all(12)
	ts.content_margin_left = 10
	ts.content_margin_right = 10
	ts.content_margin_top = 5
	ts.content_margin_bottom = 5
	timer.add_theme_stylebox_override("panel", ts)
	timer.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	timer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(timer)
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 5)
	timer.add_child(trow)
	trow.add_child(UiKit.icon("stopwatch", 14))
	trow.add_child(EventsPanel.countdown_label("event.left", float(run["end"]), 12, Color.WHITE, 3))
	top.add_child(EventsPanel.map_picture(event, Vector2(86, 104), 12, UiKit.OUTLINE, 3))

	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 10)
	v.add_child(tiles)
	tiles.add_child(_preview_tile(L.t("event.preview.node"), HousePanel.sprite_rect(Events.PREVIEW[event], 2.0, Vector2(70, 50))))
	tiles.add_child(_preview_tile(L.t("event.preview.decor"),
		HousePanel.sprite_rect(House.decor_sprite(Events.decor_of(event)), 2.0, Vector2(70, 50))))
	var skin := EventsPanel.skin_icon(Events.skin_of(event), 46)
	skin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tiles.add_child(_preview_tile(L.t("event.preview.skin"), skin))

	if Game.events.events_open():
		if Game.current == Events.location(event):
			var home := UiKit.button(L.t("event.home"), "wood")
			home.pressed.connect(func() -> void:
				Game.events.leave_event()
				on_travel.call())
			v.add_child(home)
		else:
			var go := UiKit.button(L.t("event.go"), "green")
			go.disabled = Game.save.get("expedition") != null
			go.pressed.connect(func() -> void:
				Game.events.go_to_event()
				on_travel.call())
			v.add_child(go)
	return card


static func _preview_tile(caption: String, art: Control) -> Control:
	var p := PanelContainer.new()
	var s := UiKit.box(Color(UiKit.PARCHMENT_LIGHT, 0.92), Color(UiKit.OUTLINE, 0.7), 12, 2, false)
	s.content_margin_left = 4
	s.content_margin_right = 4
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", s)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	p.add_child(col)
	var box := CenterContainer.new()
	box.custom_minimum_size = Vector2(0, 50)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(art)
	col.add_child(box)
	var l := UiKit.label(caption, 10, UiKit.INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	col.add_child(l)
	return p


# MARK: Забег и очки

## Забег по этапам: где ты сейчас, рекорд и взятые усиления (EventRunCard).
func _run_card() -> Control:
	var c := _card(UiKit.TONES["orange"][1], 3)
	var v := _body(c)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	row.add_child(UiKit.icon("portal", 34))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	col.add_child(UiKit.label(L.t("event.stage", [Game.events.event_stage()]), 16))
	col.add_child(UiKit.label(L.t("event.best", [int(Game.save.get("eventBest", 0))]), 12, UiKit.INK_SOFT))
	v.add_child(HousePanel.wrapped(L.t("event.runHint"), 12, UiKit.INK_SOFT))
	var taken := Events.BOONS.filter(func(b: String) -> bool: return Game.events.boon_rank(b) > 0)
	if taken.is_empty():
		return c
	var line := ColorRect.new()
	line.color = Color(UiKit.WOOD_DARK, 0.3)
	line.custom_minimum_size = Vector2(0, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(line)
	for b in taken:
		var rank := Game.events.boon_rank(b)
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 8)
		v.add_child(r)
		r.add_child(UiKit.icon(Events.boon_icon(b), 22))
		var caption := UiKit.label(Events.boon_name(b) + " " + L.t("boon.rank", [rank, Events.BOON_MAX_RANK]), 13)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(caption)
		var text := UiKit.label(Events.boon_text(b, rank), 11, UiKit.INK_SOFT)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size = Vector2(130, 0)
		r.add_child(text)
	return c


## Очки и ступень пропуска (EventProgressCard).
func _progress_card(event: String) -> Control:
	var tier_n := Game.events.event_tier()
	var points := int(Game.save.get("eventPoints", 0))
	var maxed := tier_n >= Events.TIERS
	var from := Events.total() + ((points - Events.total()) / Events.BONUS_EVERY) * Events.BONUS_EVERY if maxed \
		else Events.threshold(tier_n)
	var need := Events.BONUS_EVERY if maxed else Events.cost(tier_n + 1)
	var have := points - from
	var c := _card(Color(UiKit.WOOD_DARK, 0.45), 2)
	var v := _body(c)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	row.add_child(UiKit.icon(Events.ICON[event], 32))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	col.add_child(UiKit.label(L.t("event.tier", [tier_n, Events.TIERS]), 16))
	col.add_child(UiKit.label(L.t("event.points", [Fmt.n(points)]), 12, UiKit.INK_SOFT))
	if Game.events.has_vip():
		row.add_child(_capsule(L.t("event.vip.active"), UiKit.TONES["gold"][1], UiKit.TONES["gold"][2], 12))
	var label := L.t("event.bonusProgress", [have, need]) if maxed else "%d / %d" % [have, need]
	var bar := UiKit.bar(float(have) / float(maxi(1, need)), "purple" if maxed else "orange", 100, 18, label)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(bar)
	var claimable := Game.events.event_claimable()
	if claimable > 0:
		var b := UiKit.button(L.t("event.claimAll", [claimable]), "green")
		b.pressed.connect(func() -> void: Game.events.claim_all_event())
		v.add_child(b)
	return c


# MARK: Пропуск

## Ступени пропуска: бесплатная линия и VIP (EventTierList).
func _tier_list(event: String) -> void:
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	content.add_child(list)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	list.add_child(head)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(34, 1)
	head.add_child(gap)
	for track in [["event.track.free", UiKit.INK_SOFT], ["event.track.vip", UiKit.TONES["gold"][2]]]:
		var l := UiKit.label(L.t(track[0]), 12, track[1])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(l)
	var reached := Game.events.event_tier()
	for t in range(1, Events.TIERS + 1):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		list.add_child(row)
		row.add_child(_tier_badge(t, t <= reached))
		row.add_child(_reward_cell(Events.free_reward(t), event, t, false))
		row.add_child(_reward_cell(Events.vip_reward(t), event, t, true))
	list.add_child(_bonus_row())


static func _tier_badge(tier_n: int, reached: bool) -> Control:
	var tone: Array = UiKit.TONES["orange" if reached else "gray"]
	var p := PanelContainer.new()
	var s := UiKit.box(tone[1], UiKit.OUTLINE, 17, 2, false)
	s.set_content_margin_all(0)
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size = Vector2(34, 34)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UiKit.label(str(tier_n), 14, Color.WHITE, 3)
	l.label_settings.outline_color = tone[2]
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


static func _reward_cell(reward: Dictionary, event: String, tier_n: int, vip: bool) -> Control:
	var claimed: bool = tier_n in Game.save.get("eventVip" if vip else "eventFree", [])
	var reached := tier_n <= Game.events.event_tier()
	var locked := vip and not Game.events.has_vip()
	var ready := Game.events.can_claim_event(tier_n, vip)
	var b := Button.new()
	var fill := Color("fbe3a8") if vip else UiKit.PARCHMENT_LIGHT
	var s := UiKit.box(fill, UiKit.TONES["green"][1] if ready else Color(UiKit.WOOD_DARK, 0.45), 12, 3 if ready else 2, false)
	s.set_content_margin_all(0)
	for state in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(state, s)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 58)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.disabled = not ready
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.modulate.a = 0.4 if claimed else (1.0 if reached else 0.6)
	center.add_child(EventsPanel.reward_icon(reward, event))
	b.add_child(center)
	var mark: Control = null
	if claimed:
		mark = HousePanel.check_mark(20)
	elif locked:
		mark = UiKit.icon("key", 14)
		mark.modulate = UiKit.INK_SOFT
	if mark != null:
		mark.anchor_left = 1.0
		mark.anchor_right = 1.0
		mark.offset_left = -16 if claimed else -18
		mark.offset_right = 4 if claimed else -4
		mark.offset_top = -4 if claimed else 4
		mark.offset_bottom = 16 if claimed else 18
		b.add_child(mark)
	if ready:
		var tag := _capsule(L.t("quests.claim"), UiKit.TONES["green"][1], UiKit.TONES["green"][2], 10)
		var ts := tag.get_theme_stylebox("panel") as StyleBoxFlat
		ts.content_margin_left = 7
		ts.content_margin_right = 7
		ts.content_margin_top = 1
		ts.content_margin_bottom = 1
		tag.anchor_left = 0.5
		tag.anchor_right = 0.5
		tag.anchor_top = 1.0
		tag.anchor_bottom = 1.0
		tag.offset_top = 8
		tag.offset_bottom = 8
		tag.grow_horizontal = Control.GROW_DIRECTION_BOTH
		tag.grow_vertical = Control.GROW_DIRECTION_BEGIN
		b.add_child(tag)
	b.pressed.connect(func() -> void: Game.events.claim_event(tier_n, vip))
	return b


## Иконка награды пропуска (EventRewardIcon).
static func reward_icon(reward: Dictionary, event: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n := int(reward.get("n", 0))
	var amount := "x%d" % n
	match str(reward["type"]):
		"coins":
			row.add_child(UiKit.icon("coin", 26))
			amount = Fmt.n(Game.events.event_reward_coins(n))
		"tickets":
			row.add_child(UiKit.icon("ticket", 26))
		"seeds":
			row.add_child(UiKit.icon(Farming.seed_icon(Events.CROP[event]), 28))
		"dish":
			row.add_child(UiKit.icon(House.dish_icon(Events.DISH[event]), 28))
		"cards":
			row.add_child(UiKit.icon("cards", 26))
		"sparks":
			row.add_child(UiKit.icon("spark", 26))
		"maps":
			row.add_child(UiKit.icon("tmap", 26))
		"decor":
			row.add_child(HousePanel.sprite_rect(House.decor_sprite(Events.decor_of(event)), 1.4, Vector2(56, 44)))
			return row
		"skin":
			row.add_child(EventsPanel.skin_icon(Events.skin_of(event), 44))
			return row
	var l := UiKit.label(amount, 13, UiKit.INK)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	return row


## Бонусный сундук после последней ступени (BonusRow).
static func _bonus_row() -> Control:
	var ready := Game.events.event_bonus_ready()
	var p := PanelContainer.new()
	var s := UiKit.box(UiKit.PARCHMENT_LIGHT, Color(UiKit.WOOD_DARK, 0.45), 12, 2, false)
	s.set_content_margin_all(10)
	s.shadow_color = Color(UiKit.WOOD_DARK, 0.25)
	s.shadow_offset = Vector2(0, 3)
	s.shadow_size = 1
	p.add_theme_stylebox_override("panel", s)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	p.add_child(row)
	row.add_child(UiKit.icon("chest_gold", 34))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	col.add_child(UiKit.label(L.t("event.bonus.title"), 13))
	var line := HFlowContainer.new()
	line.add_theme_constant_override("h_separation", 4)
	col.add_child(line)
	line.add_child(UiKit.label(L.t("event.bonus.desc", [Events.BONUS_EVERY]), 11, UiKit.INK_SOFT))
	var coins := HBoxContainer.new()
	coins.add_theme_constant_override("separation", 3)
	line.add_child(coins)
	coins.add_child(UiKit.icon("coin", 13))
	coins.add_child(UiKit.label(Fmt.n(Events.bonus_coins(Game.level)), 11))
	if ready > 0:
		var b := UiKit.button(L.t("event.bonus.claim", [ready]), "green", 13, true)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func() -> void: Game.events.claim_event_bonus())
		row.add_child(b)
	return p


# MARK: Анонсы и карточки для других окон

## Анонс следующего ивента (UpcomingEventCard).
static func upcoming_card(run: Dictionary) -> Control:
	var event: String = run["event"]
	var c := _card(Color(Events.COLORS[event][0], 0.18), 3)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_body(c).add_child(row)
	var pic := EventsPanel.map_picture(event, Vector2(62, 76), 10, Color(UiKit.OUTLINE, 0.7), 2)
	pic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(pic)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	row.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	col.add_child(head)
	head.add_child(UiKit.icon(Events.ICON[event], 20))
	head.add_child(UiKit.label(Events.name_of(event), 15))
	col.add_child(HousePanel.wrapped(Events.blurb(event), 11, UiKit.INK_SOFT))
	var when := HBoxContainer.new()
	when.add_theme_constant_override("separation", 4)
	col.add_child(when)
	when.add_child(UiKit.icon("calendar", 13))
	when.add_child(EventsPanel.countdown_label("event.startsIn", float(run["start"]), 11, UiKit.INK_SOFT))
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 4)
	row.add_child(side)
	side.add_child(HousePanel.sprite_rect(Events.PREVIEW[event], 1.4, Vector2(40, 36)))
	var skin := EventsPanel.skin_icon(Events.skin_of(event), 34)
	skin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	side.add_child(skin)
	return c


## Ивент на карте мира (EventMapCard): таймер, окно пропуска и быстрый переход.
## on_travel вызывается после перехода (закрыть окно карты).
static func map_card(on_travel: Callable) -> Control:
	var run := Events.current()
	var event: String = run["event"]
	var outer := MarginContainer.new()
	outer.add_theme_constant_override("margin_top", 14)
	var p := PanelContainer.new()
	var s := UiKit.box(UiKit.PARCHMENT_LIGHT, UiKit.TONES["orange"][1], 18, 4)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 26
	s.content_margin_bottom = 14
	p.add_theme_stylebox_override("panel", s)
	outer.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	# Лента с заголовком над верхним краем карточки
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(holder)
	var ribbon := LevelUpOverlay.Ribbon.new()
	ribbon.label.label_settings.font_size = 17
	ribbon.anchor_left = 0.5
	ribbon.anchor_right = 0.5
	ribbon.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ribbon.offset_top = -41
	ribbon.set_text(L.t("event.title"))
	holder.add_child(ribbon)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	row.add_child(HousePanel.sprite_rect(Events.PREVIEW[event], 1.6, Vector2(44, 44)))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 3)
	row.add_child(col)
	col.add_child(UiKit.label(Events.name_of(event), 14))
	col.add_child(EventsPanel.countdown_label("event.left", float(run["end"]), 11, UiKit.INK_SOFT))
	if Game.events.events_open():
		var buttons := HBoxContainer.new()
		buttons.add_theme_constant_override("separation", 8)
		v.add_child(buttons)
		var pass_b := UiKit.button(L.t("event.pass"), "wood")
		pass_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pass_b.pressed.connect(func() -> void: EventsPanel.open())
		buttons.add_child(pass_b)
		if Game.current != Events.location(event):
			var go := UiKit.button(L.t("event.go"), "green")
			go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			go.disabled = Game.save.get("expedition") != null
			go.pressed.connect(func() -> void:
				Game.events.go_to_event()
				on_travel.call())
			buttons.add_child(go)
	else:
		var locked := HBoxContainer.new()
		locked.add_theme_constant_override("separation", 6)
		v.add_child(locked)
		locked.add_child(UiKit.icon("key", 14))
		locked.add_child(UiKit.label(L.t("event.locked", [Events.MIN_LEVEL]), 12, UiKit.INK_SOFT))
	return outer


## Ивенты в календаре (EventSchedule): что идёт сейчас и что будет дальше.
static func schedule(on_open: Callable) -> Control:
	var run := Events.current()
	var event: String = run["event"]
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	var c := _card(Events.COLORS[event][0], 3)
	list.add_child(c)
	var v := _body(c)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	row.add_child(UiKit.icon(Events.ICON[event], 34))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	col.add_child(UiKit.label(L.t("calendar.eventNow"), 11, UiKit.INK_SOFT))
	col.add_child(UiKit.label(Events.name_of(event), 16))
	var ends := HBoxContainer.new()
	ends.add_theme_constant_override("separation", 4)
	col.add_child(ends)
	ends.add_child(UiKit.icon("stopwatch", 12))
	ends.add_child(EventsPanel.countdown_label("shop.endsIn", float(run["end"]), 11, UiKit.INK_SOFT))
	if Game.events.events_open():
		var b := UiKit.button(L.t("calendar.openEvent"), "orange", 15, true)
		b.pressed.connect(on_open)
		v.add_child(b)
	else:
		var locked := HBoxContainer.new()
		locked.add_theme_constant_override("separation", 6)
		v.add_child(locked)
		locked.add_child(UiKit.icon("key", 14))
		locked.add_child(UiKit.label(L.t("common.needLevel", [Events.MIN_LEVEL]), 12, UiKit.TONES["orange"][2]))
	list.add_child(EventsPanel.section(L.t("calendar.eventsNext")))
	for r in Events.upcoming(4):
		list.add_child(EventsPanel.upcoming_card(r))
	return list


## Открыть окно ивентов в шапке.
static func open() -> void:
	if Hud.current != null:
		Hud.current.open_window(EventsPanel.new())


# MARK: Выбор усиления

## После этапа: выбор одного из трёх усилений до конца ивента (EventBoonPicker).
## Показывает EventFeature через Hud.show_overlay; убирает себя, когда выбор сделан или герой ушёл с карты.
class BoonPicker extends Control:
	var _choice: Array = []

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		_choice = Game.save.get("eventChoice", []).duplicate()
		var dim := ColorRect.new()
		dim.color = UiKit.DIM
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(dim)
		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(center)
		var panel := PanelContainer.new()
		var style := UiKit.panel_style(22)
		style.set_content_margin_all(16)
		panel.add_theme_stylebox_override("panel", style)
		panel.custom_minimum_size = Vector2(minf(380.0, get_viewport_rect().size.x - 40.0), 0)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		center.add_child(panel)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 12)
		panel.add_child(col)
		# Лента с заголовком над верхним краем панели
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(holder)
		var ribbon := LevelUpOverlay.Ribbon.new()
		ribbon.tone = UiKit.TONES["gold"]
		ribbon.label.label_settings.font_size = 18
		ribbon.label.label_settings.outline_color = ribbon.tone[2]
		ribbon.anchor_left = 0.5
		ribbon.anchor_right = 0.5
		ribbon.grow_horizontal = Control.GROW_DIRECTION_BOTH
		ribbon.offset_top = -36
		ribbon.set_text(L.t("boon.title", [Game.events.event_stage()]))
		holder.add_child(ribbon)
		var sub := HousePanel.wrapped(L.t("boon.subtitle"), 13, UiKit.INK_SOFT)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var top := MarginContainer.new()
		top.add_theme_constant_override("margin_top", 18)
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(sub)
		col.add_child(top)
		for boon in _choice:
			col.add_child(_option(str(boon)))
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.2)

	func _process(_delta: float) -> void:
		if not Game.events.in_event() or Game.save.get("eventChoice", []) != _choice:
			queue_free()

	func _option(boon: String) -> Control:
		var rank := Game.events.boon_rank(boon)
		var b := Button.new()
		var s := UiKit.box(UiKit.PARCHMENT_LIGHT, UiKit.GOLD_DARK, 14, 2, false)
		s.set_content_margin_all(10)
		s.shadow_color = Color(UiKit.WOOD_DARK, 0.3)
		s.shadow_offset = Vector2(0, 3)
		s.shadow_size = 1
		var pressed := s.duplicate() as StyleBoxFlat
		pressed.bg_color = UiKit.PARCHMENT
		b.add_theme_stylebox_override("normal", s)
		b.add_theme_stylebox_override("hover", s)
		b.add_theme_stylebox_override("pressed", pressed)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.focus_mode = Control.FOCUS_NONE
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 10
		row.offset_right = -10
		b.add_child(row)
		var circle := PanelContainer.new()
		var cs := UiKit.box(Color("fff3d0"), UiKit.OUTLINE, 25, 2, false)
		cs.set_content_margin_all(0)
		circle.add_theme_stylebox_override("panel", cs)
		circle.custom_minimum_size = Vector2(50, 50)
		circle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic := UiKit.icon(Events.boon_icon(boon), 34)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		circle.add_child(ic)
		row.add_child(circle)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		col.add_theme_constant_override("separation", 3)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(col)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 6)
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(head)
		head.add_child(UiKit.label(Events.boon_name(boon), 15))
		var r := UiKit.label(L.t("boon.rank", [rank + 1, Events.BOON_MAX_RANK]), 11, UiKit.INK_SOFT)
		r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(r)
		col.add_child(HousePanel.wrapped(Events.boon_text(boon, rank + 1), 12, UiKit.INK))
		b.custom_minimum_size = Vector2(0, 74)
		b.pressed.connect(func() -> void: Game.events.choose_boon(boon))
		return b
