class_name WardrobePanel
extends Sheet
## Гардероб: все образы героя, закрытые - с подписью, как открыть (порт WardrobeView и SkinTile).
## Образы из покупок открываются покупкой в магазине (ShopPanel), до неё - закрыты с названием покупки.

const SELECTED_FILL := Color("ddefc8")


func _init() -> void:
	title_key = "wardrobe.title"


func build() -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 12)
	content.add_child(grid)
	for skin in Skins.IDS:
		grid.add_child(_tile(skin))


## Плитка образа: портрет, имя, замок с подписью или галочка у выбранного.
func _tile(skin: String) -> Button:
	var unlocked := Skins.is_unlocked(skin)
	var selected := Skins.current() == skin
	var b := Button.new()
	var s := UiKit.box(SELECTED_FILL if selected else UiKit.PARCHMENT_LIGHT,
		UiKit.OUTLINE if selected else Color(UiKit.WOOD_DARK, 0.4), 16, 3 if selected else 2, false)
	s.shadow_color = Color(UiKit.WOOD_DARK, 0.25)
	s.shadow_offset = Vector2(0, 3)
	s.shadow_size = 1
	var down := s.duplicate() as StyleBoxFlat
	down.bg_color = s.bg_color.darkened(0.08)
	for state in ["normal", "hover", "disabled"]:
		b.add_theme_stylebox_override(state, s)
	b.add_theme_stylebox_override("pressed", down)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 118)
	b.disabled = not unlocked
	b.pressed.connect(func() -> void:
		Skins.select(skin)
		Input.vibrate_handheld(10))

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 6
	col.offset_right = -6
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	var face := skin_icon(skin, 52)
	face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if not unlocked:
		face.material = HousePanel.gray_material(0.0)
		face.modulate.a = 0.45
	col.add_child(face)
	var name_label := UiKit.label(Skins.name_of(skin), 12)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(name_label)
	if not unlocked:
		var lock := HBoxContainer.new()
		lock.alignment = BoxContainer.ALIGNMENT_CENTER
		lock.add_theme_constant_override("separation", 3)
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(lock)
		var key := UiKit.icon("key", 12)
		key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lock.add_child(key)
		var why := UiKit.label(Skins.lock_text(skin), 10, UiKit.INK_SOFT)
		why.clip_text = true
		why.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		why.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		why.custom_minimum_size = Vector2(10, 0)
		lock.add_child(why)
	elif selected:
		var mark := HousePanel.check_mark(16)
		mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(mark)
	return b


## Портрет образа (SkinIcon): лицо из листа героя, без листа - значок гардероба.
static func skin_icon(skin: String, side: float) -> TextureRect:
	var t := UiKit.icon("wardrobe", side)
	var tex := LevelPanel.portrait(skin)
	if tex != null:
		t.texture = tex
	return t


## Строка гардероба для окна профиля (в настройках LevelView): портрет, название образа, стрелка.
static func profile_row() -> Button:
	var b := Button.new()
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(func() -> void:
		if Hud.current != null:
			Hud.current.open_window(WardrobePanel.new()))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var face := skin_icon(Skins.current(), 32)
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(face)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	col.add_child(UiKit.label(L.t("wardrobe.title"), 14))
	col.add_child(UiKit.label(Skins.name_of(Skins.current()), 12, UiKit.INK_SOFT))
	var arrow := UiKit.label("›", 18, UiKit.INK_SOFT)
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(arrow)
	return b
