class_name AnimalSheet
extends RefCounted
## Как устроен лист зверя an_<id>: клетка, ряды "стоит" и "идёт" (вбок, вниз, вверх), плавание.
## Внутри - Pixel (порт PixelAnimal): покадровая анимация зверя по направлению движения.

var name := ""
var cell := 32.0
## [ряд, кадров] для взгляда вбок, вниз, вверх. Если есть только вид сбоку - один элемент.
var idle: Array = []
var walk: Array = []
## Вид сбоку смотрит влево.
var faces_left := true
var fps := 8.0
var row_offset := 0.0
## Летает: качается вверх-вниз.
var flies := false
## Плавает: ряды "стоит в воде" и "плывёт" ([] - не плавает).
var swim_idle: Array = []
var swim: Array = []

static var _icons: Dictionary = {}
static var _shiny: ShaderMaterial


static func _make(sheet_name: String, sheet_cell: float, idle_rows: Array, walk_rows: Array, sheet_fps: float,
		left := true, fly := false, swim_idle_row: Array = [], swim_row: Array = []) -> AnimalSheet:
	var s := AnimalSheet.new()
	s.name = sheet_name
	s.cell = sheet_cell
	s.idle = idle_rows
	s.walk = walk_rows
	s.fps = sheet_fps
	s.faces_left = left
	s.flies = fly
	s.swim_idle = swim_idle_row
	s.swim = swim_row
	return s


## Лист зверя или null, если спрайта нет.
static func of(id: String) -> AnimalSheet:
	var n := "an_" + id
	var sheet: AnimalSheet
	match id:
		"cow", "horse", "pig", "sheep", "unicorn":
			sheet = _make(n, 32, [[0, 2], [1, 2], [2, 2]], [[3, 8], [4, 8], [5, 8]], 10)
		"chicken", "rooster", "goose", "goldenGoose":
			sheet = _make(n, 32, [[0, 2]], [[1, 6]], 10)
		"duck", "duckHat", "swan":
			sheet = _make(n, 32, [[0, 2]], [[1, 6]], 10, true, false, [7, 2], [8, 4])
		"frog":
			sheet = _make(n, 32, [[0, 2]], [[1, 8]], 12, false)
		"mouse":
			sheet = _make(n, 32, [[0, 6]], [[1, 6]], 12)
		"bee":
			sheet = _make(n, 16, [[0, 4]], [[0, 4]], 14, true, true)
		"butterfly":
			sheet = _make(n, 8, [[2, 2]], [[2, 2]], 8, false, true)
		_:
			return null
	return sheet if Sprites.has(sheet.name) and Sprites.texture(sheet.name) != null else null


## Первый кадр зверя для интерфейса (без прозрачных краёв).
static func icon(id: String) -> Texture2D:
	if _icons.has(id):
		return _icons[id]
	var out: Texture2D = null
	var sheet := of(id)
	if sheet != null:
		var tex := Sprites.texture(sheet.name)
		var row: Array = sheet.idle[0] if not sheet.idle.is_empty() else [0, 1]
		var rect := Rect2(0, float(row[0]) * sheet.cell + sheet.row_offset, sheet.cell, sheet.cell)
		var base: Texture2D = tex
		if tex is AtlasTexture:
			base = (tex as AtlasTexture).atlas
			rect.position += (tex as AtlasTexture).region.position
		var img := base.get_image()
		if img != null:
			if img.is_compressed():
				img.decompress()
			var used := img.get_region(Rect2i(rect)).get_used_rect()
			if used.size.x > 0 and used.size.y > 0:
				rect = Rect2(rect.position + Vector2(used.position), Vector2(used.size))
		var a := AtlasTexture.new()
		a.atlas = base
		a.region = rect
		out = a
	_icons[id] = out
	return out


## Перекраска редкого зверя: цвет смешивается с сиреневым (как colorBlendFactor в SpriteKit).
static func shiny_material() -> ShaderMaterial:
	if _shiny == null:
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;\n" \
			+ "uniform vec4 tint : source_color = vec4(0.75, 0.45, 1.0, 1.0);\n" \
			+ "uniform float amount = 0.45;\n" \
			+ "void fragment() {\n" \
			+ "\tvec4 c = texture(TEXTURE, UV);\n" \
			+ "\tCOLOR = vec4(mix(c.rgb, tint.rgb, amount), c.a) * COLOR;\n" \
			+ "}\n"
		_shiny = ShaderMaterial.new()
		_shiny.shader = sh
		_shiny.set_shader_parameter("tint", Animals.SHINY_TINT)
	return _shiny


## Анимированный зверь из листа (порт PixelAnimal). node - готовый Sprite2D, стоит на земле в (0, 0).
class Pixel:
	extends RefCounted

	var node := Sprite2D.new()
	var sheet: AnimalSheet
	## Зверь сейчас в воде (только для тех, кто умеет плавать).
	var swimming := false

	var _idle: Array = []
	var _walk: Array = []
	var _swim_idle: Array = []
	var _swim_move: Array = []
	var _clock := randf_range(0.0, 2.0)
	var _facing := 0
	var _right := false
	var _cols := 1
	var _scale := Sprites.SCALE

	var can_swim: bool:
		get: return not _swim_move.is_empty()

	func _init(s: AnimalSheet) -> void:
		sheet = s
		var tex := Sprites.texture(s.name)
		_cols = maxi(1, int(tex.get_width() / s.cell))
		var rows := maxi(1, int(tex.get_height() / s.cell))
		for r in s.idle:
			var f := _row(r, rows)
			if not f.is_empty():
				_idle.append(f)
		for r in s.walk:
			var f := _row(r, rows)
			if not f.is_empty():
				_walk.append(f)
		if not s.swim_idle.is_empty():
			_swim_idle = _row(s.swim_idle, rows)
		if not s.swim.is_empty():
			_swim_move = _row(s.swim, rows)
		if _swim_idle.is_empty():
			_swim_move = []
		if _walk.is_empty():
			_walk = _idle
		if _idle.is_empty():
			_idle = [[0]]
			_walk = _idle
		_scale = Sprites.SCALE * 2.0 if s.cell <= 8.0 else Sprites.SCALE
		node.texture = tex
		node.centered = false
		node.region_enabled = true
		node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var a := Vector2(0.5, 0.2) if s.flies else Sprites.anchor(s.name)
		node.offset = Sprites.anchor_offset(a, Vector2(s.cell, s.cell))
		node.scale = Vector2.ONE * _scale
		_show(_idle[0][0])

	## Кадры ряда. Пустые кадры в конце ряда не берём: иначе зверь мигает.
	func _row(r: Array, rows: int) -> Array:
		var row := int(r[0])
		var n := int(r[1])
		var known := Sprites.row_frames(sheet.name, row)
		if known >= 0:
			n = mini(n, known)
		n = mini(n, _cols)
		if n <= 0 or row >= rows:
			return []
		var out: Array = []
		for i in n:
			out.append(row * _cols + i)
		return out

	func _show(index: int) -> void:
		var c := index % _cols
		var r := index / _cols
		node.region_rect = Rect2(c * sheet.cell, r * sheet.cell + sheet.row_offset, sheet.cell, sheet.cell)

	## Обновить кадр. velocity - куда идёт зверь (для выбора вида).
	func update(velocity: Vector2, dt: float) -> void:
		var moving := velocity.length() > 12.0
		if moving:
			if _idle.size() >= 3 and not swimming:
				if absf(velocity.x) > absf(velocity.y) * 0.8:
					_facing = 0
				else:
					# В Godot ось y смотрит вниз: отрицательная скорость - вверх
					_facing = 2 if velocity.y < 0.0 else 1
			if absf(velocity.x) > 6.0:
				_right = velocity.x > 0.0
		var frames: Array
		if swimming and can_swim:
			_facing = 0
			frames = _swim_move if moving else _swim_idle
		else:
			var group: Array = _walk if moving else _idle
			frames = group[mini(_facing, group.size() - 1)]
		_clock += dt * (sheet.fps if moving else 2.5)
		_show(frames[int(_clock) % frames.size()])
		_apply_flip()

	func _apply_flip() -> void:
		if _facing != 0:
			node.scale.x = _scale
			return
		var mirrored := _right if sheet.faces_left else not _right
		node.scale.x = -_scale if mirrored else _scale

	## Повернуться к цели (для удара помощника).
	func look(dx: float) -> void:
		if absf(dx) <= 2.0:
			return
		_facing = 0
		_right = dx > 0.0
		_apply_flip()
