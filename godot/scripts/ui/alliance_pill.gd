class_name AlliancePill
extends Button
## Плашка альянса на главном экране, чтобы альянсы было легко найти.
## Не в альянсе: "Альянсы" с отметкой, пока игрок ни разу не открыл окно. В альянсе: эмблема и что ждёт:
## награда событий, удары по стражу или бесплатные вклады на сегодня. В остальное время скрыта.

var _row := HBoxContainer.new()
var _icon: TextureRect
var _text: Label
var _badge: Control
var _tick := 0.0
var _shown := ""


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var s := UiKit.pill_style()
	s.set_corner_radius_all(13)
	s.set_content_margin_all(0)
	var down := s.duplicate() as GameStyle
	down.bg_color = s.bg_color.darkened(0.15)
	for state in ["normal", "hover", "disabled", "focus"]:
		add_theme_stylebox_override(state, s)
	add_theme_stylebox_override("pressed", down)
	add_theme_stylebox_override("hover_pressed", down)
	_row.add_theme_constant_override("separation", 5)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_row)
	_icon = UiKit.icon("crown", 20)
	_row.add_child(_icon)
	_text = UiKit.title("", 12)
	_text.label_settings.outline_size = 4
	_row.add_child(_text)
	pressed.connect(func() -> void: Nav.open_sub("alliance"))
	visible = false


func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.5
	_refresh()


func _refresh() -> void:
	var al := Game.alliance
	var mode := ""
	if al.open():
		if not al.in_alliance():
			mode = "" if al.seen() else "invite"
		elif not al.claimable().is_empty():
			mode = "reward"
		elif al.hits_left() > 0 and not al.ev.is_empty():
			mode = "hits"
		elif al.free_left() > 0:
			mode = "free"
	var key := "%s|%d|%d|%d|%s" % [mode, al.free_left(), al.hits_left(), int(Game.save.get("alliance", {}).get("emblem", 0)), L.code]
	if key == _shown:
		return
	_shown = key
	visible = mode != ""
	if not visible:
		return
	if mode == "invite":
		_icon.texture = UiKit.icon("crown", 20).texture
		_text.text = L.t("alliance.pill")
	else:
		var emblem := int(Game.save["alliance"].get("emblem", 0))
		_icon.texture = UiKit.icon(Alliances.emblem_icon(emblem), 20).texture
		match mode:
			"reward": _text.text = L.t("alliance.pillReward")
			"hits": _text.text = L.t("alliance.pillHits", [al.hits_left()])
			_: _text.text = L.t("alliance.pillFree", [al.free_left()])
	if _badge == null and mode in ["invite", "reward"]:
		_badge = UiKit.count_badge(0)
		(_badge.get_child(0) as Label).text = "!"
		UiKit.pin_badge(_badge, self)
	elif _badge != null and not mode in ["invite", "reward"]:
		_badge.queue_free()
		_badge = null
	custom_minimum_size = _row.get_combined_minimum_size() + Vector2(16, 10)
