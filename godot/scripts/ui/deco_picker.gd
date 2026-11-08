class_name DecoPicker
extends Control
## Украшения домика в деревне альянса: купить за кристаллы, выставить у домика (до 3) и набор за деньги.


static func open() -> void:
	if Hud.current == null:
		return
	Hud.current.show_overlay(DecoPicker.new())


var _box: VBoxContainer


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
	panel.custom_minimum_size = Vector2(minf(350.0, get_viewport_rect().size.x - 24.0), 0)
	center.add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	panel.add_child(_box)
	Game.changed.connect(_build)
	_build()


func _build() -> void:
	if not is_inside_tree():
		return
	UiKit.clear(_box)
	var al := Game.alliance
	var title := UiKit.label(L.t("village.decorate"), 17)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(title)
	var hint := UiKit.label(L.t("village.decoHint", [Village.SHOWN]), 11, UiKit.INK_SOFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(hint)
	var owned := al.owned_decos()
	var shown := al.shown_decos()
	for id in Village.DECO_ORDER:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_box.add_child(row)
		row.add_child(UiKit.icon(str(Village.DECOS[id]["icon"]), 26))
		var nl := UiKit.label(L.t("village.deco." + id), 13)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nl)
		var deco: String = id
		if id in owned:
			var on: bool = id in shown
			var b := UiKit.button(L.t("village.hide") if on else L.t("village.show"), "wood" if on else "green", 12, true)
			b.pressed.connect(func() -> void: al.toggle_deco(deco))
			row.add_child(b)
		elif Village.in_pack(id):
			row.add_child(UiKit.label(L.t("village.inPack"), 11, UiKit.INK_SOFT))
		else:
			var cb := ShopPanel.crystal_button(Village.deco_price(id), "purple", true)
			cb.pressed.connect(func() -> void: al.buy_deco(deco))
			row.add_child(cb)
	if not Game.premium.owns("villagePack"):
		var parts := ShopPanel.shop_card(Products.title("villagePack"), "purple")
		var v: VBoxContainer = parts[1]
		v.add_child(HousePanel.wrapped(L.t("village.packDesc", [Village.PACK_CRYSTALS]), 12))
		v.add_child(ShopPanel.buy_button("villagePack", "purple"))
		_box.add_child(parts[0])
	var close := UiKit.button(L.t("common.close"), "wood", 14)
	close.pressed.connect(queue_free)
	_box.add_child(close)
