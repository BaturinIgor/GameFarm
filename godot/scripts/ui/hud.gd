class_name Hud
extends CanvasLayer
## Шапка игры: уровень и опыт, монеты, рюкзак, кнопки окон, всплывающие сообщения и название локации.

## Окна нижней панели: id, иконка, ключ подписи, скрипт окна. Кнопка есть, только если окно уже сделано.
const WINDOWS := [
	["storage", "chest", "hud.storage", "res://scripts/ui/storage_panel.gd"],
	["workshop", "tool_hammer", "hud.workshop", "res://scripts/ui/workshop_panel.gd"],
	["talents", "stardust", "hud.talents", "res://scripts/ui/talents_panel.gd"],
	["animals", "paw", "hud.animals", "res://scripts/ui/animals_panel.gd"],
	["quests", "scroll", "hud.quests", "res://scripts/ui/quests_panel.gd"],
	["collection", "cards", "hud.collection", "res://scripts/ui/collection_panel.gd"],
	["map", "map", "hud.map", "res://scripts/ui/map_panel.gd"],
]
const LEVEL_PANEL := "res://scripts/ui/level_panel.gd"

## Текущая шапка: фичи сцены показывают через неё карточки и окна.
static var current: Hud

var root := Control.new()
var _prompts := VBoxContainer.new()
var _prompt_cards: Dictionary = {}
var _overlay_layer := CanvasLayer.new()
var _badges: Dictionary = {}
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
	current = self
	layer = 10
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	level_box.mouse_filter = Control.MOUSE_FILTER_STOP
	level_box.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT \
				and ResourceLoader.exists(LEVEL_PANEL):
			open_window(load(LEVEL_PANEL).new()))
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
	var bottom: float = UiKit.safe_insets(get_viewport())["bottom"]
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 10
	bar.offset_right = -10
	bar.offset_top = -64 - bottom
	bar.offset_bottom = -6 - bottom
	bar.add_theme_constant_override("separation", 5)
	root.add_child(bar)
	for w in WINDOWS:
		if not ResourceLoader.exists(w[3]):
			continue
		bar.add_child(_hud_button(w))

	# Карточки-подсказки над кнопками (приручить зверя, проход, дом...)
	_prompts.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_prompts.offset_left = 12
	_prompts.offset_right = -12
	_prompts.offset_bottom = -72 - bottom
	_prompts.offset_top = -72 - bottom
	_prompts.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompts.alignment = BoxContainer.ALIGNMENT_END
	_prompts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompts.add_theme_constant_override("separation", 8)
	root.add_child(_prompts)


## Кнопка нижней панели (HUDButton): иконка, подпись и счётчик.
func _hud_button(w: Array) -> Control:
	var b := Button.new()
	var style := UiKit.pill_style()
	style.set_corner_radius_all(14)
	style.set_content_margin_all(2)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var s := style.duplicate() as StyleBoxFlat
		if state == "pressed":
			s.bg_color = UiKit.WOOD_DARK
		b.add_theme_stylebox_override(state, s)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 58)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	var ic := UiKit.icon(w[1], 30)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(ic)
	var t := UiKit.title(L.t(w[2]), 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.clip_text = true
	t.set_meta("key", w[2])
	col.add_child(t)
	var badge := UiKit.count_badge(0)
	badge.position = Vector2(0, -7)
	badge.visible = false
	b.add_child(badge)
	_badges[w[0]] = badge
	b.pressed.connect(func() -> void: open_named(w[0]))
	return b


## Открыть окно по имени из WINDOWS (storage, workshop, talents, ...).
func open_named(id: String) -> void:
	for w in WINDOWS:
		if w[0] == id and ResourceLoader.exists(w[3]):
			open_window(load(w[3]).new())
			return


## Полноэкранная заставка поверх окон (новый уровень, доход за время без игры, клад).
## Заставка сама убирает себя через queue_free().
func show_overlay(c: Control) -> void:
	if _overlay_layer.get_parent() == null:
		_overlay_layer.layer = 20
		add_child(_overlay_layer)
	_overlay_layer.add_child(c)


## Показать карточку-подсказку над кнопками (null - убрать). Одна карточка на ключ.
func set_prompt(key: String, card: Control) -> void:
	if _prompt_cards.has(key):
		var old: Control = _prompt_cards[key]
		if is_instance_valid(old) and old != card:
			old.queue_free()
		_prompt_cards.erase(key)
	if card != null:
		_prompt_cards[key] = card
		if card.get_parent() == null:
			_prompts.add_child(card)


func _update_badges() -> void:
	for id in _badges:
		var n := 0
		match id:
			"workshop":
				if Game.workshop.has_method("upgradable_count"):
					n = Game.workshop.upgradable_count()
			"talents":
				if Game.talents.has_method("points_free"):
					n = Game.talents.points_free()
			"quests":
				if Game.quests.has_method("claimable_count"):
					n = Game.quests.claimable_count()
		var badge: PanelContainer = _badges[id]
		badge.visible = n > 0
		if n > 0:
			(badge.get_child(0) as Label).text = str(n)
			badge.position.x = badge.get_parent().size.x - 16


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
	_update_badges()


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

func open_window(w: Control) -> void:
	close_window()
	_window = w
	root.add_child(w)


func close_window() -> void:
	if _window != null and is_instance_valid(_window):
		_window.queue_free()
	_window = null
