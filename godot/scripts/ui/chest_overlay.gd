class_name ChestOverlay
extends Control
## Открытие сундука: сундук трясётся (чем реже находка, тем больше раз), лучи перекрашиваются
## по шкале редкости до цвета лучшей награды, вспышка - и вылетают карточки наград.
## Касание во время анимации пропускает её, после - закрывает окно.

var chest := ""
var rewards: Array = []

var _best := "gray"
var _rays: Rays
var _chest_box := CenterContainer.new()
var _flash := ColorRect.new()
var _cards := GridContainer.new()
var _bottom := VBoxContainer.new()
var _tween: Tween
var _done := false
var _card_frames: Array = []
var _t := 0.0


static func show_rewards(chest_id: String, list: Array) -> void:
	if Hud.current == null or list.is_empty():
		return
	var o := ChestOverlay.new()
	o.chest = chest_id
	o.rewards = list
	Hud.current.show_overlay(o)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.02, 0.06, 0.9)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	for r in rewards:
		if Chests.rarity_index(str(r["rarity"])) > Chests.rarity_index(_best):
			_best = str(r["rarity"])

	var area := get_viewport_rect().size
	_rays = Rays.new()
	_rays.position = Vector2(area.x / 2.0, area.y * 0.4)
	_rays.color = Chests.color("gray")
	add_child(_rays)

	_chest_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_chest_box.offset_bottom = -area.y * 0.2
	_chest_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_chest_box)
	var icon := ChestsPanel.chest_icon(chest, 112.0)
	icon.pivot_offset = icon.custom_minimum_size / 2.0
	_chest_box.add_child(icon)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(col)
	_cards.columns = 1 if rewards.size() == 1 else 2
	_cards.add_theme_constant_override("h_separation", 8)
	_cards.add_theme_constant_override("v_separation", 8)
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_cards)
	var card_w := 260.0 if rewards.size() == 1 else minf(170.0, (area.x - 40.0) / 2.0)
	for r in rewards:
		var c := _reward_card(r, card_w, rewards.size() == 1)
		c.modulate.a = 0.0
		_cards.add_child(c)
	_bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	_bottom.add_theme_constant_override("separation", 8)
	_bottom.modulate.a = 0.0
	col.add_child(_bottom)
	_bottom.add_child(_center_label(L.t("chest.tapClose"), 12, Color(1, 1, 1, 0.7)))
	var more := Game.chests.keys(Chests.key_of(chest))
	if more > 0:
		var again := UiKit.button(L.t("chest.again", [more]), "orange", 14, true)
		again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		again.pressed.connect(func() -> void:
			var next := Game.chests.open(chest, rewards.size())
			queue_free()
			ChestOverlay.show_rewards(chest, next))
		_bottom.add_child(again)

	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_play(icon)


func _process(delta: float) -> void:
	_t += delta
	# Радужные рамки переливаются
	for f in _card_frames:
		if is_instance_valid(f[0]):
			(f[1] as StyleBoxFlat).border_color = Chests.rainbow_color(_t + float(f[2]))
			(f[0] as Control).queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed):
		return
	if _done:
		queue_free()
	else:
		_finish()


## Тряска сундука: по одной на ступень, на каждой лучи перекрашиваются в следующий цвет.
func _play(icon: Control) -> void:
	Sound.keep_smooth(8.0)
	var shakes := int(Chests.SHAKES.get(_best, 1))
	var top := Chests.rarity_index(_best)
	_tween = create_tween()
	_tween.tween_property(icon, "scale", Vector2(0.6, 0.6), 0.0)
	_tween.tween_property(icon, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in shakes:
		# Цвет лучей поднимается по шкале к лучшей награде
		var step := int(round(float(top) * float(i + 1) / float(shakes)))
		var c := Chests.color(Chests.RARITIES[step])
		_tween.tween_callback(func() -> void:
			_rays.color = c
			_rays.boost = 1.0 + 0.25 * float(i)
			Sound.play("tap" if i < shakes - 1 else "unlock"))
		for s in [0.18, -0.18, 0.12, -0.12, 0.0]:
			_tween.tween_property(icon, "rotation", float(s) * (1.0 + 0.3 * float(i)), 0.05)
		_tween.tween_property(icon, "scale", Vector2.ONE * (1.0 + 0.08 * float(i + 1)), 0.08)
		_tween.tween_interval(0.22)
	_tween.tween_callback(_burst)


## Вспышка, сундук исчезает, карточки вылетают по очереди.
func _burst() -> void:
	_chest_box.visible = false
	_rays.color = Chests.color(_best)
	_rays.rainbow = _best == "rainbow"
	_rays.boost = 1.6
	_flash.color = Color(1, 1, 1, 0.9)
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, 0.35)
	if Chests.rarity_index(_best) >= Chests.rarity_index("gold"):
		Sound.play("levelUp")
		_confetti()
	else:
		Sound.play("treasure")
	var cards := create_tween()
	for c in _cards.get_children():
		var card := c as Control
		cards.tween_callback(func() -> void:
			card.pivot_offset = card.size / 2.0
			card.scale = Vector2(0.4, 0.4)
			Sound.play("pickup", 0.6))
		cards.tween_property(card, "modulate:a", 1.0, 0.08)
		cards.parallel().tween_property(card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	cards.tween_property(_bottom, "modulate:a", 1.0, 0.2)
	cards.tween_callback(func() -> void: _done = true)
	_tween = cards


## Пропустить анимацию: всё сразу на местах.
func _finish() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if _chest_box.visible:
		_burst()
		if _tween != null and _tween.is_valid():
			_tween.kill()
	for c in _cards.get_children():
		(c as Control).modulate.a = 1.0
		(c as Control).scale = Vector2.ONE
	_bottom.modulate.a = 1.0
	_done = true


## Конфетти цветов редкости для золота и выше.
func _confetti() -> void:
	var area := get_viewport_rect().size
	for i in 40:
		var p := ColorRect.new()
		p.size = Vector2(6, 10)
		p.color = Chests.color(Chests.RARITIES[randi_range(2, Chests.RARITIES.size() - 1)], randf() * 3.0)
		p.position = Vector2(area.x / 2.0, area.y * 0.4)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.rotation = randf() * TAU
		add_child(p)
		var to := p.position + Vector2(randf_range(-area.x * 0.6, area.x * 0.6), randf_range(-area.y * 0.35, area.y * 0.5))
		var tw := create_tween().set_parallel()
		tw.tween_property(p, "position", to, randf_range(0.7, 1.3)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(p, "rotation", p.rotation + randf_range(-8.0, 8.0), 1.3)
		tw.tween_property(p, "modulate:a", 0.0, 0.5).set_delay(0.9)
		tw.chain().tween_callback(p.queue_free)


## Карточка награды: рамка цвета редкости, звёзды, значок, подпись и название редкости.
func _reward_card(r: Dictionary, width: float, big: bool) -> PanelContainer:
	var rarity := str(r["rarity"])
	var p := PanelContainer.new()
	var col := Chests.color(rarity)
	var s := UiKit.box(Color(0.12, 0.09, 0.14).lerp(col, 0.18), col, 14, 4 if big else 3, false)
	s.set_content_margin_all(10 if big else 7)
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size = Vector2(width, 0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if rarity == "rainbow":
		_card_frames.append([p, s, randf()])
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4 if big else 2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	var stars := UiKit.stars(int(r["stars"]), 3, 18.0 if big else 12.0)
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(stars)
	var icon_box := CenterContainer.new()
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_box.add_child(UiKit.icon_any(ChestSystem.reward_icon(r), 56.0 if big else 30.0))
	v.add_child(icon_box)
	var text := _center_label(ChestSystem.reward_text(r), 15 if big else 11, Color.WHITE)
	text.custom_minimum_size.x = width - 20.0
	v.add_child(text)
	v.add_child(_center_label(Chests.rarity_name(rarity), 12 if big else 10, col.lightened(0.25)))
	if r.has("overflow"):
		v.add_child(_center_label(L.t("chest.overflow", [Fmt.n(int(r["overflow"]))]), 10, Color(1, 1, 1, 0.6)))
	return p


static func _center_label(text: String, size: int, color: Color) -> Label:
	var l := UiKit.label(text, size, color, 3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Вращающиеся лучи за сундуком.
class Rays:
	extends Node2D

	var color := Color.WHITE
	var boost := 1.0
	## Радужная находка: каждый луч своего цвета, цвета бегут по кругу.
	var rainbow := false
	var _a := 0.0

	func _process(delta: float) -> void:
		_a += delta * 0.6 * boost
		queue_redraw()

	func _draw() -> void:
		var n := 12
		var r := 260.0 * minf(boost, 1.6)
		for i in n:
			var a := _a + TAU * float(i) / float(n)
			var pts := PackedVector2Array([Vector2.ZERO, Vector2.from_angle(a - 0.12) * r, Vector2.from_angle(a + 0.12) * r])
			var c := Chests.rainbow_color(_a + float(i) / float(n) * 2.8) if rainbow else color
			draw_colored_polygon(pts, Color(c, 0.18))
		var mid := Chests.rainbow_color(_a) if rainbow else color
		draw_circle(Vector2.ZERO, 70.0 * boost, Color(mid, 0.22))
		draw_circle(Vector2.ZERO, 40.0 * boost, Color(mid, 0.32))
