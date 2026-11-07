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
## Вкладка участников: список или летопись со статуями.
var members_kind := "list"
## Подвкладка событий: boss (страж и задания) или war (карта войны).
var events_kind := "boss"
## Призыв погоды: какую и через сколько секунд.
var _wx_kind := "rain"
var _wx_delay := 0
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
	if start_tab == "war":
		tab = "events"
		events_kind = "war"
	if start_tab in ["chronicle", "fair", "village"]:
		tab = "members"
		members_kind = start_tab
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
			["events", L.t("alliance.tab.events"), Game.alliance.events_count() + Game.war.ready_count(), "swords"],
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
			if events_kind == "war":
				Game.war.fetch()
		elif id == "top":
			_fetch_top()
		elif id == "members" and members_kind == "chronicle":
			Game.alliance.fetch_chronicle()
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
	_pet_card()
	_weather_card()
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


## Погода альянса: час дождя (грядки вдвое быстрее) или солнца (добыча и опыт) для всех участников.
func _weather_card() -> void:
	var al := Game.alliance
	var w := al.weather
	section_title(L.t("weather.title"))
	var c := card()
	if w.is_empty():
		c.add_child(_note(L.t("alliance.loading")))
		return
	var t := Clock.now()
	var now_kind := AllianceWeather.active(w, t)
	var status := HBoxContainer.new()
	status.add_theme_constant_override("separation", 8)
	c.add_child(status)
	var kind := str(w.get("kind", ""))
	status.add_child(UiKit.icon(str(AllianceWeather.ICONS.get(kind, "rainbow")) if now_kind != "" or AllianceWeather.pending(w, t) else "rainbow", 28))
	var text: String
	if now_kind != "":
		text = L.t("weather.now." + now_kind, [Fmt.seconds(float(w.get("ends", 0)) - t)])
	elif AllianceWeather.pending(w, t):
		text = L.t("weather.soon." + kind, [Fmt.clock(int(w.get("starts", 0))), str(w.get("caller", ""))])
	else:
		text = L.t("weather.clear")
	var l := UiKit.label(text, 14)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_child(l)
	if now_kind != "" or AllianceWeather.pending(w, t):
		c.add_child(_small(L.t("weather.effect." + kind, [Fmt.pct(AllianceWeather.SUN_YIELD)])))
		return
	var free := al.can_call_weather(false)
	var paid := al.can_call_weather(true)
	if not free and not paid:
		c.add_child(_small(L.t("weather.none")))
		return
	c.add_child(UiKit.tabs([["rain", L.t("weather.rain")], ["sun", L.t("weather.sun")]], _wx_kind, func(id: String) -> void:
		_wx_kind = id
		_dirty = true))
	c.add_child(_small(L.t("weather.effect." + _wx_kind, [Fmt.pct(AllianceWeather.SUN_YIELD)])))
	var delays: Array = []
	for d in AllianceWeather.DELAYS:
		delays.append([str(d), L.t("weather.at.now") if d == 0 else "+" + Fmt.seconds(float(d))])
	c.add_child(UiKit.tabs(delays, str(_wx_delay), func(id: String) -> void:
		_wx_delay = int(id)
		_dirty = true))
	if free:
		var b := UiKit.button(L.t("weather.callFree"), "green", 15)
		b.disabled = al.busy
		b.pressed.connect(func() -> void: al.call_weather(_wx_kind, _wx_delay, false))
		c.add_child(b)
	elif int(w.get("free_left", 0)) > 0:
		c.add_child(_small(L.t("weather.leaderOnly")))
	if paid:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		c.add_child(row)
		var pl := UiKit.label(L.t("weather.callPaid", [int(w.get("paid_left", 0))]), 13)
		pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(pl)
		var pb := ShopPanel.crystal_button(AllianceWeather.PAID_CRYSTALS, "purple", true)
		pb.pressed.connect(func() -> void:
			if Game.shop.crystals() < AllianceWeather.PAID_CRYSTALS:
				Game.show_toast("px:gem", L.t("crystals.notEnough", [Fmt.n(AllianceWeather.PAID_CRYSTALS - Game.shop.crystals())]))
				return
			al.call_weather(_wx_kind, _wx_delay, true))
		row.add_child(pb)


## Хранитель альянса: зверь растёт от угощений, которые приносят все участники.
func _pet_card() -> void:
	var al := Game.alliance
	var pet := al.pet
	section_title(L.t("alliance.pet.title"))
	var c := card()
	if pet.is_empty():
		c.add_child(_note(L.t("alliance.loading")))
		return
	var kind := str(pet.get("kind", "phoenixChick"))
	var stage := int(pet.get("stage", 1))
	var xp := int(pet.get("xp", 0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	c.add_child(row)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", AnimalsPanel.awaken_frame(clampi((stage - 1) / 3 + 1, 1, Animals.AWAKEN_MAX) if stage > 1 else 0))
	frame.custom_minimum_size = Vector2(84, 84)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ic := AnimalsPanel.animal_icon(kind, AlliancePet.size_for(stage))
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.add_child(ic)
	row.add_child(frame)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 3)
	row.add_child(col)
	var name := UiKit.label(L.t("alliance.pet.stage", [Animals.name_of(kind), stage, AlliancePet.MAX_STAGE]), 15)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(name)
	if stage < AlliancePet.MAX_STAGE:
		var from := AlliancePet.xp_for(stage)
		var to := AlliancePet.xp_for(stage + 1)
		col.add_child(UiKit.bar(float(xp - from) / float(maxi(1, to - from)), "gold", 160, 12,
			"%s / %s" % [Fmt.n(xp - from), Fmt.n(to - from)]))
	col.add_child(_small(L.t("alliance.pet.bonus", [Fmt.pct(AlliancePet.bonus(stage)), Fmt.pct(AlliancePet.bonus(stage + 1))])
		if stage < AlliancePet.MAX_STAGE else L.t("alliance.pet.bonusMax", [Fmt.pct(AlliancePet.bonus(stage))])))
	# Глава выбирает вид, пока Хранителя не кормили
	if xp == 0 and al.is_leader():
		c.add_child(_small(L.t("alliance.pet.choose")))
		var kinds := HBoxContainer.new()
		kinds.add_theme_constant_override("separation", 6)
		c.add_child(kinds)
		for k in AlliancePet.KINDS:
			var b := UiKit.button("", "green" if k == kind else "wood", 12, true)
			b.icon = AnimalsPanel.animal_icon(k, 28).texture
			b.expand_icon = true
			b.custom_minimum_size = Vector2(0, 48)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var kk: String = k
			b.pressed.connect(func() -> void: Game.alliance.choose_pet(kk))
			kinds.add_child(b)
	# Угощения дня
	var left := float(int(pet.get("ends", 0)) - int(Time.get_unix_time_from_system()))
	c.add_child(_small(L.t("alliance.pet.hint", [al.pet_fed(), AlliancePet.PORTIONS, EventsPanel.long_countdown(maxf(0.0, left))])))
	var items: Array = pet.get("cravings", [])
	for slot in items.size():
		var cost := al.pet_cost(slot)
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 8)
		c.add_child(r)
		var cv := UiKit.cost_view(cost)
		cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(cv)
		var b := UiKit.button(L.t("alliance.pet.give", [AlliancePet.xp_per_portion(slot)]), "green", 13, true)
		b.disabled = not al.can_feed_pet(slot)
		var sl: int = slot
		b.pressed.connect(func() -> void: Game.alliance.feed_pet(sl))
		r.add_child(b)
	var top: Array = pet.get("top", [])
	if not top.is_empty():
		var names: Array = top.map(func(x: Dictionary) -> String: return "%s %s" % [str(x.get("name", "")), Fmt.n(int(x.get("total", 0)))])
		c.add_child(_small(L.t("alliance.pet.top", [", ".join(names)])))


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
	var kinds := [["list", L.t("alliance.members.list")], ["village", L.t("village.title")], ["fair", L.t("afair.title")],
		["chronicle", L.t("chronicle.title")]]
	content.add_child(UiKit.tabs(kinds, members_kind, func(id: String) -> void:
		members_kind = id
		if id == "chronicle":
			Game.alliance.fetch_chronicle()
		elif id == "fair":
			Game.alliance.fetch_fair()
		elif id == "village":
			Game.alliance.fetch_village()
		_dirty = true))
	if members_kind == "chronicle":
		_chronicle()
		return
	if members_kind == "fair":
		_fair()
		return
	if members_kind == "village":
		_village()
		return
	var al := Game.alliance
	var me_role := al.role()
	_guests_card()
	_mentor_card()
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
		if al.can_pick_mentor(m):
			var pick := UiKit.button(L.t("mentor.pick"), "orange", 12, true)
			pick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var mid_pick := str(m.get("id", ""))
			var mname := str(m.get("name", ""))
			pick.pressed.connect(func() -> void:
				ConfirmPopup.ask("px:star", mname, L.t("mentor.pickText", [mname]), L.t("mentor.pick"), "orange",
					func() -> void: al.pick_mentor(mid_pick)))
			row.add_child(pick)
		var visit := UiKit.button(L.t("guests.send"), "green", 12, true)
		visit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		visit.disabled = al.guests_away().size() >= al.guest_slots()
		var host_id := str(m.get("id", ""))
		var host_name := str(m.get("name", ""))
		visit.pressed.connect(func() -> void: GuestPicker.open(host_id, host_name))
		row.add_child(visit)
		var can_manage := me_role == "leader" or (me_role == "officer" and r == "member")
		if can_manage:
			var more := UiKit.button("...", "wood", 13, true)
			more.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var uid := str(m.get("id", ""))
			var name := str(m.get("name", ""))
			more.pressed.connect(func() -> void: _manage(uid, name, r))
			row.add_child(more)


## Деревня альянса: общие постройки, мой домик с украшениями и домики друзей (полить, подарок).
func _village() -> void:
	var al := Game.alliance
	var v := al.village
	if v.is_empty():
		content.add_child(_note(L.t("alliance.loading")))
		return
	var c := card()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	c.add_child(head)
	head.add_child(UiKit.icon("hammer", 24))
	var hl := UiKit.label(L.t("village.buildings"), 15)
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hl)
	head.add_child(UiKit.label(L.t("village.donatesLeft", [al.donates_left()]), 12, UiKit.INK_SOFT))
	c.add_child(_small(L.t("village.buildHint")))
	var coins := Village.donate_coins(Game.level)
	var bs: Dictionary = v.get("buildings", {}) if v.get("buildings") is Dictionary else {}
	for k in Village.BUILDINGS:
		var b: Dictionary = bs.get(k, {})
		var lvl := int(b.get("level", 0))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		c.add_child(row)
		var ic := UiKit.icon(str(Village.ICONS[k]), 28)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 2)
		row.add_child(col)
		col.add_child(UiKit.label(L.t("village.bLevel", [L.t("village.b." + k), lvl]), 13))
		col.add_child(UiKit.label(L.t("village.bonus." + k, [Fmt.pct(Village.bonus(lvl))]), 11, UiKit.INK_SOFT))
		if lvl < Village.MAX_LEVEL:
			var need := maxi(1, int(b.get("need", Village.need(lvl + 1))))
			var pts := int(b.get("points", 0))
			var bar := UiKit.bar(float(pts) / float(need), "gold", 150.0, 12.0, "%s/%s" % [Fmt.n(pts), Fmt.n(need)])
			bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_child(bar)
			var give := MapPanel.icon_button([["i", "coins"], ["t", Fmt.n(coins)]], "orange", 12)
			give.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			give.disabled = al.donates_left() <= 0 or int(Game.save["coins"]) < coins
			var kind: String = k
			give.pressed.connect(func() -> void: al.donate_building(kind))
			row.add_child(give)
		else:
			row.add_child(UiKit.label(L.t("common.max"), 12, UiKit.GOOD))
	# Мой домик
	var mine := card()
	var mh := HBoxContainer.new()
	mh.add_theme_constant_override("separation", 8)
	mine.add_child(mh)
	mh.add_child(UiKit.icon("door", 24))
	var ml := UiKit.label(L.t("village.myHouse"), 14)
	ml.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mh.add_child(ml)
	var deco := UiKit.button(L.t("village.decorate"), "purple", 12, true)
	deco.pressed.connect(func() -> void: DecoPicker.open())
	mh.add_child(deco)
	mine.add_child(_deco_row(al.shown_decos()))
	mine.add_child(_small(L.t("village.visitHint", [al.waters_left(), Village.WATERS_PER_DAY, Fmt.n(Village.water_coins(Game.level))])))
	# Домики друзей
	for x in v.get("houses", []):
		var h: Dictionary = x
		if bool(h.get("me", false)):
			continue
		var hc := card()
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		hc.add_child(row)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 2)
		row.add_child(col)
		col.add_child(UiKit.label(L.t("village.house", [str(h.get("name", "")), int(h.get("level", 1))]), 13))
		col.add_child(_deco_row(h.get("deco", []) if h.get("deco") is Array else []))
		var hid := str(h.get("id", ""))
		var w := UiKit.button(L.t("village.water"), "blue", 12, true)
		w.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		w.disabled = bool(h.get("watered", false)) or al.waters_left() <= 0
		w.pressed.connect(func() -> void: al.visit(hid, "water"))
		if not w.disabled:
			UiKit.attention(w)
		row.add_child(w)
		if not bool(h.get("gifted", false)):
			var g := ShopPanel.crystal_button(Village.GIFT_CRYSTALS, "purple", true)
			g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			g.pressed.connect(func() -> void: al.visit(hid, "gift"))
			row.add_child(g)
	content.add_child(_note(L.t("village.giftHint")))


func _deco_row(list: Array) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 4)
	row.add_theme_constant_override("v_separation", 2)
	if list.is_empty():
		row.add_child(UiKit.label(L.t("village.noDeco"), 11, UiKit.INK_SOFT))
	for x in list:
		var id := str(x)
		if not Village.valid_deco(id):
			continue
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 2)
		item.add_child(UiKit.icon(str(Village.DECOS[id]["icon"]), 18))
		item.add_child(UiKit.label(L.t("village.deco." + id), 11, UiKit.INK_SOFT))
		row.add_child(item)
	return row


## Ярмарка альянса: мой прилавок, лоты других участников и лучшие продавцы недели.
func _fair() -> void:
	var al := Game.alliance
	var f := al.fair
	if f.is_empty():
		content.add_child(_note(L.t("alliance.loading")))
		return
	var c := card()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	c.add_child(head)
	head.add_child(UiKit.icon("basket", 24))
	var hl := UiKit.label(L.t("afair.title"), 15)
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hl)
	head.add_child(UiKit.label(EventsPanel.long_countdown(DailySystem.week_left()), 12, UiKit.INK_SOFT))
	c.add_child(_small(L.t("afair.hint")))
	if f.get("best") != null:
		c.add_child(UiKit.label(L.t("afair.best", [str(f["best"])]), 13, UiKit.GOLD_DARK))
	for x in f.get("top", []):
		var t: Dictionary = x
		c.add_child(_small(L.t("afair.seller", [str(t.get("name", "")), Fmt.n(int(t.get("coins", 0))), int(t.get("sold", 0))])))
	# Мой прилавок
	var mine := card()
	var on_sale := al.fair_on_sale()
	var mh := HBoxContainer.new()
	mine.add_child(mh)
	var ml := UiKit.label(L.t("afair.mine"), 14)
	ml.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mh.add_child(ml)
	mh.add_child(UiKit.label(L.t("afair.slots", [on_sale.size(), al.fair_slots()]), 12, UiKit.INK_SOFT))
	for x in on_sale:
		var lot: Dictionary = x
		var row := _lot_row(lot, "")
		mine.add_child(row)
		var cancel := UiKit.button(L.t("afair.cancel"), "wood", 12, true)
		cancel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var lid := int(lot.get("id", 0))
		cancel.pressed.connect(func() -> void: al.cancel_lot(lid))
		row.add_child(cancel)
	if al.can_list_lot():
		var put := UiKit.button(L.t("afair.put"), "green", 14)
		put.pressed.connect(func() -> void: FairLotPicker.open())
		mine.add_child(put)
	if al.fair_slots() < AllianceFair.MAX_SLOTS:
		var srow := HBoxContainer.new()
		srow.add_theme_constant_override("separation", 8)
		mine.add_child(srow)
		var sl := _small(L.t("afair.slot2"))
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		srow.add_child(sl)
		var sb := ShopPanel.crystal_button(AllianceFair.SLOT_CRYSTALS, "purple", true)
		sb.pressed.connect(func() -> void:
			if not al.buy_fair_slot():
				Game.show_toast("px:gem", L.t("crystals.notEnough", [Fmt.n(AllianceFair.SLOT_CRYSTALS - Game.shop.crystals())])))
		srow.add_child(sb)
	# Лоты других
	var lots: Array = f.get("lots", [])
	var lc := card()
	lc.add_child(UiKit.label(L.t("afair.lots"), 14))
	if lots.is_empty():
		lc.add_child(_small(L.t("afair.empty")))
	for x in lots:
		var lot: Dictionary = x
		var row := _lot_row(lot, str(lot.get("seller", "")))
		lc.add_child(row)
		var price := int(lot.get("price", 0))
		var b := MapPanel.icon_button([["i", "coins"], ["t", Fmt.n(price)]], "green" if int(Game.save["coins"]) >= price else "gray", 13)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.disabled = int(Game.save["coins"]) < price
		b.pressed.connect(func() -> void: al.buy_lot(lot))
		row.add_child(b)


func _lot_row(lot: Dictionary, seller: String) -> HBoxContainer:
	var kind := str(lot.get("kind", ""))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var ic := UiKit.icon_any("res:" + kind, 30)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	col.add_child(UiKit.label(L.t("afair.lot", [Res.name_of(kind), int(lot.get("qty", 0))]), 13))
	var sub := L.t("afair.from", [seller]) if seller != "" else L.t("afair.price", [Fmt.n(int(lot.get("price", 0)))])
	col.add_child(UiKit.label(sub, 11, UiKit.INK_SOFT))
	return row


## Звери в гости: мои звери у друзей (с подарком по возвращении), гости у меня и дружба.
func _guests_card() -> void:
	var al := Game.alliance
	var g := al.guests
	var c := card()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	c.add_child(head)
	head.add_child(UiKit.icon("paw", 24))
	var t := UiKit.label(L.t("guests.title"), 15)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UiKit.label(L.t("guests.slots", [al.guests_away().size(), al.guest_slots()]), 12, UiKit.INK_SOFT))
	c.add_child(_small(L.t("guests.hint")))
	var now := Clock.now()
	for x in al.guests_away():
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 8)
		c.add_child(r)
		var animal := str(x.get("animal", ""))
		r.add_child(AnimalsPanel.animal_icon(animal, 28))
		var left := float(x.get("returns", 0)) - now
		var l := UiKit.label(L.t("guests.away", [Animals.name_of(animal), str(x.get("name", "")), Fmt.seconds(left)]) if left > 0
			else L.t("guests.ready", [Animals.name_of(animal), str(x.get("name", ""))]), 12)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(l)
		if left <= 0:
			var b := UiKit.button(L.t("guests.claim"), "gold", 12, true)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var id := int(x.get("id", 0))
			b.pressed.connect(func() -> void: al.claim_guest(id))
			r.add_child(b)
	var hosted: Array = g.get("in", []).filter(func(x: Dictionary) -> bool: return float(x.get("returns", 0)) > now)
	if hosted.is_empty():
		c.add_child(_small(L.t("guests.none")))
	else:
		c.add_child(UiKit.label(L.t("guests.in", [hosted.size(), Fmt.pct(al.guest_bonus())]), 13))
		for x in hosted:
			var r := HBoxContainer.new()
			r.add_theme_constant_override("separation", 6)
			c.add_child(r)
			r.add_child(AnimalsPanel.animal_icon(str(x.get("animal", "")), 22))
			r.add_child(UiKit.label(L.t("guests.inRow", [Animals.name_of(str(x.get("animal", ""))), str(x.get("name", "")),
				Fmt.seconds(float(x.get("returns", 0)) - now)]), 12, UiKit.INK_SOFT))
	var friends: Array = g.get("friends", [])
	if not friends.is_empty():
		var names: Array = []
		for f in friends.slice(0, 3):
			names.append(L.t("guests.visits", [str(f.get("name", "")), int(f.get("visits", 0))]))
		c.add_child(_small(L.t("guests.friends") + ": " + ", ".join(names)))
	if al.guest_slots() < Guests.MAX_SLOTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		c.add_child(row)
		var bl := UiKit.label(L.t("guests.buySlot"), 13)
		bl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(bl)
		var pb := ShopPanel.crystal_button(Guests.SLOT_CRYSTALS, "purple", true)
		pb.pressed.connect(func() -> void:
			if not al.buy_guest_slot():
				Game.show_toast("px:gem", L.t("crystals.notEnough", [Fmt.n(Guests.SLOT_CRYSTALS - Game.shop.crystals())]))
			else:
				Sound.play("purchase"))
		row.add_child(pb)


## Наставник: ученик до 15 уровня выбирает наставника от 25 уровня, ступени ученика дают награды обоим.
func _mentor_card() -> void:
	var al := Game.alliance
	if al.mentor.is_empty():
		return
	var me := al.my_mentor()
	var list := al.apprentices()
	if me.is_empty() and list.is_empty() and Game.level > Mentor.APPRENTICE_MAX and Game.level < Mentor.MENTOR_LEVEL:
		return
	var c := card()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	c.add_child(head)
	head.add_child(UiKit.icon("book", 24))
	head.add_child(UiKit.label(L.t("mentor.title"), 15))
	if not me.is_empty():
		c.add_child(UiKit.label(L.t("mentor.yours", [str(me.get("name", "")), int(me.get("level", 1))]), 13))
		_mentor_steps(c, "", int(me.get("start", 1)), Game.level, me.get("claimed", []), false)
	elif Game.level <= Mentor.APPRENTICE_MAX:
		c.add_child(_small(L.t("mentor.findHint", [Mentor.MENTOR_LEVEL])))
	if Game.level >= Mentor.MENTOR_LEVEL or not list.is_empty():
		c.add_child(_small(L.t("mentor.teachHint", [Mentor.APPRENTICE_MAX, list.size(), Mentor.MAX_APPRENTICES])))
		for x in list:
			var a: Dictionary = x
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			c.add_child(row)
			var nl := UiKit.label(L.t("mentor.apprentice", [str(a.get("name", "")), int(a.get("level", 1))]), 13)
			nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(nl)
			if not bool(a.get("gift", false)):
				var gb := ShopPanel.crystal_button(Mentor.GIFT_CRYSTALS, "purple", true)
				var gid := str(a.get("id", ""))
				gb.pressed.connect(func() -> void:
					if Game.shop.crystals() < Mentor.GIFT_CRYSTALS:
						Game.show_toast("px:gem", L.t("crystals.notEnough", [Fmt.n(Mentor.GIFT_CRYSTALS - Game.shop.crystals())]))
						return
					al.gift_apprentice(gid))
				row.add_child(gb)
			_mentor_steps(c, str(a.get("id", "")), int(a.get("start", 1)), int(a.get("level", 1)), a.get("claimed", []), true)
		if not list.is_empty():
			c.add_child(_small(L.t("mentor.giftHint")))


## Ступени ученика: готовые к награде - кнопками, следующая - строкой.
func _mentor_steps(c: VBoxContainer, apprentice_id: String, start: int, level: int, claimed: Array, as_mentor: bool) -> void:
	var al := Game.alliance
	var id := apprentice_id if apprentice_id != "" else Game.rating.user_id()
	for step in Mentor.ready_steps(start, level, claimed):
		var r := Mentor.reward(step, as_mentor)
		var b := UiKit.button(L.t("mentor.claim", [step, Fmt.n(int(r["coins"])), int(r["crystals"])]), "gold", 12, true)
		var st: int = step
		b.pressed.connect(func() -> void: al.claim_mentor(id, st))
		c.add_child(b)
	var next := Mentor.next_step(start, level)
	if next > 0:
		var r := Mentor.reward(next, as_mentor)
		c.add_child(_small(L.t("mentor.next", [next, Fmt.n(int(r["coins"])), int(r["crystals"])])))


# MARK: Летопись и статуи

func _chronicle() -> void:
	var ch := Game.alliance.chronicle
	if ch.is_empty():
		content.add_child(_note(L.t("alliance.loading")))
		return
	# Зал славы: статуи нынешних участников
	var hall := card()
	hall.add_child(UiKit.label(L.t("chronicle.hall"), 16))
	hall.add_child(_small(L.t("chronicle.hallHint")))
	var statues: Array = ch.get("statues", [])
	if statues.is_empty():
		hall.add_child(_small(L.t("chronicle.hallEmpty")))
	else:
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		hall.add_child(grid)
		for x in statues.slice(0, 9):
			grid.add_child(_statue(x))
	_frame_card()
	# Страницы по неделям
	var weeks: Array = ch.get("weeks", [])
	if weeks.is_empty():
		content.add_child(_note(L.t("chronicle.empty")))
	var founded := int(ch.get("founded_week", 0))
	for x in weeks:
		_week_page(x, founded)


## Статуя: фигура в рамке на постаменте, имя и сколько недель был лучшим.
func _statue(s: Dictionary) -> Control:
	var frame: Dictionary = Chronicle.FRAMES.get(str(s.get("frame", "stone")), Chronicle.FRAMES["stone"])
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	var fig := PanelContainer.new()
	var st := UiKit.box(frame["fill"], frame["edge"], 12, 3, false)
	st.set_content_margin_all(6)
	fig.add_theme_stylebox_override("panel", st)
	fig.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var hero := UiKit.icon("swords" if int(s.get("hits", 0)) >= int(s.get("gives", 0)) else "crown", 36)
	hero.modulate = Color(0.85, 0.85, 0.85) if str(s.get("frame", "stone")) == "stone" else Color.WHITE
	fig.add_child(hero)
	col.add_child(fig)
	var base := PanelContainer.new()
	base.add_theme_stylebox_override("panel", UiKit.box(Color("8a8070"), Color(UiKit.OUTLINE, 0.7), 4, 2, false))
	base.custom_minimum_size = Vector2(70, 8)
	base.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(base)
	var name := UiKit.label(str(s.get("name", "")), 12, UiKit.TONES["green"][2] if bool(s.get("me", false)) else UiKit.INK)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.clip_text = true
	name.custom_minimum_size = Vector2(90, 0)
	col.add_child(name)
	var counts := HBoxContainer.new()
	counts.alignment = BoxContainer.ALIGNMENT_CENTER
	counts.add_theme_constant_override("separation", 3)
	for part in [["swords", int(s.get("hits", 0))], ["crown", int(s.get("gives", 0))]]:
		if int(part[1]) > 0:
			counts.add_child(UiKit.icon(str(part[0]), 14))
			counts.add_child(UiKit.label(str(part[1]), 12, UiKit.INK_SOFT))
	col.add_child(counts)
	return col


## Рамка своей статуи: камень бесплатно, остальные за кристаллы, только для красоты.
func _frame_card() -> void:
	var c := card()
	c.add_child(UiKit.label(L.t("chronicle.frame"), 15))
	c.add_child(_small(L.t("chronicle.frameHint")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	c.add_child(row)
	var al := Game.alliance
	var frames: Array = Chronicle.ORDER.duplicate()
	if Village.PACK_FRAME in al.owned_frames():
		frames.append(Village.PACK_FRAME)
	for id in frames:
		var f: Dictionary = Chronicle.FRAMES[id]
		var owned: bool = id in al.owned_frames()
		var b := Button.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 54)
		var chosen: bool = id == al.statue_frame()
		var st := UiKit.box(f["fill"], UiKit.OUTLINE if chosen else f["edge"], 10, 4 if chosen else 2, false)
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(state, st)
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		var line := HBoxContainer.new()
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		line.add_theme_constant_override("separation", 2)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if chosen:
			line.add_child(UiKit.icon("check", 18))
		elif owned:
			line.add_child(UiKit.label(L.t("chronicle.put"), 11))
		else:
			line.add_child(UiKit.icon("gem", 14))
			line.add_child(UiKit.label(Fmt.n(Chronicle.price(id)), 12))
		v.add_child(line)
		var frame_id: String = id
		b.pressed.connect(func() -> void:
			if frame_id == al.statue_frame():
				return
			if not frame_id in al.owned_frames() and Game.shop.crystals() < Chronicle.price(frame_id):
				Game.show_toast("px:gem", L.t("crystals.notEnough", [Fmt.n(Chronicle.price(frame_id) - Game.shop.crystals())]))
				return
			if al.pick_frame(frame_id):
				Sound.play("purchase")
				_dirty = true)
		row.add_child(b)


## Страница летописи: итоги одной недели.
func _week_page(w: Dictionary, founded: int) -> void:
	var c := card()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	c.add_child(head)
	head.add_child(UiKit.icon("book", 22))
	var t := UiKit.label(L.t("chronicle.week", [Chronicle.week_number(int(w.get("week", 0)), founded)]), 15)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var place := int(w.get("place", 0)) if w.get("place") != null else 0
	if place > 0:
		head.add_child(UiKit.label(L.t("chronicle.place", [place]), 13, UiKit.TONES["orange"][2] if place <= 3 else UiKit.INK_SOFT))
	var lines := [["star", L.t("chronicle.xp", [Fmt.n(int(w.get("xp", 0))), int(w.get("level", 1))])]]
	if int(w.get("boss", 0)) > 0:
		lines.append(["skull", L.t("chronicle.boss", [int(w.get("boss", 0))])])
	lines.append(["scroll", L.t("chronicle.tasks", [int(w.get("tasks", 0)), 3])])
	if w.get("hit") != null and str(w.get("hit")) != "":
		lines.append(["swords", L.t("chronicle.hit", [str(w["hit"]), Fmt.n(int(w.get("hit_value", 0)))])])
	if w.get("give") != null and str(w.get("give")) != "":
		lines.append(["crown", L.t("chronicle.give", [str(w["give"]), Fmt.n(int(w.get("give_value", 0)))])])
	for line in lines:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 6)
		r.add_child(UiKit.icon(str(line[0]), 16))
		var l := UiKit.label(str(line[1]), 12, UiKit.INK_SOFT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r.add_child(l)
		c.add_child(r)


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
	var kinds := [["boss", L.t("alliance.ev.boss")], ["war", L.t("war.title")]]
	var tabs := UiKit.tabs(kinds, events_kind, func(id: String) -> void:
		events_kind = id
		if id == "war":
			Game.war.fetch()
		_dirty = true)
	content.add_child(tabs)
	if events_kind == "war":
		_war()
		return
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


# MARK: Война альянсов

func _war() -> void:
	var w := Game.war
	if w.error != "":
		var e := _note(L.t("alliance.err." + w.error.replace(" ", "_")))
		e.modulate = Color(1, 0.85, 0.8)
		content.add_child(e)
	if not w.joined():
		content.add_child(_note(L.t("alliance.loading")))
		return
	var left := float(int(w.state.get("ends", 0)) - int(Time.get_unix_time_from_system()))
	content.add_child(_small(L.t("war.ends", [EventsPanel.long_countdown(maxf(0.0, left))])))
	# Награда за прошлую неделю
	var rw := w.reward()
	if not rw.is_empty():
		var rc := card(Color("f6e7b0"))
		var rr := HBoxContainer.new()
		rr.add_theme_constant_override("separation", 8)
		rc.add_child(rr)
		var rcol := VBoxContainer.new()
		rcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rr.add_child(rcol)
		var rl := UiKit.label(L.t("war.reward", [int(rw.get("place", 0)), int(rw.get("teams", 0))]), 13)
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rcol.add_child(rl)
		rcol.add_child(_reward_line(War.place_reward(int(rw.get("place", 8)), Game.level)))
		var cb := UiKit.button(L.t("alliance.ev.claim"), "green", 13, true)
		cb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cb.disabled = w.busy
		cb.pressed.connect(func() -> void: Game.war.claim())
		rr.add_child(cb)
		UiKit.attention(cb)
	# Сводка: место, атаки, буст
	var head := card()
	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", 8)
	head.add_child(hr)
	hr.add_child(UiKit.icon("swords", 26))
	var hl := UiKit.label(L.t("war.place", [w.my_place(), w.teams().size()]), 14)
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr.add_child(hl)
	hr.add_child(UiKit.label(L.t("war.attacks", [w.attacks_left(), int(w.state.get("max", War.ATTACKS))]), 13, UiKit.INK_SOFT))
	head.add_child(_small(L.t("war.hint")))
	# Карта
	var side := minf(340.0, get_viewport_rect().size.x - 50.0)
	var holder := CenterContainer.new()
	content.add_child(holder)
	holder.add_child(WarMap.new(side))
	_war_node_card()
	# Казна
	section_title(L.t("war.chest"))
	var cc := card()
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 8)
	cc.add_child(crow)
	var ccol := VBoxContainer.new()
	ccol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crow.add_child(ccol)
	ccol.add_child(UiKit.label(L.t("war.boost", [int(round(War.boost(w.chest()) * 100.0)), int(War.BOOST_MAX * 100.0)]), 13))
	ccol.add_child(UiKit.bar(War.boost(w.chest()) / War.BOOST_MAX, "orange", 170, 12, Fmt.n(w.chest())))
	ccol.add_child(_small(L.t("war.donatesLeft", [w.donates_left(), War.DONATES_PER_DAY])))
	var db := UiKit.button(Fmt.n(War.donate_coins(Game.level)), "orange", 13, true)
	db.icon = UiKit.icon("coin", 16).texture
	db.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	db.disabled = w.busy or w.donates_left() <= 0
	db.pressed.connect(func() -> void: Game.war.donate())
	crow.add_child(db)
	# Лига
	section_title(L.t("war.league"))
	var lc := card()
	var i := 0
	for t in w.teams():
		i += 1
		var tr := HBoxContainer.new()
		tr.add_theme_constant_override("separation", 6)
		lc.add_child(tr)
		tr.add_child(UiKit.label("#%d" % i, 12, UiKit.INK_SOFT))
		var dot := ColorRect.new()
		dot.color = War.COLORS[clampi(int(t.get("slot", 0)), 0, War.COLORS.size() - 1)]
		dot.custom_minimum_size = Vector2(12, 12)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tr.add_child(dot)
		var tn := UiKit.label("[%s] %s" % [str(t.get("tag", "")), str(t.get("name", ""))], 13, UiKit.INK if not bool(t.get("me", false)) else UiKit.GOOD)
		tn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tn.clip_text = true
		tr.add_child(tn)
		tr.add_child(UiKit.label(L.t("war.points", [Fmt.n(int(t.get("points", 0))), int(t.get("nodes", 0))]), 12, UiKit.INK_SOFT))
	var pg := GridContainer.new()
	pg.columns = 4
	pg.add_theme_constant_override("h_separation", 10)
	lc.add_child(_small(L.t("war.rewards")))
	lc.add_child(pg)
	for p in [1, 2, 3, 4]:
		pg.add_child(UiKit.label("#%d%s" % [p, "+" if p == 4 else ""], 12, UiKit.INK_SOFT))
	for p in [1, 2, 3, 4]:
		pg.add_child(_reward_line({"crystals": War.place_reward(p, Game.level)["crystals"]}))
	# Знамя войны
	if not w.has_pass():
		var parts := ShopPanel.shop_card(Products.title("warBanner"), "red")
		var v: VBoxContainer = parts[1]
		v.add_child(HousePanel.wrapped(L.t("war.passDesc", [War.PASS_ATTACKS]), 12))
		v.add_child(ShopPanel.buy_button("warBanner", "orange"))
		content.add_child(parts[0])
	# Журнал
	var log: Array = w.state.get("log", [])
	if not log.is_empty():
		section_title(L.t("war.log"))
		var gc := card()
		for x in log.slice(0, 12):
			var en: Dictionary = x
			var lr := HBoxContainer.new()
			lr.add_theme_constant_override("separation", 6)
			gc.add_child(lr)
			var dd := ColorRect.new()
			dd.color = War.COLORS[clampi(int(en.get("slot", 0)), 0, War.COLORS.size() - 1)]
			dd.custom_minimum_size = Vector2(8, 8)
			dd.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			lr.add_child(dd)
			var ll := _small(L.t("war.act." + str(en.get("act", "win")), [str(en.get("name", "")), _node_name(int(en.get("node", 0)))]))
			ll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lr.add_child(ll)


static func _node_name(n: int) -> String:
	if n == 0:
		return L.t("war.castle")
	if War.is_base(n):
		var t := Game.war.team(n)
		return L.t("war.base", [str(t.get("tag", "?"))])
	return L.t("war.post", [n - War.TEAMS])


## Выбранная точка: владелец, щиты, гарнизон, шанс и кнопка атаки.
func _war_node_card() -> void:
	var w := Game.war
	var n := w.selected
	var c := card()
	if n < 0:
		c.add_child(_small(L.t("war.pick")))
		return
	var d := w.node(n)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	c.add_child(row)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	col.add_child(UiKit.label(_node_name(n), 15))
	var owner := int(d["owner"])
	var ot := w.team(owner)
	col.add_child(_small(L.t("war.owner", [str(ot.get("name", ""))]) if owner > 0 else L.t("war.neutral")))
	if War.is_base(n):
		col.add_child(_small(L.t("war.baseHint")))
		_war_last(c)
		return
	col.add_child(_small(L.t("war.info", [int(d["shields"]), War.max_shields(War.tier(n)), Fmt.n(int(d["garrison"])),
		War.rate(War.tier(n))])))
	if w.can_reinforce(n):
		var rb := UiKit.button(L.t("war.reinforce"), "blue", 13, true)
		rb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rb.disabled = w.busy
		rb.pressed.connect(func() -> void: Game.war.attack(n, true))
		row.add_child(rb)
	elif owner != w.my_slot():
		col.add_child(_small(L.t("war.chance", [int(round(w.chance(n) * 100.0))])))
		if w.can_attack(n):
			var ab := UiKit.button(L.t("war.attack"), "red", 14, true)
			ab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			ab.disabled = w.busy
			ab.pressed.connect(func() -> void: Game.war.attack(n))
			row.add_child(ab)
			UiKit.attention(ab)
		elif not bool(d["reach"]):
			col.add_child(_small(L.t("war.far")))
		else:
			col.add_child(_small(L.t("war.noAttacks")))
	_war_last(c)


func _war_last(c: VBoxContainer) -> void:
	var r := Game.war.last
	if r.is_empty() or int(r.get("node", -1)) != Game.war.selected:
		return
	var key := "war.res.reinforced" if bool(r.get("reinforced", false)) else "war.res.captured" if bool(r.get("captured", false)) \
		else "war.res.won" if bool(r.get("won", false)) else "war.res.lost"
	var l := UiKit.label(L.t(key, [Fmt.n(int(r.get("coins", 0)))]), 13, UiKit.GOOD if bool(r.get("won", false)) else UiKit.BAD)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(l)


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
