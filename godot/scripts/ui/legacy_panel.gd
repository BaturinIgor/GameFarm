class_name LegacyPanel
extends Sheet
## Вечные бонусы наследия за искры (порт LegacyView, LegacyRow, SparkBadge).
## Здесь же карточка наследия для окна профиля.

const LILAC := Color("ede2fa")


func _init() -> void:
	title_key = "legacy.title"


func build() -> void:
	content.add_theme_constant_override("separation", 16)
	_sparks_card()
	section_title(L.t("legacy.perks"))
	for perk in Legacy.PERKS:
		_perk_row(perk)
	var hint := _wrap(L.t("legacy.hint"), 12, UiKit.INK_SOFT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(hint)


# MARK: Искры

func _sparks_card() -> void:
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
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	var text := _wrap(L.t("legacy.text"), 13, UiKit.INK_SOFT)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(text)
	var badge := spark_badge(Game.legacy.sparks())
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(badge)
	if Game.level >= Story.MIN_LEVEL:
		var go := UiKit.button(L.t("legacy.toAltar"), "purple", 15)
		go.pressed.connect(func() -> void:
			if Hud.current != null:
				Hud.current.open_window(StoryPanel.new("altar")))
		v.add_child(go)


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


## Карточка наследия для окна профиля: сколько искр и кнопка в это окно.
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
	col.add_child(UiKit.label(L.t("legacy.title"), 16))
	var sub := UiKit.label(L.t("legacy.short"), 12, UiKit.INK_SOFT)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(sub)
	row.add_child(spark_badge(Game.legacy.sparks()))
	var open := UiKit.button(L.t("legacy.open"), "purple", 15)
	open.pressed.connect(func() -> void:
		if Hud.current != null:
			Hud.current.open_window(LegacyPanel.new()))
	v.add_child(open)
	return p
