class_name UiKit
## Стиль интерфейса как в iOS-версии: пергамент, дерево, тёмный контур, белые буквы с обводкой.

const PARCHMENT := Color("f4e4c1")
const PARCHMENT_LIGHT := Color("fbf1dc")
const PARCHMENT_DEEP := Color("e7cf9f")
const WOOD := Color("a0673a")
const WOOD_LIGHT := Color("c48a55")
const WOOD_DARK := Color("5e3a1f")
const OUTLINE := Color("2b1a0f")
const INK := Color("3b2416")
const INK_SOFT := Color("7b5b40")
const GOLD := Color("f7c948")
const GOLD_DARK := Color("c98a1b")
const GOOD := Color("3e8e3a")
const BAD := Color("c0392b")
const DIM := Color(0.1, 0.06, 0.03, 0.55)

## Цвета кнопок: верх, основа, низ (тень).
const TONES := {
	"green": [Color("8bd45a"), Color("5cb338"), Color("3a7d22")],
	"orange": [Color("ffb04a"), Color("f08a1c"), Color("b35f0a")],
	"red": [Color("f0725e"), Color("d9483a"), Color("962a1f")],
	"blue": [Color("6cc3f2"), Color("3a9ad9"), Color("21679b")],
	"purple": [Color("b58bf0"), Color("8a5ad9"), Color("5a3596")],
	"gold": [Color("ffe07a"), Color("f2b632"), Color("a8740f")],
	"wood": [Color("d29a62"), Color("a0673a"), Color("6b4122")],
	"gray": [Color("bdb3a6"), Color("958a7c"), Color("665c50")],
}

static var _font: Font


static func font() -> Font:
	if _font == null:
		_font = preload("res://fonts/Nunito-900.ttf")
	return _font


static func box(fill: Color, border := OUTLINE, radius := 16, width := 3, shadow := true) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	if shadow:
		s.shadow_color = Color(WOOD_DARK, 0.45)
		s.shadow_offset = Vector2(0, 3)
		s.shadow_size = 0
	s.anti_aliasing = true
	return s


static func panel_style(radius := 18) -> StyleBoxFlat:
	return box(PARCHMENT, OUTLINE, radius, 3)


## Подпись: белая с обводкой (title) или тёмная на пергаменте.
static func label(text: String, size := 14, color := INK, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font = font()
	ls.font_size = size
	ls.font_color = color
	if outline > 0:
		ls.outline_size = outline
		ls.outline_color = OUTLINE
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func title(text: String, size := 18) -> Label:
	return label(text, size, Color.WHITE, 6)


## Кнопка в игровом стиле: цветная "таблетка" с тенью снизу.
static func button(text: String, tone := "green", size := 15, small := false) -> Button:
	var b := Button.new()
	b.text = text
	var c: Array = TONES.get(tone, TONES["green"])
	var r := 12 if small else 14
	var normal := box(c[1], OUTLINE, r, 3, false)
	normal.shadow_color = c[2]
	normal.shadow_offset = Vector2(0, 4)
	normal.shadow_size = 1
	normal.content_margin_top = 6 if small else 9
	normal.content_margin_bottom = 6 if small else 9
	var pressed := normal.duplicate()
	pressed.bg_color = c[2].lerp(c[1], 0.5)
	pressed.shadow_offset = Vector2(0, 1)
	var hover := normal.duplicate()
	hover.bg_color = c[0].lerp(c[1], 0.5)
	var disabled := normal.duplicate()
	disabled.bg_color = TONES["gray"][1]
	disabled.shadow_color = TONES["gray"][2]
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_override("font", font())
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.7))
	b.add_theme_color_override("font_outline_color", OUTLINE)
	b.add_theme_constant_override("outline_size", 5)
	b.focus_mode = Control.FOCUS_NONE
	return b


## Иконка из спрайтов (ic_<имя>) в интерфейсе, без сглаживания.
static func icon(name: String, size := 24.0) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Sprites.icon(name)
	t.custom_minimum_size = Vector2(size, size)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Иконка по строке как IconView в iOS: "px:имя", "res:вид", "an:зверь", иначе текст (эмодзи).
static func icon_any(code: String, size := 22.0) -> Control:
	if code.begins_with("px:"):
		return icon(code.substr(3), size)
	if code.begins_with("res:"):
		return icon(code.substr(4), size)
	if code.begins_with("an:"):
		var t := icon("paw", size)
		var tex := AnimalSheet.icon(code.substr(3))
		if tex != null:
			t.texture = tex
		return t
	var l := label(code, int(size * 0.8), INK)
	l.custom_minimum_size = Vector2(size, size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


## Полоска прогресса (GameBar): тон из TONES, подпись поверх по центру.
static func bar(value: float, tone := "green", width := 120.0, height := 12.0, text := "") -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(width, height)
	b.show_percentage = false
	b.max_value = 1.0
	b.step = 0.0
	b.value = clampf(value, 0.0, 1.0)
	var r := int(height / 2.0)
	var bg := box(Color(WOOD_DARK, 0.85), OUTLINE, r, 2, false)
	bg.set_content_margin_all(0)
	var c: Array = TONES.get(tone, TONES["green"])
	var fill := box(c[1], Color(0, 0, 0, 0), r, 0, false)
	fill.set_content_margin_all(0)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fill)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if text != "":
		var l := label(text, maxi(9, int(height * 0.8)), Color.WHITE, 4)
		l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b.add_child(l)
	return b


## Цена (CostView): монеты и ресурсы "есть/нужно", красным то, чего не хватает.
static func cost_view(cost: Dictionary, size := 13) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 4)
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var coins := int(cost.get("coins", 0))
	if coins > 0:
		flow.add_child(_chip("coins", Fmt.n(coins), int(Game.save["coins"]) >= coins, size))
	for it in cost.get("items", []):
		var have := Game.amount(it[0])
		flow.add_child(_chip(it[0], "%s/%s" % [Fmt.n(have), Fmt.n(int(it[1]))], have >= int(it[1]), size))
	return flow


static func _chip(icon_name: String, text: String, ok: bool, size: int) -> PanelContainer:
	var p := PanelContainer.new()
	var s := box(Color(1, 1, 1, 0.55) if ok else Color(BAD, 0.15), Color(OUTLINE, 0.35), 9, 1, false)
	s.content_margin_left = 5
	s.content_margin_right = 7
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	p.add_child(row)
	row.add_child(icon(icon_name, size + 4))
	row.add_child(label(text, size, INK if ok else BAD))
	return p


## Звёзды зверя: закрашено stars из total.
static func stars(n: int, total := 5, size := 12.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in total:
		var t := icon("star", size)
		if i >= n:
			t.modulate = Color(0.3, 0.25, 0.2, 0.35)
		row.add_child(t)
	return row


## Красный кружок со счётчиком (CountBadge).
static func count_badge(n: int) -> PanelContainer:
	var p := PanelContainer.new()
	var s := box(TONES["red"][1], OUTLINE, 10, 2, false)
	s.content_margin_left = 5
	s.content_margin_right = 5
	s.content_margin_top = 0
	s.content_margin_bottom = 0
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size = Vector2(20, 20)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label(str(n), 11, Color.WHITE, 3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


## Деревянная "плашка" (счётчики в шапке).
static func pill_style() -> StyleBoxFlat:
	var s := box(Color(WOOD, 0.95), OUTLINE, 14, 2, false)
	s.content_margin_left = 8
	s.content_margin_right = 10
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


## Отступы безопасной зоны (вырез камеры) в координатах интерфейса.
static func safe_insets(viewport: Viewport) -> Dictionary:
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	var vp := viewport.get_visible_rect().size
	if win.x <= 0 or win.y <= 0 or safe.size == Vector2i.ZERO:
		return {"top": 0.0, "bottom": 0.0}
	var k := vp.y / float(win.y)
	return {"top": maxf(0.0, safe.position.y * k), "bottom": maxf(0.0, (win.y - safe.end.y) * k)}
