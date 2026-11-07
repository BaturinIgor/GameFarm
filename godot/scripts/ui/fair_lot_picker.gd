class_name FairLotPicker
extends Control
## Выставить лот на ярмарку альянса: ресурс со склада, количество и цена за весь лот.

var _kind := ""
var _qty := 1
var _price := 1
var _box: VBoxContainer


static func open() -> void:
	if Hud.current == null:
		return
	Hud.current.show_overlay(FairLotPicker.new())


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = UiKit.DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			queue_free())
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	var st := UiKit.panel_style(18)
	st.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", st)
	panel.custom_minimum_size = Vector2(minf(340.0, get_viewport_rect().size.x - 32.0), 0)
	center.add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	panel.add_child(_box)
	_build()


## Ресурсы на складе, самые дорогие сверху.
static func goods() -> Array:
	var list: Array = Res.KINDS.filter(func(k: String) -> bool: return Game.amount(k) > 0)
	list.sort_custom(func(a: String, b: String) -> bool: return Res.price(a) * Game.amount(a) > Res.price(b) * Game.amount(b))
	return list


func _build() -> void:
	UiKit.clear(_box)
	var title := UiKit.label(L.t("afair.put"), 17)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(title)
	if _kind == "":
		_pick_kind()
	else:
		_pick_amount()
	var close := UiKit.button(L.t("common.close"), "wood", 14)
	close.pressed.connect(queue_free)
	_box.add_child(close)


func _pick_kind() -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, minf(380.0, get_viewport_rect().size.y * 0.5))
	_box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)
	var list := goods()
	if list.is_empty():
		_box.add_child(UiKit.label(L.t("afair.nothing"), 12, UiKit.INK_SOFT))
	for k in list:
		var b := UiKit.button(Fmt.n(Game.amount(k)), "wood", 12, true)
		b.icon = Res.icon(k)
		b.add_theme_constant_override("icon_max_width", 20)
		UiKit.pixel_art(b)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var kind: String = k
		b.pressed.connect(func() -> void:
			_kind = kind
			_qty = mini(Game.amount(kind), AllianceFair.MAX_QTY)
			_price = AllianceFair.default_price(kind, _qty)
			_build())
		grid.add_child(b)


func _pick_amount() -> void:
	var have := mini(Game.amount(_kind), AllianceFair.MAX_QTY)
	_qty = clampi(_qty, 1, maxi(1, have))
	_price = AllianceFair.clamp_price(_kind, _qty, _price)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_child(row)
	row.add_child(UiKit.icon_any("res:" + _kind, 36))
	row.add_child(UiKit.label(L.t("afair.lot", [Res.name_of(_kind), _qty]), 15))
	_box.add_child(UiKit.label(L.t("afair.qty"), 12, UiKit.INK_SOFT))
	_box.add_child(_stepper([-10, -1, 1, 10], func(d: int) -> void:
		var old_default := AllianceFair.default_price(_kind, _qty)
		var keep := _price == old_default
		_qty = clampi(_qty + d, 1, maxi(1, have))
		if keep:
			_price = AllianceFair.default_price(_kind, _qty)
		_build()))
	_box.add_child(UiKit.label(L.t("afair.price", [Fmt.n(_price)]), 14))
	var step := AllianceFair.price_step(_kind, _qty)
	_box.add_child(_stepper([-step * 5, -step, step, step * 5], func(d: int) -> void:
		_price = AllianceFair.clamp_price(_kind, _qty, _price + d)
		_build()))
	var hint := UiKit.label(L.t("afair.priceHint", [Fmt.n(AllianceFair.min_price(_kind, _qty)),
		Fmt.n(AllianceFair.max_price(_kind, _qty)), Fmt.n(Res.price(_kind) * _qty)]), 11, UiKit.INK_SOFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(hint)
	var go := UiKit.button(L.t("afair.putGo"), "green", 15)
	go.pressed.connect(func() -> void:
		Game.alliance.list_lot(_kind, _qty, _price)
		queue_free())
	_box.add_child(go)
	var back := UiKit.button(L.t("afair.other"), "wood", 13, true)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void:
		_kind = ""
		_build())
	_box.add_child(back)


func _stepper(deltas: Array, on_step: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for d in deltas:
		var b := UiKit.button(("%+d" % int(d)) if absi(int(d)) < 10000 else ("+" if int(d) > 0 else "-") + Fmt.n(absi(int(d))), "wood", 12, true)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var dv: int = d
		b.pressed.connect(func() -> void: on_step.call(dv))
		row.add_child(b)
	return row
