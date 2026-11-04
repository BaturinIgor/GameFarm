class_name FarmEventCards
## Вкладка фарм-ивента в окне ивентов: баннер с целью и таймером, очки и ступень, лестница наград
## и анонсы следующих фарм-ивентов. Данные - FarmEvents, состояние - Game.farm.


static func build(content: VBoxContainer) -> void:
	Game.farm.sync()
	var run := FarmEvents.current()
	var event: String = run["event"]
	content.add_child(_banner(run))
	content.add_child(_progress_card(event))
	content.add_child(_ladder(event))
	content.add_child(EventsPanel.section(L.t("farm.upcoming")))
	for r in FarmEvents.upcoming():
		content.add_child(_upcoming_card(r))


static func _banner(run: Dictionary) -> Control:
	var event: String = run["event"]
	var colors: Array = FarmEvents.COLORS[event]
	var card := DungeonPanel.GradientPanel.new(colors[0], colors[1])
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	v.add_child(head)
	head.add_child(UiKit.icon(FarmEvents.icon(event), 30))
	var title := UiKit.title(FarmEvents.name_of(event), 21)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	for text in [FarmEvents.blurb(event), _goal_text(event)]:
		var l := UiKit.label(text, 12, Color.WHITE, 3)
		l.label_settings.outline_color = Color(UiKit.OUTLINE, 0.8)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
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
	v.add_child(timer)
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 5)
	timer.add_child(trow)
	trow.add_child(UiKit.icon("stopwatch", 14))
	trow.add_child(EventsPanel.countdown_label("event.left", float(run["end"]), 12, Color.WHITE, 3))
	return card


## Как набирать очки в этом ивенте.
static func _goal_text(event: String) -> String:
	if FarmEvents.kind(event) == "hunt":
		return L.t("farm.goal.hunt", [FarmEvents.KILL_POINTS])
	return L.t("farm.goal." + str(FarmEvents.TOOL[event]), [FarmEvents.SPOT_POINTS])


static func _progress_card(event: String) -> Control:
	var points := Game.farm.points()
	var step := FarmEvents.step_of(event, points)
	var maxed := step >= FarmEvents.MILESTONES
	var from := FarmEvents.threshold(event, step)
	var need := 1 if maxed else FarmEvents.threshold(event, step + 1) - from
	var have := need if maxed else points - from
	var c := EventsPanel._card(Color(UiKit.WOOD_DARK, 0.45), 2)
	var v := EventsPanel._body(c)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	row.add_child(UiKit.icon(FarmEvents.icon(event), 32))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	col.add_child(UiKit.label(L.t("event.tier", [step, FarmEvents.MILESTONES]), 16))
	col.add_child(UiKit.label(L.t("event.points", [Fmt.n(points)]), 12, UiKit.INK_SOFT))
	var label := L.t("farm.done") if maxed else "%s / %s" % [Fmt.n(have), Fmt.n(need)]
	var bar := UiKit.bar(float(have) / float(maxi(1, need)), "purple" if maxed else "orange", 100, 18, label)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(bar)
	var claimable := Game.farm.claimable()
	if claimable > 0:
		var b := UiKit.button(L.t("event.claimAll", [claimable]), "green")
		b.pressed.connect(func() -> void: Game.farm.claim_all())
		v.add_child(b)
	return c


## Лестница наград: ступень, награда, сколько очков нужно и кнопка "Забрать".
static func _ladder(event: String) -> Control:
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	var reached := Game.farm.step()
	for t in range(1, FarmEvents.MILESTONES + 1):
		var claimed: bool = t in Game.save.get("farmClaimed", [])
		var ready := Game.farm.can_claim(t)
		var p := PanelContainer.new()
		var border := UiKit.TONES["green"][1] if ready else Color(UiKit.WOOD_DARK, 0.45)
		var s := UiKit.box(UiKit.PARCHMENT_LIGHT, border, 12, 3 if ready else 2, false)
		s.content_margin_left = 8
		s.content_margin_right = 8
		s.content_margin_top = 6
		s.content_margin_bottom = 6
		p.add_theme_stylebox_override("panel", s)
		list.add_child(p)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		p.add_child(row)
		row.add_child(EventsPanel._tier_badge(t, t <= reached))
		var reward := _reward_view(FarmEvents.reward(t))
		reward.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		reward.modulate.a = 0.45 if claimed else 1.0
		row.add_child(reward)
		# Фиксированная ширина правой колонки, чтобы строки не скакали
		var right := CenterContainer.new()
		right.custom_minimum_size = Vector2(96, 34)
		row.add_child(right)
		if claimed:
			right.add_child(HousePanel.check_mark(22))
		elif ready:
			var b := UiKit.button(L.t("quests.claim"), "green", 13, true)
			b.custom_minimum_size = Vector2(92, 0)
			b.pressed.connect(func() -> void: Game.farm.claim(t))
			right.add_child(b)
		else:
			var l := UiKit.label(Fmt.n(FarmEvents.threshold(event, t)), 12, UiKit.INK_SOFT)
			right.add_child(l)
	return list


static func _reward_view(reward: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_name: String = str({"coins": "coin", "planks": "planks", "crystals": "gem", "tickets": "ticket",
		"cards": "cards", "sparks": "spark"}.get(str(reward["type"]), "chest"))
	var ic := UiKit.icon(icon_name, 26)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var l := UiKit.label("x" + Fmt.n(FarmEvents.scaled(reward, Game.level)), 14, UiKit.INK)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	return row


static func _upcoming_card(run: Dictionary) -> Control:
	var event: String = run["event"]
	var c := EventsPanel._card(Color(FarmEvents.COLORS[event][0], 0.5), 3)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	EventsPanel._body(c).add_child(row)
	row.add_child(UiKit.icon(FarmEvents.icon(event), 34))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	row.add_child(col)
	col.add_child(UiKit.label(FarmEvents.name_of(event), 15))
	var goal := HousePanel.wrapped(_goal_text(event), 11, UiKit.INK_SOFT)
	col.add_child(goal)
	col.add_child(EventsPanel.countdown_label("event.startsIn", float(run["start"]), 11, UiKit.INK_SOFT))
	return c
