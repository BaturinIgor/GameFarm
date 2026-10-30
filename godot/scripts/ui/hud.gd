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
## Плашки справа под монетами (блюдо, этаж дома, ивент...): Control, сам прячется, когда не нужен.
const PILLS := [
	"res://scripts/ui/shop_pill.gd",
	"res://scripts/ui/estate_pill.gd",
	"res://scripts/ui/event_pill.gd",
	"res://scripts/ui/meal_pill.gd",
	"res://scripts/ui/expedition_pill.gd",
	"res://scripts/ui/event_map_pill.gd",
	"res://scripts/ui/home_floor_pill.gd",
	"res://scripts/ui/dungeon_pill.gd",
]

## Текущая шапка: фичи сцены показывают через неё карточки и окна.
static var current: Hud

var root := Control.new()
var _prompts := VBoxContainer.new()
var _pills := VBoxContainer.new()
var _level_box: PanelContainer
var _pack_box: PanelContainer
var _potion: PotionButton
## Ряд справа над нижней панелью: расходники и зелье.
var _combat_row := CombatRow.new()
var _minimap: MiniMap
var _pro_crown: TextureRect
var _badge_box: PanelContainer
var _portrait: TextureRect
var _portrait_skin := ""
var _prompt_cards: Dictionary = {}
var _overlay_layer := CanvasLayer.new()
var _badges: Dictionary = {}
var _level_label: Label
var _level_name: Label
var _xp_bar: ProgressBar
## Ширина подписи нижней кнопки: 7 кнопок в ряд на узком экране.
const TAB_LABEL_WIDTH := 44.0

var _coins_label: Label
var _crystals_label: Label
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
	if not bool(Game.save.get("tutorialDone", false)):
		set_prompt("tutorial", _tutorial_card())
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
	# Портрет героя в светлой рамке, номер уровня - в оранжевом кружке в углу (как в iOS)
	var badge := PanelContainer.new()
	var badge_style := UiKit.box(UiKit.PARCHMENT_LIGHT, UiKit.OUTLINE, 10, 2, false)
	badge_style.set_content_margin_all(2)
	badge.add_theme_stylebox_override("panel", badge_style)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(46, 46)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(holder)
	badge.position = Vector2.ZERO
	badge.size = Vector2(42, 42)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(badge)
	_badge_box = badge
	_portrait = WardrobePanel.skin_icon(Skins.current(), 36)
	_portrait_skin = Skins.current()
	badge.add_child(_portrait)
	var num := PanelContainer.new()
	var ns := UiKit.box(UiKit.TONES["orange"][1], UiKit.OUTLINE, 11, 2, false)
	ns.content_margin_left = 3
	ns.content_margin_right = 3
	ns.content_margin_top = 0
	ns.content_margin_bottom = 0
	num.add_theme_stylebox_override("panel", ns)
	num.custom_minimum_size = Vector2(22, 22)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level_label = UiKit.title("1", 13)
	_level_label.label_settings.outline_size = 4
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.add_child(_level_label)
	holder.add_child(num)
	# Кружок выходит за рамку портрета вниз и вправо
	num.resized.connect(func() -> void: num.position = Vector2(46, 46) - num.size * 0.8)
	num.position = Vector2(46, 46) - Vector2(22, 22) * 0.8
	_pro_crown = UiKit.icon("crown", 16)
	root.add_child(_pro_crown)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	_level_name = UiKit.title("", 13)
	_level_name.custom_minimum_size = Vector2(140, 0)
	_level_name.clip_text = true
	col.add_child(_level_name)
	_xp_bar = UiKit.bar(0.0, "gold", 140, 14, " ")
	col.add_child(_xp_bar)
	# Здоровье: видно в бою или если ранен
	col.add_child(CombatCards.HpStrip.new())
	_level_box = level_box

	# Рюкзак справа под монетами (как в iOS), первой плашкой в столбце справа
	var pack_box := PanelContainer.new()
	pack_box.add_theme_stylebox_override("panel", UiKit.pill_style())
	pack_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pack_box.size_flags_horizontal = Control.SIZE_SHRINK_END
	_pills.add_child(pack_box)
	_pack_box = pack_box
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 6)
	pack_box.add_child(prow)
	prow.add_child(UiKit.icon("bag", 22))
	var pcol := VBoxContainer.new()
	pcol.add_theme_constant_override("separation", 1)
	prow.add_child(pcol)
	_pack_bar = UiKit.bar(0.0, "green", 100, 14, " ")
	_pack_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pcol.add_child(_pack_bar)
	_minimap = MiniMap.new()
	_minimap.position = Vector2(10, top + 96)
	root.add_child(_minimap)

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
	# Кристаллы: нажатие открывает магазин на вкладке кристаллов
	var gem_button := Button.new()
	gem_button.flat = true
	gem_button.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		gem_button.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	gem_button.pressed.connect(func() -> void: ShopPanel.open("crystals"))
	crow.add_child(gem_button)
	var grow := HBoxContainer.new()
	grow.add_theme_constant_override("separation", 3)
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gem_button.add_child(grow)
	grow.add_child(UiKit.icon("gem", 20))
	_crystals_label = UiKit.title("0", 15)
	grow.add_child(_crystals_label)
	grow.resized.connect(func() -> void: gem_button.custom_minimum_size = grow.size)
	var sep := ColorRect.new()
	sep.color = Color(UiKit.OUTLINE, 0.35)
	sep.custom_minimum_size = Vector2(2, 18)
	sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crow.add_child(sep)
	crow.add_child(UiKit.icon("coin", 22))
	_coins_label = UiKit.title("0", 16)
	crow.add_child(_coins_label)

	_pills.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_pills.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_pills.offset_left = -10
	_pills.offset_right = -10
	_pills.offset_top = top + 42
	_pills.alignment = BoxContainer.ALIGNMENT_BEGIN
	_pills.add_theme_constant_override("separation", 6)
	_pills.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_pills)

	# Полоска босса под шапкой
	var boss := BossBar.new()
	boss.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	boss.grow_horizontal = Control.GROW_DIRECTION_BOTH
	boss.offset_top = top + 92
	root.add_child(boss)
	for path in PILLS:
		if ResourceLoader.exists(path):
			var pill: Control = load(path).new()
			pill.size_flags_horizontal = Control.SIZE_SHRINK_END
			_pills.add_child(pill)


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
	# Зелье и расходники справа над нижней панелью, под карточками
	_combat_row.size_flags_horizontal = Control.SIZE_SHRINK_END
	_combat_row.add_theme_constant_override("separation", 8)
	_combat_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompts.add_child(_combat_row)
	var items := ConsumableBar.new()
	items.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_combat_row.add_child(items)
	_potion = PotionButton.new()
	_potion.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_combat_row.add_child(_potion)


## Подсказка новичку (TutorialCard): как ходить, добывать и сдавать на склад.
func _tutorial_card() -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.panel_style(16))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	p.add_child(col)
	col.add_child(UiKit.label(L.t("tutorial.title"), 16))
	for row in [["paw", "tutorial.move"], ["tool_pickaxe", "tutorial.gather"], ["chest", "tutorial.deposit"]]:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		h.add_child(UiKit.icon(row[0], 20))
		var l := UiKit.label(L.t(row[1]), 13)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		col.add_child(h)
	# Подсказка не мешает касаниям: под ней джойстик
	for c in p.find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## Кнопка нижней панели (HUDButton): иконка, подпись и счётчик.
func _hud_button(w: Array) -> Control:
	var b := Button.new()
	var style := UiKit.pill_style()
	style.set_corner_radius_all(14)
	style.set_content_margin_all(2)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var s := style.duplicate() as GameStyle
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
	t.set_meta("fit", 10)
	UiKit.fit_label(t, TAB_LABEL_WIDTH, 10)
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
## Кнопка "Назад" на Android: закрыть верхнюю заставку, иначе окно. false - закрывать было нечего.
func back() -> bool:
	if _overlay_layer.get_parent() != null:
		var kids := _overlay_layer.get_children().filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())
		if not kids.is_empty():
			var top: Node = kids[-1]
			if top.has_method("close"):
				top.call("close")
			else:
				top.queue_free()
			return true
	if has_window():
		close_window()
		return true
	return false


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
			if _potion != null:
				_prompts.move_child(_combat_row, -1)


func _update_badges() -> void:
	for id in _badges:
		var n := 0
		match id:
			"map":
				n = Game.world_map.openable_gates() + (1 if Game.premium.free_ticket_ready() else 0)
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
		# В доме названия нет (как в iOS): этажи меняются часто
		if Locations.kind(Game.current) != "home":
			_show_banner(Game.current)


func _refresh_values() -> void:
	# Сменили образ - новый портрет
	if _portrait != null and _portrait_skin != Skins.current():
		_portrait_skin = Skins.current()
		var tex := LevelPanel.portrait(_portrait_skin)
		if tex != null:
			_portrait.texture = tex
	if _pro_crown != null:
		_pro_crown.visible = Game.premium.has_pro()
		_pro_crown.global_position = _badge_box.global_position + Vector2(_badge_box.size.x - 10, -8)
	if _level_box != null and _minimap != null:
		_minimap.position = Vector2(10, _level_box.get_rect().end.y + 10.0)
	_level_label.text = str(Game.level)
	_level_name.text = Locations.name_of(Game.current)
	_xp_bar.value = Game.level_progress
	(_xp_bar.get_child(0) as Label).text = L.t("level.max") if Game.level >= Game.MAX_LEVEL \
		else "%s/%s" % [Fmt.n(int(Game.save["xp"])), Fmt.n(Game.xp_needed)]
	_coins_label.text = Fmt.n(int(Game.save["coins"]))
	_crystals_label.text = Fmt.n(Game.shop.crystals())
	var cap := Game.stats.capacity
	var fraction := minf(1.0, float(Game.backpack_count) / float(maxi(1, cap)))
	_pack_bar.value = fraction
	(_pack_bar.get_child(0) as Label).text = "%d/%d" % [Game.backpack_count, cap]
	var tone := "red" if fraction >= 1.0 else ("orange" if fraction > 0.8 else "green")
	(_pack_bar as GameBar).tone = tone
	_update_badges()
	if _prompt_cards.has("tutorial") and bool(Game.save.get("tutorialDone", false)):
		set_prompt("tutorial", null)


func _refresh_texts() -> void:
	_refresh_values()
	# Подписи вкладок - Label, у кнопок с текстом - сама кнопка
	for n in root.find_children("*", "", true, false):
		if n.has_meta("key") and (n is Label or n is Button):
			n.text = L.t(n.get_meta("key"))
			if n is Label and n.has_meta("fit"):
				UiKit.fit_label(n, TAB_LABEL_WIDTH, int(n.get_meta("fit")))


func _on_toast(icon: String, text: String) -> void:
	# Как в iOS: одинаковый тост не дублируется, на экране не больше трёх
	var live := _toasts.get_children().filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())
	for t in live:
		if t.get_meta("text", "") == text:
			return
	if live.size() >= 3:
		live[0].queue_free()
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.PARCHMENT_LIGHT, 0.97), UiKit.OUTLINE, 14, 2))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_meta("text", text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	if icon != "":
		row.add_child(UiKit.icon_any(icon, 22))
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


func _on_level_up(from: int, to: int) -> void:
	LevelUpOverlay.present(from, to)


# MARK: Окна

func open_window(w: Control) -> void:
	close_window()
	_window = w
	root.add_child(w)
	Sound.set_window_open(true)


## Открыто ли сейчас окно (магазин, склад...).
func has_window() -> bool:
	return _window != null and is_instance_valid(_window)


func close_window() -> void:
	if _window != null and is_instance_valid(_window):
		_window.queue_free()
	_window = null
	Sound.set_window_open(false)


## Ряд зелья и расходников: виден, только когда видна хоть одна кнопка (иначе лишний отступ в столбце).
class CombatRow extends HBoxContainer:
	func _process(_delta: float) -> void:
		var any := false
		for c in get_children():
			if c is Control and (c as Control).visible:
				any = true
		visible = any
