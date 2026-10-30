class_name FreeButton
extends GameButton
## Кнопка бесплатной награды по таймеру: "Бесплатно: +60" или "Через 5:12:03" (выключена). Сама переключается,
## когда время пришло. on_take вызывается после Freebies.take(key).

var key := ""
var what := ""
var _on_take: Callable
var _tick := 0.0


func _init(free_key: String, label: String, on_take: Callable, size := 14) -> void:
	super("green", true, size)
	key = free_key
	what = label
	_on_take = on_take
	pressed.connect(func() -> void:
		if Freebies.take(key):
			Sound.play("success")
			_on_take.call()
			_refresh())
	_refresh()


func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.5
	_refresh()


func _refresh() -> void:
	var on := Freebies.ready(key)
	disabled = not on
	if on:
		text = L.t("free.takeAny") if what == "" else L.t("free.take", [what])
	else:
		text = L.t("free.in", [House.countdown(Freebies.left(key))])
