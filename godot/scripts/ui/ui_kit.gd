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

## Цвета кнопок как ButtonTone в iOS: верх, основа, губа (низ).
const TONES := {
	"green": [Color("8bd45a"), Color("4fa83a"), Color("2e6e25")],
	"orange": [Color("ffb04a"), Color("f0821e"), Color("a5520e")],
	"red": [Color("f0725e"), Color("d2412f"), Color("8a2419")],
	"blue": [Color("6cc3f2"), Color("2f8fd0"), Color("1c5a8a")],
	"purple": [Color("b58bf0"), Color("7c55c9"), Color("4d3285")],
	"gold": [Color("ffe07a"), Color("f0b22e"), Color("a8721a")],
	"wood": [Color("d29a62"), Color("a0673a"), Color("5e3a1f")],
	"gray": [Color("bdb3a6"), Color("958a7e"), Color("5f574f")],
}

static var _font: Font
static var _pixel_mat: ShaderMaterial
## Пиксельный рисунок при любом масштабе: все пиксели одного размера, края сглажены на один пиксель экрана
## (при обычном ближайшем пикселе картинка 16x16 размером 22 точки выходит "кривой" - пиксели разной ширины).
const PIXEL_SHADER := """shader_type canvas_item;
varying vec4 tint;
void vertex() {
	tint = COLOR;
}
void fragment() {
	vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 pix = UV * size;
	vec2 seam = floor(pix + 0.5);
	vec2 dudv = max(fwidth(pix), vec2(0.0001));
	pix = seam + clamp((pix - seam) / dudv, vec2(-0.5), vec2(0.5));
	COLOR = texture(TEXTURE, pix / size) * tint;
}
"""
static var _body_font: Font


static func font() -> Font:
	if _font == null:
		# load, а не preload: при чистом импорте шрифт ещё не готов, когда скрипты уже разбираются
		_font = load("res://fonts/Nunito-900.ttf")
		_fallback_code = "-"
	_sync_fallbacks()
	return _font


## Шрифт пояснений (серый текст): полегче, как .semibold в iOS.
static func body_font() -> Font:
	if _body_font == null:
		_body_font = load("res://fonts/Nunito-700.ttf")
		_fallback_code = "-"
	_sync_fallbacks()
	return _body_font


# MARK: Шрифты-замены

## В Nunito нет японского, корейского, китайского и хинди - их буквы берутся из шрифтов-замен
## (tools/make_fallback_fonts.py), тайский и эмодзи - из системы телефона. Иначе вместо букв квадратики.
const FALLBACK_FONTS := {"ja": "NotoSansJP-Bold-sub.otf", "ko": "NotoSansKR-Bold-sub.otf",
	"zh-Hans": "NotoSansSC-Bold-sub.otf", "zh-Hant": "NotoSansTC-Bold-sub.otf"}
const DEVANAGARI_FONT := "Poppins-Devanagari-sub.ttf"
static var _fallback_code := "-"
static var _fallback_fonts: Dictionary = {}
static var _system: SystemFont


static func _fallback_font(file: String) -> Font:
	if not _fallback_fonts.has(file):
		var path := "res://fonts/" + file
		_fallback_fonts[file] = load(path) if ResourceLoader.exists(path) else null
	return _fallback_fonts[file]


## Замены по порядку: у японского, китайского и корейского одни и те же знаки рисуются по-разному,
## поэтому шрифт текущего языка - первым.
static func _sync_fallbacks() -> void:
	if _fallback_code == L.code:
		return
	_fallback_code = L.code
	var order: Array = ["ja", "ko", "zh-Hans", "zh-Hant"]
	if L.code in order:
		order.erase(L.code)
		order.push_front(L.code)
	var list: Array[Font] = []
	var dev := _fallback_font(DEVANAGARI_FONT)
	if dev != null:
		list.append(dev)
	for c in order:
		var f := _fallback_font(str(FALLBACK_FONTS[c]))
		if f != null:
			list.append(f)
	if _system == null:
		_system = SystemFont.new()
		_system.font_names = PackedStringArray(["Noto Sans Thai", "Noto Sans Thai UI", "Thonburi", "Sukhumvit Set",
			"Leelawadee UI", "Tahoma", "sans-serif"])
		_system.font_weight = 700
	list.append(_system)
	for main in [_font, _body_font]:
		if main != null:
			(main as Font).fallbacks = list


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


## Пергамент в деревянной рамке с жёсткой тенью (gamePanel в iOS).
static func panel_style(radius := 18) -> GameStyle:
	var s := GameStyle.make(PARCHMENT, PARCHMENT, float(radius))
	s.border_width = 4.0
	s.border_color = WOOD
	s.shadow_offset = 4.0
	s.shadow_color = Color(OUTLINE, 0.45)
	s.set_content_margin_all(14)
	return s


## Подпись: белая с обводкой (title) или тёмная на пергаменте.
static func label(text: String, size := 14, color := INK, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	# Серые пояснения - полегче, как в iOS; названия и заголовки - жирные
	ls.font = body_font() if (outline == 0 and color == INK_SOFT) else font()
	ls.font_size = size
	ls.font_color = color
	if outline > 0:
		ls.outline_size = outline
		ls.outline_color = OUTLINE
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Палец (кнопка мыши) сейчас нажат над этим элементом: перестраивать его нельзя, иначе нажатие потеряется.
static func touch_held(c: Control) -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and c.get_global_rect().has_point(c.get_global_mouse_position())


## Уменьшить шрифт подписи, чтобы текст влез в ширину (как minimumScaleFactor в iOS).
static func fit_label(l: Label, width: float, max_size: int, min_size := 7) -> void:
	var fs := max_size
	while fs > min_size and font().get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
		fs -= 1
	l.label_settings.font_size = fs


## Заголовок: белые буквы с обводкой (gameTitle в iOS: обводка тоньше у мелкого текста).
static func title(text: String, size := 18) -> Label:
	return label(text, size, Color.WHITE, 5 if size >= 20 else 4)


## Кнопка в игровом стиле (GameButton): градиент, светлая полоска, контур и губа снизу, как в iOS.
static func button(text: String, tone := "green", size := 15, small := false) -> GameButton:
	var b := GameButton.new(tone, small, size)
	b.text = text
	return b


## Деревянные вкладки (GameTabs): светлая дорожка, выбранная вкладка - деревянная плашка.
## items = [[id, подпись, счётчик, иконка], ...] (счётчик и иконка - по желанию); on_select(id).
## С иконками вкладки выше: иконка над подписью, счётчик - в углу.
static func tabs(items: Array, selected: String, on_select: Callable) -> PanelContainer:
	var track := PanelContainer.new()
	var ts := box(PARCHMENT_DEEP, Color(WOOD_DARK, 0.5), 13, 2, false)
	ts.set_content_margin_all(4)
	track.add_theme_stylebox_override("panel", ts)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	track.add_child(row)
	for it in items:
		var id: String = it[0]
		var on := id == selected
		var icon_name := str(it[3]) if it.size() > 3 else ""
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 50 if icon_name != "" else 34)
		var st: StyleBox = StyleBoxEmpty.new()
		if on:
			var g := GameStyle.make(WOOD_LIGHT, WOOD, 10.0)
			g.outline_width = 1.5
			st = g
		for k in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(k, st)
		var inner: BoxContainer = VBoxContainer.new() if icon_name != "" else HBoxContainer.new()
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.add_theme_constant_override("separation", 1 if icon_name != "" else 4)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(inner)
		if icon_name != "":
			var ic := icon(icon_name, 22)
			ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			if not on:
				ic.modulate = Color(1, 1, 1, 0.8)
			inner.add_child(ic)
		var l := label(str(it[1]), 11 if icon_name != "" else 13, Color.WHITE if on else INK_SOFT, 4 if on else 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if on:
			l.label_settings.outline_color = WOOD_DARK
		else:
			l.label_settings.font = font()
		l.clip_text = true
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		# Обрезаемая подпись без растяжения получает нулевую ширину
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inner.add_child(l)
		var n := int(it[2]) if it.size() > 2 else 0
		if n > 0:
			var badge := count_badge(mini(n, 99))
			if icon_name != "":
				badge.position = Vector2(-4, -6)
				b.add_child(badge)
			else:
				badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				inner.add_child(badge)
		b.pressed.connect(func() -> void:
			if id != selected:
				Sound.play("tap")
				on_select.call(id))
		# Подпись уменьшается, если не влезает (minimumScaleFactor)
		var base_size := 11 if icon_name != "" else 13
		var badge_w := 24.0 if (n > 0 and icon_name == "") else 0.0
		b.resized.connect(func() -> void:
			fit_label(l, maxf(20.0, b.size.x - 8.0 - badge_w), base_size, 7))
		row.add_child(b)
	return track


## Иконка из спрайтов (ic_<имя>) в интерфейсе, без сглаживания.
static func icon(name: String, size := 24.0) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Sprites.icon(name)
	t.custom_minimum_size = Vector2(size, size)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pixel_art(t)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Ровные пиксели у картинки в любом размере (см. PIXEL_SHADER).
static func pixel_art(c: CanvasItem) -> void:
	if _pixel_mat == null:
		var sh := Shader.new()
		sh.code = PIXEL_SHADER
		_pixel_mat = ShaderMaterial.new()
		_pixel_mat.shader = sh
	c.material = _pixel_mat
	c.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


## Картинка ровно в целое число раз больше рисунка (16 -> 32, 48...), ближайшее к target и не больше limit.
## Для крупных картинок в магазине: так пиксели одинаковые и без сглаживания.
static func crisp(code: String, target: float, limit := 0.0) -> Control:
	var c := icon_any(code, target)
	var t := c as TextureRect
	if t == null or t.texture == null:
		return c
	var ts := t.texture.get_size()
	var big := maxf(ts.x, ts.y)
	var k := maxf(1.0, roundf(target / big))
	while limit > 0.0 and k > 1.0 and big * k > limit:
		k -= 1.0
	var s := ts * k
	t.custom_minimum_size = s
	t.size = s
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.material = null
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return t


## Иконка по строке как IconView в iOS: "px:имя", "res:вид", "an:зверь", иначе текст (эмодзи).
static func icon_any(code: String, size := 22.0) -> Control:
	if code.begins_with("px:"):
		return icon(code.substr(3), size)
	if code.begins_with("res:"):
		return icon(code.substr(4), size)
	if code.begins_with("skin:"):
		return EventsPanel.skin_icon(code.substr(5), size)
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
static func bar(value: float, tone := "green", width := 120.0, height := 12.0, text := "") -> GameBar:
	var b := GameBar.new()
	b.custom_minimum_size = Vector2(width, height)
	b.value = clampf(value, 0.0, 1.0)
	b.tone = tone
	if text != "":
		var l := label(text, maxi(9, int(height * 0.72)), Color.WHITE, 4)
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
		var chip := _chip(it[0], "%s/%s" % [Fmt.n(have), Fmt.n(int(it[1]))], have >= int(it[1]), size)
		# Нажатие на ресурс - "Где взять"
		WherePopup.tap_to_open(chip, str(it[0]))
		flow.add_child(chip)
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


## Деревянная "плашка" (woodPill в iOS): светлее сверху, светлая черта внутри, контур и тень.
static func pill_style() -> GameStyle:
	var s := GameStyle.make(WOOD.lerp(Color.WHITE, 0.18), WOOD, 14.0)
	s.frame_color = Color(1, 1, 1, 0.18)
	s.frame_width = 2.0
	s.shadow_offset = 3.0
	s.shadow_color = Color(OUTLINE, 0.5)
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
