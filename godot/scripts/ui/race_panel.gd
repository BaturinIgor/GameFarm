class_name RacePanel
extends Sheet
## Гонка к Сердцу долины: как играть, флажки, старт или возврат в идущую гонку, трофеи, лига и статистика мест.
## Поле гонки - RaceScene, правила - RaceRun, данные - Race.

var _flag_label: Label


func _init() -> void:
	title_key = "race.title"


func _process(delta: float) -> void:
	super(delta)
	if _flag_label != null and is_instance_valid(_flag_label):
		_flag_label.text = _flag_text()


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
		v.add_child(_flag_label)
		var go := UiKit.button(L.t("race.start"), "green", 18)
		go.disabled = not sys.can_start()
		go.pressed.connect(func() -> void:
			if Game.race.start() != null:
				close()
				RaceScene.launch())
		v.add_child(go)
		if sys.can_start():
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
	for i in Race.SEATS:
		var rw := RaceSystem.reward_for(i + 1)
		var h := HFlowContainer.new()
		h.add_theme_constant_override("h_separation", 8)
		var pl := UiKit.label(L.t("race.place", [i + 1]), 13)
		pl.custom_minimum_size = Vector2(76, 0)
		h.add_child(pl)
		h.add_child(UiKit.icon_any("px:trophy", 16))
		h.add_child(UiKit.label("+%d" % int(rw["trophies"]), 13))
		h.add_child(UiKit.icon_any("px:gem", 16))
		h.add_child(UiKit.label("+%d" % int(rw["crystals"]), 13))
		if str(rw["key"]) != "":
			var key := HBoxContainer.new()
			key.add_theme_constant_override("separation", 4)
			key.add_child(UiKit.icon_any("px:key", 16))
			key.add_child(UiKit.label(Chests.key_name(str(rw["key"])), 13))
			h.add_child(key)
		r.add_child(h)
