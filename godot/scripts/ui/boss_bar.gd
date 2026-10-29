class_name BossBar
extends VBoxContainer
## Полоска здоровья босса сверху экрана (порт BossBar): имя и сколько здоровья осталось.
## Читает Game.combat.boss_info ({"name", "fraction"}), без босса плавно прячется.

const WIDTH := 220.0

var _name: Label
var _bar: ProgressBar
var _shown := -1.0


func _init() -> void:
	add_theme_constant_override("separation", 3)
	alignment = BoxContainer.ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name = UiKit.title("", 13)
	_name.label_settings.outline_size = 4
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_name)
	_bar = UiKit.bar(1.0, "red", WIDTH, 14.0)
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(_bar)
	modulate.a = 0.0
	visible = false


func _process(delta: float) -> void:
	var info: Variant = Game.combat.boss_info
	if not (info is Dictionary):
		modulate.a = maxf(0.0, modulate.a - delta * 5.0)
		visible = modulate.a > 0.0
		_shown = -1.0
		return
	visible = true
	modulate.a = minf(1.0, modulate.a + delta * 5.0)
	_name.text = str(info.get("name", ""))
	var fraction := clampf(float(info.get("fraction", 0.0)), 0.0, 1.0)
	# Полоска плавно догоняет здоровье (easeOut 0.2 с)
	_shown = fraction if _shown < 0.0 else lerpf(_shown, fraction, minf(1.0, delta * 12.0))
	_bar.value = _shown
