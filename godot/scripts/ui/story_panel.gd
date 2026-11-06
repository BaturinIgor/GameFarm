class_name StoryPanel
extends Sheet
## Сердца земли: сюжет по главам (страницы дневника, дар, слуги Мглы, пробуждение) и Алтарь Древних,
## где осколки поднимают потолки бонусов. Данные - data/story.gd, логика - systems/story_system.gd.

const NIGHT := Color("1b1830")
const NIGHT_EDGE := Color("4a3f7a")
const PAGE_INK := Color("e9e1cf")

const TABS := [["heart", "book", "heart.tab.story"], ["altar", "spark", "heart.tab.altar"]]

var tab := "heart"


func _init(start_tab := "") -> void:
	title_key = "heart.title"
	if start_tab != "":
		tab = start_tab


## Открыть вкладку, где можно что-то сделать.
func focus_attention() -> void:
	if Game.story.ready_count() == 0 and Game.story.can_raise_altar():
		tab = "altar"


func build_top() -> void:
	var items: Array = []
	for t in TABS:
		var n := Game.story.ready_count() if t[0] == "heart" else (1 if Game.story.can_raise_altar() else 0)
		items.append([t[0], L.t(t[2]), n, t[1]])
	top_bar.add_child(UiKit.tabs(items, tab, func(id: String) -> void:
		tab = id
		scroll_to_top()))


func build() -> void:
	content.add_theme_constant_override("separation", 14)
	content.add_child(_header())
	if tab == "altar":
		_build_altar()
	else:
		_build_story()


## Шапка: разбуженные Сердца и осколки.
func _header() -> Control:
	var p := PanelContainer.new()
	var s := UiKit.box(NIGHT, NIGHT_EDGE, 14, 3, false)
	s.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", s)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	row.add_child(UiKit.icon("heart", 24))
	var hearts := UiKit.label(L.t("heart.hearts", [Game.story.hearts(), Story.count()]), 15, Color.WHITE, 3)
	hearts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(hearts)
	row.add_child(UiKit.shard_icon(22))
	row.add_child(UiKit.label(Fmt.n(Game.story.shards()), 15, Story.SHARD_TINT.lightened(0.2), 3))
	var hint := UiKit.label(L.t("heart.hint" if tab == "heart" else "altar.hint"), 12, Color(1, 1, 1, 0.75))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	return p


# MARK: Сюжет

func _build_story() -> void:
	var sys := Game.story
	if sys.finished():
		var v := TraderPanel.card_box(content, UiKit.GOLD_DARK, 3)
		v.add_child(UiKit.label(L.t("heart.done"), 16))
		var t := UiKit.label(L.t("heart.doneText"), 13, UiKit.INK_SOFT)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(t)
	else:
		_chapter_card(sys.chapter())
	# Пройденные главы - короткими строками, новые сверху
	if sys.chapter() > 0:
		section_title(L.t("heart.past"))
		for ch in range(mini(sys.chapter(), Story.count()) - 1, -1, -1):
			_past_row(ch)


func _chapter_card(ch: int) -> void:
	var sys := Game.story
	var loc := Story.loc(ch)
	var open := sys.chapter_open()
	var v := TraderPanel.card_box(content, NIGHT_EDGE if open else Color(UiKit.WOOD_DARK, 0.45), 3 if open else 2)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	head.add_child(UiKit.icon(Locations.icon(loc), 34))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	head.add_child(col)
	col.add_child(UiKit.label(L.t("heart.chapter", [ch + 1, Story.count()]), 12, UiKit.INK_SOFT))
	var title := UiKit.label(Story.title(ch), 17)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(title)
	col.add_child(UiKit.label(Locations.name_of(loc), 12, UiKit.INK_SOFT))
	if not open:
		var t := UiKit.label(L.t("heart.locked", [Locations.name_of(loc)]), 13, UiKit.INK_SOFT)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(t)
		return

	# 1. Страницы дневника
	var pages := sys.pages()
	v.add_child(_step(1, L.t("heart.step.pages", [pages, Story.PAGES]), pages >= Story.PAGES,
		L.t("heart.step.pagesHint", [Locations.name_of(loc)])))
	for i in pages:
		v.add_child(page_view(ch, i))

	# 2. Дар Сердцу
	var given := sys.gift_given()
	v.add_child(_step(2, L.t("heart.step.gift"), given, L.t("heart.step.giftHint")))
	if not given:
		v.add_child(UiKit.cost_view(sys.gift_left()))
		var give := UiKit.button(L.t("heart.give"), "gold", 15)
		give.disabled = not sys.can_give_gift()
		give.pressed.connect(func() -> void: Game.story.give_gift())
		v.add_child(give)
		if sys.can_give_gift():
			UiKit.attention(give)

	# 3. Слуги Мглы
	var need := Story.kills(ch)
	v.add_child(_step(3, L.t("heart.step.kills", [mini(sys.kills(), need), need]), sys.kills() >= need,
		L.t("heart.step.killsHint", [Locations.name_of(loc)])))

	# Награда и пробуждение
	var reward := HFlowContainer.new()
	reward.add_theme_constant_override("h_separation", 6)
	reward.add_theme_constant_override("v_separation", 4)
	reward.add_child(UiKit.label(L.t("heart.reward"), 12, UiKit.INK_SOFT))
	reward.add_child(UiKit.shard_icon(18))
	reward.add_child(UiKit.label("x%d" % Story.shards_for(ch), 13))
	var key := UiKit.icon("key", 18)
	key.modulate = Chests.KEY_TINT.get(Story.key_for(ch), Color.WHITE)
	reward.add_child(key)
	reward.add_child(UiKit.label(Chests.key_name(Story.key_for(ch)), 13))
	reward.add_child(UiKit.icon("spark", 18))
	reward.add_child(UiKit.label("x%d" % Story.sparks_for(ch), 13))
	reward.add_child(UiKit.label(L.t("heart.yield", [int(round(Story.HEART_YIELD * 100.0))]), 13, UiKit.GOOD))
	v.add_child(reward)
	var awaken := UiKit.button(L.t("heart.awaken"), "green", 16)
	awaken.disabled = not sys.can_awaken()
	awaken.pressed.connect(_awaken)
	v.add_child(awaken)
	if sys.can_awaken():
		UiKit.attention(awaken)


## Строка шага: номер или галочка, текст, подсказка мелко.
func _step(n: int, text: String, done: bool, hint: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	if done:
		row.add_child(UiKit.icon("check", 20))
	else:
		var num := UiKit.label(str(n), 14, Color.WHITE, 3)
		num.custom_minimum_size = Vector2(20, 20)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(num)
	var l := UiKit.label(text, 14, UiKit.GOOD if done else UiKit.INK)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(l)
	if hint != "" and not done:
		var h := UiKit.label(hint, 11, UiKit.INK_SOFT)
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(h)
	return v


## Страница дневника: тёмный лист со светлым текстом.
static func page_view(ch: int, i: int) -> Control:
	var p := PanelContainer.new()
	var s := UiKit.box(NIGHT, NIGHT_EDGE, 10, 2, false)
	s.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", s)
	var l := UiKit.label(Story.page_text(ch, i), 12, PAGE_INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(l)
	return p


func _past_row(ch: int) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.box(UiKit.PARCHMENT_LIGHT, Color(UiKit.WOOD_DARK, 0.3), 12, 2, false))
	content.add_child(p)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	p.add_child(row)
	row.add_child(UiKit.icon("heart", 20))
	var l := UiKit.label(L.t("heart.chapterShort", [ch + 1, Story.title(ch)]), 13)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(l)
	row.add_child(UiKit.icon("check", 18))


func _awaken() -> void:
	var ch := Game.story.chapter()
	RewardsPopup.track(func() -> void: Game.story.awaken_heart(), "heart.awakened")
	Game.show_toast("heart", L.t("heart.awakenedToast", [Story.title(ch)]))


# MARK: Алтарь

func _build_altar() -> void:
	var sys := Game.story
	var lvl := sys.altar()
	var caps := Story.altar_caps(lvl)
	var v := TraderPanel.card_box(content, NIGHT_EDGE, 3)
	v.add_child(UiKit.label(L.t("altar.level", [lvl, Story.ALTAR.size()]), 16))
	for k in ["yield", "xp", "animal", "sell"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(UiKit.icon(str(Story.ALTAR_ICON[k]), 18))
		row.add_child(UiKit.label(L.t("altar." + k, [int(round(float(caps[k]) * 100.0))]), 13, UiKit.GOOD if float(caps[k]) > 0.0 else UiKit.INK_SOFT))
		v.add_child(row)
	if lvl < Story.ALTAR.size():
		var price := sys.altar_price()
		var b := UiKit.button(L.t("altar.raise"), "blue", 15)
		b.disabled = not sys.can_raise_altar()
		b.pressed.connect(func() -> void: Game.story.raise_altar())
		v.add_child(AnimalsPanel.shard_line(price))
		v.add_child(b)
		if sys.can_raise_altar():
			UiKit.attention(b)
	else:
		v.add_child(UiKit.label(L.t("altar.max"), 13, UiKit.GOOD))
	section_title(L.t("altar.steps"))
	for i in Story.ALTAR.size():
		_altar_row(i, lvl)
	var where := UiKit.label(L.t("shard.where"), 12, UiKit.INK_SOFT)
	where.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(where)


func _altar_row(i: int, lvl: int) -> void:
	var k := str(Story.ALTAR[i][0])
	var done := i < lvl
	var p := PanelContainer.new()
	var border := UiKit.GOOD if done else (NIGHT_EDGE if i == lvl else Color(UiKit.WOOD_DARK, 0.3))
	p.add_theme_stylebox_override("panel", UiKit.box(UiKit.PARCHMENT_LIGHT, border, 12, 2, false))
	content.add_child(p)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	p.add_child(row)
	row.add_child(UiKit.label(str(i + 1), 13, UiKit.INK_SOFT))
	row.add_child(UiKit.icon(str(Story.ALTAR_ICON[k]), 18))
	var l := UiKit.label(L.t("altar.step." + k, [int(round(float(Story.ALTAR[i][1]) * 100.0))]), 13)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(l)
	if done:
		row.add_child(UiKit.icon("check", 18))
	else:
		row.add_child(UiKit.shard_icon(16))
		row.add_child(UiKit.label(str(Story.ALTAR_COST[i]), 13))
	if i > lvl:
		p.modulate.a = 0.6
