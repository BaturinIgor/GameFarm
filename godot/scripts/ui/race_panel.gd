class_name RacePanel
extends Sheet
## Гонка к Сердцу долины: как играть, флажки, старт или возврат в идущую гонку, трофеи, лига и статистика мест.
## Поле гонки - RaceScene, правила - RaceRun, данные - Race.

var _flag_label: Label
## Рейтинг: "day" или "month".
var period := "day"
var _asked := {}


func _init() -> void:
	title_key = "race.title"


func _ready() -> void:
	super()
	_ask_top()


func _ask_top() -> void:
	if _asked.has(period):
		return
	_asked[period] = true
	Game.race.fetch_top(period)


func _process(delta: float) -> void:
	super(delta)
	if _flag_label != null and is_instance_valid(_flag_label):
		_flag_label.text = _flag_text()
		_flag_label.visible = _flag_label.text != ""


func _flag_text() -> String:
	var left := Game.race.flag_left()
	return L.t("race.flagNext", [Fmt.seconds(left)]) if left > 0.0 else ""


func build() -> void:
	var sys := Game.race
	var hint := UiKit.label(L.t("race.hint"), 12, UiKit.INK_SOFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(hint)

	# Старт или возврат
	var v := TraderPanel.card_box(content, Color("e9c46a"), 3)
	if sys.active():
		var run := sys.run()
		var now := Clock.now()
		if run.decided(now):
			v.add_child(UiKit.label(L.t("race.place", [run.place(now)]), 20))
		elif run.ended(now):
			v.add_child(UiKit.label(L.t("race.waiting"), 16))
		else:
			v.add_child(UiKit.label(L.t("race.left", [Race.clock(run.left(now))]), 16))
		var back := UiKit.button(L.t("race.resume"), "green", 17)
		back.pressed.connect(func() -> void:
			close()
			RaceScene.launch())
		v.add_child(back)
		UiKit.attention(back)
	else:
		var flags := HBoxContainer.new()
		flags.add_theme_constant_override("separation", 6)
		flags.add_child(UiKit.icon_any("px:bolt", 22))
		flags.add_child(UiKit.label(L.t("race.flags", [sys.flags(), Race.FLAGS_MAX]), 15))
		v.add_child(flags)
		_flag_label = UiKit.label(_flag_text(), 11, UiKit.INK_SOFT)
		_flag_label.visible = _flag_label.text != ""
		v.add_child(_flag_label)
		var go := UiKit.button(L.t("race.searching") if sys.busy else L.t("race.start"), "green", 18)
		go.disabled = not sys.can_start() or sys.busy
		go.pressed.connect(func() -> void:
			var run: RaceRun = await Game.race.start_online()
			if run != null and is_inside_tree():
				close()
				RaceScene.launch())
		v.add_child(go)
		if sys.can_start() and not sys.busy:
			UiKit.attention(go)

	# Трофеи и лига
	var t := TraderPanel.card_box(content, Color("b5d99c"), 3)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(UiKit.icon_any("px:trophy", 28))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UiKit.label("%s: %s" % [L.t("race.trophies"), Fmt.n(sys.trophies())], 16))
	var lg := sys.league()
	col.add_child(UiKit.label("%s: %s" % [L.t("race.league"), Race.league_name(lg)], 13, UiKit.INK_SOFT))
	if lg + 1 < Race.LEAGUES.size():
		var next: Dictionary = Race.LEAGUES[lg + 1]
		var from := int(Race.LEAGUES[lg]["from"])
		var to := int(next["from"])
		col.add_child(UiKit.bar(float(sys.trophies() - from) / float(maxi(1, to - from)), "gold", 200.0, 10.0))
		col.add_child(UiKit.label(L.t("race.leagueNext", [Race.league_name(lg + 1), Fmt.n(to - sys.trophies())]), 11, UiKit.INK_SOFT))
	row.add_child(col)
	t.add_child(row)

	# Места
	var s := TraderPanel.card_box(content, Color("a8c5e6"), 3)
	s.add_child(UiKit.label(L.t("race.stats"), 15))
	var places := HBoxContainer.new()
	places.add_theme_constant_override("separation", 14)
	for i in Race.SEATS:
		var p := VBoxContainer.new()
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.add_child(UiKit.label(L.t("race.place", [i + 1]), 12, UiKit.INK_SOFT))
		p.add_child(UiKit.label(Fmt.n(int(sys.places()[i])), 18))
		places.add_child(p)
	s.add_child(places)
	s.add_child(UiKit.label(L.t("race.races", [sys.races()]), 12, UiKit.INK_SOFT))
	if sys.best() > 0.0:
		s.add_child(UiKit.label(L.t("race.best", [Race.clock(sys.best())]), 12, UiKit.INK_SOFT))

	# Награды за место
	var r := TraderPanel.card_box(content, Color("f4d6a0"), 3)
	r.add_child(UiKit.label(L.t("race.rewardsTitle"), 15))
	# Таблица: место | трофеи | кристаллы | ключ - столбцы ровно друг под другом
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	r.add_child(grid)
	for i in Race.SEATS:
		var rw := RaceSystem.reward_for(i + 1)
		grid.add_child(UiKit.label(L.t("race.place", [i + 1]), 13))
		grid.add_child(_reward_chip("px:trophy", "+%d" % int(rw["trophies"])))
		grid.add_child(_reward_chip("px:gem", "+%d" % int(rw["crystals"])))
		if str(rw["key"]) != "":
			var key := _reward_chip("px:key", Chests.key_name(str(rw["key"])), 11)
			key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(key)
		else:
			grid.add_child(Control.new())

	_build_rating()


# MARK: Рейтинг

func _build_rating() -> void:
	var sys := Game.race
	var c := TraderPanel.card_box(content, Color("d9b8e6"), 3)
	c.add_child(UiKit.label(L.t("race.rating"), 15))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	for p in ["day", "month"]:
		var b := UiKit.button(L.t("race.rating." + p), "green" if p == period else "gray", 13, true)
		b.pressed.connect(func() -> void:
			period = p
			_ask_top()
			_dirty = true)
		tabs.add_child(b)
	c.add_child(tabs)
	var hint := UiKit.label(L.t("race.ratingHint"), 11, UiKit.INK_SOFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(hint)
	var data: Dictionary = sys.top.get(period, {})
	if data.is_empty():
		var wait := L.t("race.offline") if sys.top_error or not (OnlineConfig.enabled() or sys.demo) else L.t("rating.loading")
		c.add_child(UiKit.label(wait, 12, UiKit.INK_SOFT))
		return
	var rows: Array = data.get("top", [])
	if rows.is_empty():
		c.add_child(UiKit.label(L.t("race.ratingEmpty"), 12, UiKit.INK_SOFT))
	var shown_me := false
	for i in mini(rows.size(), 10):
		var r: Dictionary = rows[i]
		shown_me = shown_me or bool(r.get("me", false))
		c.add_child(_rating_row(int(r["place"]), str(r["name"]), int(r["points"]), bool(r.get("me", false))))
	var me: Variant = data.get("me")
	if not shown_me and me is Dictionary:
		c.add_child(_rating_row(int(me["place"]), Game.rating.player_name(), int(me["points"]), true))


func _rating_row(place: int, name: String, points: int, me: bool) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var color := UiKit.INK if me else UiKit.INK_SOFT
	var pl := UiKit.label("%d." % place, 13, color)
	pl.custom_minimum_size = Vector2(34, 0)
	h.add_child(pl)
	var nl := UiKit.label(name, 13, color)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.clip_text = true
	h.add_child(nl)
	h.add_child(UiKit.icon_any("px:trophy", 14))
	h.add_child(UiKit.label(Fmt.n(points), 13, color))
	return h


func _reward_chip(icon: String, text: String, size := 13) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.add_child(UiKit.icon_any(icon, 16))
	var l := UiKit.label(text, size)
	if size < 13:
		# Длинное название ключа обрезается, а не растягивает окно
		l.clip_text = true
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size = Vector2(40, 0)
	h.add_child(l)
	return h
