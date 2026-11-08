class_name AllianceUi
extends RefCounted
## Крупные элементы окна альянса: плитки разделов, круглые значки талантов, аватары и пузыри чата.
## Окно собирает из них экраны, чтобы вместо полотна текста были картинки, числа и одна строка подписи.


## Плитка раздела: большой значок, название, короткая подпись и счётчик в углу.
static func tile(icon_name: String, title: String, sub: String, count: int, on_tap: Callable, tint := UiKit.PARCHMENT_LIGHT) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 104)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var normal := UiKit.box(tint, Color(UiKit.WOOD_DARK, 0.6), 14, 2, true)
	var pressed := UiKit.box(tint.darkened(0.08), Color(UiKit.WOOD_DARK, 0.8), 14, 2, false)
	for st in ["normal", "hover", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, normal)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var ic := UiKit.icon_any(icon_name, 40)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(ic)
	var t := UiKit.label(title, 14)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.clip_text = true
	v.add_child(t)
	if sub != "":
		var s := UiKit.label(sub, 11, UiKit.INK_SOFT)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		s.clip_text = true
		v.add_child(s)
	if count > 0:
		UiKit.pin_badge(UiKit.count_badge(count), b)
	b.pressed.connect(on_tap)
	return b


## Сетка плиток в два столбца.
static func grid(columns := 2) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	return g


## Шапка раздела: кнопка «назад» и название.
static func back_row(title: String, on_back: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var back := UiKit.button("‹", "wood", 18, true)
	back.custom_minimum_size = Vector2(44, 38)
	back.pressed.connect(on_back)
	row.add_child(back)
	var t := UiKit.label(title, 17)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(t)
	return row


## Строка «значок + число» для показателей вместо фраз.
static func stat(icon_name: String, value: String, color := UiKit.INK, size := 13) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	var ic := UiKit.icon_any(icon_name, size + 3)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	h.add_child(UiKit.label(value, size, color))
	return h


## Круглый аватар: цвет и буква от имени (одинаковые у одного игрока на всех экранах).
static func avatar(name: String, size := 34.0, role := "") -> Control:
	var a := Avatar.new()
	a.who = name
	a.role = role
	a.custom_minimum_size = Vector2(size, size)
	a.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return a


const AVATAR_COLORS := ["e07a5f", "3d85c6", "6aa84f", "c27ba0", "f1c232", "8e7cc3", "45818e", "e69138", "a64d79", "76a5af"]


static func color_of(name: String) -> Color:
	return Color(AVATAR_COLORS[absi(name.hash()) % AVATAR_COLORS.size()])


class Avatar extends Control:
	var who := ""
	var role := ""

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := UiKit.label(who.left(1).to_upper() if who != "" else "?", int(custom_minimum_size.x * 0.45), Color.WHITE, 3)
		l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(l)
		if role == "leader" or role == "officer":
			var ic := UiKit.icon("crown" if role == "leader" else "star", custom_minimum_size.x * 0.42)
			ic.position = Vector2(custom_minimum_size.x * 0.62, -custom_minimum_size.x * 0.12)
			add_child(ic)

	func _draw() -> void:
		var r := size.x / 2.0
		draw_circle(size / 2.0, r, UiKit.OUTLINE)
		draw_circle(size / 2.0, r - 2.0, AllianceUi.color_of(who))


## Круглый значок таланта: кольцо заполняется рангами, число ранга снизу, закрытый - серый с замком.
class TalentOrb extends Button:
	var icon_name := ""
	var rank := 0
	var max_rank := 15
	var progress := 0.0
	var locked := false
	var selected := false
	const SIDE := 50.0

	func _init() -> void:
		focus_mode = Control.FOCUS_NONE
		flat = true
		custom_minimum_size = Vector2(SIDE, SIDE + 10)
		var empty := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			add_theme_stylebox_override(st, empty)

	func _ready() -> void:
		var ic := UiKit.icon(icon_name, 26)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.position = Vector2((size.x - 26) / 2.0, (SIDE - 26) / 2.0)
		if locked:
			ic.modulate = Color(0.35, 0.35, 0.35, 0.7)
		add_child(ic)
		resized.connect(func() -> void: ic.position = Vector2((size.x - 26) / 2.0, (SIDE - 26) / 2.0))
		if not locked:
			var p := PanelContainer.new()
			var s := UiKit.box(UiKit.GOLD if rank >= max_rank else UiKit.WOOD_DARK, UiKit.OUTLINE, 8, 1, false)
			s.content_margin_left = 5
			s.content_margin_right = 5
			s.content_margin_top = 0
			s.content_margin_bottom = 0
			p.add_theme_stylebox_override("panel", s)
			p.mouse_filter = Control.MOUSE_FILTER_IGNORE
			p.add_child(UiKit.label(str(rank), 10, UiKit.INK if rank >= max_rank else Color.WHITE))
			add_child(p)
			var place := func() -> void: p.position = Vector2((size.x - p.size.x) / 2.0, SIDE - 8)
			p.resized.connect(place)
			resized.connect(place)

	func _draw() -> void:
		var c := Vector2(size.x / 2.0, SIDE / 2.0)
		var r := SIDE / 2.0 - 2.0
		if selected:
			draw_circle(c, r + 3.0, UiKit.GOLD)
		draw_circle(c, r, UiKit.OUTLINE)
		var fill := Color("cfc6b8") if locked else (Color("f7e7b0") if rank >= max_rank else UiKit.PARCHMENT_LIGHT)
		draw_circle(c, r - 2.0, fill)
		if not locked:
			draw_arc(c, r - 4.0, 0, TAU, 48, Color(UiKit.WOOD_DARK, 0.18), 4.0, true)
			var part := float(rank) / float(max_rank)
			if part > 0.0:
				draw_arc(c, r - 4.0, -PI / 2.0, -PI / 2.0 + TAU * part, 48, UiKit.GOOD if rank < max_rank else UiKit.GOLD_DARK, 4.0, true)
