class_name WarMap
extends Control
## Карта войны альянсов: точки, дороги между ними и цвета владельцев. Нажатие выбирает точку (Game.war.selected).

var _pulse := 0.0


func _init(side: float) -> void:
	custom_minimum_size = Vector2(side, side)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	_pulse = fmod(_pulse + delta * 2.0, TAU)
	queue_redraw()


func _scale() -> float:
	return size.x / float(War.SIZE)


func _pos(n: int) -> Vector2:
	var p: Array = War.NODES[n]
	return Vector2(float(p[0]), float(p[1])) * _scale()


func _radius(n: int) -> float:
	var t := War.tier(n)
	var s := _scale()
	return s * (5.4 if t == 4 else 4.2 if t == 0 else 2.8 + 0.3 * t)


func _draw() -> void:
	var w := Game.war
	var s := size.x
	# Поле
	draw_rect(Rect2(Vector2.ZERO, size), Color("7fae5a"))
	draw_circle(size / 2.0, s * 0.47, Color("8dbb63"))
	draw_circle(size / 2.0, s * 0.3, Color("9cc56f"))
	draw_circle(size / 2.0, s * 0.14, Color("b5d184"))
	# Дороги
	for l in War.LINKS:
		var a := int(l[0])
		var b := int(l[1])
		var oa := int(w.node(a)["owner"])
		var ob := int(w.node(b)["owner"])
		var col := Color(0.35, 0.25, 0.15, 0.45)
		if oa > 0 and oa == ob:
			col = Color(War.COLORS[oa], 0.85)
		draw_line(_pos(a), _pos(b), col, maxf(1.5, _scale() * 0.8), true)
	var font := UiKit.font()
	for n in War.NODES.size():
		var d := w.node(n)
		var owner := int(d["owner"])
		var p := _pos(n)
		var r := _radius(n)
		var fill: Color = War.COLORS[clampi(owner, 0, War.COLORS.size() - 1)]
		if War.is_base(n) and owner == 0:
			fill = Color(0.55, 0.5, 0.42, 0.5)
		# Можно атаковать - мигающее кольцо
		if w.can_attack(n):
			draw_arc(p, r + 3.0 + sin(_pulse) * 1.5, 0, TAU, 24, Color(1, 0.95, 0.5, 0.9), 2.0, true)
		if n == w.selected:
			draw_circle(p, r + 5.0, Color(1, 1, 1, 0.55))
		if War.is_base(n):
			draw_rect(Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), fill)
			draw_rect(Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), UiKit.OUTLINE, false, 2.0)
			var tm := w.team(n)
			if not tm.is_empty():
				var tag := str(tm.get("tag", ""))
				var fs := 10
				var tw := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				draw_string_outline(font, p + Vector2(-tw / 2.0, r + 12.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, UiKit.OUTLINE)
				draw_string(font, p + Vector2(-tw / 2.0, r + 12.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
		else:
			draw_circle(p, r, fill)
			draw_arc(p, r, 0, TAU, 24, UiKit.OUTLINE, 2.0 if War.tier(n) < 4 else 3.0, true)
			if War.tier(n) == 4:
				# Башенки замка
				for i in 3:
					var x := p.x + (i - 1) * r * 0.55
					draw_rect(Rect2(x - r * 0.18, p.y - r * 0.55, r * 0.36, r * 0.75), UiKit.WOOD_DARK)
			# Щиты - точки под кружком
			var sh := int(d["shields"])
			for i in sh:
				var off := (float(i) - (sh - 1) / 2.0) * 5.0
				draw_circle(p + Vector2(off, r + 3.5), 2.0, Color("f7f0d0"))


func _gui_input(e: InputEvent) -> void:
	var pressed: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) \
		or (e is InputEventScreenTouch and e.pressed)
	if not pressed:
		return
	var at: Vector2 = e.position
	var best := -1
	var dist := 1e9
	for n in War.NODES.size():
		var d := at.distance_to(_pos(n))
		if d < dist:
			dist = d
			best = n
	if best >= 0 and dist <= _radius(best) + 14.0:
		Game.war.selected = best
		Game.war.last = {}
		Game.changed.emit()
		accept_event()
