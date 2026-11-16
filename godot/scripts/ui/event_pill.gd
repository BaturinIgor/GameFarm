class_name EventPill
extends Button
## Кружок ивента в ряду таймеров под магазином (порт EventHUDPill): значок праздника, таймер до конца
## и отметка о наградах (счётчик или "!", если ивент ещё не открывали). По нажатию - окно ивентов.
## До уровня ивентов прячется.

var _icon: TextureRect
var _time: Label
var _badge: PanelContainer
var _shown := ""
var _tick := 0.0


func _init() -> void:
	_icon = UiKit.icon("star", 26)
	_time = HudRound.circle(self, _icon, Color(UiKit.WOOD, 0.95))
	_badge = UiKit.count_badge(0)
	_badge.visible = false
	UiKit.pin_badge(_badge, self)
	pressed.connect(func() -> void: EventsPanel.open())
	visible = false


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
	var claimable := Game.events.event_claimable() + Game.farm.claimable()
	var fresh := Game.events.event_is_new() or Game.farm.is_new()
	var key := "%s|%d|%s" % [run["key"], claimable, fresh]
	if key != _shown:
		_shown = key
		_restyle(run["event"], claimable, fresh)


func _restyle(event: String, claimable: int, fresh: bool) -> void:
	HudRound.tint(self, Events.COLORS[event][1])
	_icon.texture = Sprites.icon(Events.ICON[event])
	_badge.visible = claimable > 0 or fresh
	(_badge.get_child(0) as Label).text = str(mini(claimable, 99)) if claimable > 0 else "!"
