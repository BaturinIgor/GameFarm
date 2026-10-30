class_name GiftPopup
extends Control
## Подарок жителю: уровень дружбы (сердечки), сколько до следующего, бонус дружбы и товары со склада.
## Любимые подарки - сверху и со звёздочкой, за них вдвое больше очков. До 3 подарков в день каждому.

var id := ""


static func open(resident: String) -> void:
	if Hud.current == null:
		return
	var p := GiftPopup.new()
	p.id = resident
	Hud.current.show_overlay(p)


## Пять сердечек: закрашены по уровню дружбы.
static func hearts(level: int, size := 16.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in Residents.FRIEND_LEVELS.size():
		var h := UiKit.icon("heart", size)
		if i >= level:
			h.modulate = Color(0.3, 0.3, 0.3, 0.45)
		row.add_child(h)
	return row


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = UiKit.DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			close())
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	var st := UiKit.panel_style(20)
	st.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", st)
	panel.custom_minimum_size = Vector2(minf(350.0, get_viewport_rect().size.x - 32.0), 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	_fill(v)
	Game.changed.connect(func() -> void:
		if not is_queued_for_deletion():
			for c in v.get_children():
				c.queue_free()
			_fill(v))


func _fill(v: VBoxContainer) -> void:
	var rs := Game.residents
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	head.add_child(TraderPanel.portrait(Residents.sheet(id), 56))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 3)
	head.add_child(col)
	col.add_child(UiKit.label(Residents.name_of(id), 17))
	var lvl := rs.friend_level(id)
	col.add_child(hearts(lvl))
	var pts := rs.friend_points(id)
	if lvl < Residents.FRIEND_LEVELS.size():
		var lo := 0 if lvl == 0 else int(Residents.FRIEND_LEVELS[lvl - 1])
		var hi := int(Residents.FRIEND_LEVELS[lvl])
		v.add_child(UiKit.bar(float(pts - lo) / float(hi - lo), "red", 0.0, 14.0, "%d / %d" % [pts, hi]))
	var bonus := UiKit.label(L.t("friend.bonus", [Residents.friend_bonus_text(id, lvl),
		Residents.friend_bonus_text(id, mini(Residents.FRIEND_LEVELS.size(), lvl + 1))]), 12, UiKit.INK_SOFT)
	bonus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(bonus)
	v.add_child(UiKit.label(L.t("friend.giftsLeft", [rs.gifts_left(id), Residents.GIFTS_PER_DAY]), 13))
	# Товары со склада: любимые сверху
	var goods: Array = Estate.GOODS.filter(func(g: String) -> bool: return Game.storage_of(g) > 0)
	var liked := Residents.likes(id)
	goods.sort_custom(func(a: String, b: String) -> bool:
		var la := a in liked
		var lb := b in liked
		if la != lb:
			return la
		return Residents.gift_points(id, a) > Residents.gift_points(id, b))
	if goods.is_empty():
		var none := UiKit.label(L.t("friend.noGoods", [", ".join(liked.map(func(g: String) -> String: return Res.name_of(g)))]),
			12, UiKit.INK_SOFT)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(none)
	for g in goods.slice(0, 6):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		v.add_child(row)
		row.add_child(UiKit.icon(g, 26))
		var title := UiKit.label(("★ " if g in liked else "") + Res.name_of(g) + " · " + Fmt.n(Game.storage_of(g)), 13)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.clip_text = true
		row.add_child(title)
		var b := UiKit.button(L.t("friend.give", [Residents.gift_points(id, g)]), "green", 12, true)
		b.disabled = rs.gifts_left(id) <= 0
		var good: String = g
		b.pressed.connect(func() -> void:
			if Game.residents.give(id, good) > 0:
				Sound.play("success"))
		row.add_child(b)
	var close_b := UiKit.button(L.t("common.close"), "wood", 14, true)
	close_b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_b.pressed.connect(close)
	v.add_child(close_b)


func close() -> void:
	queue_free()
