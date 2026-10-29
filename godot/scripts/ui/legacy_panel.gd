class_name LegacyPanel
extends Sheet
## Перерождение и вечные бонусы наследия (порт LegacyView, LegacyRow, SparkBadge).
## Здесь же карточка перерождения для окна профиля (rebirthCard из LevelView).

const LILAC := Color("ede2fa")


func _init() -> void:
	title_key = "rebirth.title"


func build() -> void:
	content.add_theme_constant_override("separation", 16)
	_rebirth_card()
	section_title(L.t("legacy.title"))
	for perk in Legacy.PERKS:
		_perk_row(perk)
	var hint := _wrap(L.t("legacy.hint"), 12, UiKit.INK_SOFT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(hint)


# MARK: Перерождение

func _rebirth_card() -> void:
	var reward := Game.legacy.rebirth_reward()
	var p := PanelContainer.new()
	var ps := UiKit.box(UiKit.PARCHMENT_LIGHT, _purple(1), 18, 4, false)
	ps.content_margin_left = 16
	ps.content_margin_right = 16
	ps.content_margin_top = 10
	ps.content_margin_bottom = 14
	p.add_theme_stylebox_override("panel", ps)
	content.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(_ribbon(L.t("rebirth.title")))

	var head := HBoxContainer.new()
	v.add_child(head)
	var count := UiKit.label(L.t("rebirth.count", [Game.legacy.rebirths()]), 14)
	count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(count)
	head.add_child(spark_badge(Game.legacy.sparks()))
	v.add_child(_wrap(L.t("rebirth.text"), 13, UiKit.INK_SOFT))

	var keep := HBoxContainer.new()
	keep.add_theme_constant_override("separation", 6)
	v.add_child(keep)
	keep.add_child(HousePanel.check_mark(16))
	var keep_text := _wrap(L.t("rebirth.keep"), 12, UiKit.GOOD)
	keep_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keep.add_child(keep_text)
	var lose := HBoxContainer.new()
	lose.add_theme_constant_override("separation", 6)
	v.add_child(lose)
	lose.add_child(_reset_mark(16))
	var lose_text := _wrap(L.t("rebirth.lose"), 12, UiKit.TONES["red"][2])
	lose_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lose.add_child(lose_text)

	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiKit.box(LILAC, Color(_purple(1), 0.5), 12, 2, false))
	v.add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	if Game.level >= Legacy.MIN_LEVEL:
		var t := UiKit.label(L.t("rebirth.reward"), 14)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(t)
		var ic := UiKit.icon("spark", 22)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)
		row.add_child(UiKit.label("+" + Fmt.n(reward), 18))
	else:
		var key := UiKit.icon("key", 18)
		key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(key)
		var locked := _wrap(L.t("rebirth.locked", [Legacy.MIN_LEVEL]), 13, UiKit.TONES["orange"][2])
		locked.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(locked)

	var go := UiKit.button(L.t("rebirth.action"), "purple", 16)
	go.pressed.connect(func() -> void: LegacyPanel.confirm_rebirth())
	v.add_child(go)


## Лента с названием карточки (RibbonTitle).
func _ribbon(text: String) -> PanelContainer:
	var r := PanelContainer.new()
	var s := UiKit.box(_purple(1), UiKit.OUTLINE, 12, 3, false)
	s.shadow_color = _purple(2)
	s.shadow_offset = Vector2(0, 3)
	s.shadow_size = 1
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	r.add_theme_stylebox_override("panel", s)
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UiKit.title(text, 17)
	l.label_settings.outline_color = _purple(2)
	r.add_child(l)
	return r


## Значок "сбросится": красный кружок со стрелкой по кругу.
func _reset_mark(side: float) -> Control:
	var m := Control.new()
	m.custom_minimum_size = Vector2(side, side)
	m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.draw.connect(func() -> void:
		var r := side / 2.0
		var c := Vector2(r, r)
		m.draw_circle(c, r, Color.WHITE)
		m.draw_circle(c, r - 1.5, UiKit.TONES["red"][1])
		var ar := r * 0.48
		var w := maxf(1.5, side * 0.11)
		m.draw_arc(c, ar, -PI * 0.15, PI * 1.35, 16, Color.WHITE, w, true)
		var tip := c + Vector2(cos(-PI * 0.15), sin(-PI * 0.15)) * ar
		m.draw_colored_polygon(PackedVector2Array([tip + Vector2(-r * 0.32, -r * 0.05), tip + Vector2(r * 0.22, -r * 0.3),
			tip + Vector2(r * 0.12, r * 0.28)]), Color.WHITE))
	return m


## "Начать ферму заново?": сколько искр дадут, отменить нельзя.
static func confirm_rebirth() -> void:
	if Hud.current == null:
		return
	var reward := Game.legacy.rebirth_reward()
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = UiKit.DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			layer.queue_free())
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	var box := PanelContainer.new()
	var st := UiKit.panel_style(18)
	st.set_content_margin_all(20)
	box.add_theme_stylebox_override("panel", st)
	box.custom_minimum_size = Vector2(300, 0)
	center.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	box.add_child(v)
	var ic := UiKit.icon("spark", 44)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var title := UiKit.label(L.t("rebirth.confirm"), 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(title)
	var msg := UiKit.label(L.t("rebirth.confirm.message", [reward]), 13, UiKit.INK_SOFT)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(msg)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	v.add_child(buttons)
	var cancel := UiKit.button(L.t("common.cancel"), "wood", 15)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(layer.queue_free)
	buttons.add_child(cancel)
	var ok := UiKit.button(L.t("rebirth.action"), "purple", 15)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(func() -> void:
		layer.queue_free()
		if Hud.current != null:
			Hud.current.close_window()
		Game.legacy.rebirth())
	buttons.add_child(ok)
	Hud.current.show_overlay(layer)


# MARK: Наследие

## Строка бонуса (LegacyRow): что даёт сейчас, что даст следующий ранг и цена в искрах.
func _perk_row(perk: String) -> void:
	var rank := Game.legacy.rank(perk)
	var top := Legacy.max_rank(perk)
	var maxed := rank >= top
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.box(UiKit.PARCHMENT_LIGHT,
		Color(_purple(1), 0.7) if rank > 0 else Color(UiKit.WOOD_DARK, 0.45), 14, 3 if rank > 0 else 2, false))
	content.add_child(p)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	p.add_child(row)

	var frame := PanelContainer.new()
	var fs := UiKit.box(LILAC if rank > 0 else Color(UiKit.PARCHMENT_DEEP, 0.7), Color(UiKit.OUTLINE, 0.6), 12, 2, false)
	fs.set_content_margin_all(8)
	frame.add_theme_stylebox_override("panel", fs)
	frame.custom_minimum_size = Vector2(50, 50)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(UiKit.icon(Legacy.icon(perk), 30))
	row.add_child(frame)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 3)
	row.add_child(col)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	col.add_child(name_row)
	var n := UiKit.label(Legacy.name_of(perk), 15)
	n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	n.clip_text = true
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(n)
	name_row.add_child(AnimalsPanel.pill("%d/%d" % [rank, top], UiKit.PARCHMENT_DEEP, UiKit.INK, 11,
		Color(UiKit.WOOD_DARK, 0.4)))
	if rank > 0:
		col.add_child(_wrap(L.t("legacy.now", [Legacy.effect(perk, rank)]), 12))
	if not maxed:
		col.add_child(_wrap(L.t("legacy.next", [Legacy.effect(perk, rank + 1)]), 12, UiKit.INK_SOFT))

	if maxed:
		var m := UiKit.label(L.t("common.max"), 12, UiKit.GOOD)
		m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(m)
		return
	var buy := UiKit.button(Fmt.n(Legacy.cost(perk, rank)), "purple", 13, true)
	buy.icon = Sprites.icon("spark")
	buy.add_theme_constant_override("icon_max_width", 16)
	buy.add_theme_constant_override("h_separation", 3)
	buy.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy.disabled = not Game.legacy.can_buy_legacy(perk)
	buy.pressed.connect(func() -> void:
		if Game.legacy.buy_legacy(perk):
			Input.vibrate_handheld(20))
	row.add_child(buy)


func _wrap(text: String, size: int, color := UiKit.INK) -> Label:
	var l := UiKit.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


# MARK: Общие элементы

## Фиолетовый тон кнопок: 0 - верх, 1 - основа, 2 - тень.
static func _purple(i: int) -> Color:
	return UiKit.TONES["purple"][i]


## Сколько искр у игрока (SparkBadge).
static func spark_badge(sparks: int) -> PanelContainer:
	var p := PanelContainer.new()
	var s := UiKit.box(_purple(1), UiKit.OUTLINE, 14, 2, false)
	s.content_margin_left = 6
	s.content_margin_right = 10
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", s)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	p.add_child(row)
	row.add_child(UiKit.icon("spark", 18))
	var l := UiKit.label(Fmt.n(sparks), 15, Color.WHITE, 4)
	l.label_settings.outline_color = _purple(2)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	return p


## Карточка перерождения для окна профиля (rebirthCard из LevelView): искры за забег и кнопка в это окно.
static func profile_card() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.box(UiKit.PARCHMENT_LIGHT, _purple(1), 14, 3, false))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var ic := UiKit.icon("spark", 36)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	col.add_child(UiKit.label(L.t("rebirth.title"), 16))
	var sub_text := L.t("rebirth.short", [Game.legacy.rebirth_reward()]) if Game.level >= Legacy.MIN_LEVEL \
		else L.t("rebirth.locked", [Legacy.MIN_LEVEL])
	var sub := UiKit.label(sub_text, 12, UiKit.INK_SOFT)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(sub)
	row.add_child(spark_badge(Game.legacy.sparks()))
	var open := UiKit.button(L.t("legacy.open"), "purple", 15)
	open.pressed.connect(func() -> void:
		if Hud.current != null:
			Hud.current.open_window(LegacyPanel.new()))
	v.add_child(open)
	return p
