extends Node
## Пиксельные спрайты из пака (готовятся tools/sprites.py и tools/world.py, как для iOS).
## Мир считается в "точках" iOS: один пиксель рисунка = 2 точки.
## Точка спрайта (0, 0) - место, где предмет стоит на земле (якорь из манифеста).

const SCALE := 2.0
const DIR := "res://assets/sprites/"

var manifest: Dictionary = {}
var _textures: Dictionary = {}
var _atlas: Texture2D
var available := false


func _ready() -> void:
	var path := DIR + "sp_manifest.json"
	if FileAccess.file_exists(path):
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary:
			manifest = data
	_atlas = _load_png("atlas")
	available = not manifest.is_empty() and _load_png("pl_farmer") != null


func has(name: String) -> bool:
	return manifest.has(name)


func info(name: String) -> Dictionary:
	return manifest.get(name, {})


func _load_png(name: String) -> Texture2D:
	var path := DIR + "sp_" + name + ".png"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


## Текстура целиком: из общего атласа или отдельный файл.
func texture(name: String) -> Texture2D:
	if _textures.has(name):
		return _textures[name]
	var tex: Texture2D = null
	var i: Dictionary = info(name)
	if i.has("atlas") and _atlas != null:
		var r: Array = i["atlas"]
		var a := AtlasTexture.new()
		a.atlas = _atlas
		a.region = Rect2(r[0], r[1], r[2], r[3])
		tex = a
	else:
		tex = _load_png(name)
	_textures[name] = tex
	return tex


## Якорь: доля ширины слева и доля высоты снизу (как в SpriteKit).
func anchor(name: String) -> Vector2:
	var a = info(name).get("anchor", [0.5, 0.0])
	return Vector2(a[0], a[1])


## Смещение кадра под якорь для Sprite2D с centered = false.
static func anchor_offset(anchor_point: Vector2, frame_size: Vector2) -> Vector2:
	return Vector2(-anchor_point.x * frame_size.x, -(1.0 - anchor_point.y) * frame_size.y)


## Спрайт, стоящий на земле в точке pos. Ленты кадров (frame в манифесте) показывают первый кадр.
func make(name: String, pos := Vector2.ZERO, scale_mult := 1.0) -> Sprite2D:
	var tex := texture(name)
	if tex == null:
		return null
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	var i: Dictionary = info(name)
	var frame_size := Vector2(tex.get_width(), tex.get_height())
	if i.has("frame"):
		var fw: float = float(i["frame"])
		var fh: float = float(i.get("h", fw))
		s.hframes = maxi(1, int(round(tex.get_width() / fw)))
		s.vframes = maxi(1, int(round(tex.get_height() / fh)))
		frame_size = Vector2(tex.get_width() / float(s.hframes), tex.get_height() / float(s.vframes))
	s.offset = anchor_offset(anchor(name), frame_size)
	s.scale = Vector2.ONE * SCALE * scale_mult
	s.position = pos
	return s


## Анимированная лента кадров.
func animated(name: String, fps := 8.0, pos := Vector2.ZERO, random_start := true) -> Sprite2D:
	var tex := texture(name)
	if tex == null:
		return null
	var i: Dictionary = info(name)
	if not i.has("frame"):
		return make(name, pos)
	var s := AnimSprite.new()
	s.texture = tex
	s.centered = false
	var fw: float = float(i["frame"])
	var fh: float = float(i.get("h", fw))
	s.hframes = maxi(1, int(round(tex.get_width() / fw)))
	s.vframes = maxi(1, int(round(tex.get_height() / fh)))
	s.offset = anchor_offset(anchor(name), Vector2(fw, fh))
	s.scale = Vector2.ONE * SCALE
	s.position = pos
	s.setup(s.hframes * s.vframes, fps, random_start)
	return s


## Число кадров ленты.
func frame_count(name: String) -> int:
	var tex := texture(name)
	var i: Dictionary = info(name)
	if tex == null or not i.has("frame"):
		return 1
	return maxi(1, int(round(tex.get_width() / float(i["frame"]))))


## Непустых кадров в ряду листа зверя (если известно).
func row_frames(name: String, row: int) -> int:
	var counts = info(name).get("counts", null)
	if counts is Array and row >= 0 and row < counts.size():
		return int(counts[row])
	return -1


## Иконка ресурса или интерфейса (ic_<имя>) как текстура.
func icon(name: String) -> Texture2D:
	return texture("ic_" + name)


func ground(id: String) -> Texture2D:
	return _load_png("ground_" + id)
