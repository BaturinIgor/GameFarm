class_name HatchOverlay
extends Control
## Вылупление: яйцо трясётся (чем реже, тем дольше), трещины растут, вспышка - и появляется зверь
## с именем, звёздами и отметками "новый" и "редкая окраска". Касание пропускает анимацию, потом закрывает.

var result: Dictionary = {}

var _rays: ChestOverlay.Rays
var _egg: EggView
var _egg_box := CenterContainer.new()
var _reveal := VBoxContainer.new()
var _card := PanelContainer.new()
var _flash := ColorRect.new()
var _tween: Tween
var _done := false


static func show_result(out: Dictionary) -> void:
	if Hud.current == null or out.is_empty():
		return
	var o := HatchOverlay.new()
	o.result = out
	Hud.current.show_overlay(o)


func _rarity() -> String:
	return str(result.get("rarity", "green"))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.02, 0.06, 0.9)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var area := get_viewport_rect().size
	_rays = ChestOverlay.Rays.new()
	_rays.position = Vector2(area.x / 2.0, area.y * 0.42)
	_rays.color = EggView.shell_color(_rarity())
	_rays.boost = 0.6
	add_child(_rays)

	_egg_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_egg_box.offset_bottom = -area.y * 0.16
	_egg_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_egg_box)
	_egg = EggView.icon(_rarity(), 132.0)
	_egg.pivot_offset = Vector2(66, 110)
	_egg_box.add_child(_egg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	# Карточка зверя: тёмная подложка с рамкой цвета яйца, чтобы текст читался поверх лучей
	var col := EggView.shell_color(_rarity())
	var st := UiKit.box(Color(0.12, 0.09, 0.14, 0.92).lerp(col, 0.12), col, 16, 4, false)
	st.set_content_margin_all(16)
	_card.add_theme_stylebox_override("panel", st)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.modulate.a = 0.0
	center.add_child(_card)
	_reveal.alignment = BoxContainer.ALIGNMENT_CENTER
	_reveal.add_theme_constant_override("separation", 8)
	_reveal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_reveal)
	_build_reveal(area)

	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_play()


func _build_reveal(area: Vector2) -> void:
	var id := str(result.get("animal", ""))
	var col := EggView.shell_color(_rarity())
	if bool(result.get("new", false)):
		_reveal.add_child(_center(L.t("hatch.new"), 16, Color(1.0, 0.86, 0.35)))
	var icon_box := CenterContainer.new()
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := AnimalsPanel.animal_icon(id, minf(120.0, area.x * 0.32))
	if bool(result.get("shiny", false)):
		icon.material = AnimalSheet.shiny_material()
	icon_box.add_child(icon)
	_reveal.add_child(icon_box)
	_reveal.add_child(_center(Animals.name_of(id), 24, Color.WHITE))
	var crystals := int(result.get("crystals", 0))
	if crystals > 0:
		_reveal.add_child(_center(L.t("hatch.maxStars", [crystals]), 14, col.lightened(0.3)))
	else:
		var stars := UiKit.stars(Game.animals.stars(id), Animals.MAX_STARS, 22.0)
		stars.alignment = BoxContainer.ALIGNMENT_CENTER
		_reveal.add_child(stars)
		_reveal.add_child(_center(L.t("hatch.stars", [int(result.get("stars", 1))]), 13, col.lightened(0.3)))
	if bool(result.get("shiny", false)):
		_reveal.add_child(_center(L.t("hatch.shiny"), 15, Animals.SHINY_TINT.lightened(0.3)))
	if Animals.is_hybrid(id):
		_reveal.add_child(_center(L.t("hatch.hybrid"), 13, Color(1.0, 0.86, 0.35)))
	_reveal.add_child(_center(L.t("chest.tapClose"), 12, Color(1, 1, 1, 0.7)))


func _gui_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed):
		return
	if _done:
		queue_free()
	else:
		_finish()


## Тряска: по одной на ступень редкости, с каждой трещин больше.
func _play() -> void:
	Sound.keep_smooth(6.0)
	var shakes := int(Chests.SHAKES.get(_rarity(), 1)) + 1
	_tween = create_tween()
	_tween.tween_property(_egg, "scale", Vector2(0.6, 0.6), 0.0)
	_tween.tween_property(_egg, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in shakes:
		var crack := float(i + 1) / float(shakes)
		_tween.tween_callback(func() -> void:
			_egg.cracks = crack
			_egg.glow = crack
			_egg.queue_redraw()
			_rays.boost = 0.6 + 0.8 * crack
			Sound.play("tap" if i < shakes - 1 else "unlock"))
		for s in [0.14, -0.14, 0.09, -0.09, 0.0]:
			_tween.tween_property(_egg, "rotation", float(s) * (1.0 + 0.3 * float(i)), 0.05)
		_tween.tween_interval(0.28)
	_tween.tween_callback(_burst)


func _burst() -> void:
	_egg_box.visible = false
	_rays.boost = 1.6
	_rays.rainbow = _rarity() == "rainbow" or bool(result.get("shiny", false))
	_flash.color = Color(1, 1, 1, 0.9)
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, 0.35)
	Sound.play("levelUp" if bool(result.get("new", false)) or bool(result.get("shiny", false)) else "treasure")
	_card.pivot_offset = _card.size / 2.0
	_card.scale = Vector2(0.5, 0.5)
	var rv := create_tween().set_parallel()
	rv.tween_property(_card, "modulate:a", 1.0, 0.15)
	rv.tween_property(_card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rv.chain().tween_callback(func() -> void: _done = true)
	_tween = rv


func _finish() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if _egg_box.visible:
		_burst()
		if _tween != null and _tween.is_valid():
			_tween.kill()
	_card.modulate.a = 1.0
	_card.scale = Vector2.ONE
	_done = true


static func _center(text: String, size: int, color: Color) -> Label:
	var l := UiKit.label(text, size, color, 3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 280
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
