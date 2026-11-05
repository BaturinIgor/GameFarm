class_name MineGame
extends Control
## Поле Шахты Глубин: блоки руды падают, группы взрываются, камни трескаются.
## Сверху - этаж, удары и сколько камней осталось, снизу - добытая руда и выход.
## Кончились удары - можно докупить ещё 5 (кристаллы или ролик), иначе руда уходит на склад, этаж остаётся.

const GRAVITY := 5200.0
const MAX_CELL := 58.0

var floor_n := 1
var board := MineBoard.new()
var moves := 0
## Добытые блоки по номеру руды (на склад уйдёт по Mine.BLOCKS_PER_UNIT за единицу).
var blocks := {}
var _ad_used := false
var _over := false
## Смещение клетки при падении (пиксели) и скорость: индекс -> float.
var _off := {}
var _vel := {}
var _parts: Array = []
var _rings: Array = []
var _shake := 0.0
var _t := 0.0
var _cell := 48.0
var _origin := Vector2.ZERO

var _view := BoardView.new()
var _moves_label: Label
var _rocks_label: Label
var _ore_row := HBoxContainer.new()
var _end_layer := CenterContainer.new()


static func launch(f: int, seed_value := -1) -> MineGame:
	if Hud.current == null:
		return null
	var g := MineGame.new()
	g.floor_n = f
	g.board.setup(f, seed_value)
	g.moves = Mine.moves(f)
	Hud.current.show_overlay(g)
	return g


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var lay := Mine.layer(floor_n)
	var bg := ColorRect.new()
	bg.color = Color(lay["bg"]).darkened(0.25)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var insets := UiKit.safe_insets(get_viewport())
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_top = insets["top"] + 10
	col.offset_bottom = -insets["bottom"] - 10
	col.offset_left = 12
	col.offset_right = -12
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)

	# Шапка: этаж и порода, удары, камни
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	var title := VBoxContainer.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_constant_override("separation", 0)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(title)
	title.add_child(UiKit.label(L.t("mine.floor", [floor_n]), 20, Color.WHITE, 4))
	title.add_child(UiKit.label(Mine.layer_name(floor_n), 12, Color(1, 1, 1, 0.75), 3))
	head.add_child(_stat("bolt", L.t("mine.moves")))
	_moves_label = head.get_child(head.get_child_count() - 1).get_meta("value")
	head.add_child(_stat("rock", L.t("mine.rocks")))
	_rocks_label = head.get_child(head.get_child_count() - 1).get_meta("value")

	_view.game = self
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	col.add_child(_view)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(foot)
	_ore_row.add_theme_constant_override("separation", 8)
	_ore_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ore_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(_ore_row)
	var quit := UiKit.button(L.t("mine.leave"), "red", 13, true)
	quit.custom_minimum_size.x = 96
	quit.pressed.connect(func() -> void:
		if not _over:
			_show_end("leave"))
	foot.add_child(quit)

	_end_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_end_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_end_layer)
	_refresh_labels()
	_drop_in()


## Всё поле падает сверху при входе.
func _drop_in() -> void:
	for i in board.cells.size():
		var y := i / board.w
		_off[i] = -float(board.h - y + 3) * 60.0 - float(i % board.w) * 14.0
		_vel[i] = 0.0


func _stat(icon_name: String, caption: String) -> PanelContainer:
	var p := PanelContainer.new()
	var s := UiKit.box(Color(0, 0, 0, 0.35), Color(1, 1, 1, 0.25), 12, 2, false)
	s.set_content_margin_all(6)
	s.content_margin_left = 10
	s.content_margin_right = 10
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	if icon_name == "rock":
		top.add_child(RockIcon.new(Color(Mine.layer(floor_n)["rock"])))
	else:
		top.add_child(UiKit.icon(icon_name, 18))
	var val := UiKit.title("0", 20)
	top.add_child(val)
	var cap := UiKit.label(caption, 10, Color(1, 1, 1, 0.7), 2)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(cap)
	p.set_meta("value", val)
	return p


func _refresh_labels() -> void:
	_moves_label.text = str(moves)
	_moves_label.modulate = Color(1, 0.55, 0.5) if moves <= 3 else Color.WHITE
	_rocks_label.text = str(board.rocks_left())
	UiKit.clear(_ore_row)
	for c in board.colors:
		var n := int(blocks.get(c, 0))
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 2)
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(UiKit.icon(Mine.ore_of(floor_n, c), 20))
		item.add_child(UiKit.label(str(n / Mine.BLOCKS_PER_UNIT), 13, Color.WHITE, 3))
		_ore_row.add_child(item)


func settled() -> bool:
	for i in _off:
		if absf(float(_off[i])) > 0.5:
			return false
	return true


func _process(delta: float) -> void:
	_t += delta
	for i in _off.keys():
		var o := float(_off[i])
		if o >= 0.0:
			_off.erase(i)
			_vel.erase(i)
			continue
		var v := float(_vel.get(i, 0.0)) + GRAVITY * delta
		o += v * delta
		if o >= 0.0:
			o = 0.0
		_off[i] = o
		_vel[i] = v
	for p in _parts:
		p["life"] = float(p["life"]) - delta
		p["vel"] = Vector2(p["vel"]) + Vector2(0, 900.0) * delta
		p["pos"] = Vector2(p["pos"]) + Vector2(p["vel"]) * delta
	_parts = _parts.filter(func(p: Dictionary) -> bool: return float(p["life"]) > 0.0)
	for r in _rings:
		r["t"] = float(r["t"]) + delta
	_rings = _rings.filter(func(r: Dictionary) -> bool: return float(r["t"]) < 0.45)
	_shake = maxf(0.0, _shake - delta * 2.5)
	_view.queue_redraw()


## Касание клетки поля.
func tap_cell(i: int) -> void:
	if _over or moves <= 0 or not settled():
		return
	var cell: Variant = board.cells[i]
	var before := board.rocks_left()
	var res := board.tap(i)
	if res.is_empty():
		if cell != null and cell["k"] == "ore":
			Sound.play("error", 0.5)
		return
	moves -= 1
	for c in res["ore"]:
		blocks[c] = int(blocks.get(c, 0)) + int(res["ore"][c])
	_effects(res, cell)
	_animate_falls(res)
	_refresh_labels()
	if board.rocks_left() < before:
		Sound.play("rockBreak")
	if board.rocks_left() == 0:
		_over = true
		get_tree().create_timer(0.6).timeout.connect(func() -> void: _show_end("win"))
		return
	if not board.has_moves():
		board.shuffle()
		_drop_in()
		Game.show_toast("px:spark", L.t("mine.shuffle"))
	if moves <= 0:
		get_tree().create_timer(0.6).timeout.connect(func() -> void:
			if not _over and moves <= 0:
				_show_end("moves"))


func _effects(res: Dictionary, cell: Variant) -> void:
	var removed: Array = res["removed"]
	for j in removed:
		var col := Color(1, 1, 1)
		if cell != null and cell["k"] == "ore":
			col = Mine.ORE_COLORS[int(cell["c"]) % Mine.ORE_COLORS.size()]
		_burst(_center(j), col, 6)
	for j in res["hits"]:
		_burst(_center(j), Color(Mine.layer(floor_n)["rock"]).lightened(0.3), 4 if not j in res["broken"] else 12)
	var big := false
	for b in res["blasts"]:
		_rings.append({"pos": _center(int(b[0])), "t": 0.0, "kind": str(b[1])})
		big = true
	if big:
		_shake = 1.0
		Sound.play("crit")
	elif removed.size() >= Mine.TNT_AT:
		_shake = 0.4
		Sound.play("mine")
	else:
		Sound.play("pick", 0.8)
	if int(res["spawned"]) >= 0:
		Sound.play("luck", 0.7)


## Упавшие клетки начинают с прежней высоты, новые - над полем.
func _animate_falls(res: Dictionary) -> void:
	var old_off := _off.duplicate()
	for f in res["falls"]:
		var from := int(f[0])
		var to := int(f[1])
		var dy := float(to / board.w - from / board.w) * _cell
		_off[to] = -dy + float(old_off.get(from, 0.0))
		_vel[to] = 0.0
	var per_col := {}
	for j in res["fresh"]:
		var x := int(j) % board.w
		per_col[x] = int(per_col.get(x, 0)) + 1
	for j in res["fresh"]:
		var x := int(j) % board.w
		_off[j] = -float(per_col[x]) * _cell - 10.0
		_vel[j] = 0.0
	# Клетка, где появился особый блок, не падает
	if int(res["spawned"]) >= 0 and not _off.has(int(res["spawned"])):
		_burst(_center(int(res["spawned"])), Color(1, 0.9, 0.4), 10)


func _burst(at: Vector2, col: Color, n: int) -> void:
	for k in n:
		var a := randf() * TAU
		var sp := randf_range(120.0, 420.0)
		_parts.append({"pos": at, "vel": Vector2.from_angle(a) * sp + Vector2(0, -160), "life": randf_range(0.35, 0.7),
			"col": col.lightened(randf() * 0.3), "size": randf_range(3.0, 7.0)})


func _center(i: int) -> Vector2:
	return _origin + Vector2(float(i % board.w) + 0.5, float(i / board.w) + 0.5) * _cell


# MARK: Конец этажа

func _show_end(kind: String) -> void:
	UiKit.clear(_end_layer)
	_end_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var p := PanelContainer.new()
	var s := UiKit.box(UiKit.PARCHMENT, UiKit.OUTLINE, 18, 3, true)
	s.set_content_margin_all(18)
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size = Vector2(minf(320.0, get_viewport_rect().size.x - 40.0), 0)
	_end_layer.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var head := UiKit.title(L.t("mine.win" if kind == "win" else ("mine.noMoves" if kind == "moves" else "mine.leaveAsk"), [floor_n]), 20)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(head)
	if kind == "win":
		Sound.play("levelUp")
		_confetti()
		var t := UiKit.label(L.t("mine.winText"), 12, UiKit.INK_SOFT)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)
		var take := UiKit.button(L.t("mine.take"), "green", 16)
		take.pressed.connect(func() -> void: _finish(true))
		v.add_child(take)
		return
	var t2 := UiKit.label(L.t("mine.rocksLeft", [board.rocks_left()]), 13, UiKit.INK_SOFT)
	t2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t2)
	if kind == "moves":
		Sound.play("error")
		var price := Game.mine.extra_price()
		var buy := UiKit.button(L.t("mine.buyMoves", [Mine.EXTRA_MOVES, price]), "blue" if Game.shop.crystals() >= price else "gray", 15)
		buy.pressed.connect(func() -> void:
			if Game.mine.buy_extra():
				_continue()
			else:
				Sound.play("error")
				Game.show_toast("px:gem", L.t("chest.noCrystals")))
		v.add_child(buy)
		if not _ad_used and Ads.ready():
			var ad := Ads.reward_button(L.t(Ads.k("mine.adMoves"), [Mine.EXTRA_MOVES]), "orange", 15)
			ad.pressed.connect(func() -> void:
				Ads.show_rewarded(func() -> void:
					_ad_used = true
					_continue()))
			v.add_child(ad)
	else:
		var back := UiKit.button(L.t("mine.keep"), "green", 15)
		back.pressed.connect(func() -> void:
			_clear_end())
		v.add_child(back)
	var out := UiKit.button(L.t("mine.leaveOre"), "red", 14, true)
	out.pressed.connect(func() -> void: _finish(false))
	v.add_child(out)


func _clear_end() -> void:
	UiKit.clear(_end_layer)
	_end_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _continue() -> void:
	moves += Mine.EXTRA_MOVES
	Sound.play("unlock")
	_clear_end()
	_refresh_labels()


## Выйти: руда на склад, при победе - награды этажа. Окно наград показывает всё разом.
func _finish(won: bool) -> void:
	_over = true
	var got := blocks.duplicate()
	var f := floor_n
	queue_free()
	RewardsPopup.track(func() -> void:
		Game.mine.take_ore(f, got)
		if won:
			Game.mine.win(f), "mine.rewardsTitle")


func _confetti() -> void:
	for k in 60:
		var at := Vector2(randf_range(0.0, size.x), -20.0)
		_parts.append({"pos": at, "vel": Vector2(randf_range(-120, 120), randf_range(200, 600)), "life": randf_range(1.0, 1.8),
			"col": Mine.ORE_COLORS[k % Mine.ORE_COLORS.size()], "size": randf_range(4.0, 8.0)})


# MARK: Рисование блоков (общее с окном шахты)

static func draw_ore(ci: CanvasItem, r: Rect2, f: int, c: int) -> void:
	var col: Color = Mine.ORE_COLORS[c % Mine.ORE_COLORS.size()]
	var rad := r.size.x * 0.22
	_round(ci, r.grow(1.5), rad + 1.5, UiKit.OUTLINE)
	_round(ci, r, rad, col.darkened(0.25))
	_round(ci, Rect2(r.position, Vector2(r.size.x, r.size.y - r.size.y * 0.12)), rad, col)
	# Блик сверху
	_round(ci, Rect2(r.position + Vector2(r.size.x * 0.14, r.size.y * 0.08), Vector2(r.size.x * 0.4, r.size.y * 0.12)),
		r.size.y * 0.06, Color(1, 1, 1, 0.35))
	var tex := Sprites.icon(Mine.ore_of(f, c))
	if tex != null:
		var side := r.size.x * 0.62
		ci.draw_texture_rect(tex, Rect2(r.get_center() - Vector2(side, side) / 2.0 + Vector2(0, -r.size.y * 0.03), Vector2(side, side)), false)


static func draw_rock(ci: CanvasItem, r: Rect2, hp: int, col: Color) -> void:
	var rad := r.size.x * 0.16
	_round(ci, r.grow(1.5), rad + 1.5, UiKit.OUTLINE)
	_round(ci, r, rad, col.darkened(0.35))
	_round(ci, Rect2(r.position, Vector2(r.size.x, r.size.y * 0.86)), rad, col.darkened(0.08 * float(hp)))
	# Пятна на камне
	ci.draw_circle(r.position + r.size * Vector2(0.3, 0.32), r.size.x * 0.08, col.lightened(0.15))
	ci.draw_circle(r.position + r.size * Vector2(0.68, 0.6), r.size.x * 0.06, col.darkened(0.3))
	# Трещины: чем меньше прочности, тем больше
	var crack := Color(0.1, 0.07, 0.05, 0.85)
	var w := maxf(1.5, r.size.x * 0.05)
	if hp <= 2:
		ci.draw_polyline(PackedVector2Array([r.position + r.size * Vector2(0.2, 0.15), r.position + r.size * Vector2(0.42, 0.42),
			r.position + r.size * Vector2(0.35, 0.62), r.position + r.size * Vector2(0.55, 0.85)]), crack, w)
	if hp <= 1:
		ci.draw_polyline(PackedVector2Array([r.position + r.size * Vector2(0.85, 0.2), r.position + r.size * Vector2(0.6, 0.45),
			r.position + r.size * Vector2(0.75, 0.7)]), crack, w)
	if hp >= 2:
		# Прочный камень: обводка-обойма
		ci.draw_rect(r.grow(-r.size.x * 0.12), Color(1, 1, 1, 0.12 * float(hp)), false, w)


static func draw_special(ci: CanvasItem, r: Rect2, kind: String, c: int, t: float) -> void:
	var cx := r.get_center()
	var s := r.size.x
	match kind:
		"tnt":
			_round(ci, r.grow(-s * 0.08).grow(1.5), s * 0.16, UiKit.OUTLINE)
			_round(ci, r.grow(-s * 0.08), s * 0.14, Color("c8302a"))
			ci.draw_rect(Rect2(r.position + Vector2(s * 0.08, s * 0.38), Vector2(s * 0.84, s * 0.2)), Color("f1e2c4"))
			ci.draw_line(cx + Vector2(s * 0.18, -s * 0.42), cx + Vector2(s * 0.3, -s * 0.55), UiKit.OUTLINE, maxf(2.0, s * 0.05))
			var spark := 0.5 + 0.5 * sin(t * 18.0)
			ci.draw_circle(cx + Vector2(s * 0.32, -s * 0.58), s * (0.07 + 0.04 * spark), Color(1, 0.85, 0.2))
		"drill":
			var pts := PackedVector2Array([cx + Vector2(-s * 0.32, -s * 0.36), cx + Vector2(s * 0.32, -s * 0.36), cx + Vector2(0, s * 0.42)])
			var outline := PackedVector2Array([cx + Vector2(-s * 0.38, -s * 0.4), cx + Vector2(s * 0.38, -s * 0.4), cx + Vector2(0, s * 0.5)])
			ci.draw_colored_polygon(outline, UiKit.OUTLINE)
			ci.draw_colored_polygon(pts, Color("c9ced6"))
			var ph := fposmod(t * 3.0, 1.0)
			for k in 3:
				var y := lerpf(-0.3, 0.25, (float(k) + ph) / 3.0)
				var half := 0.32 * (0.42 - y) / 0.78
				ci.draw_line(cx + Vector2(-s * half, s * y), cx + Vector2(s * half, s * y + s * 0.06), Color("6b7280"), maxf(1.5, s * 0.05))
		"orb":
			var hue := fposmod(t * 0.4, 1.0)
			ci.draw_circle(cx, s * 0.42, UiKit.OUTLINE)
			ci.draw_circle(cx, s * 0.38, Color.from_hsv(hue, 0.65, 1.0))
			ci.draw_circle(cx, s * 0.24, Color.from_hsv(fposmod(hue + 0.33, 1.0), 0.5, 1.0))
			ci.draw_circle(cx + Vector2(-s * 0.12, -s * 0.12), s * 0.08, Color(1, 1, 1, 0.7))
			if c >= 0:
				var col: Color = Mine.ORE_COLORS[c % Mine.ORE_COLORS.size()]
				ci.draw_arc(cx, s * 0.46, 0.0, TAU, 24, col, maxf(2.0, s * 0.06))


static var _sb: StyleBoxFlat


## Скруглённый прямоугольник. Одна общая StyleBox: рисование сразу записывает команды, её можно менять дальше.
static func _round(ci: CanvasItem, r: Rect2, radius: float, col: Color) -> void:
	if _sb == null:
		_sb = StyleBoxFlat.new()
		_sb.anti_aliasing = true
	_sb.bg_color = col
	_sb.set_corner_radius_all(int(radius))
	ci.draw_style_box(_sb, r)


## Поле: рисует клетки, частицы и кольца взрывов, ловит касания.
class BoardView:
	extends Control

	var game: MineGame

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		clip_contents = false

	func _layout() -> void:
		var b := game.board
		game._cell = floorf(minf(MineGame.MAX_CELL, minf(size.x / float(b.w), size.y / float(b.h))))
		var full := Vector2(float(b.w), float(b.h)) * game._cell
		game._origin = ((size - full) / 2.0).floor()

	func _gui_input(e: InputEvent) -> void:
		if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
			return
		var p: Vector2 = (e as InputEventMouseButton).position - game._origin
		var x := int(floorf(p.x / game._cell))
		var y := int(floorf(p.y / game._cell))
		if x < 0 or y < 0 or x >= game.board.w or y >= game.board.h:
			return
		game.tap_cell(y * game.board.w + x)

	func _draw() -> void:
		_layout()
		var b := game.board
		var cs := game._cell
		var lay := Mine.layer(game.floor_n)
		var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 6.0 * game._shake
		var o := game._origin + shake
		var full := Rect2(o, Vector2(float(b.w), float(b.h)) * cs)
		MineGame._round(self, full.grow(8), 16, UiKit.OUTLINE)
		MineGame._round(self, full.grow(6), 14, Color(lay["bg"]))
		for y in b.h:
			for x in b.w:
				if (x + y) % 2 == 0:
					draw_rect(Rect2(o + Vector2(x, y) * cs, Vector2(cs, cs)), Color(0, 0, 0, 0.12))
		for i in b.cells.size():
			var cell: Variant = b.cells[i]
			if cell == null:
				continue
			var off := float(game._off.get(i, 0.0))
			var pos := o + Vector2(float(i % b.w), float(i / b.w)) * cs + Vector2(0, off)
			if pos.y + cs < full.position.y - 4.0:
				continue
			var r := Rect2(pos, Vector2(cs, cs)).grow(-cs * 0.06)
			match str(cell["k"]):
				"ore": MineGame.draw_ore(self, r, game.floor_n, int(cell["c"]))
				"rock": MineGame.draw_rock(self, r, int(cell["hp"]), Color(lay["rock"]))
				_: MineGame.draw_special(self, r, str(cell["k"]), int(cell["c"]), game._t)
		for ring in game._rings:
			var k := float(ring["t"]) / 0.45
			var rad := cs * (0.6 + 2.2 * k)
			if str(ring["kind"]) == "drill":
				var p: Vector2 = ring["pos"]
				draw_rect(Rect2(Vector2(p.x - cs * 0.5, full.position.y), Vector2(cs, full.size.y)), Color(1, 0.9, 0.6, 0.5 * (1.0 - k)))
			else:
				draw_arc(Vector2(ring["pos"]) + shake, rad, 0.0, TAU, 32, Color(1, 0.85, 0.4, 1.0 - k), cs * 0.18 * (1.0 - k) + 1.0)
		for p in game._parts:
			var a := clampf(float(p["life"]) * 2.5, 0.0, 1.0)
			var sz := float(p["size"])
			draw_rect(Rect2(Vector2(p["pos"]) + shake - Vector2(sz, sz) / 2.0, Vector2(sz, sz)), Color(Color(p["col"]), a))


## Значок камня в шапке.
class RockIcon:
	extends Control

	var col := Color.GRAY

	func _init(c: Color) -> void:
		col = c
		custom_minimum_size = Vector2(18, 18)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		MineGame.draw_rock(self, Rect2(Vector2(1, 1), size - Vector2(2, 2)), 2, col)
