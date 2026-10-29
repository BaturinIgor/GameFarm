class_name EventPill
extends Control
## Кнопка ивента в правом столбце под монетами (порт EventHUDPill): значок праздника, таймер до конца
## и отметка о наградах (счётчик или "!", если ивент ещё не открывали). По нажатию - окно ивентов.
## До уровня ивентов прячется.

var _panel := PanelContainer.new()
var _icon: TextureRect
var _time: Label
var _badge: Control
var _shown := ""
var _tick := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(row)
	_icon = UiKit.icon("star", 18)
	row.add_child(_icon)
	_time = UiKit.title("", 12)
	_time.label_settings.outline_size = 4
	row.add_child(_time)
	visible = false


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		EventsPanel.open()


func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.5
	visible = Game.events.events_open()
	if not visible:
		return
	var run := Events.current()
	_time.text = EventsPanel.short_countdown(float(run["end"]) - Time.get_unix_time_from_system())
	var claimable := Game.events.event_claimable()
	var fresh := Game.events.event_is_new()
	var key := "%s|%d|%s" % [run["key"], claimable, fresh]
	if key != _shown:
		_shown = key
		_restyle(run["event"], claimable, fresh)
	custom_minimum_size = _panel.get_combined_minimum_size()
	if _badge != null:
		var b := _badge.get_combined_minimum_size()
		_badge.position = Vector2(custom_minimum_size.x + 8.0 - b.x, -8.0)


func _restyle(event: String, claimable: int, fresh: bool) -> void:
	var s := UiKit.pill_style()
	s.bg_color = Events.COLORS[event][1]
	s.set_corner_radius_all(13)
	s.content_margin_top = 5
	s.content_margin_bottom = 5
	_panel.add_theme_stylebox_override("panel", s)
	_icon.texture = Sprites.icon(Events.ICON[event])
	if _badge != null:
		_badge.queue_free()
		_badge = null
	if claimable > 0:
		_badge = UiKit.count_badge(claimable)
	elif fresh:
		_badge = UiKit.count_badge(0)
		(_badge.get_child(0) as Label).text = "!"
	if _badge != null:
		add_child(_badge)
