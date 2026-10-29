class_name CollectionPanel
extends Sheet
## Коллекция карт: десять созвездий по пять карт (порт CollectionView). Копии поднимают звёзды карты,
## полное созвездие даёт вечный бонус и новый образ героя.

const SKY_TOP := Color("10163a")
const SKY_BOTTOM := Color("2a1f5a")
const CARD_TOP := Color("3a4fa0")
const CARD_BOTTOM := Color("23306a")
const CARD_EMPTY_TOP := Color("5a5560")
const CARD_EMPTY_BOTTOM := Color("3a3640")

## Раскрыта ли подсказка "Как работают карты".
var _guide_open := false


func _init() -> void:
	title_key = "collection.title"


func build() -> void:
	content.add_theme_constant_override("separation", 16)
	var col := Game.collection
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	content.add_child(row)
	row.add_child(_summary("cards", L.t("collection.cards", [col.cards_owned(), Cards.IDS.size()])))
	row.add_child(_summary("spark", L.t("collection.done", [col.complete_count(), Cards.CONSTELLATIONS.size()])))
	_guide()
	for c in Cards.CONSTELLATIONS:
		_constellation_card(c)


func _summary(icon_name: String, text: String) -> PanelContainer:
	var p := PanelContainer.new()
	var s := _list_box(12)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", s)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 6)
	p.add_child(h)
	h.add_child(UiKit.icon(icon_name, 22))
	var l := UiKit.label(text, 14)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(l)
	return p


# MARK: Как работают карты

## Подсказка (CollectionGuide): раскрывается по нажатию.
func _guide() -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _list_box(14))
	content.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)

	var head := Button.new()
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		head.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	head.focus_mode = Control.FOCUS_NONE
	head.custom_minimum_size = Vector2(0, 26)
	head.pressed.connect(func() -> void:
		_guide_open = not _guide_open
		_dirty = true)
	v.add_child(head)
	var hrow := HBoxContainer.new()
	hrow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hrow.add_theme_constant_override("separation", 8)
	hrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(hrow)
	hrow.add_child(UiKit.icon("book", 22))
	var t := UiKit.label(L.t("collection.guide"), 14)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hrow.add_child(t)
	var arrow := UiKit.label("›", 16, UiKit.INK_SOFT)
	arrow.custom_minimum_size = Vector2(16, 16)
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	arrow.pivot_offset = Vector2(8, 8)
	arrow.rotation_degrees = -90.0 if _guide_open else 90.0
	hrow.add_child(arrow)
	if not _guide_open:
		return

	_guide_row(v, "cards", L.t("collection.guide.drop"))
	_guide_row(v, "star", L.t("collection.guide.stars"))
	var steps := HBoxContainer.new()
	steps.add_theme_constant_override("separation", 6)
	v.add_child(steps)
	for i in Cards.THRESHOLDS.size():
		var cell := PanelContainer.new()
		var cs := UiKit.box(UiKit.PARCHMENT_DEEP, Color(0, 0, 0, 0), 8, 0, false)
		cs.set_content_margin_all(4)
		cell.add_theme_stylebox_override("panel", cs)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		steps.add_child(cell)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 2)
		cell.add_child(cv)
		var st := UiKit.stars(i + 1, Cards.THRESHOLDS.size(), 8.0)
		st.alignment = BoxContainer.ALIGNMENT_CENTER
		cv.add_child(st)
		var n := UiKit.label(L.t("collection.copies", [Cards.THRESHOLDS[i]]), 10, UiKit.INK_SOFT)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(n)
	_guide_row(v, "spark", L.t("collection.guide.complete"))
	_guide_row(v, "coins", L.t("collection.guide.bonus"))


func _guide_row(parent: Control, icon_name: String, text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var ic := UiKit.icon(icon_name, 20)
	ic.custom_minimum_size = Vector2(24, 20)
	ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(ic)
	var l := UiKit.label(text, 12)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)


# MARK: Созвездие

func _constellation_card(c: String) -> void:
	var col := Game.collection
	var complete := col.is_complete(c)
	var low := col.min_stars(c)
	var p := PanelContainer.new()
	var ps := UiKit.box(UiKit.PARCHMENT_LIGHT, UiKit.GOLD if complete else Color(UiKit.WOOD_DARK, 0.45), 18,
		3 if complete else 2, false)
	ps.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", ps)
	content.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)

	v.add_child(NightSky.new(c))
	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 6)
	v.add_child(tiles)
	for card in Cards.cards_of(c):
		tiles.add_child(_card_tile(card))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var frame := PanelContainer.new()
	var fs := UiKit.box(UiKit.PARCHMENT_DEEP, Color(UiKit.OUTLINE, 0.6), 10, 2, false)
	fs.set_content_margin_all(4)
	frame.add_theme_stylebox_override("panel", fs)
	frame.custom_minimum_size = Vector2(44, 44)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(frame)
	var skin: String = Cards.SKIN[c]
	var face := WardrobePanel.skin_icon(skin, 34)
	if not complete:
		face.material = HousePanel.gray_material(0.0)
		face.modulate.a = 0.6
	frame.add_child(face)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 2)
	row.add_child(texts)
	texts.add_child(_wrap(Cards.bonus_text(c, Cards.bonus(maxi(1, low))), 12, UiKit.GOOD if complete else UiKit.INK_SOFT))
	var status := ""
	if not complete:
		var missing := 0
		for card in Cards.cards_of(c):
			if col.card_count(card) == 0:
				missing += 1
		status = L.t("collection.missing", [missing])
	elif low < Cards.THRESHOLDS.size():
		status = L.t("collection.nextStar", [Fmt.pct(Cards.bonus(low + 1))])
	else:
		status = L.t("collection.maxed")
	texts.add_child(_wrap(status, 11, UiKit.INK_SOFT))
	texts.add_child(_wrap(L.t("collection.skin", [Skins.name_of(skin)]), 11, UiKit.INK_SOFT))
	if complete:
		row.add_child(HousePanel.check_mark(22))


## Одна карта (CardTile): картинка, звёзды и сколько копий до следующей звезды.
func _card_tile(card: String) -> VBoxContainer:
	var count := Game.collection.card_count(card)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var owned := count > 0
	var frame := Tile.new(CARD_TOP if owned else CARD_EMPTY_TOP, CARD_BOTTOM if owned else CARD_EMPTY_BOTTOM,
		UiKit.GOLD if owned else Color(UiKit.OUTLINE, 0.6), 2.0 if owned else 1.5)
	frame.custom_minimum_size = Vector2(0, 62)
	v.add_child(frame)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(center)
	var pic := _art(card)
	if not owned:
		pic.material = HousePanel.gray_material(0.0)
		pic.modulate.a = 0.25
	center.add_child(pic)
	if not owned:
		var q := UiKit.label("?", 18, Color(1, 1, 1, 0.7))
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		center.add_child(q)
	var st := UiKit.stars(Game.collection.card_stars(card), Cards.THRESHOLDS.size(), 9.0)
	st.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(st)
	var next := Cards.next(count)
	var text := Cards.name_of(card)
	if owned:
		text = "%d/%d" % [count, next] if next > 0 else L.t("common.max")
	var l := UiKit.label(text, 9, UiKit.INK_SOFT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size = Vector2(10, 0)
	v.add_child(l)
	return v


func _art(card: String) -> TextureRect:
	var a := Cards.art(card)
	match str(a[0]):
		"animal": return AnimalsPanel.animal_icon(str(a[1]), 34)
		"monster": return CombatCards.monster_icon(str(a[1]), 34)
	if a[1] == "essence":
		return DungeonPanel.essence_icon(32)
	return UiKit.icon(str(a[1]), 32)


func _list_box(radius: int) -> StyleBoxFlat:
	return UiKit.box(UiKit.PARCHMENT_LIGHT, Color(UiKit.WOOD_DARK, 0.45), radius, 2, false)


func _wrap(text: String, size: int, color := UiKit.INK) -> Label:
	var l := UiKit.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Пятиконечная звезда (star.fill) вокруг точки.
static func star_points(center: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + PI * float(i) / 5.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(center + Vector2(cos(a), sin(a)) * rr)
	return pts


## Подложка карты: заливка сверху вниз и рамка.
class Tile extends PanelContainer:
	var top: Color
	var bottom: Color
	var border: Color
	var width: float

	func _init(a: Color, b: Color, line: Color, w: float) -> void:
		top = a
		bottom = b
		border = line
		width = w
		var s := StyleBoxEmpty.new()
		s.set_content_margin_all(4)
		add_theme_stylebox_override("panel", s)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		if size.x < 4.0 or size.y < 4.0:
			return
		var pts := DungeonPanel.rounded_points(Rect2(Vector2(1, 1), size - Vector2(2, 2)), 9.0)
		var colors := PackedColorArray()
		for p in pts:
			colors.append(top.lerp(bottom, clampf(p.y / size.y, 0.0, 1.0)))
		draw_polygon(pts, colors)
		var line := pts.duplicate()
		line.append(pts[0])
		draw_polyline(line, border, width, true)


## Ночное небо со звёздами созвездия: собранные карты горят золотом.
class NightSky extends Control:
	var constellation := ""

	func _init(c: String) -> void:
		constellation = c
		custom_minimum_size = Vector2(0, 110)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
		var title := UiKit.label(Cards.constellation_name(c), 15, Color.WHITE, 4)
		title.label_settings.outline_color = CollectionPanel.SKY_TOP
		title.position = Vector2(8, 6)
		add_child(title)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w < 4.0 or h < 4.0:
			return
		var col := Game.collection
		var complete := col.is_complete(constellation)
		var pts := DungeonPanel.rounded_points(Rect2(Vector2(1, 1), size - Vector2(2, 2)), 12.0)
		var colors := PackedColorArray()
		for p in pts:
			colors.append(CollectionPanel.SKY_TOP.lerp(CollectionPanel.SKY_BOTTOM, clampf(p.y / h, 0.0, 1.0)))
		draw_polygon(pts, colors)
		# Фоновые звёздочки (одни и те же для каждого созвездия)
		for i in 18:
			var dot := Vector2(w * float((i * 37 + 11) % 100) / 100.0, h * float((i * 53 + 7) % 100) / 100.0)
			draw_rect(Rect2(dot - Vector2(1, 1), Vector2(2, 2)), Color(1, 1, 1, 0.35))
		var shape: Array = Cards.SHAPES.get(constellation, [])
		var cards := Cards.cards_of(constellation)
		for i in range(1, shape.size()):
			var a := Vector2(w * float(shape[i - 1][0]), h * float(shape[i - 1][1]))
			var b := Vector2(w * float(shape[i][0]), h * float(shape[i][1]))
			if complete:
				draw_line(a, b, Color(UiKit.GOLD, 0.8), 2.0, true)
			else:
				draw_dashed_line(a, b, Color(1, 1, 1, 0.22), 1.2, 4.0)
		for i in cards.size():
			var card: String = cards[i]
			var s: Array = shape[mini(i, shape.size() - 1)]
			var center := Vector2(w * float(s[0]), h * float(s[1]))
			if col.card_count(card) > 0:
				var r := (14.0 + float(col.card_stars(card)) * 1.5) / 2.0
				var star := CollectionPanel.star_points(center, r)
				draw_colored_polygon(star, UiKit.GOLD)
				var edge := star.duplicate()
				edge.append(star[0])
				draw_polyline(edge, UiKit.GOLD_DARK, 1.0, true)
			else:
				draw_colored_polygon(CollectionPanel.star_points(center, 5.0), Color(1, 1, 1, 0.3))
		var line := pts.duplicate()
		line.append(pts[0])
		draw_polyline(line, UiKit.OUTLINE, 2.0, true)
