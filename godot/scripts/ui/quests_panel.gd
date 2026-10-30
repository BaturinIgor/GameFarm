class_name QuestsPanel
extends Sheet
## Задания и достижения (порт QuestsView). Вкладка охоты появится вместе с боем.

const DONE_FILL := Color("ddefc8")
const OPEN_FILL := Color("fbe3c2")
## Эмодзи в строках, которые рисуем пиксельными иконками.
const EMOJI_ICONS := {"🪙": "coins", "🌟": "stardust", "🎁": "chest_gold"}

static var _gray: Shader

var tab := "quests"


func _init(start_tab := "quests") -> void:
	title_key = "hud.quests"
	tab = start_tab


func build() -> void:
	if tab == "achievements":
		_achievements_list()
	elif tab == "hunts":
		content.add_child(CombatCards.hunts_list())
	elif tab == "story":
		_story_list()
	else:
		_quests_list()


## Вкладки закреплены под шапкой: прокручивается только содержимое.
func build_top() -> void:
	_tabs()


func _tabs() -> void:
	var items := [
		["quests", L.t("hud.quests"), Game.quests.claimable_quests()],
		["hunts", L.t("hunt.tab"), Game.combat.claimable_hunts()],
		["story", L.t("story.tab"), Game.residents.attention_count()],
		["achievements", L.t("quests.achievements"), Game.quests.claimable_achievements()],
	]
	top_bar.add_child(UiKit.tabs(items, tab, func(id: String) -> void:
		tab = id
		scroll_to_top()))


# MARK: Задания

## Цели дня: три задачи за кристаллы.
func _daily_card() -> Control:
	var parts := ShopPanel.shop_card(L.t("daily.title"), "purple")
	var v: VBoxContainer = parts[1]
	var goals := Game.daily.goals()
	for i in goals.size():
		var g: Dictionary = goals[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		v.add_child(row)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 3)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var t := UiKit.label(DailySystem.text(g), 13, UiKit.INK_SOFT if g["claimed"] else UiKit.INK)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(t)
		col.add_child(UiKit.bar(float(g["progress"]) / float(maxi(1, int(g["target"]))), "purple", 150.0, 12.0,
			"%s / %s" % [Fmt.n(int(g["progress"])), Fmt.n(int(g["target"]))]))
		if g["claimed"]:
			var ok := HousePanel.check_mark(22)
			row.add_child(ok)
		else:
			var idx := i
			var b := MapPanel.icon_button([["i", "gem"], ["t", str(g["crystals"])]], "green" if Game.daily.done(g) else "gray", 13)
			b.disabled = not Game.daily.done(g)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			b.pressed.connect(func() -> void: Game.daily.claim(idx))
			row.add_child(b)
	return parts[0]


func _quests_list() -> void:
	content.add_child(_daily_card())
	var list := Game.quests.current_quests()
	content.add_child(UiKit.label(L.t("quests.done", [int(Game.save.get("questsDone", 0))]), 14))
	var claimable := Game.quests.claimable_quests()
	if claimable >= 2:
		content.add_child(_claim_all(claimable, Game.quests.claim_all_quests))
	for q in list:
		_quest_card(q)
	var hint := UiKit.label(L.t("quests.hint"), 12, UiKit.INK_SOFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(hint)


func _quest_card(q: Dictionary) -> void:
	var done := Quests.is_done(q)
	var id: String = q["id"]
	var p := PanelContainer.new()
	var style := UiKit.box(UiKit.PARCHMENT_LIGHT, UiKit.TONES["green"][1] if done else Color(UiKit.WOOD_DARK, 0.45),
		18, 3 if done else 2, false)
	style.set_content_margin_all(14)
	style.shadow_color = Color(UiKit.WOOD_DARK, 0.25)
	style.shadow_offset = Vector2(0, 3)
	style.shadow_size = 1
	p.add_theme_stylebox_override("panel", style)
	content.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	v.add_child(top)
	var frame := PanelContainer.new()
	var fs := UiKit.box(DONE_FILL if done else OPEN_FILL, Color(UiKit.OUTLINE, 0.7), 14, 2, false)
	fs.set_content_margin_all(0)
	frame.add_theme_stylebox_override("panel", fs)
	frame.custom_minimum_size = Vector2(52, 52)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(frame)
	var ic := UiKit.icon_any(Quests.icon(q), 30.0 if q["type"] == "gather" else 28.0)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.add_child(ic)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 3)
	top.add_child(col)
	var t := UiKit.label(Quests.title(q), 16)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(t)
	var tags := HBoxContainer.new()
	tags.add_theme_constant_override("separation", 10)
	col.add_child(tags)
	tags.add_child(_reward_tag("coins", Fmt.n(int(q["coins"])), 15, 13))
	tags.add_child(_reward_tag("book", Fmt.n(int(q["xp"])), 15, 13))

	var bar := UiKit.bar(Quests.fraction(q), "green" if done else "orange", 0.0, 16.0,
		"%s / %s" % [Fmt.n(int(q["progress"])), Fmt.n(int(q["target"]))])
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(bar)

	if done:
		var claim := UiKit.button(L.t("quests.claim"), "green", 15)
		claim.pressed.connect(func() -> void:
			Game.quests.claim_quest(id)
			Input.vibrate_handheld(20))
		v.add_child(claim)
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var cost := Game.quests.reroll_cost()
	var reroll := _icon_button(L.t("quests.reroll", [Fmt.n(cost)]), "wood")
	reroll.disabled = int(Game.save["coins"]) < cost
	reroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reroll.pressed.connect(func() -> void: Game.quests.reroll_quest(id))
	row.add_child(reroll)
	# Бесплатная замена за рекламу; с Pro реклама не нужна
	var free_btn := Ads.reward_button(L.t("quests.rerollFree"), "blue", 13, true)
	free_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	free_btn.pressed.connect(func() -> void:
		Ads.show_rewarded(func() -> void: Game.quests.reroll_quest(id, true)))
	row.add_child(free_btn)


# MARK: Жители

## Истории жителей: глава, задание, кнопка разговора. Кто переедет следующим - внизу.
func _story_list() -> void:
	var rs := Game.residents
	var list := rs.arrived_list()
	for id in list:
		_resident_card(id)
	var next := rs.next_away()
	if next != "":
		_resident_card(next)
	var hint := UiKit.label(L.t("story.hint", [Locations.name_of("meadow")]), 12, UiKit.INK_SOFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(hint)


func _resident_card(id: String) -> void:
	var rs := Game.residents
	var s := rs.state(id)
	var wants := s == "ready" or s == "new"
	var p := PanelContainer.new()
	var style := UiKit.box(UiKit.PARCHMENT_LIGHT if s != "away" else Color(UiKit.PARCHMENT_DEEP, 0.6),
		UiKit.TONES["green"][1] if wants else Color(UiKit.WOOD_DARK, 0.45), 18, 3 if wants else 2, false)
	style.set_content_margin_all(14)
	p.add_theme_stylebox_override("panel", style)
	content.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	v.add_child(top)
	var portrait := TraderPanel.portrait(Residents.sheet(id), 56)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if s == "away":
		portrait.modulate = Color(1, 1, 1, 0.5)
	top.add_child(portrait)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 3)
	top.add_child(col)
	col.add_child(UiKit.label(Residents.name_of(id), 16))
	var total := Residents.chapters(id).size()
	if s != "away":
		col.add_child(UiKit.bar(float(rs.chapter(id)) / float(total), "purple", 150.0, 12.0,
			L.t("story.chapter", [mini(rs.chapter(id) + 1, total), total]) if s != "done" else L.t("story.finished")))
	var status := UiKit.label(ResidentCard.status_text(id), 13, UiKit.INK_SOFT)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(status)
	if s == "active" or s == "ready" or s == "new":
		var task: Dictionary = rs.current(id)["task"]
		if task["type"] == "give":
			v.add_child(UiKit.cost_view({"items": task["items"]}, 13))
		elif s != "new":
			var pr := rs.progress(id)
			var bar := UiKit.bar(float(pr[0]) / float(maxi(1, int(pr[1]))), "green" if s == "ready" else "orange", 0.0, 16.0,
				"%s · %s / %s" % [Residents.task_text(task), Fmt.n(int(pr[0])), Fmt.n(int(pr[1]))])
			bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			v.add_child(bar)
		if s == "new":
			v.add_child(DialogPopup.reward_row(Residents.reward(id, rs.chapter(id))))
	# Дружба: сердечки и подарок
	if s != "away":
		var frow := HBoxContainer.new()
		frow.add_theme_constant_override("separation", 8)
		v.add_child(frow)
		var hs := GiftPopup.hearts(rs.friend_level(id), 16)
		hs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		frow.add_child(hs)
		var gift := UiKit.button(L.t("friend.gift"), "wood", 12, true)
		var rid: String = id
		gift.pressed.connect(func() -> void: GiftPopup.open(rid))
		frow.add_child(gift)
	if wants:
		var b := UiKit.button(L.t("story.talk") if s == "new" else L.t("story.handIn"), "green", 15)
		b.pressed.connect(func() -> void:
			DialogPopup.talk(id)
			Input.vibrate_handheld(20))
		v.add_child(b)


# MARK: Достижения

func _achievements_list() -> void:
	var all := Quests.achievements()
	var to_claim: Array = []
	var open: Array = []
	var done: Array = []
	for a in all:
		if Game.quests.is_claimed(a):
			done.append(a)
		elif Game.quests.can_claim(a):
			to_claim.append(a)
		else:
			open.append(a)
	var head := HBoxContainer.new()
	content.add_child(head)
	var count := UiKit.label(L.t("achievements.count", [done.size(), all.size()]), 14)
	count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(count)
	head.add_child(with_icons(L.t("achievements.points", [int(Game.save.get("bonusTalentPoints", 0))]), 12, UiKit.INK_SOFT))
	if to_claim.size() >= 2:
		content.add_child(_claim_all(to_claim.size(), Game.quests.claim_all_achievements))
	for a in to_claim + open + done:
		_achievement_row(a)


func _achievement_row(a: Dictionary) -> void:
	var target := int(a["target"])
	var progress := Quests.progress(a)
	var claimed := Game.quests.is_claimed(a)
	var can := not claimed and progress >= target
	var p := PanelContainer.new()
	var style := UiKit.box(UiKit.PARCHMENT_LIGHT, UiKit.TONES["orange"][1] if can else Color(UiKit.WOOD_DARK, 0.4),
		16, 3 if can else 2, false)
	style.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", style)
	if claimed:
		p.modulate.a = 0.7
	content.add_child(p)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	p.add_child(row)

	var frame := PanelContainer.new()
	var fs := UiKit.box(Color(UiKit.GOLD, 0.5) if can else Color(UiKit.PARCHMENT_DEEP, 0.7),
		Color(UiKit.OUTLINE, 0.8 if can else 0.3), 12, 2, false)
	fs.set_content_margin_all(0)
	frame.add_theme_stylebox_override("panel", fs)
	frame.custom_minimum_size = Vector2(48, 48)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(frame)
	var ic := UiKit.icon_any("px:" + str(a["icon"]), 30.0)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not (claimed or can):
		ic.material = _gray_material()
	frame.add_child(ic)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	row.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	col.add_child(head)
	var t := UiKit.label(Quests.achievement_title(a), 14)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(t)
	head.add_child(_reward_tag("coins", Fmt.n(int(a["coins"])), 14, 12, UiKit.INK_SOFT))
	if int(a["points"]) > 0:
		head.add_child(_reward_tag("star", "+%d" % int(a["points"]), 14, 12, UiKit.INK_SOFT))
	var detail := UiKit.label(Quests.achievement_detail(a), 12, UiKit.INK_SOFT)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(detail)
	if claimed:
		col.add_child(UiKit.label(L.t("achievements.earned"), 12, UiKit.GOOD))
	elif can:
		var b := UiKit.button(L.t("achievements.claim"), "orange", 13, true)
		b.pressed.connect(func() -> void:
			Game.quests.claim(a)
			Input.vibrate_handheld(20))
		col.add_child(b)
	else:
		var bar := UiKit.bar(minf(1.0, float(progress) / float(maxi(1, target))), "orange", 0.0, 14.0,
			"%s / %s" % [Fmt.n(mini(progress, target)), Fmt.n(target)])
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(bar)


# MARK: Общее

## Кнопка "Забрать всё", когда наград несколько.
func _claim_all(count: int, action: Callable) -> Button:
	var b := UiKit.button(L.t("common.claimAll", [count]), "green", 15)
	b.pressed.connect(func() -> void:
		action.call()
		Input.vibrate_handheld(20))
	return b


## Награда: иконка и число (RewardTag).
func _reward_tag(icon_name: String, text: String, icon_size: float, font_size: int, color := UiKit.INK) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := UiKit.icon(icon_name, icon_size)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	row.add_child(UiKit.label(text, font_size, color))
	return row


## Кнопка, в тексте которой монета: монета рисуется иконкой справа.
func _icon_button(text: String, tone: String) -> Button:
	var has_coin := "🪙" in text
	var b := UiKit.button(text.replace("🪙", "").strip_edges(), tone, 13, true)
	if has_coin:
		_set_icon(b, "coins")
		b.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.clip_text = true
	return b


func _set_icon(b: Button, icon_name: String) -> void:
	b.icon = Sprites.icon(icon_name)
	b.add_theme_constant_override("icon_max_width", 16)
	b.add_theme_constant_override("h_separation", 4)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Текст, в котором эмодзи заменены пиксельными иконками (как Text.withCoins в iOS).
static func with_icons(text: String, font_size: int, color: Color, outline := 0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rest := text
	while true:
		var at := -1
		var found := ""
		for e in EMOJI_ICONS:
			var i := rest.find(e)
			if i >= 0 and (at < 0 or i < at):
				at = i
				found = e
		if at < 0:
			break
		var before := rest.substr(0, at).strip_edges()
		if before != "":
			row.add_child(UiKit.label(before, font_size, color, outline))
		var ic := UiKit.icon(EMOJI_ICONS[found], font_size + 4.0)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)
		rest = rest.substr(at + found.length())
	rest = rest.strip_edges()
	if rest != "":
		row.add_child(UiKit.label(rest, font_size, color, outline))
	return row


## Серая иконка ещё не выполненного достижения.
static func _gray_material() -> ShaderMaterial:
	if _gray == null:
		_gray = Shader.new()
		_gray.code = "shader_type canvas_item;\nvoid fragment() {\n\tfloat g = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));\n\tCOLOR.rgb = mix(COLOR.rgb, vec3(g), 0.8);\n}\n"
	var m := ShaderMaterial.new()
	m.shader = _gray
	return m
