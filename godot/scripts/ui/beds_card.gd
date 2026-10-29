class_name BedsCard
extends PanelContainer
## Карточка у грядок (порт BedsCard): все грядки, выбор семян и удобрения, "посадить всё" и "собрать всё".
## Показывается через Hud.current.set_prompt("beds", card).

const RIPE_FILL := Color("c8eba0")
const SOIL_FILL := Color("c99a6e")
const FERT_SELECTED := Color("c8eba0")

var _col := VBoxContainer.new()
var _tiles: HBoxContainer
var _harvest: Button
var _dirty := true
var _tick := 0.0


func _init() -> void:
	add_theme_stylebox_override("panel", UiKit.panel_style(18))
	mouse_filter = Control.MOUSE_FILTER_STOP
	_col.add_theme_constant_override("separation", 8)
	add_child(_col)


func _ready() -> void:
	Game.changed.connect(_on_changed)
	L.language_changed.connect(_on_changed)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)


func _on_changed() -> void:
	_dirty = true


func _process(delta: float) -> void:
	if _dirty:
		_dirty = false
		_tick = 1.0
		for c in _col.get_children():
			c.queue_free()
		_build()
		return
	# Рост идёт сам: клетки и "собрать" обновляются раз в секунду
	_tick -= delta
	if _tick <= 0.0:
		_tick = 1.0
		_refresh_tiles()


func _build() -> void:
	var g := Game.garden
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	_col.add_child(head)
	head.add_child(UiKit.icon("seed_wheat", 20))
	var title := UiKit.label(L.t("beds.title"), 15)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UiKit.label(L.t("beds.count", [g.bed_count(), Farming.MAX_BEDS]), 12))

	_tiles = HBoxContainer.new()
	_tiles.add_theme_constant_override("separation", 3)
	_col.add_child(_tiles)
	_fill_tiles()

	_seeds_row()
	_fertilizer_row()
	_buttons()


func _refresh_tiles() -> void:
	if _tiles == null or not is_instance_valid(_tiles):
		return
	for c in _tiles.get_children():
		c.queue_free()
	_fill_tiles()
	if _harvest != null and is_instance_valid(_harvest):
		var ripe := Game.garden.ripe_beds()
		_harvest.text = L.t("beds.harvestAll", [ripe])
		_harvest.disabled = ripe == 0


func _fill_tiles() -> void:
	var now := GardenSystem.now()
	for i in Farming.MAX_BEDS:
		_tiles.add_child(_tile(i, now))


## Маленькая клетка грядки (BedTile): пусто, растёт, созрело или закрыто.
func _tile(i: int, now: float) -> Button:
	var g := Game.garden
	var bed := g.bed(i)
	var locked := i >= g.bed_count()
	var ripe := Farming.is_ripe(bed, now)
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 30)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	var fill := Color(UiKit.PARCHMENT_DEEP, 0.5) if locked else (RIPE_FILL if ripe else SOIL_FILL)
	var border: Color = UiKit.TONES["green"][1] if ripe else Color(UiKit.OUTLINE, 0.25 if locked else 0.6)
	var style := UiKit.box(fill, border, 6, 2 if ripe else 1, false)
	style.set_content_margin_all(0)
	for state in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(state, style)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.disabled = locked
	b.pressed.connect(_tap.bind(i))
	if locked:
		return b
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(center)
	if Farming.is_empty(bed):
		var plus := UiKit.label("+", 12, Color(1, 1, 1, 0.85), 2)
		center.add_child(plus)
		return b
	var crop: String = bed["crop"]
	center.add_child(UiKit.icon(Farming.spec(crop)["produce"] if ripe else Farming.seed_icon(crop), 18))
	if ripe:
		return b
	if bed.get("fertilized", false) == true:
		var dot := Panel.new()
		var ds := UiKit.box(UiKit.TONES["purple"][0], Color(0, 0, 0, 0), 3, 0, false)
		dot.add_theme_stylebox_override("panel", ds)
		dot.anchor_left = 1.0
		dot.anchor_right = 1.0
		dot.offset_left = -9
		dot.offset_right = -3
		dot.offset_top = 3
		dot.offset_bottom = 9
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(dot)
	var bar := ColorRect.new()
	bar.color = UiKit.TONES["green"][1]
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.anchor_right = Farming.progress(bed, now)
	bar.offset_top = -3
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(bar)
	return b


func _tap(i: int) -> void:
	var g := Game.garden
	var bed := g.bed(i)
	if Farming.is_ripe(bed, GardenSystem.now()):
		g.harvest_one(i)
	elif not Farming.is_empty(bed) and g.chosen_fertilizer() != "":
		g.fertilize(i)
	elif Farming.is_empty(bed) and i < g.bed_count():
		if not g.plant(i):
			Game.show_toast("px:sprout", L.t("toast.noSeeds" if g.total_seeds() == 0 else "beds.pick"))


## Семена, которые есть: выбор, что сажать (капсулы переносятся на новую строку).
func _seeds_row() -> void:
	var g := Game.garden
	var owned := Farming.CROP_IDS.filter(func(c: String) -> bool: return g.seeds(c) > 0)
	if owned.is_empty():
		var none := UiKit.label(L.t("beds.noSeeds"), 12, UiKit.TONES["orange"][2])
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_col.add_child(none)
		return
	var chosen := g.chosen_seed()
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	_col.add_child(row)
	for crop in owned:
		var chip := _chip(Farming.seed_icon(crop), g.seeds(crop), crop == chosen, UiKit.GOLD, 22)
		chip.pressed.connect(func() -> void: Game.garden.select_seed(crop))
		row.add_child(chip)
	var hint := L.t("beds.pick")
	if chosen != "":
		hint = L.t("beds.chosen", [Farming.name_of(chosen), Fmt.seconds(float(Farming.spec(chosen)["grow_time"]))])
	var l := UiKit.label(hint, 11, UiKit.INK_SOFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_col.add_child(l)


## Удобрения, которые есть: выбор (повторное нажатие снимает) и "удобрить всё".
func _fertilizer_row() -> void:
	var g := Game.garden
	var ferts := Farming.FERTILIZER_IDS.filter(func(id: String) -> bool: return g.fertilizers(id) > 0)
	if ferts.is_empty():
		return
	var chosen := g.chosen_fertilizer()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_col.add_child(row)
	for id in ferts:
		var selected: bool = id == chosen
		var chip := _chip(Farming.fert_icon(id), g.fertilizers(id), selected, FERT_SELECTED, 20)
		chip.pressed.connect(func() -> void: Game.garden.select_fertilizer("" if selected else id))
		row.add_child(chip)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	if chosen != "":
		var n := g.fertilizable_beds()
		var b := UiKit.button(L.t("beds.fertAll", [n]), "purple", 13, true)
		b.disabled = n == 0
		b.pressed.connect(func() -> void: Game.garden.fertilize_all())
		row.add_child(b)


func _buttons() -> void:
	var g := Game.garden
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_col.add_child(row)
	var chosen := g.chosen_seed()
	var can := mini(g.empty_beds(), g.seeds(chosen)) if chosen != "" else 0
	var plant := UiKit.button(L.t("beds.plantAll", [can]), "green", 13, true)
	plant.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plant.clip_text = true
	plant.disabled = can == 0
	plant.pressed.connect(func() -> void: Game.garden.plant_all())
	row.add_child(plant)
	var ripe := g.ripe_beds()
	_harvest = UiKit.button(L.t("beds.harvestAll", [ripe]), "orange", 13, true)
	_harvest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_harvest.clip_text = true
	_harvest.disabled = ripe == 0
	_harvest.pressed.connect(func() -> void: Game.garden.harvest_all())
	row.add_child(_harvest)
	var shed := _icon_button("watering_can", "blue")
	shed.pressed.connect(func() -> void:
		if Hud.current != null:
			Hud.current.open_window(GardenPanel.new()))
	row.add_child(shed)
	var shop := _icon_button("basket", "wood")
	shop.pressed.connect(func() -> void:
		if Hud.current != null:
			Hud.current.open_window(TraderPanel.new()))
	row.add_child(shop)


func _icon_button(icon_name: String, tone: String) -> Button:
	var b := UiKit.button("", tone, 13, true)
	b.icon = Sprites.icon(icon_name)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", 18)
	b.custom_minimum_size = Vector2(42, 0)
	return b


## Капсула-переключатель: иконка и сколько есть.
func _chip(icon_name: String, count: int, selected: bool, selected_fill: Color, icon_size: float) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	var style := UiKit.box(selected_fill if selected else UiKit.PARCHMENT_LIGHT,
		UiKit.OUTLINE if selected else Color(UiKit.WOOD_DARK, 0.4), 14, 2 if selected else 1, false)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	for state in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(state, style)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.icon = Sprites.icon(icon_name)
	b.add_theme_constant_override("icon_max_width", int(icon_size))
	b.add_theme_constant_override("h_separation", 3)
	b.text = str(count)
	b.add_theme_font_override("font", UiKit.font())
	b.add_theme_font_size_override("font_size", 13)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, UiKit.INK)
	return b
