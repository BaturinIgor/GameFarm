class_name AcademyTree
extends VBoxContainer
## Дерево исследований академии: четыре колонки, линии от родителя к ребёнку, под деревом - карточка
## выбранного узла (бонус сейчас и дальше, цена, время, кнопка "Изучить" или ход изучения).

const ROW_H := 104.0
const TOP := 34.0
const R := 26.0
const COLORS := [Color("e0a040"), Color("c85a48"), Color("4f9a5a"), Color("4a86d0")]

var selected := ""
var _on_select: Callable


func _init(pick: String, on_select: Callable) -> void:
	_on_select = on_select
	selected = pick if pick in Academy.IDS else _default_pick()
	add_theme_constant_override("separation", 10)
	var a := Game.academy
	var hint := UiKit.label(L.t("academy.hint", [a.cap()]), 13, UiKit.INK_SOFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)
	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(0, TOP + ROW_H * 4.0 - 20.0)
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(canvas)
	var nodes: Array = []
	for id in Academy.IDS:
		var n := _node(id)
		canvas.add_child(n)
		nodes.append(n)
	canvas.draw.connect(func() -> void: _draw_lines(canvas))
	canvas.resized.connect(func() -> void:
		for n in nodes:
			n.position = pos(n.get_meta("id"), canvas.size.x) - n.size / 2.0
		canvas.queue_redraw())
	add_child(_detail(selected))


func _default_pick() -> String:
	var a := Game.academy
	if a.active() != "":
		return a.active()
	for id in Academy.IDS:
		if a.block(id) == "":
			return id
	return "build"


static func pos(id: String, width: float) -> Vector2:
	var s := Academy.spec(id)
	var cw := width / 4.0
	return Vector2(cw * (float(s["col"]) + 0.5), TOP + R + float(s["row"]) * ROW_H)


## Подписи колонок и линии: сплошная - родитель изучен до 2 уровня, пунктир - ещё нет.
func _draw_lines(canvas: Control) -> void:
	var w := canvas.size.x
	var font := UiKit.font()
	for c in Academy.COLUMNS.size():
		# Подпись колонки ужимается по ширине колонки
		var t := L.t("academy.col." + str(Academy.COLUMNS[c]))
		var fs := TalentsPanel.fit_size(t, w / 4.0 - 6.0, 11, 7)
		var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		canvas.draw_string(font, Vector2(w / 4.0 * (float(c) + 0.5) - tw / 2.0, 14), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			COLORS[c].darkened(0.25))
	for id in Academy.IDS:
		var p := Academy.parent(id)
		if p == "":
			continue
		var a := pos(p, w) + Vector2(0, R + 14)
		var b := pos(id, w) - Vector2(0, R + 2)
		if Game.academy.level(p) >= 2:
			canvas.draw_line(a, b, COLORS[int(Academy.spec(id)["col"])], 4.0, true)
		else:
			canvas.draw_dashed_line(a, b, Color(UiKit.INK_SOFT, 0.35), 3.0, 6.0)


func _node(id: String) -> Control:
	var a := Game.academy
	var n := Control.new()
	n.set_meta("id", id)
	n.custom_minimum_size = Vector2(R * 2.0 + 8.0, R * 2.0 + 22.0)
	n.size = n.custom_minimum_size
	n.mouse_filter = Control.MOUSE_FILTER_PASS
	var col: Color = COLORS[int(Academy.spec(id)["col"])]
	var lvl := a.level(id)
	var open := a.unlocked(id)
	var on := id == selected
	var busy := a.active() == id
	n.draw.connect(func() -> void:
		var c := Vector2(n.size.x / 2.0, R + 4.0)
		var fill := col if lvl > 0 else (UiKit.PARCHMENT_LIGHT if open else Color(UiKit.PARCHMENT_DEEP, 0.7))
		n.draw_circle(c + Vector2(0, 3), R, Color(UiKit.WOOD_DARK, 0.35))
		n.draw_circle(c, R, fill)
		n.draw_arc(c, R, 0.0, TAU, 40, UiKit.GOLD if on or busy else UiKit.OUTLINE, 4.0 if on or busy else 2.5, true))
	var ic := UiKit.icon(Academy.icon(id), 28)
	ic.position = Vector2(n.size.x / 2.0 - 14.0, R + 4.0 - 14.0)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not open:
		ic.modulate = Color(1, 1, 1, 0.4)
	n.add_child(ic)
	var t := UiKit.label("%d/%d" % [lvl, Academy.max_level(id)], 12, UiKit.INK if open else UiKit.INK_SOFT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.size = Vector2(n.size.x, 16)
	t.position = Vector2(0, R * 2.0 + 6.0)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.add_child(t)
	if busy:
		var hg := UiKit.icon("hourglass", 18)
		hg.position = Vector2(n.size.x - 18.0, 0)
		hg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		n.add_child(hg)
	# Короткое касание выбирает узел (прокрутка не считается)
	var press := [Vector2.ZERO]
	n.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			press[0] = mb.global_position
		elif mb.global_position.distance_to(press[0]) < 10.0:
			Sound.play("tap")
			_on_select.call(id))
	return n


## Карточка выбранного исследования.
func _detail(id: String) -> PanelContainer:
	var a := Game.academy
	var p := PanelContainer.new()
	var st := UiKit.box(UiKit.PARCHMENT_LIGHT, Color(UiKit.WOOD_DARK, 0.5), 14, 2, false)
	st.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", st)
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 8)
	p.add_child(c)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	c.add_child(top)
	var ic := UiKit.icon(Academy.icon(id), 32)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(ic)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	top.add_child(col)
	var n := a.level(id)
	col.add_child(UiKit.label(Academy.name_of(id), 16))
	var info := UiKit.label(L.t("academy.%s.info" % id), 12, UiKit.INK_SOFT)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(info)
	top.add_child(HousePanel.level_tag(n, true))
	c.add_child(UiKit.label(L.t("academy.effect", [Academy.bonus_text(id, n),
		Academy.bonus_text(id, mini(Academy.max_level(id), n + 1))]), 13))
	if a.active() == id:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		c.add_child(row)
		var left := func() -> String: return L.t("academy.studying", [House.countdown(Game.academy.left())])
		var live := CombatCards.LiveLabel.new(left, 13, UiKit.INK)
		live.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		live.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(live)
		var fast := MapPanel.icon_button([["i", "gem"], ["t", str(a.speedup_cost())]], "purple", 13)
		fast.pressed.connect(func() -> void:
			if not Game.academy.speed_up():
				Game.show_toast("px:gem", L.t("crystals.notEnough", [Fmt.n(Game.academy.speedup_cost() - Game.shop.crystals())])))
		row.add_child(fast)
		return p
	if n >= Academy.max_level(id):
		c.add_child(UiKit.label(L.t("academy.block.max"), 12, UiKit.INK_SOFT))
		return p
	var why := a.block(id)
	if why == "academy.block.locked":
		var req := Academy.parent(id)
		var lvl_need := int(Academy.ROW_LEVEL[Academy.row(id)])
		var text := L.t("academy.needLevel", [lvl_need]) if Game.estate.level("academy") < lvl_need \
			else L.t("academy.needParent", [Academy.name_of(req)])
		var l := UiKit.label(text, 12, UiKit.BAD)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c.add_child(l)
		return p
	var cost_row := HBoxContainer.new()
	cost_row.add_theme_constant_override("separation", 8)
	c.add_child(cost_row)
	var cv := UiKit.cost_view(Academy.cost(id, n + 1), 12)
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_row.add_child(cv)
	cost_row.add_child(UiKit.label(EventsPanel.long_countdown(Academy.seconds(id, n + 1)), 12, UiKit.INK_SOFT))
	if why == "academy.block.cap" or why == "academy.block.busy":
		c.add_child(UiKit.label(L.t(why), 12, UiKit.INK_SOFT))
	var b := UiKit.button(L.t("academy.study"), "green", 14)
	b.disabled = why != ""
	b.pressed.connect(func() -> void: Game.academy.start(id))
	c.add_child(b)
	return p
