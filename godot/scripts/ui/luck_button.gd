class_name LuckButton
extends Button
## Удача: x2 ресурсов на 10 минут за рекламу, для Pro без рекламы (порт LuckButton).
## Вид "pill" - плашка в шапке рядом с магазином, "wide" - широкая кнопка в магазине.

var kind := "pill"
var _row := HBoxContainer.new()
## В плашке - время или x2, в широкой кнопке - строка под заголовком.
var _text: Label
var _ad: Control
var _state := ""
var _tick := 0.0


func _init(style := "pill") -> void:
	kind = style
	focus_mode = Control.FOCUS_NONE
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_row)
	if kind == "wide":
		_build_wide()
	else:
		_build_pill()
	pressed.connect(_watch)
	_refresh()


func _build_pill() -> void:
	_row.add_theme_constant_override("separation", 5)
	_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_row.add_child(UiKit.icon("clover", 16))
	_text = UiKit.title("", 12)
	_text.label_settings.outline_size = 4
	_row.add_child(_text)
	_ad = Ads.mark(11.0)
	_row.add_child(_ad)


func _build_wide() -> void:
	var proto := UiKit.button("", "green", 15)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, proto.get_theme_stylebox(state))
	proto.free()
	custom_minimum_size = Vector2(0, 64)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row.add_theme_constant_override("separation", 10)
	_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_row.offset_left = 14
	_row.offset_right = -14
	var clover := UiKit.icon("clover", 28)
	clover.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row.add_child(clover)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(col)
	var title := UiKit.title(L.t("luck.title"), 16)
	title.label_settings.outline_size = 5
	_clip(title)
	col.add_child(title)
	_text = UiKit.title("", 12)
	_text.label_settings.outline_size = 4
	_clip(_text)
	col.add_child(_text)
	_ad = Ads.mark(19.0)
	_row.add_child(_ad)


static func _clip(l: Label) -> void:
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size = Vector2(10, 0)


func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.25
	_refresh()


func _refresh() -> void:
	var p := Game.premium
	var now := Time.get_unix_time_from_system()
	var active := p.luck_active()
	var can := p.luck_ready()
	var until := float(Game.save.get("luckUntil", now))
	var ready_at := float(Game.save.get("luckReadyAt", now))
	_ad.visible = can and not p.has_pro()
	if kind == "wide":
		if active:
			_text.text = L.t("luck.active", [House.countdown(until - now)])
		elif can:
			_text.text = L.t("luck.ready.pro") if p.has_pro() else L.t("luck.ready")
		else:
			_text.text = L.t("luck.cooldown", [House.countdown(ready_at - now)])
		disabled = not can
		return
	if active:
		_text.text = House.countdown(until - now)
	elif can:
		_text.text = "x2"
	else:
		_text.text = House.countdown(ready_at - now)
	_text.modulate.a = 1.0 if active or can else 0.8
	var state := "active" if active else "idle"
	if state != _state:
		_state = state
		_pill_style(active)
	custom_minimum_size = _row.get_combined_minimum_size() + Vector2(16, 12)


## Деревянная плашка, пока удача действует - зелёная.
func _pill_style(active: bool) -> void:
	var s := UiKit.pill_style()
	s.set_corner_radius_all(13)
	s.set_content_margin_all(0)
	s.bg_color = UiKit.TONES["green"][1] if active else Color(UiKit.WOOD, 0.95)
	var down := s.duplicate() as GameStyle
	down.bg_color = s.bg_color.darkened(0.15)
	for state in ["normal", "hover", "disabled"]:
		add_theme_stylebox_override(state, s)
	add_theme_stylebox_override("pressed", down)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _watch() -> void:
	if not Game.premium.luck_ready():
		return
	Ads.show_rewarded(func() -> void:
		Game.premium.activate_luck(not Game.premium.has_pro())
		Input.vibrate_handheld(20))
