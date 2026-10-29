class_name HousePanel
extends Sheet
## План дома: уют, этажи, что они дают, постройка новых (порт HouseView).
## Внутри - выбор украшения для свободного места (DecorPicker).

static var _gray: Shader


func _init() -> void:
	title_key = "house.title"


func build() -> void:
	_comfort_card()
	for f in House.FLOORS:
		_floor_card(f)
	var tip := UiKit.label(L.t("house.tip"), 11, UiKit.INK_SOFT)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(tip)


func _comfort_card() -> void:
	var c := tinted_card(content, UiKit.GOLD_DARK)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	c.add_child(row)
	row.add_child(sprite_rect("hm_sofa", 1.2, Vector2(56, 40)))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	var comfort := Game.house.comfort()
	col.add_child(UiKit.label(L.t("house.comfort", [comfort]), 15))
	col.add_child(wrapped(L.t("house.comfort.bonus", [Fmt.pct(House.comfort_bonus(comfort))]), 12, UiKit.INK_SOFT))


## Этаж в плане: построен или что нужно для постройки.
func _floor_card(f: String) -> void:
	var built := Game.house.is_built(f)
	var level_ok := Game.level >= House.floor_level(f)
	var c := tinted_card(content, Color(UiKit.TONES["green"][1], 0.6)) if built else card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	c.add_child(row)
	row.add_child(_thumb(House.floor_location(f), built))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	row.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	col.add_child(head)
	head.add_child(UiKit.label(House.floor_title(f), 15))
	head.add_child(check_mark(20) if built else level_tag(House.floor_level(f), level_ok))
	col.add_child(UiKit.label(House.floor_room(f), 12, UiKit.INK_SOFT))
	col.add_child(wrapped(House.floor_perk(f), 11, UiKit.INK_SOFT))
	if built:
		return
	c.add_child(UiKit.cost_view(House.floor_cost(f)))
	var b := UiKit.button(L.t("house.build") if level_ok else L.t("common.needLevel", [House.floor_level(f)]), "green", 14, true)
	b.disabled = not Game.house.can_build(f)
	b.pressed.connect(func() -> void: Game.house.build(f))
	c.add_child(b)


## Картинка этажа (пол комнаты), серая, пока этаж не построен.
func _thumb(location: String, built: bool) -> Control:
	var frame := PanelContainer.new()
	var s := UiKit.box(Color(UiKit.WOOD_DARK, 0.5), Color(UiKit.OUTLINE, 0.6), 10, 2, false)
	s.set_content_margin_all(2)
	frame.add_theme_stylebox_override("panel", s)
	frame.custom_minimum_size = Vector2(70, 52)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	frame.clip_contents = true
	var tex := Sprites.ground(location)
	if tex != null:
		var t := TextureRect.new()
		t.texture = tex
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		t.custom_minimum_size = Vector2(66, 48)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not built:
			t.material = gray_material(0.2)
		frame.add_child(t)
	return frame


# MARK: Общие элементы окон дома

## Карточка с цветной рамкой (Card(tint:)): пергамент, рамка цвета tint.
static func tinted_card(parent: Control, tint: Color) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.box(UiKit.PARCHMENT_LIGHT, tint, 14, 3, false))
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	return v


## Подпись с переносом строк.
static func wrapped(text: String, font_size: int, color := UiKit.INK) -> Label:
	var l := UiKit.label(text, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Пиксельный спрайт из набора (PixelSprite): scale точек на пиксель арта, по центру box.
## Если спрайт больше box, он уменьшается, чтобы влезть.
static func sprite_rect(sprite: String, pixel_scale: float, box := Vector2.ZERO) -> Control:
	var tex := Sprites.texture(sprite)
	if tex == null:
		return UiKit.icon("plan", 16.0 * pixel_scale)
	var sz := Vector2(tex.get_width(), tex.get_height()) * pixel_scale
	var area := box if box != Vector2.ZERO else sz
	if sz.x > area.x or sz.y > area.y:
		sz *= minf(area.x / sz.x, area.y / sz.y)
	var holder := CenterContainer.new()
	holder.custom_minimum_size = area
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.custom_minimum_size = sz
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(t)
	return holder


## Зелёный кружок с галочкой (вместо значка ✓, которого нет в шрифте).
static func check_mark(side: float) -> Control:
	var m := Control.new()
	m.custom_minimum_size = Vector2(side, side)
	m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.draw.connect(func() -> void:
		var r := side / 2.0
		var c := Vector2(r, r)
		m.draw_circle(c, r, Color.WHITE)
		m.draw_circle(c, r - 1.5, UiKit.GOOD)
		m.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.45, 0.0), c + Vector2(-r * 0.1, r * 0.35),
			c + Vector2(r * 0.45, -r * 0.35)]), Color.WHITE, maxf(2.0, side * 0.12), true))
	return m


## Плашка "Ур. N": зелёная, если уровень достигнут (LevelTag).
static func level_tag(level: int, ok: bool) -> PanelContainer:
	var tone: Array = UiKit.TONES["green" if ok else "red"]
	var p := PanelContainer.new()
	var s := UiKit.box(tone[1], UiKit.OUTLINE, 10, 2, false)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", s)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UiKit.label(L.t("common.lvl", [level]), 12, Color.WHITE, 3)
	l.label_settings.outline_color = tone[2]
	p.add_child(l)
	return p


## Материал, который обесцвечивает картинку (saturation в SwiftUI): 0 - серая, 1 - как есть.
static func gray_material(saturation: float) -> ShaderMaterial:
	if _gray == null:
		_gray = Shader.new()
		_gray.code = "shader_type canvas_item;\nuniform float saturation = 0.2;\nvoid fragment() {\n" \
			+ "\tvec4 c = texture(TEXTURE, UV);\n\tfloat g = dot(c.rgb, vec3(0.299, 0.587, 0.114));\n" \
			+ "\tCOLOR = vec4(mix(vec3(g), c.rgb, saturation), c.a) * COLOR;\n}\n"
	var m := ShaderMaterial.new()
	m.shader = _gray
	m.set_shader_parameter("saturation", saturation)
	return m


## Выбор украшения для свободного места (порт DecorPicker).
class DecorPicker extends Sheet:
	var slot := ""

	func _init(id: String) -> void:
		slot = id
		title_key = "decor.pick"

	func build() -> void:
		for decor in House.DECOR:
			_row(decor)
		var close_button := UiKit.button(L.t("common.close"), "wood", 14, true)
		close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		close_button.pressed.connect(close)
		content.add_child(close_button)

	func _row(decor: String) -> void:
		var c := card()
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		c.add_child(row)
		var frame := PanelContainer.new()
		var fs := UiKit.box(Color(UiKit.PARCHMENT_DEEP, 0.7), Color(0, 0, 0, 0), 10, 0, false)
		fs.set_content_margin_all(0)
		frame.add_theme_stylebox_override("panel", fs)
		frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		frame.add_child(HousePanel.sprite_rect(House.decor_sprite(decor), 1.8, Vector2(60, 52)))
		row.add_child(frame)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 4)
		row.add_child(col)
		col.add_child(UiKit.label(House.decor_name(decor), 14))
		col.add_child(UiKit.label(L.t("decor.comfort", [House.decor_comfort(decor)]), 11, UiKit.GOOD))
		var event := House.decor_event(decor)
		if event != "":
			var owned := Game.house.has_decor(decor)
			col.add_child(HousePanel.wrapped(L.t("decor.event.owned") if owned else L.t("decor.event.locked", [L.t("event." + event)]),
				11, UiKit.GOOD if owned else UiKit.INK_SOFT))
		else:
			col.add_child(UiKit.cost_view(House.decor_cost(decor)))
		var b := UiKit.button(L.t("common.buy") if event == "" else L.t("decor.place"), "green", 14, true)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.disabled = not Game.house.can_place(decor)
		b.pressed.connect(func() -> void:
			if Game.house.place(decor, slot):
				close())
		row.add_child(b)
