class_name ArenaPanel
extends Sheet
## Турнир зверей: вкладки «Бой» (отряд, бои, итог последнего боя, защиты), «Награды» (дорожка недели,
## бесплатная и по пропуску) и «Рейтинг» (места недели и награда за прошлую). Данные - Game.tourney.

var tab := "fight"


func _init(start_tab := "") -> void:
	title_key = "tourney.title"
	if start_tab in ["fight", "track", "top"]:
		tab = start_tab


func focus_attention() -> void:
	var t := Game.tourney
	if t.can_claim_week():
		tab = "top"
	elif t.ready_count() > 0:
		tab = "track"


func _ready() -> void:
	super._ready()
	await Game.tourney.fetch()


func build_top() -> void:
	var t := Game.tourney
	if not t.open() or not t.online() or t.state.is_empty():
		return
	var claim := 0
	for i in Tourney.tiers_open(t.points()):
		claim += int(t.can_claim_tier(i, false)) + int(t.can_claim_tier(i, true))
	top_bar.add_child(UiKit.tabs([["fight", L.t("tourney.tab.fight"), 0, "swords"],
		["track", L.t("tourney.tab.track"), claim, "chest"],
		["top", L.t("tourney.tab.top"), 1 if t.can_claim_week() else 0, "trophy"]], tab, func(id: String) -> void:
		tab = id
		scroll_to_top()))


func build() -> void:
	var t := Game.tourney
	if not t.open():
		content.add_child(_note(L.t("tourney.locked", [Tourney.MIN_LEVEL])))
		return
	if not t.online():
		content.add_child(_note(L.t("tourney.offline")))
		return
	if t.state.is_empty():
		content.add_child(_note(L.t("tourney.loading") if t.error == "" else L.t("tourney.err.network")))
		return
	if t.error != "":
		var e := UiKit.label(L.t("tourney.err." + t.error), 12, UiKit.BAD)
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(e)
	match tab:
		"track": _track()
		"top": _top()
		_: _fight()


# MARK: Бой

func _fight() -> void:
	var t := Game.tourney
	if not t.last_fight.is_empty():
		_result(t.last_fight)
	var c := card()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	c.add_child(head)
	head.add_child(UiKit.icon("paw", 22))
	var hl := UiKit.label(L.t("tourney.squad"), 15)
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hl)
	head.add_child(UiKit.label(L.t("power.value", [Fmt.n(t.squad_power())]), 12, UiKit.INK_SOFT))
	c.add_child(_small(L.t("tourney.squadHint")))
	var squad := t.squad()
	for i in Tourney.SQUAD:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		c.add_child(row)
		row.add_child(UiKit.label("%d." % (i + 1), 14))
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 0)
		if i < squad.size():
			var id := str(squad[i])
			row.add_child(AnimalsPanel.animal_icon(id, 34))
			col.add_child(UiKit.label(Animals.name_of(id), 14))
			col.add_child(UiKit.label(L.t("power.value", [Fmt.n(Power.animal(id))]), 11, UiKit.INK_SOFT))
		else:
			col.add_child(UiKit.label(L.t("tourney.empty"), 13, UiKit.INK_SOFT))
		row.add_child(col)
		var b := UiKit.button(L.t("tourney.change"), "wood", 12, true)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var slot := i
		b.pressed.connect(func() -> void: SquadPicker.open(slot))
		row.add_child(b)
	# Рейтинг и бои
	var f := card()
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 8)
	f.add_child(r)
	r.add_child(UiKit.icon("trophy", 22))
	var rl := UiKit.label(L.t("tourney.rating", [Fmt.n(int(t.state.get("rating", 0)))]), 15)
	rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(rl)
	r.add_child(UiKit.label(L.t("tourney.points", [t.points()]), 12, UiKit.INK_SOFT))
	f.add_child(_small(L.t("tourney.fightsLeft", [t.fights_left()])))
	var go := UiKit.button(L.t("tourney.fight"), "orange", 16)
	go.disabled = t.busy or t.fights_left() <= 0 or squad.is_empty()
	go.pressed.connect(func() -> void: t.fight())
	f.add_child(go)
	if t.fights_left() > 0 and not squad.is_empty():
		UiKit.attention(go)
	if t.fights_left() <= 0 and t.buys_left() > 0:
		var buy_row := HBoxContainer.new()
		buy_row.add_theme_constant_override("separation", 8)
		f.add_child(buy_row)
		var bl := _small(L.t("tourney.buyFights", [Tourney.BUY_FIGHTS, t.buys_left()]))
		bl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buy_row.add_child(bl)
		var cb := ShopPanel.crystal_button(Tourney.BUY_CRYSTALS, "purple", true)
		cb.pressed.connect(func() -> void: t.buy_fights())
		buy_row.add_child(cb)
	elif t.fights_left() <= 0:
		f.add_child(_small(L.t("tourney.tomorrow")))
	_log()


## Итог последнего боя: три поединка, рейтинг и очки.
func _result(res: Dictionary) -> void:
	var won := bool(res.get("won", false))
	var c := card(Color(UiKit.GOOD, 0.18) if won else Color(UiKit.BAD, 0.12))
	var title := UiKit.label(L.t("tourney.won") if won else L.t("tourney.lost"), 17)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(title)
	var opp: Dictionary = res.get("opp", {}) if res.get("opp") is Dictionary else {}
	var vs := _small(L.t("tourney.vs", [str(opp.get("name", "")), int(opp.get("level", 1))]))
	vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(vs)
	for x in res.get("duels", []):
		var d: Dictionary = x
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		c.add_child(row)
		var a := str(d.get("a", ""))
		var b := str(d.get("b", ""))
		var ok := bool(d.get("won", false))
		if a != "":
			row.add_child(AnimalsPanel.animal_icon(a, 28))
		row.add_child(UiKit.label(Fmt.n(int(d.get("ap", 0))), 12, UiKit.GOOD if ok else UiKit.INK_SOFT))
		row.add_child(UiKit.label(L.t("tourney.duelWon") if ok else L.t("tourney.duelLost"), 12, UiKit.GOOD if ok else UiKit.BAD))
		row.add_child(UiKit.label(Fmt.n(int(d.get("bp", 0))), 12, UiKit.INK_SOFT if ok else UiKit.BAD))
		if b != "":
			row.add_child(AnimalsPanel.animal_icon(b, 28))
	var delta := int(res.get("delta", 0))
	var sum := UiKit.label(L.t("tourney.after", ["%+d" % delta, int(res.get("points", 0))]), 13)
	sum.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(sum)
	var ok_b := UiKit.button(L.t("common.ok"), "green", 13, true)
	ok_b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok_b.pressed.connect(func() -> void:
		Game.tourney.last_fight = {}
		Game.changed.emit())
	c.add_child(ok_b)


## Кто нападал на мой отряд.
func _log() -> void:
	var log: Array = Game.tourney.state.get("log", [])
	if log.is_empty():
		return
	var c := card()
	c.add_child(UiKit.label(L.t("tourney.defense"), 14))
	for x in log:
		var e: Dictionary = x
		var held := bool(e.get("held", false))
		var d := int(e.get("delta", 0))
		c.add_child(_small(L.t("tourney.held" if held else "tourney.fell", [str(e.get("name", "")), "%+d" % d])))


# MARK: Дорожка

func _track() -> void:
	var t := Game.tourney
	var pts := t.points()
	var open := Tourney.tiers_open(pts)
	var c := card()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	c.add_child(head)
	head.add_child(UiKit.icon("chest", 22))
	var hl := UiKit.label(L.t("tourney.points", [pts]), 15)
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hl)
	head.add_child(UiKit.label(EventsPanel.long_countdown(DailySystem.week_left()), 12, UiKit.INK_SOFT))
	if open < Tourney.TRACK.size():
		var need := int(Tourney.TRACK[open])
		var prev := 0 if open == 0 else int(Tourney.TRACK[open - 1])
		var bar := UiKit.bar(float(pts - prev) / float(maxi(1, need - prev)), "gold", 200.0, 16.0, "%d/%d" % [pts, need])
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.add_child(bar)
	c.add_child(_small(L.t("tourney.trackHint", [Tourney.WIN_POINTS, Tourney.LOSS_POINTS])))
	if not t.has_pass():
		var parts := ShopPanel.shop_card(Products.title("tourneyPass"), "gold")
		var v: VBoxContainer = parts[1]
		var text := HousePanel.wrapped(L.t("tourney.passDesc"), 12)
		v.add_child(text)
		v.add_child(ShopPanel.buy_button("tourneyPass", "orange"))
		content.add_child(parts[0])
	for i in Tourney.TRACK.size():
		var row_card := card(Color(UiKit.PARCHMENT_LIGHT) if i < open else Color(UiKit.PARCHMENT_DEEP, 0.6))
		var top := HBoxContainer.new()
		row_card.add_child(top)
		var tl := UiKit.label(L.t("tourney.tier", [i + 1]), 13)
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(tl)
		top.add_child(UiKit.label(L.t("tourney.tierNeed", [int(Tourney.TRACK[i])]), 11, UiKit.INK_SOFT))
		for paid in [false, true]:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			row_card.add_child(row)
			row.add_child(UiKit.icon("star" if paid else "chest", 16))
			var rw := _reward_row(Tourney.tier_reward(i, paid, Game.level))
			rw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(rw)
			if t.tier_claimed(i, paid):
				row.add_child(UiKit.label(L.t("tourney.taken"), 11, UiKit.GOOD))
			elif paid and not t.has_pass():
				var lk := UiKit.icon("key", 16)
				lk.modulate = Color(1, 1, 1, 0.35)
				row.add_child(lk)
			elif i < open:
				var b := UiKit.button(L.t("tourney.take"), "gold" if paid else "green", 12, true)
				var tier := i
				var is_paid: bool = paid
				b.pressed.connect(func() -> void: t.claim_tier(tier, is_paid))
				UiKit.attention(b)
				row.add_child(b)


func _reward_row(r: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	if int(r.get("coins", 0)) > 0:
		row.add_child(UiKit.icon("coins", 16))
		row.add_child(UiKit.label(Fmt.n(int(r["coins"])), 12))
	if int(r.get("crystals", 0)) > 0:
		row.add_child(UiKit.icon("gem", 16))
		row.add_child(UiKit.label(Fmt.n(int(r["crystals"])), 12))
	for k in Chests.KEYS:
		if int(r.get(k, 0)) > 0:
			row.add_child(ChestsPanel.key_icon(k, 16))
			row.add_child(UiKit.label("x%d" % int(r[k]), 12))
	return row


# MARK: Рейтинг недели

func _top() -> void:
	var t := Game.tourney
	if t.can_claim_week():
		var l := t.last_week()
		var place := int(l.get("place", 0))
		var c := card(Color(UiKit.GOOD, 0.15))
		c.add_child(UiKit.label(L.t("tourney.lastWeek", [place, int(l.get("points", 0))]), 14))
		c.add_child(_reward_row(Tourney.place_reward(place, Game.level)))
		var b := UiKit.button(L.t("tourney.take"), "gold", 14)
		b.pressed.connect(func() -> void: t.claim_week())
		UiKit.attention(b)
		c.add_child(b)
	var info := card()
	info.add_child(_small(L.t("tourney.topHint")))
	for x in t.state.get("top", []):
		var e: Dictionary = x
		var me := bool(e.get("me", false))
		var c := card(Color(UiKit.GOLD, 0.25) if me else UiKit.PARCHMENT_LIGHT)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		c.add_child(row)
		row.add_child(UiKit.label("#%d" % int(e.get("place", 0)), 14))
		var nl := UiKit.label(L.t("tourney.player", [str(e.get("name", "")), int(e.get("level", 1))]), 13)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nl)
		row.add_child(UiKit.label(L.t("tourney.points", [int(e.get("points", 0))]), 12, UiKit.INK_SOFT))


func _note(text: String) -> Label:
	var l := UiKit.label(text, 13, UiKit.INK_SOFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _small(text: String) -> Label:
	var l := UiKit.label(text, 12, UiKit.INK_SOFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
