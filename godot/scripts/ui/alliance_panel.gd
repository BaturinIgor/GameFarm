class_name AlliancePanel
extends Sheet
## Окно альянса (шаг 1): без альянса - поиск и создание, в альянсе - вкладки «Альянс» (уровень и таланты),
## «Чат», «Участники» и «Рейтинг». Данные - Game.alliance, правила - Alliances, сервер - docs/supabase/alliances.sql.
## Поля ввода живут всё время окна и не пересоздаются при перерисовке, иначе текст и фокус терялись бы.

var tab := "main"
## Каким способом вкладывать в таланты: free, coins, gems.
var give_kind := "free"
## Какой рейтинг открыт: week - альянсы за неделю, strength - альянсы по силе, players - игроки по мощи.
var top_kind := "week"
## Создание альянса: выбранная эмблема.
var emblem := 0

var _search := LineEdit.new()
var _name := LineEdit.new()
var _tag := LineEdit.new()
var _about := LineEdit.new()
var _chat := LineEdit.new()
var _chat_row := HBoxContainer.new()
var _poll: Timer
var _seen_msgs := 0
## Форма создания: превью, подсказка и кнопки обновляются на лету.
var _preview: Label
var _hint: Label
var _create_buttons: Array = []


func _init(start_tab := "") -> void:
	title_key = "alliance.title"
	if start_tab != "":
		tab = start_tab
	# "players" и "strength" - вкладка рейтинга с нужным списком
	if start_tab in ["players", "strength"]:
		tab = "top"
		top_kind = start_tab
	_search.placeholder_text = L.t("alliance.searchHint")
	_search.max_length = 20
	_search.text_submitted.connect(func(t: String) -> void: Game.alliance.search(t))
	_name.placeholder_text = L.t("alliance.field.nameExample")
	_name.max_length = 20
	_tag.placeholder_text = "GV"
	_tag.max_length = 4
	_about.placeholder_text = L.t("alliance.aboutHint")
	_about.max_length = 120
	_chat.placeholder_text = L.t("alliance.chatHint")
	_chat.max_length = Alliances.MSG_LEN
	_chat.text_submitted.connect(func(_t: String) -> void: _send())
	_tag.text_changed.connect(_on_tag_typed)
	_name.text_changed.connect(func(_t: String) -> void: _update_create())
	_chat_row.add_theme_constant_override("separation", 6)
	_chat_row.add_child(UiKit.input(_chat, "scroll"))
	var send := UiKit.button(L.t("alliance.send"), "green", 13, true)
	send.pressed.connect(_send)
	_chat_row.add_child(send)


## Открыть там, где горит отметка: удары и награды событий.
func focus_attention() -> void:
	if Game.alliance.in_alliance() and Game.alliance.events_count() > 0:
		tab = "events"


func _ready() -> void:
	super._ready()
	Game.alliance.mark_seen()
	_poll = Timer.new()
	_poll.wait_time = Alliances.CHAT_POLL
	_poll.autostart = true
	_poll.timeout.connect(func() -> void:
		if tab == "chat":
			Game.alliance.poll_chat())
	add_child(_poll)
	await Game.alliance.refresh(true)
	if Game.alliance.in_alliance():
		Game.alliance.poll_chat()
	else:
		Game.alliance.search("")
	Game.alliance.fetch_top()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for e in [_search, _name, _tag, _about, _chat_row]:
			if is_instance_valid(e) and e.get_parent() == null:
				e.free()


## Поля ввода переживают перерисовку: снимаем их до очистки окна.
func _refresh() -> void:
	if _dirty and is_inside_tree():
		for e in [_search, _name, _tag, _about, _chat_row]:
			if e.get_parent() != null:
				e.get_parent().remove_child(e)
	super._refresh()


func build_top() -> void:
	if not Game.alliance.open() or not Game.alliance.loaded:
		return
	var items: Array
	if Game.alliance.in_alliance():
		if not tab in ["main", "events", "chat", "members", "top"]:
			tab = "main"
		items = [["main", L.t("alliance.tab.main"), 0, "crown"],
			["events", L.t("alliance.tab.events"), Game.alliance.events_count(), "swords"],
			["chat", L.t("alliance.tab.chat"), 0, "scroll"],
			["members", L.t("alliance.tab.members"), 0, "paw"], ["top", L.t("alliance.tab.top"), 0, "trophy"]]
	else:
		if not tab in ["find", "create", "top"]:
			tab = "find"
		items = [["find", L.t("alliance.tab.find"), 0, "compass"], ["top", L.t("alliance.tab.top"), 0, "trophy"]]
	top_bar.add_child(UiKit.tabs(items, "find" if tab == "create" else tab, func(id: String) -> void:
		tab = id
		if id == "chat":
			Game.alliance.poll_chat()
		elif id == "events":
			Game.alliance.refresh_events()
		elif id == "top":
			_fetch_top()
		scroll_to_top()))


func build() -> void:
	var al := Game.alliance
	if not al.available():
		content.add_child(_note(L.t("alliance.offline")))
		return
	if Game.level < Alliances.JOIN_LEVEL:
		content.add_child(_note(L.t("alliance.locked", [Alliances.JOIN_LEVEL])))
		_about_card()
		return
	if not al.loaded:
		content.add_child(_note(L.t("alliance.err.network") if al.error == "network" else L.t("alliance.loading")))
		return
	if al.error != "":
		var e := _note(L.t("alliance.err." + al.error.replace(" ", "_")))
		e.modulate = Color(1, 0.85, 0.8)
		content.add_child(e)
	match tab:
		"main": _main()
		"events": _events()
		"chat": _chat_tab()
		"members": _members()
		"top": _top()
		"create": _create()
		_: _find()


# MARK: Без альянса

func _find() -> void:
	var c := card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	c.add_child(row)
	row.add_child(UiKit.input(_search, "compass"))
	var go := UiKit.button(L.t("alliance.search"), "wood", 13, true)
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(func() -> void: Game.alliance.search(_search.text))
	row.add_child(go)
	var make := UiKit.button(L.t("alliance.create"), "orange", 14)
	make.disabled = Game.level < Alliances.CREATE_LEVEL
	make.pressed.connect(func() -> void:
		tab = "create"
		_dirty = true)
	c.add_child(make)
	if Game.level < Alliances.CREATE_LEVEL:
		c.add_child(_small(L.t("alliance.createLevel", [Alliances.CREATE_LEVEL])))
	if Game.alliance.found.is_empty():
		content.add_child(_note(L.t("alliance.noneFound")))
	for a in Game.alliance.found:
		_alliance_row(a)
	_about_card()


func _alliance_row(a: Dictionary) -> void:
	var v := card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	row.add_child(_emblem(int(a.get("emblem", 0)), 40))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 1)
	row.add_child(col)
	col.add_child(UiKit.label("[%s] %s" % [a.get("tag", ""), a.get("name", "")], 15))
	col.add_child(_small(L.t("alliance.rowInfo", [int(a.get("level", 1)), int(a.get("members", 0)), int(a.get("cap", 25)),
		int(a.get("min_level", Alliances.JOIN_LEVEL))])))
	if str(a.get("about", "")) != "":
		var about := _small(str(a["about"]))
		col.add_child(about)
	var full := int(a.get("members", 0)) >= int(a.get("cap", 25))
	var low := Game.level < int(a.get("min_level", Alliances.JOIN_LEVEL))
	var join := UiKit.button(L.t("alliance.join"), "green", 13, true)
	join.disabled = full or low or Game.alliance.busy
	join.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var id := int(a.get("id", 0))
	join.pressed.connect(func() -> void: Game.alliance.join(id))
	row.add_child(join)


func _create() -> void:
	_create_buttons.clear()
	var c := card()
	c.add_child(UiKit.label(L.t("alliance.create"), 16))
	# Как альянс будет выглядеть в списках: эмблема, тег и название
	var prev := PanelContainer.new()
	prev.add_theme_stylebox_override("panel", UiKit.box(Color("f6e7b0"), Color(UiKit.WOOD_DARK, 0.4), 12, 2, false))
	c.add_child(prev)
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 10)
	prev.add_child(prow)
	prow.add_child(_emblem(emblem, 44))
	_preview = UiKit.label("", 16)
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview.clip_text = true
	_preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prow.add_child(_preview)
	var names := HBoxContainer.new()
	names.add_theme_constant_override("separation", 8)
	c.add_child(names)
	names.add_child(UiKit.input(_name, "crown", L.t("alliance.field.name")))
	var tag_box := UiKit.input(_tag, "", L.t("alliance.field.tag"))
	tag_box.size_flags_horizontal = Control.SIZE_FILL
	tag_box.custom_minimum_size.x = 104
	names.add_child(tag_box)
	c.add_child(_small(L.t("alliance.tagHint")))
	c.add_child(UiKit.input(_about, "scroll", L.t("alliance.field.about")))
	_hint = _small("")
	_hint.add_theme_color_override("font_color", UiKit.BAD)
	c.add_child(_hint)
	c.add_child(_small(L.t("alliance.emblem")))
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	c.add_child(grid)
	for i in Alliances.EMBLEMS.size():
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(36, 36)
		var e := _emblem(i, 34)
		e.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i != emblem:
			e.modulate = Color(1, 1, 1, 0.45)
		b.add_child(e)
		var idx := i
		b.pressed.connect(func() -> void:
			emblem = idx
			_dirty = true)
		grid.add_child(b)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	c.add_child(row)
	for with_coins in [false, true]:
		var price := Fmt.n(Alliances.CREATE_COINS) if with_coins else Fmt.n(Alliances.CREATE_CRYSTALS)
		var b := UiKit.button(price, "green" if with_coins else "purple", 14)
		b.icon = UiKit.icon("coin" if with_coins else "gem", 18).texture
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = not Game.alliance.can_create(with_coins) or Game.alliance.busy
		b.set_meta("can", not b.disabled)
		_create_buttons.append(b)
		var wc: bool = with_coins
		b.pressed.connect(func() -> void:
			Game.alliance.create(_name.text, _tag.text, emblem, _about.text, wc))
		row.add_child(b)
	c.add_child(_small(L.t("alliance.createRules")))
	_update_create()
	var back := UiKit.button(L.t("alliance.back"), "wood", 13, true)
	back.pressed.connect(func() -> void:
		tab = "find"
		_dirty = true)
	content.add_child(back)


## Тег: только латинские буквы и цифры, сразу заглавными (как проверяет сервер).
func _on_tag_typed(t: String) -> void:
	var clean := ""
	for ch in t.to_upper():
		if (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9"):
			clean += ch
	if clean != t:
		var caret := _tag.caret_column
		_tag.text = clean
		_tag.caret_column = mini(caret, clean.length())
	_update_create()


## Проверка формы на лету: превью, подсказка, кнопки создания. Без перестройки окна (иначе пропадёт клавиатура).
func _update_create() -> void:
	var name_ok := _name.text.strip_edges().length() >= 3
	var tag_ok := _tag.text.length() >= 2
	if is_instance_valid(_preview):
		var tag := _tag.text if _tag.text != "" else "TAG"
		var nm := _name.text.strip_edges() if _name.text.strip_edges() != "" else L.t("alliance.field.name")
		_preview.text = "[%s] %s" % [tag, nm]
		_preview.modulate = Color.WHITE if name_ok and tag_ok else Color(1, 1, 1, 0.55)
	UiKit.input_bad(_name, _name.text != "" and not name_ok)
	UiKit.input_bad(_tag, _tag.text != "" and not tag_ok)
	if is_instance_valid(_hint):
		var msg := ""
		if _name.text != "" and not name_ok:
			msg = L.t("alliance.field.nameShort")
		elif _tag.text != "" and not tag_ok:
			msg = L.t("alliance.field.tagShort")
		_hint.text = msg
		_hint.visible = msg != ""
	for b in _create_buttons:
		if is_instance_valid(b):
			b.disabled = not (bool(b.get_meta("can", false)) and name_ok and tag_ok)


## Что такое альянс (для тех, кто ещё не вступил).
func _about_card() -> void:
	var c := card(Color(UiKit.PARCHMENT_LIGHT, 0.7))
	c.add_child(UiKit.label(L.t("alliance.whatTitle"), 14))
	for k in ["alliance.what1", "alliance.what2", "alliance.what3", "alliance.what4"]:
		c.add_child(_small(L.t(k)))


# MARK: В альянсе

func _main() -> void:
	var al := Game.alliance
	var d := al.data
	var c := card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	c.add_child(row)
	row.add_child(_emblem(int(d.get("emblem", 0)), 56))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	col.add_child(UiKit.label("[%s] %s" % [d.get("tag", ""), d.get("name", "")], 17))
	var lvl := al.level()
	var members: Array = d.get("members", [])
	col.add_child(_small(L.t("alliance.levelInfo", [lvl, members.size(), int(d.get("cap", Alliances.cap_of(d.get("talents", {}))))])))
	if not al.powers.is_empty():
		var srow := HBoxContainer.new()
		srow.add_theme_constant_override("separation", 4)
		srow.add_child(UiKit.icon("fist", 14))
		srow.add_child(UiKit.label(L.t("alliance.strength", [Fmt.n(al.strength())]), 12, UiKit.INK_SOFT))
		col.add_child(srow)
	var xp := int(d.get("xp", 0))
	if lvl < Alliances.MAX_LEVEL:
		var from := Alliances.xp_for(lvl)
		var to := Alliances.xp_for(lvl + 1)
		col.add_child(UiKit.bar(float(xp - from) / float(maxi(1, to - from)), "gold", 200, 12,
			"%s / %s" % [Fmt.n(xp - from), Fmt.n(to - from)]))
	if str(d.get("about", "")) != "":
		c.add_child(_small(str(d["about"])))
	# Как вкладывать: бесплатно, за монеты, за кристаллы
	section_title(L.t("alliance.talents"))
	var kinds := card()
	kinds.add_child(_small(L.t("alliance.giveHint")))
	var krow := HBoxContainer.new()
	krow.add_theme_constant_override("separation", 6)
	kinds.add_child(krow)
	for k in ["free", "coins", "gems"]:
		var cost := al.contribute_cost(k)
		var caption: String
		match k:
			"free": caption = L.t("alliance.give.free", [Alliances.FREE_PER_DAY - al.day_used("free"), Alliances.FREE_PER_DAY])
			"coins": caption = L.t("alliance.give.coins", [Alliances.COINS_PER_DAY - al.day_used("coins"), Alliances.COINS_PER_DAY])
			_: caption = L.t("alliance.give.gems")
		var b := UiKit.button(caption, "wood" if k != give_kind else "green", 12, true)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if cost.has("coins"):
			b.icon = UiKit.icon("coin", 14).texture
			b.text += " " + Fmt.n(int(cost["coins"]))
		elif cost.has("crystals"):
			b.icon = UiKit.icon("gem", 14).texture
			b.text += " " + Fmt.n(int(cost["crystals"]))
		var kk: String = k
		b.pressed.connect(func() -> void:
			give_kind = kk
			_dirty = true)
		krow.add_child(b)
	# 4 ряда: открытые - по таланту на строку, закрытый ряд - одна карточка со значками
	for i in Alliances.ROWS.size():
		var need: int = Alliances.ROWS[i]
		content.add_child(UiKit.label(L.t("alliance.talentRow", [i + 1, need]), 14, UiKit.INK_SOFT))
		if al.level() >= need:
			for id in Alliances.row(need):
				_talent_row(id)
		else:
			_locked_row(need)
	var leave := UiKit.button(L.t("alliance.leave"), "red", 13, true)
	leave.pressed.connect(func() -> void:
		ConfirmPopup.ask("px:crown", L.t("alliance.leave"), L.t("alliance.leaveText"), L.t("alliance.leave"), "red",
			func() -> void: Game.alliance.leave()))
	content.add_child(leave)


func _locked_row(need: int) -> void:
	var v := card()
	var icons := HFlowContainer.new()
	icons.add_theme_constant_override("h_separation", 10)
	v.add_child(icons)
	for id in Alliances.row(need):
		var ic := UiKit.icon(str(Alliances.TALENTS[id]["icon"]), 28)
		ic.modulate = Color(1, 1, 1, 0.4)
		icons.add_child(ic)
	var names: Array = Alliances.row(need).map(func(id: String) -> String: return Alliances.talent_name(id))
	v.add_child(_small(", ".join(names)))
	v.add_child(_small(L.t("alliance.talentLocked", [need])))


func _talent_row(id: String) -> void:
	var al := Game.alliance
	var points := int(al.data.get("talents", {}).get(id, 0))
	var rank := Alliances.rank_of(id, points)
	var need_level := Alliances.talent_level(id)
	var open := al.level() >= need_level
	var v := card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var ic := UiKit.icon(str(Alliances.TALENTS[id]["icon"]), 30)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not open:
		ic.modulate = Color(1, 1, 1, 0.4)
	row.add_child(ic)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	col.add_child(UiKit.label("%s  %d/%d" % [Alliances.talent_name(id), rank, Alliances.MAX_RANK], 14))
	col.add_child(_small(Alliances.talent_text(id, maxi(1, rank))))
	if not open:
		col.add_child(_small(L.t("alliance.talentLocked", [need_level])))
		return
	if rank < Alliances.MAX_RANK:
		var from := Alliances.points_for(id, rank)
		var to := Alliances.points_for(id, rank + 1)
		col.add_child(UiKit.bar(float(points - from) / float(maxi(1, to - from)), "green", 180, 10,
			"%s / %s" % [Fmt.n(points - from), Fmt.n(to - from)]))
		var plus := UiKit.button("+1", "green", 15, true)
		plus.custom_minimum_size = Vector2(52, 40)
		plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		plus.disabled = not al.can_contribute(id, give_kind) or al.busy
		plus.pressed.connect(func() -> void: Game.alliance.contribute(id, give_kind))
		row.add_child(plus)


func _chat_tab() -> void:
	content.add_child(_small(L.t("alliance.chatRules")))
	var msgs: Array = Game.alliance.messages
	if msgs.is_empty():
		content.add_child(_note(L.t("alliance.chatEmpty")))
	for m in msgs:
		content.add_child(_message(m))
	content.add_child(_chat_row)
	# Новые сообщения - прокрутить вниз
	if msgs.size() != _seen_msgs:
		_seen_msgs = msgs.size()
		_scroll.set_deferred("scroll_vertical", 1 << 20)


func _message(m: Dictionary) -> Control:
	var kind := str(m.get("kind", "text"))
	if kind != "text":
		var s := _small(AllianceSystem.system_text(m))
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return s
	var mine := bool(m.get("me", false))
	var p := PanelContainer.new()
	var tint := Color("e6f4d2") if mine else UiKit.PARCHMENT_LIGHT
	p.add_theme_stylebox_override("panel", UiKit.box(tint, Color(UiKit.WOOD_DARK, 0.35), 10, 1, false))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	p.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var who := UiKit.label(str(m.get("name", "")), 12, UiKit.INK_SOFT)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(who)
	var when := Time.get_datetime_string_from_unix_time(int(m.get("at", 0)) + int(Time.get_time_zone_from_system().get("bias", 0)) * 60, true)
	head.add_child(UiKit.label(when.substr(11, 5), 11, UiKit.INK_SOFT))
	if not mine:
		var more := UiKit.button("...", "wood", 11, true)
		more.custom_minimum_size = Vector2(30, 22)
		var mid := int(m.get("id", 0))
		var uid := str(m.get("user_id", ""))
		more.pressed.connect(func() -> void:
			ConfirmPopup.ask("px:scroll", str(m.get("name", "")), L.t("alliance.moderate"), L.t("alliance.report"), "orange",
				func() -> void: Game.alliance.report(mid, "chat"),
				L.t("alliance.block"), func() -> void: Game.alliance.block(uid)))
		head.add_child(more)
	var body := UiKit.label(str(m.get("body", "")), 14)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(body)
	return p


func _send() -> void:
	var t := _chat.text
	if t.strip_edges() == "":
		return
	_chat.text = ""
	if not await Game.alliance.say(t):
		_chat.text = t


func _members() -> void:
	var al := Game.alliance
	var me_role := al.role()
	for x in al.data.get("members", []):
		var m: Dictionary = x
		var v := card()
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		v.add_child(row)
		var r := str(m.get("role", "member"))
		var ic := UiKit.icon("crown" if r == "leader" else ("star" if r == "officer" else "paw"), 22)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 1)
		row.add_child(col)
		col.add_child(UiKit.label(str(m.get("name", "")) + ("  (" + L.t("alliance.you") + ")" if bool(m.get("me", false)) else ""), 14))
		col.add_child(_small(L.t("alliance.memberInfo", [L.t("alliance.role." + r), int(m.get("level", 1)),
			Fmt.n(int(m.get("week", 0))), Fmt.n(int(m.get("total", 0)))])))
		var mid := str(m.get("id", ""))
		var pw := Power.total() if bool(m.get("me", false)) else int(al.powers.get(mid, -1))
		if pw >= 0:
			var prow := HBoxContainer.new()
			prow.add_theme_constant_override("separation", 4)
			prow.add_child(UiKit.icon("fist", 14))
			prow.add_child(UiKit.label(L.t("power.value", [Fmt.n(pw)]), 12, UiKit.INK_SOFT))
			col.add_child(prow)
		if bool(m.get("me", false)):
			continue
		var can_manage := me_role == "leader" or (me_role == "officer" and r == "member")
		if can_manage:
			var more := UiKit.button("...", "wood", 13, true)
			more.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var uid := str(m.get("id", ""))
			var name := str(m.get("name", ""))
			more.pressed.connect(func() -> void: _manage(uid, name, r))
			row.add_child(more)


## Что сделать с участником: глава повышает и передаёт главенство, глава и заместитель исключают.
func _manage(uid: String, name: String, r: String) -> void:
	if Game.alliance.is_leader():
		var promote := "officer" if r == "member" else "member"
		ConfirmPopup.ask("px:crown", name, L.t("alliance.manageText"), L.t("alliance.makeRole." + promote), "green",
			func() -> void: Game.alliance.set_role(uid, promote),
			L.t("alliance.kick"), func() -> void: Game.alliance.kick(uid))
	else:
		ConfirmPopup.ask("px:crown", name, L.t("alliance.kickText"), L.t("alliance.kick"), "red",
			func() -> void: Game.alliance.kick(uid))


func _fetch_top() -> void:
	match top_kind:
		"strength": Game.alliance.fetch_strength_top()
		"players": Game.alliance.fetch_power_top()
		_: Game.alliance.fetch_top()


func _top() -> void:
	var al := Game.alliance
	var kinds := [["week", L.t("alliance.top.week")], ["strength", L.t("alliance.top.strength")],
		["players", L.t("alliance.top.players")]]
	content.add_child(UiKit.tabs(kinds, top_kind, func(id: String) -> void:
		top_kind = id
		_fetch_top()
		_dirty = true))
	var list: Array
	match top_kind:
		"strength":
			content.add_child(_small(L.t("alliance.top.strengthHint", [Power.ALLIANCE_TOP])))
			list = al.strength_top
		"players":
			content.add_child(_small(L.t("alliance.top.playersHint", [Fmt.n(Power.total())])))
			list = al.power_top
		_:
			content.add_child(_small(L.t("alliance.topHint")))
			list = al.top
	if list.is_empty():
		content.add_child(_note(L.t("alliance.loading")))
	for x in list:
		var a: Dictionary = x
		var p := PanelContainer.new()
		var tint := Color("f6e7b0") if bool(a.get("me", false)) else UiKit.PARCHMENT_LIGHT
		p.add_theme_stylebox_override("panel", UiKit.box(tint, Color(UiKit.WOOD_DARK, 0.35), 10, 1, false))
		content.add_child(p)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		p.add_child(row)
		var place := UiKit.label("#%d" % int(a.get("place", 0)), 14)
		place.custom_minimum_size = Vector2(40, 0)
		row.add_child(place)
		var value := 0
		if top_kind == "players":
			row.add_child(UiKit.icon("fist", 22))
			var tag := str(a.get("tag", "")) if a.get("tag") != null else ""
			var n := UiKit.label(("[%s] " % tag if tag != "" else "") + str(a.get("name", "")), 13)
			n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			n.clip_text = true
			row.add_child(n)
			value = int(a.get("power", 0))
		else:
			row.add_child(_emblem(int(a.get("emblem", 0)), 26))
			var n := UiKit.label("[%s] %s" % [a.get("tag", ""), a.get("name", "")], 13)
			n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			n.clip_text = true
			row.add_child(n)
			value = int(a.get("strength" if top_kind == "strength" else "week_xp", 0))
		row.add_child(UiKit.label(L.t("common.lvl", [int(a.get("level", 1))]), 12, UiKit.INK_SOFT))
		var pts := UiKit.label(Fmt.n(value), 13)
		pts.custom_minimum_size = Vector2(56, 0)
		pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(pts)


# MARK: События альянса

func _events() -> void:
	var al := Game.alliance
	var ev := al.ev
	if ev.is_empty():
		content.add_child(_note(L.t("alliance.loading")))
		return
	var left := float(int(ev.get("ends", 0)) - int(Time.get_unix_time_from_system()))
	content.add_child(_small(L.t("alliance.ev.weekEnds", [EventsPanel.long_countdown(maxf(0.0, left))])))

	# Страж: портрет, здоровье, удары
	var tier := int(ev.get("tier", 1))
	var kind := AllianceEvents.boss_kind(tier)
	section_title(L.t("alliance.ev.boss"))
	var c := card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	c.add_child(row)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiKit.box(Color("3a2a22"), Color(UiKit.WOOD_DARK, 0.8), 12, 2, false))
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.add_child(CombatCards.monster_icon(kind, 64))
	row.add_child(frame)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 3)
	row.add_child(col)
	var bn := UiKit.label(L.t("alliance.ev.bossName", [Monsters.name_of(kind), tier]), 15)
	bn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(bn)
	var hp := int(ev.get("hp", 0))
	var max_hp := maxi(1, int(ev.get("max_hp", 1)))
	col.add_child(UiKit.bar(float(hp) / float(max_hp), "red", 190, 14, "%s / %s" % [Fmt.n(hp), Fmt.n(max_hp)]))
	col.add_child(_small(L.t("alliance.ev.myDamage", [Fmt.n(int(ev.get("damage", 0)))])))
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 6)
	c.add_child(btns)
	if al.hits_left() > 0:
		var hit := UiKit.button(L.t("alliance.ev.hit.free", [al.hits_left(), al.free_hits()]), "green", 14)
		hit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hit.disabled = al.busy
		hit.pressed.connect(func() -> void: Game.alliance.attack(false))
		btns.add_child(hit)
		UiKit.attention(hit)
	else:
		var more := UiKit.button(L.t("alliance.ev.hit.extra", [al.extra_left(), AllianceEvents.EXTRA_HITS]), "orange", 14)
		more.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		more.icon = UiKit.icon("gem", 16).texture
		more.text += " " + str(AllianceEvents.EXTRA_COST)
		more.disabled = not al.can_attack(true)
		more.pressed.connect(func() -> void: Game.alliance.attack(true))
		btns.add_child(more)
	c.add_child(_small(L.t("alliance.ev.bossHint", [al.free_hits(), Alliances.talent_name("guard")])))
	c.add_child(_small(L.t("alliance.ev.powerHint", [Fmt.n(Power.total() / 100)])))
	for t in ev.get("unclaimed", []):
		_claim_row(L.t("alliance.ev.bossReward", [int(t)]), "boss", int(t))

	# Задания недели
	section_title(L.t("alliance.ev.tasks"))
	var tasks: Array = ev.get("tasks", [])
	for i in tasks.size():
		_task_row(tasks[i], i)
	content.add_child(_small(L.t("alliance.ev.tasksHint")))

	# Место за неделю
	section_title(L.t("alliance.ev.place"))
	var pc := card()
	var place: Variant = ev.get("place")
	var now_l := UiKit.label(L.t("alliance.ev.placeNow", [int(place)]) if place != null else L.t("alliance.ev.placeNone"), 13)
	now_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pc.add_child(now_l)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 4)
	pc.add_child(grid)
	var from := 1
	for p in AllianceEvents.PLACES:
		var to := int(p[0])
		var label := ("#%d" % to) if to == from else (("#%d-%d" % [from, to]) if to < 1000000 else L.t("alliance.ev.placeRest", [from]))
		grid.add_child(UiKit.label(label, 12, UiKit.INK_SOFT))
		grid.add_child(_reward_line(AllianceEvents.place_reward(to, Game.level)))
		from = to + 1
	if ev.get("last_place") != null and not bool(ev.get("last_claimed", true)):
		_claim_row(L.t("alliance.ev.placeReward", [int(ev["last_place"])]), "place", 0)


func _task_row(t: Dictionary, i: int) -> void:
	var al := Game.alliance
	var kind := str(t.get("kind", ""))
	var v := card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var ic := UiKit.icon(str(AllianceEvents.KIND_ICON.get(kind, "star")), 30)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	var tn := UiKit.label(AllianceEvents.kind_name(kind), 14)
	tn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(tn)
	var progress := int(t.get("progress", 0))
	var target := maxi(1, int(t.get("target", 1)))
	var done := progress >= target
	col.add_child(UiKit.bar(float(mini(progress, target)) / float(target), "green" if done else "orange", 180, 12,
		"%s / %s" % [Fmt.n(mini(progress, target)), Fmt.n(target)]))
	col.add_child(_small(L.t("alliance.ev.mine", [Fmt.n(int(t.get("mine", 0))),
		Fmt.n(int(ceil(float(t.get("share", 1)) * AllianceEvents.MIN_SHARE)))])))
	if bool(t.get("claimed", false)):
		var got := UiKit.label(L.t("alliance.ev.claimed"), 12, UiKit.INK_SOFT)
		got.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(got)
	elif al.task_ready(t):
		var b := UiKit.button(L.t("alliance.ev.claim"), "green", 13, true)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.disabled = al.busy
		b.pressed.connect(func() -> void: Game.alliance.claim("task", i))
		row.add_child(b)
		UiKit.attention(b)
	else:
		row.add_child(_reward_line(AllianceEvents.task_reward(Game.level), true))


func _claim_row(text: String, what: String, ref: int) -> void:
	var v := card(Color("f6e7b0"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var cl := UiKit.label(text, 13)
	cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(cl)
	col.add_child(_reward_line(Game.alliance.reward_for(what, ref)))
	var b := UiKit.button(L.t("alliance.ev.claim"), "green", 13, true)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.disabled = Game.alliance.busy
	b.pressed.connect(func() -> void: Game.alliance.claim(what, ref))
	row.add_child(b)
	UiKit.attention(b)


## Награда одной строкой: кристаллы, монеты, ключ.
func _reward_line(r: Dictionary, column := false) -> Control:
	var box: BoxContainer = VBoxContainer.new() if column else HBoxContainer.new()
	box.add_theme_constant_override("separation", 4 if not column else 1)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var parts: Array = []
	if int(r.get("crystals", 0)) > 0:
		parts.append([UiKit.icon("gem", 14), Fmt.n(int(r["crystals"]))])
	if int(r.get("coins", 0)) > 0:
		parts.append([UiKit.icon("coin", 14), Fmt.n(int(r["coins"]))])
	if str(r.get("key", "")) != "":
		parts.append([ChestsPanel.key_icon(str(r["key"]), 14), "1"])
	for part in parts:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 2)
		h.add_child(part[0])
		h.add_child(UiKit.label(str(part[1]), 12))
		box.add_child(h)
	return box


# MARK: Мелочи

static func _emblem(i: int, side: float) -> Control:
	var p := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Alliances.emblem_color(i)
	st.set_corner_radius_all(int(side * 0.3))
	st.border_color = Color(UiKit.WOOD_DARK, 0.6)
	st.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", st)
	p.custom_minimum_size = Vector2(side, side)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ic := UiKit.icon(Alliances.emblem_icon(i), side * 0.62)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(ic)
	return p


func _note(text: String) -> Label:
	var l := UiKit.label(text, 13, UiKit.INK_SOFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _small(text: String) -> Label:
	var l := UiKit.label(text, 12, UiKit.INK_SOFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
