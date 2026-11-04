class_name HotOfferPill
extends Button
## Горячее предложение на главном экране: красная пульсирующая плашка под магазином с таймером.
## Показывает самое срочное: набор новичка или набор по уровню (пока идёт его окно), иначе предложение дня
## и скидку дня, пока их не купили сегодня. Нажатие - магазин на вкладке акций. Нечего предложить - прячется.

const FILL := Color("e8463c")
const RIM := Color("ffcf4a")

var _icon: TextureRect
var _caption: Label
var _timer: Label
var _until := 0.0
var _kind := ""
var _tick := 0.0
var _pulse: Tween


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	var st := GameStyle.make(FILL.lightened(0.15), FILL.darkened(0.1), 13.0)
	st.border_width = 2.0
	st.border_color = RIM
	st.set_content_margin_all(0)
	var down := st.duplicate() as GameStyle
	down.bg_color = FILL.darkened(0.15)
	for state in ["normal", "hover", "disabled"]:
		add_theme_stylebox_override(state, st)
	add_theme_stylebox_override("pressed", down)
	add_theme_stylebox_override("hover_pressed", down)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(row)
	_icon = UiKit.icon("flame", 24)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_icon)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -2)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	_caption = UiKit.title(L.t("hot.title"), 11)
	_caption.label_settings = _caption.label_settings.duplicate()
	_caption.label_settings.font_color = Color("fff3a0")
	_caption.label_settings.outline_color = Color("7a1a0e")
	col.add_child(_caption)
	_timer = UiKit.title("", 12)
	_timer.label_settings = _timer.label_settings.duplicate()
	_timer.label_settings.outline_color = Color("7a1a0e")
	col.add_child(_timer)
	# Постоянная ширина под таймер "00:00:00": плашка не прыгает каждую секунду
	custom_minimum_size = Vector2(ShopPill.WIDTH, 40)
	resized.connect(func() -> void: pivot_offset = size / 2.0)
	pressed.connect(func() -> void:
		Sound.play("tap")
		ShopPanel.open("offers"))
	L.language_changed.connect(func() -> void: _caption.text = L.t("hot.title"))
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
	var until := ShopPill.urgent_until()
	if until > Time.get_unix_time_from_system():
		return ["bundle", "flame", until]
	var shop := Game.shop
	if not shop.flash_bought():
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
