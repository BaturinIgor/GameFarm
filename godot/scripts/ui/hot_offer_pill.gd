class_name HotOfferPill
extends Button
## Горячее предложение на главном экране: красная пульсирующая квадратная кнопка под сундуками, внизу таймер.
## Показывает самое срочное: набор новичка или набор по уровню (пока идёт его окно), иначе предложение дня
## и скидку дня, пока их не купили сегодня. Нажатие - магазин на вкладке акций. Нечего предложить - прячется.

const FILL := Color("e8463c")
const RIM := Color("ffcf4a")

var _icon: TextureRect
var _timer: Label
var _until := 0.0
var _kind := ""
var _tick := 0.0
var _pulse: Tween


func _init() -> void:
	_icon = UiKit.icon("flame", 30)
	_timer = HudRound.square(self, _icon, FILL)
	_timer.label_settings = _timer.label_settings.duplicate()
	_timer.label_settings.outline_color = Color("7a1a0e")
	# Золотой ободок, как у прежней плашки
	for state in ["normal", "hover", "disabled", "pressed", "hover_pressed"]:
		var st := get_theme_stylebox(state) as GameStyle
		if st != null:
			st.border_width = 2.0
			st.border_color = RIM
	resized.connect(func() -> void: pivot_offset = size / 2.0)
	pressed.connect(func() -> void:
		Sound.play("tap")
		ShopPanel.open("offers"))
	visible = false


func _ready() -> void:
	_refresh()


func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.5
	_refresh()


## Самое срочное предложение: [вид, иконка, до какого времени] или [] - нечего показать.
static func current() -> Array:
	var until := ShopPill.urgent_until() if Store.LIVE else 0.0
	if until > Time.get_unix_time_from_system():
		return ["bundle", "flame", until]
	var shop := Game.shop
	if Store.LIVE and not shop.flash_bought():
		return ["flash", "gem", Time.get_unix_time_from_system() + ShopSystem.next_day_in()]
	if shop.daily_deal() != "" and not shop.deal_bought():
		return ["deal", "tag", Time.get_unix_time_from_system() + ShopSystem.next_day_in()]
	return []


func _refresh() -> void:
	# До 3 уровня магазин не навязываем: сначала научиться добывать
	var hot: Array = current() if Game.level >= 3 else []
	var show := not hot.is_empty()
	if show != visible:
		visible = show
		_set_pulse(show)
	if not show:
		return
	if hot[0] != _kind:
		_kind = hot[0]
		_icon.texture = Sprites.icon(hot[1])
	_until = hot[2]
	_timer.text = House.countdown(maxf(0.0, _until - Time.get_unix_time_from_system()))


## Мягкая пульсация: плашка чуть растёт и возвращается раз в полторы секунды.
func _set_pulse(on: bool) -> void:
	if _pulse != null:
		_pulse.kill()
		_pulse = null
	scale = Vector2.ONE
	if not on:
		return
	_pulse = create_tween().set_loops()
	_pulse.tween_property(self, "scale", Vector2.ONE * 1.08, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pulse.tween_property(self, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_pulse.tween_interval(0.7)
