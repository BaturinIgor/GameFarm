class_name HomeCard
extends PanelContainer
## Карточка внизу экрана в доме: станция, недостроенный этаж или место для украшения (порт HomeCard).
## У двери дома на лугу - карточка дома с кнопкой "Войти" (PlaceCard для дома).
## Показывается через Hud.current.set_prompt("home", card) и set_prompt("house", card).

## {"type": "station", "kind"}, {"type": "build", "floor"}, {"type": "slot", "id"} или {"type": "door"}.
var prompt: Dictionary

var _row := HBoxContainer.new()
var _dirty := true
var _tick := 0.0
# Что меняется со временем, а не с Game.changed (пересоздаются в каждой перестройке)
var _badge: Control
var _bed_button: Button
var _ticket_label: Label
var _ticket_ready := false


func _init(p: Dictionary) -> void:
	prompt = p
	add_theme_stylebox_override("panel", UiKit.panel_style(18))
	mouse_filter = Control.MOUSE_FILTER_STOP
	_row.add_theme_constant_override("separation", 12)
	add_child(_row)


## Ключ подсказки: одинаковые подсказки не пересоздают карточку.
static func key_of(p: Dictionary) -> String:
	if p.is_empty():
		return ""
	return "%s:%s" % [p.get("type", ""), p.get("kind", p.get("floor", p.get("id", "")))]


func _ready() -> void:
	Game.changed.connect(_on_changed)
	L.language_changed.connect(_on_changed)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)


func _on_changed() -> void:
	_dirty = true


func _process(delta: float) -> void:
	if _dirty and not UiKit.touch_held(self):
		_dirty = false
		for c in _row.get_children():
			c.queue_free()
		_badge = null
		_bed_button = null
		_ticket_label = null
		_build()
		_tick = 0.0
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.5
		_update_live()


func _build() -> void:
	match str(prompt.get("type", "")):
		"station": _build_station(str(prompt["kind"]))
		"build": _build_floor(str(prompt["floor"]))
		"slot": _build_slot(str(prompt["id"]))
		"door": _build_door()


## Счётчик на двери, кнопка кровати и таймер сундука с билетом меняются со временем.
func _update_live() -> void:
	if _badge != null:
		_badge.visible = Game.house.can_claim_login() or Game.house.has_ready_dishes()
	if _bed_button != null:
		_bed_button.disabled = _hp_full()
	if str(prompt.get("type", "")) == "station" and prompt.get("kind") == "chest":
		if _ticket_is_ready() != _ticket_ready:
			_dirty = true
		elif _ticket_label != null:
			var next = _next_ticket()
			_ticket_label.text = House.countdown(float(next) - Time.get_unix_time_from_system()) if next != null else ""


# MARK: Части карточки

func _text_column(title: String, hint: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 3)
	_row.add_child(col)
	col.add_child(UiKit.label(title, 15))
	if hint != "":
		var h := UiKit.label(hint, 11, UiKit.INK_SOFT)
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(h)
	return col


func _icon(icon_name: String, side: float) -> void:
	var ic := UiKit.icon(icon_name, side)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row.add_child(ic)


func _button(text: String, tone: String, action: Callable, small := true) -> Button:
	var b := UiKit.button(text, tone, 14 if small else 15, small)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(action)
	_row.add_child(b)
	return b


func _build_station(kind: String) -> void:
	_icon(House.station_icon(kind), 40)
	_text_column(House.station_title(kind), House.station_hint(kind))
	match kind:
		"bed":
			_bed_button = _button(L.t("home.bed.action"), "blue", Game.house.rest)
			_bed_button.disabled = _hp_full()
		"chest":
			_ticket_ready = _ticket_is_ready()
			if _ticket_ready:
				_button(L.t("home.chest.action"), "orange", func() -> void:
					if Game.premium.has_method("claim_free_ticket"):
						Game.premium.call("claim_free_ticket"))
			elif _next_ticket() != null:
				_ticket_label = UiKit.label("", 13, UiKit.INK_SOFT)
				_ticket_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				_row.add_child(_ticket_label)
		_:
			var id: String = House.STATION_WINDOW.get(kind, "")
			var b := _button(L.t("home.open"), "green", func() -> void: HomeCard.open_window_id(id))
			b.disabled = not HomeCard.window_exists(id)


## Лестница на ещё не построенный этаж.
func _build_floor(f: String) -> void:
	_icon("stairs", 40)
	var col := _text_column(L.t("home.build.title", [House.floor_title(f)]), House.floor_perk(f))
	var level_ok := Game.level >= House.floor_level(f)
	if level_ok:
		col.add_child(UiKit.cost_view(House.floor_cost(f)))
	var b := _button(L.t("house.build") if level_ok else L.t("common.needLevel", [House.floor_level(f)]), "green",
		func() -> void: Game.house.build(f))
	b.disabled = not Game.house.can_build(f)


## Место для украшения: что стоит или кнопка "Украсить".
func _build_slot(slot: String) -> void:
	var decor := Game.house.decor_at(slot)
	if decor != "":
		var pic := HousePanel.sprite_rect(House.decor_sprite(decor), 1.2, Vector2(44, 44))
		pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_row.add_child(pic)
		var col := _text_column(House.decor_name(decor), "")
		col.add_child(UiKit.label(L.t("decor.comfort", [House.decor_comfort(decor)]), 11, UiKit.GOOD))
		_button(L.t("decor.remove.action"), "red", func() -> void: HomeCard.confirm_remove(slot))
	else:
		_icon("plan", 40)
		_text_column(L.t("home.slot"), L.t("home.slot.hint", [Game.house.comfort()]))
		_button(L.t("home.slot.action"), "green", func() -> void:
			if Hud.current != null:
				Hud.current.open_window(HousePanel.DecorPicker.new(slot)))


## У двери дома на лугу (PlaceCard): войти и счётчик, если есть награда или готовое блюдо.
func _build_door() -> void:
	_icon("stairs", 36)
	var col := _text_column(L.t("house.title"), "")
	var sub := UiKit.label(L.t("house.hint"), 12, UiKit.INK_SOFT)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(sub)
	var b := _button(L.t("house.enter"), "orange", Game.house.enter_house, false)
	var badge := UiKit.count_badge(1)
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge.offset_left = -14
	badge.offset_right = 6
	badge.offset_top = -8
	badge.offset_bottom = 12
	badge.visible = false
	b.add_child(badge)
	_badge = badge


# MARK: Чужие системы (бой, экспедиции): пока их нет, кнопки неактивны

func _hp_full() -> bool:
	if not Game.combat.has_method("hp_fraction"):
		return true
	return float(Game.combat.call("hp_fraction")) >= 0.999


func _ticket_is_ready() -> bool:
	return Game.premium.has_method("free_ticket_ready") and bool(Game.premium.call("free_ticket_ready"))


## Когда будет следующий бесплатный билет (unix-секунды или null).
func _next_ticket() -> Variant:
	if not Game.premium.has_method("next_free_ticket"):
		return null
	return Game.premium.call("next_free_ticket")


# MARK: Окна и подтверждение

## Открыть окно по id (kitchen, calendar, house или файл scripts/ui/<id>_panel.gd).
static func open_window_id(id: String) -> void:
	if Hud.current == null:
		return
	match id:
		"kitchen": Hud.current.open_window(KitchenPanel.new())
		"calendar": Hud.current.open_window(CalendarPanel.new())
		"house": Hud.current.open_window(HousePanel.new())
		_:
			if window_exists(id):
				Hud.current.open_window(load(_window_path(id)).new())


static func window_exists(id: String) -> bool:
	return id in ["kitchen", "calendar", "house"] or (id != "" and ResourceLoader.exists(_window_path(id)))


static func _window_path(id: String) -> String:
	return "res://scripts/ui/%s_panel.gd" % id


## "Убрать украшение?": украшение пропадёт, ресурсы не возвращаются.
static func confirm_remove(slot: String) -> void:
	var decor := Game.house.decor_at(slot)
	if decor == "" or Hud.current == null:
		return
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = UiKit.DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			layer.queue_free())
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	var box := PanelContainer.new()
	var st := UiKit.panel_style(18)
	st.set_content_margin_all(20)
	box.add_theme_stylebox_override("panel", st)
	box.custom_minimum_size = Vector2(300, 0)
	center.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	box.add_child(v)
	var ic := UiKit.icon("plan", 44)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var title := UiKit.label(L.t("decor.remove", [House.decor_name(decor)]), 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(title)
	var msg := UiKit.label(L.t("decor.remove.message"), 13, UiKit.INK_SOFT)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(msg)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	v.add_child(buttons)
	var cancel := UiKit.button(L.t("common.cancel"), "wood", 15)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(layer.queue_free)
	buttons.add_child(cancel)
	var ok := UiKit.button(L.t("decor.remove.action"), "red", 15)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(func() -> void:
		Game.house.remove_decor(slot)
		layer.queue_free())
	buttons.add_child(ok)
	Hud.current.show_overlay(layer)
