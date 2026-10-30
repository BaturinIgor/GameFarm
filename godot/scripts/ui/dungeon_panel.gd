class_name DungeonPanel
extends Sheet
## Подземелья у стражника (порт DungeonList и DungeonCard): зелья в дорогу, карточки подземелий с этажами,
## выбор этажа и вход, анонс будущих подземелий. В iOS это вкладка "Подземелья" окна стражника: окно охоты
## ставит лавку зелий (CombatCards.potion_shop_card) и под ней список DungeonPanel.build_list(content, close).

## Выбранный этаж в каждом подземелье (по умолчанию - самый глубокий открытый).
static var floors: Dictionary = {}


func _init() -> void:
	title_key = "dungeon.tab"
	floors.clear()


func build() -> void:
	content.add_child(TraderPanel.hello_row("guard", [UiKit.label(L.t("dungeon.hello"), 13)]))
	content.add_child(CombatCards.potion_shop_card())
	DungeonPanel.build_list(content, close)


## Список подземелий в parent (без лавки зелий). on_enter вызывается после входа (закрыть окно).
static func build_list(parent: Control, on_enter: Callable) -> void:
	parent.add_child(attempts_card())
	for id in Dungeons.IDS:
		parent.add_child(_dungeon_card(id, on_enter))
	parent.add_child(_section(L.t("dungeon.soon")))
	for id in Dungeons.COMING:
		parent.add_child(_coming_card(id))
	var tip := UiKit.label(L.t("dungeon.tip"), 11, UiKit.INK_SOFT)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(tip)


## Иконка эссенции (своего рисунка нет - кристалл с фиолетовым оттенком).
static func essence_icon(side: float) -> TextureRect:
	var t := UiKit.icon("essence", side)
	if t.texture == null:
		t.texture = Sprites.icon("crystal")
		t.modulate = Color(0.85, 0.65, 1)
	return t


# MARK: Части списка

## Светлая карточка (Card) с рамкой тёмного дерева.
static func _card() -> Array:
	var p := PanelContainer.new()
	var s := UiKit.box(UiKit.PARCHMENT_LIGHT, Color(UiKit.WOOD_DARK, 0.45), 16, 1, false)
	s.set_content_margin_all(14)
	s.shadow_color = Color(UiKit.WOOD_DARK, 0.25)
	s.shadow_offset = Vector2(0, 3)
	s.shadow_size = 1
	p.add_theme_stylebox_override("panel", s)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	return [p, v]


## Заголовок раздела: черта, текст, черта.
static func _section(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for i in 2:
		var line := ColorRect.new()
		line.color = Color(UiKit.WOOD_DARK, 0.35)
		line.custom_minimum_size = Vector2(0, 2)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(line)
		if i == 0:
			row.add_child(UiKit.label(text.to_upper(), 14, UiKit.INK_SOFT))
	return row


## Карточка подземелья: босс, описание, этажи, выбор этажа, награды и вход.
static func _dungeon_card(id: String, on_enter: Callable) -> Control:
	var best := Game.dungeons.dungeon_best(id)
	var open := Game.level >= Dungeons.level(id)
	var max_floor := mini(Dungeons.FLOORS, best + 1)
	var floor_n := clampi(int(floors.get(id, max_floor)), 1, max_floor)
	var colors := Dungeons.colors(id)
	var card := GradientPanel.new(colors[0], colors[1])
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	var circle := PanelContainer.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0, 0, 0, 0.25)
	cs.set_corner_radius_all(31)
	cs.set_content_margin_all(5)
	circle.add_theme_stylebox_override("panel", cs)
	circle.custom_minimum_size = Vector2(62, 62)
	circle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(circle)
	var boss := TextureRect.new()
	boss.texture = Monsters.icon(Dungeons.boss(id))
	boss.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	boss.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	boss.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	boss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not open:
		boss.material = HousePanel.gray_material(0.0)
	circle.add_child(boss)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3)
	head.add_child(info)
	info.add_child(UiKit.title(Dungeons.name_of(id), 17))
	var blurb := UiKit.label(Dungeons.blurb(id), 11, Color(1, 1, 1, 0.92), 3)
	blurb.label_settings.outline_color = Color(UiKit.OUTLINE, 0.6)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(blurb)

	# Этажи: пройденные, текущий и закрытые
	var cells := HBoxContainer.new()
	cells.add_theme_constant_override("separation", 4)
	v.add_child(cells)
	for f: int in range(1, Dungeons.FLOORS + 1):
		var done := f <= best
		var boss_floor := Dungeons.is_boss_floor(f)
		var cell := PanelContainer.new()
		var st := UiKit.box(UiKit.TONES["green"][1] if done else Color(UiKit.PARCHMENT_LIGHT, 0.85),
			UiKit.GOLD if boss_floor else Color(UiKit.OUTLINE, 0.5), 6, 2 if boss_floor else 1, false)
		st.set_content_margin_all(0)
		cell.add_theme_stylebox_override("panel", st)
		cell.custom_minimum_size = Vector2(0, 22)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var num := UiKit.label(str(f), 10, Color.WHITE if done else UiKit.INK_SOFT, 3 if done else 0)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.add_child(num)
		cells.add_child(cell)

	if not open:
		v.add_child(UiKit.label(L.t("common.needLevel", [Dungeons.level(id)]), 13, Color.WHITE, 4))
		return card

	# Выбор этажа
	var picker := HBoxContainer.new()
	picker.add_theme_constant_override("separation", 8)
	v.add_child(picker)
	var prev := _chevron_button(true)
	prev.disabled = floor_n <= 1
	prev.pressed.connect(func() -> void: _pick(id, floor_n - 1))
	picker.add_child(prev)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 1)
	picker.add_child(mid)
	var fl := UiKit.label(L.t("dungeon.floor", [floor_n]), 14, Color.WHITE, 4)
	fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(fl)
	var ml := UiKit.label(L.t("dungeon.monsterLevel", [Dungeons.monster_level(id, floor_n)]), 10, Color(1, 1, 1, 0.85), 3)
	ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(ml)
	var nxt := _chevron_button(false)
	nxt.disabled = floor_n >= max_floor
	nxt.pressed.connect(func() -> void: _pick(id, floor_n + 1))
	picker.add_child(nxt)

	# Награда за выбранный этаж
	var first := floor_n > best
	var rewards := PanelContainer.new()
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(0, 0, 0, 0.25)
	rs.set_corner_radius_all(10)
	rs.set_content_margin_all(6)
	rewards.add_theme_stylebox_override("panel", rs)
	v.add_child(rewards)
	var rrow := HBoxContainer.new()
	rrow.add_theme_constant_override("separation", 10)
	rewards.add_child(rrow)
	rrow.add_child(_tag(UiKit.icon("coin", 15), Fmt.n(Dungeons.coins(id, floor_n, first)), 12))
	rrow.add_child(_tag(essence_icon(15), str(Dungeons.essence(id, floor_n, first)), 12))
	if first:
		rrow.add_child(_tag(UiKit.icon("gem", 15), str(Dungeons.first_crystals(id, floor_n)), 12))
	var weapon := Dungeons.weapon(id)
	if Dungeons.is_boss_floor(floor_n) and not Game.combat.owns_weapon(weapon):
		var sword := UiKit.icon("sword", 15)
		sword.modulate = Weapons.color(weapon)
		var wt := _tag(sword, Weapons.name_of(weapon), 11, true)
		wt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rrow.add_child(wt)

	var boss_floor_now := Dungeons.is_boss_floor(floor_n)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	v.add_child(buttons)
	# Пройденный этаж можно зачистить: попытка, награда сразу, без боя
	if floor_n <= best:
		var sweep := UiKit.button(L.t("dungeon.sweep"), "blue", 14)
		sweep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sweep.disabled = Game.dungeons.attempts_left() <= 0 or Game.dungeons.run != null
		sweep.pressed.connect(func() -> void:
			var got := Game.dungeons.sweep(id, floor_n)
			if not got.is_empty():
				Game.show_toast("px:chest_gold", L.t("dungeon.swept", [floor_n, Fmt.n(int(got["coins"])), int(got["essence"])])))
		buttons.add_child(sweep)
	var enter := UiKit.button(L.t("dungeon.enterBoss") if boss_floor_now else L.t("dungeon.enter"),
		"orange" if boss_floor_now else "green")
	enter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enter.disabled = not Game.dungeons.can_enter(id, floor_n)
	enter.pressed.connect(func() -> void:
		Game.dungeons.start_dungeon(id, floor_n)
		on_enter.call())
	buttons.add_child(enter)
	return card


## Попытки на сегодня: сколько осталось, ещё одна за ролик или за кристаллы.
static func attempts_card() -> Control:
	var parts := _card()
	var v: VBoxContainer = parts[1]
	var d := Game.dungeons
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	row.add_child(UiKit.icon("key", 30))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	col.add_child(UiKit.label(L.t("dungeon.attempts", [d.attempts_left(), d.attempts_total()]), 15))
	var hint := UiKit.label(L.t("dungeon.attemptsHint"), 11, UiKit.INK_SOFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(hint)
	var more := HBoxContainer.new()
	more.add_theme_constant_override("separation", 8)
	v.add_child(more)
	var ad := Ads.reward_button(L.t("dungeon.attemptAd"), "blue", 13, true)
	ad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ad.disabled = d.ad_attempts_left() <= 0
	ad.pressed.connect(func() -> void: Ads.show_rewarded(func() -> void: Game.dungeons.ad_attempt()))
	more.add_child(ad)
	var buy := MapPanel.icon_button([["t", "+1"], ["i", "gem"], ["t", str(d.attempt_price())]], "purple", 13)
	buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy.pressed.connect(func() -> void:
		if not Game.dungeons.buy_attempt():
			Game.show_toast("px:gem", L.t("crystals.notEnough", [Fmt.n(Game.dungeons.attempt_price() - Game.shop.crystals())])))
	more.add_child(buy)
	return parts[0]


static func _pick(id: String, f: int) -> void:
	floors[id] = f
	Game.changed.emit()


## Значок и подпись белым по тёмному.
static func _tag(icon: Control, text: String, size: int, clip := false) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var l := UiKit.label(text, size, Color.WHITE, 3)
	# Обрезается только длинная подпись (название оружия), числа видны целиком
	l.clip_text = clip
	if clip:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	return row


## Кнопка со стрелкой влево или вправо (в шрифте нет значка).
static func _chevron_button(left: bool) -> Button:
	var b := UiKit.button("", "wood", 14, true)
	b.custom_minimum_size = Vector2(40, 34)
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		var m := c.size / 2.0
		var dx := 3.0 if left else -3.0
		var pts := PackedVector2Array([m + Vector2(dx, -6), m + Vector2(-dx, 0), m + Vector2(dx, 6)])
		c.draw_polyline(pts, UiKit.OUTLINE, 5.0, true)
		c.draw_polyline(pts, Color.WHITE, 3.0, true))
	b.add_child(c)
	return b


## Будущее подземелье: только название и описание.
static func _coming_card(id: String) -> Control:
	var c := _card()
	var p: PanelContainer = c[0]
	p.modulate.a = 0.8
	var v: VBoxContainer = c[1]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var lock := PanelContainer.new()
	var ls := StyleBoxFlat.new()
	ls.bg_color = Color(UiKit.PARCHMENT_DEEP, 0.7)
	ls.set_corner_radius_all(12)
	ls.set_content_margin_all(15)
	lock.add_theme_stylebox_override("panel", ls)
	lock.custom_minimum_size = Vector2(52, 52)
	lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var key := UiKit.icon("key", 22)
	key.modulate = Color(UiKit.INK_SOFT, 1)
	lock.add_child(key)
	row.add_child(lock)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 3)
	row.add_child(col)
	col.add_child(UiKit.label(Dungeons.coming_name(id), 15))
	var blurb := UiKit.label(Dungeons.coming_blurb(id), 11, UiKit.INK_SOFT)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(blurb)
	var tag := PanelContainer.new()
	var ts := StyleBoxFlat.new()
	ts.bg_color = UiKit.TONES["purple"][1]
	ts.set_corner_radius_all(10)
	ts.content_margin_left = 8
	ts.content_margin_right = 8
	ts.content_margin_top = 3
	ts.content_margin_bottom = 3
	tag.add_theme_stylebox_override("panel", ts)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.add_child(UiKit.label(L.t("dungeon.soon.tag"), 11, Color.WHITE, 3))
	row.add_child(tag)
	return p


## Скруглённый прямоугольник ломаной (для градиентной заливки).
static func rounded_points(rect: Rect2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [
		[Vector2(rect.end.x - r, rect.position.y + r), -PI / 2.0],
		[Vector2(rect.end.x - r, rect.end.y - r), 0.0],
		[Vector2(rect.position.x + r, rect.end.y - r), PI / 2.0],
		[Vector2(rect.position.x + r, rect.position.y + r), PI],
	]
	for c in corners:
		for i in 7:
			var a: float = float(c[1]) + PI / 2.0 * float(i) / 6.0
			pts.append(c[0] + Vector2(cos(a), sin(a)) * r)
	return pts


## Карточка с заливкой сверху вниз из двух цветов, тёмным контуром и тенью снизу.
class GradientPanel extends PanelContainer:
	var top: Color
	var bottom: Color

	func _init(a: Color, b: Color) -> void:
		top = a
		bottom = b
		var s := StyleBoxEmpty.new()
		s.set_content_margin_all(14)
		add_theme_stylebox_override("panel", s)
		resized.connect(queue_redraw)

	func _draw() -> void:
		if size.x < 4.0 or size.y < 4.0:
			return
		var pts := DungeonPanel.rounded_points(Rect2(Vector2(1.5, 1.5), size - Vector2(3, 3)), 16.5)
		var shadow := PackedVector2Array()
		var colors := PackedColorArray()
		for p in pts:
			shadow.append(p + Vector2(0, 4))
			colors.append(top.lerp(bottom, clampf(p.y / size.y, 0.0, 1.0)))
		draw_colored_polygon(shadow, Color(UiKit.OUTLINE, 0.5))
		draw_polygon(pts, colors)
		var line := pts.duplicate()
		line.append(pts[0])
		draw_polyline(line, UiKit.OUTLINE, 3.0, true)
