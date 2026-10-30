class_name StoragePanel
extends Sheet
## Склад: что в рюкзаке, вкладки ресурсов, продажа.

const TABS := {
	"materials": ["wood", "stone", "ore"],
	"food": ["crop", "food", "farm"],
	"loot": ["loot"],
	"rare": ["gem", "treasure"],
	"goods": ["goods"],
}

var tab := "materials"


func _init() -> void:
	title_key = "hud.storage"


func build() -> void:
	content.add_child(_capacity_row())
	if Game.backpack_count > 0:
		_backpack_card()
	var list := _kinds(tab)
	if list.is_empty():
		var c := card()
		var total := 0
		for v in Game.save["storage"].values():
			total += int(v)
		c.add_child(UiKit.label(L.t("storage.empty") if total == 0 else L.t("storage.tabEmpty"), 16))
		var hint := UiKit.label(L.t("storage.empty.hint"), 13, UiKit.INK_SOFT)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c.add_child(hint)
	else:
		var cats: Array = TABS[tab]
		for cat in cats:
			var rows := list.filter(func(k: String) -> bool: return Res.category(k) == cat)
			if rows.is_empty():
				continue
			if cats.size() > 1:
				section_title(L.t("cat." + cat))
			var c := card()
			for kind in rows:
				_row(c, kind)
		_sell_tab_button(list)
	var price_hint := UiKit.label(L.t("storage.priceHint"), 12, UiKit.INK_SOFT)
	price_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(price_hint)


func _kinds(t: String) -> Array:
	var out: Array = []
	for cat in TABS[t]:
		for k in Res.in_category(cat):
			if Game.storage_of(k) > 0:
				out.append(k)
	return out


## Вкладки закреплены под шапкой: прокручивается только содержимое.
func build_top() -> void:
	_tabs()


func _tabs() -> void:
	var items: Array = []
	for t in TABS:
		items.append([t, L.t("storage.tab." + t)])
	top_bar.add_child(UiKit.tabs(items, tab, func(id: String) -> void:
		tab = id
		scroll_to_top()))


func _backpack_card() -> void:
	var c := card(Color("fbe3c2"))
	var head := HBoxContainer.new()
	c.add_child(head)
	var t := UiKit.label(L.t("storage.inBackpack"), 16)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UiKit.label("%d/%d" % [Game.backpack_count, Game.stats.capacity], 14))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	c.add_child(flow)
	for kind in Res.KINDS:
		var n := int(Game.save["backpack"].get(kind, 0))
		if n <= 0:
			continue
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 3)
		chip.add_child(UiKit.icon(kind, 18))
		chip.add_child(UiKit.label(Fmt.n(n), 13))
		flow.add_child(chip)
	var hint := UiKit.label(L.t("storage.backpackHint"), 12, UiKit.INK_SOFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(hint)


func _row(parent: Control, kind: String) -> void:
	var have := Game.storage_of(kind)
	var price := Game.sell_price(kind)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	row.add_child(UiKit.icon(kind, 34))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	col.add_child(UiKit.label(Res.name_of(kind), 15))
	col.add_child(UiKit.label(L.t("storage.row", [Fmt.n(have), price]), 12, UiKit.INK_SOFT))
	if have >= 10:
		var ten := UiKit.button("10", "wood", 13, true)
		ten.pressed.connect(func() -> void: Game.sell(kind, 10))
		row.add_child(ten)
	var all := UiKit.button(L.t("storage.sellAll") if have >= 10 else L.t("storage.sell"), "green", 13, true)
	all.pressed.connect(func() -> void: Game.sell(kind, have))
	row.add_child(all)


func _sell_tab_button(list: Array) -> void:
	var total := 0
	for k in list:
		total += Game.storage_of(k) * Game.sell_price(k)
	var b := TraderPanel.coin_button(L.t("storage.sellTab"), total, "wood", 14)
	b.pressed.connect(func() -> void:
		for k in list:
			Game.sell(k, Game.storage_of(k)))
	content.add_child(b)


## Склад и амбар: сколько занято из вместимости, нажатие - улучшить в усадьбе.
func _capacity_row() -> HBoxContainer:
	var e := Game.estate
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for store in ["storage", "barn"]:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 44)
		var st := UiKit.box(UiKit.PARCHMENT_LIGHT, Color(UiKit.WOOD_DARK, 0.45), 12, 2, false)
		st.set_content_margin_all(6)
		for k in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			b.add_theme_stylebox_override(k, st)
		var col := VBoxContainer.new()
		col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		col.offset_left = 8
		col.offset_right = -8
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 2)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(col)
		col.add_child(UiKit.label(Estate.name_of(store), 12))
		var used := e.stored(store)
		var cap := e.capacity(store)
		var bar := UiKit.bar(float(used) / float(maxi(1, cap)), "red" if used >= cap else "green", 100.0, 12.0,
			"%s/%s" % [Fmt.n(used), Fmt.n(cap)])
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(bar)
		b.pressed.connect(func() -> void: EstatePanel.open())
		row.add_child(b)
	return row
