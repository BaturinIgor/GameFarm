class_name Hud
extends CanvasLayer
## Шапка игры: уровень и опыт, монеты, рюкзак, кнопки окон, всплывающие сообщения и название локации.

var root := Control.new()
var _level_label: Label
var _level_name: Label
var _xp_bar: ProgressBar
var _coins_label: Label
var _pack_label: Label
var _pack_bar: ProgressBar
var _toasts := VBoxContainer.new()
var _banner := VBoxContainer.new()
var _banner_tween: Tween
var _shown_location := ""
var _refresh := 0.0
var _window: Control


func _ready() -> void:
	layer = 10
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_top()
	_build_bottom()
	_build_banner()
	_toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toasts.offset_left = -150
	_toasts.offset_right = 150
	_toasts.offset_top = _safe_top() + 110
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_theme_constant_override("separation", 6)
	root.add_child(_toasts)
	Game.toast.connect(_on_toast)
	Game.level_up.connect(_on_level_up)
	L.language_changed.connect(_refresh_texts)
	_refresh_values()


func _safe_top() -> float:
	return UiKit.safe_insets(get_viewport())["top"]


func _build_top() -> void:
	var top := _safe_top() + 8.0
	# Уровень и опыт слева
	var level_box := PanelContainer.new()
	level_box.add_theme_stylebox_override("panel", UiKit.pill_style())
	level_box.position = Vector2(10, top)
	level_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(level_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	level_box.add_child(row)
	var badge := PanelContainer.new()
	var badge_style := UiKit.box(UiKit.TONES["orange"][1], UiKit.OUTLINE, 18, 2, false)
	badge_style.set_content_margin_all(2)
	badge.add_theme_stylebox_override("panel", badge_style)
	badge.custom_minimum_size = Vector2(36, 36)
	row.add_child(badge)
	_level_label = UiKit.title("1", 18)
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(_level_label)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	_level_name = UiKit.title("", 13)
	col.add_child(_level_name)
	_xp_bar = _bar(Color("f7c948"))
	col.add_child(_xp_bar)

	# Рюкзак под уровнем
	var pack_box := PanelContainer.new()
	pack_box.add_theme_stylebox_override("panel", UiKit.pill_style())
	pack_box.position = Vector2(10, top + 54)
	pack_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pack_box)
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 6)
	pack_box.add_child(prow)
	prow.add_child(UiKit.icon("bag", 22))
	var pcol := VBoxContainer.new()
	pcol.add_theme_constant_override("separation", 1)
	prow.add_child(pcol)
	_pack_label = UiKit.title("0/0", 12)
	pcol.add_child(_pack_label)
	_pack_bar = _bar(Color("8bd45a"), 70)
	pcol.add_child(_pack_bar)

	# Монеты справа
	var coin_box := PanelContainer.new()
	coin_box.add_theme_stylebox_override("panel", UiKit.pill_style())
	coin_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	coin_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	coin_box.offset_left = -10
	coin_box.offset_right = -10
	coin_box.offset_top = top
	coin_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(coin_box)
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 6)
	coin_box.add_child(crow)
	crow.add_child(UiKit.icon("coins", 22))
	_coins_label = UiKit.title("0", 16)
	crow.add_child(_coins_label)


func _bar(color: Color, width := 96.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(width, 9)
	b.show_percentage = false
	b.max_value = 1.0
	b.step = 0.0
	var bg := UiKit.box(Color(0, 0, 0, 0.35), UiKit.OUTLINE, 5, 1, false)
	bg.set_content_margin_all(0)
	var fill := UiKit.box(color, Color(0, 0, 0, 0), 5, 0, false)
	fill.set_content_margin_all(0)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fill)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _build_bottom() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var bottom: float = UiKit.safe_insets(get_viewport())["bottom"]
	bar.offset_left = -90
	bar.offset_right = 90
	bar.offset_top = -70 - bottom
	bar.offset_bottom = -18 - bottom
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 10)
	root.add_child(bar)
	var storage := UiKit.button(L.t("hud.storage"), "wood", 15)
	storage.custom_minimum_size = Vector2(150, 48)
	storage.icon = Sprites.icon("chest")
	storage.expand_icon = false
	storage.pressed.connect(_open_storage)
	storage.set_meta("key", "hud.storage")
	bar.add_child(storage)


func _build_banner() -> void:
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_left = -160
	_banner.offset_right = 160
	_banner.offset_top = _safe_top() + 150
	_banner.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.modulate.a = 0.0
	root.add_child(_banner)


func _show_banner(id: String) -> void:
	for c in _banner.get_children():
		c.queue_free()
	var t := UiKit.title(Locations.name_of(id), 28)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(t)
	var sub := UiKit.label(Locations.blurb(id), 13, Color.WHITE, 4)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(320, 0)
	_banner.add_child(sub)
	if _banner_tween != null:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.4)
	_banner_tween.tween_interval(2.2)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.6)


func _process(delta: float) -> void:
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.2
		_refresh_values()
	if _shown_location != Game.current:
		_shown_location = Game.current
		_show_banner(Game.current)


func _refresh_values() -> void:
	_level_label.text = str(Game.level)
	_level_name.text = L.t("level.n", [Game.level])
	_xp_bar.value = Game.level_progress
	_coins_label.text = Fmt.n(int(Game.save["coins"]))
	var cap := Game.stats.capacity
	_pack_label.text = "%d/%d" % [Game.backpack_count, cap]
	_pack_bar.value = float(Game.backpack_count) / float(maxi(1, cap))


func _refresh_texts() -> void:
	_refresh_values()
	for b in root.find_children("*", "Button", true, false):
		if b.has_meta("key"):
			b.text = L.t(b.get_meta("key"))


func _on_toast(icon: String, text: String) -> void:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.PARCHMENT_LIGHT, 0.97), UiKit.OUTLINE, 14, 2))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	if icon.begins_with("px:"):
		row.add_child(UiKit.icon(icon.substr(3), 22))
	var l := UiKit.label(text, 13, UiKit.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(230, 0)
	row.add_child(l)
	_toasts.add_child(box)
	box.modulate.a = 0.0
	var tw := box.create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.4)
	tw.tween_property(box, "modulate:a", 0.0, 0.3)
	tw.tween_callback(box.queue_free)


func _on_level_up(_from: int, to: int) -> void:
	_on_toast("px:star", L.t("level.n", [to]) + "! " + L.t("reward.coins", [Fmt.n(Game.level_coin_reward(to))]))


# MARK: Окна

func _open_storage() -> void:
	open_window(StoragePanel.new())


func open_window(w: Control) -> void:
	close_window()
	_window = w
	root.add_child(w)


func close_window() -> void:
	if _window != null and is_instance_valid(_window):
		_window.queue_free()
	_window = null
