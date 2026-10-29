class_name MapLayout
extends RefCounted
## Раскладка локации из data/layouts/layout_<id>.json (готовит tools/world.py).
## В файлах ось y смотрит вверх (как в SpriteKit); здесь всё переводится в координаты Godot (y вниз).

enum Cell { LAND, PATH, WATER, ICE, VOID, BLOCKED }

const DIR := "res://data/layouts/"

var id := ""
var cols := 36
var rows := 46
var cell := 32.0
var edge := "forest"
var cells := PackedByteArray()
var base := Vector2.ZERO
var gates: Array = []      ## {id, to, side, barrier, inner, edge}
var spots: Array = []      ## {type, pos}
var props: Array = []      ## {name, pos, fixed}
var border: Array = []     ## {name, pos}
var farm: Array = []       ## Vector2: центры грядок
var stall = null           ## Vector2 или null
var pen := Rect2()         ## загон (пустой, если нет)
var board = null           ## Vector2 или null
var stations: Array = []   ## {kind, pos}
var slots: Array = []      ## {id, pos}

static var _cache: Dictionary = {}


var size: Vector2:
	get: return Vector2(cols * cell, rows * cell)


static func load_layout(location: String, variant := "") -> MapLayout:
	var name := variant if variant != "" else location
	if _cache.has(name):
		return _cache[name]
	var layout := MapLayout.new()
	if not layout._read(name) and (name == location or not layout._read(location)):
		layout._fallback(location)
	layout.id = location
	_cache[name] = layout
	return layout


func _read(name: String) -> bool:
	var path := DIR + "layout_" + name + ".json"
	if not FileAccess.file_exists(path):
		return false
	var raw = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not raw is Dictionary:
		return false
	cols = int(raw["w"])
	rows = int(raw["h"])
	cell = float(raw["cell"])
	edge = str(raw.get("edge", "forest"))
	cells = PackedByteArray()
	cells.resize(cols * rows)
	var i := 0
	for row in raw["rows"]:
		for ch in str(row):
			if i >= cells.size():
				break
			match ch:
				"L": cells[i] = Cell.LAND
				"P": cells[i] = Cell.PATH
				"W": cells[i] = Cell.WATER
				"I": cells[i] = Cell.ICE
				"B": cells[i] = Cell.BLOCKED
				_: cells[i] = Cell.VOID
			i += 1
	if i != cols * rows:
		return false
	base = _p(raw["base"])
	for g in raw.get("gates", []):
		gates.append({"id": g["id"], "to": g["to"], "side": g["side"],
			"barrier": _p(g["barrier"]), "inner": _p(g["inner"]), "edge": _p(g["edge"])})
	for e in raw.get("spots", []):
		if Nodes.SPECS.has(e[0]):
			spots.append({"type": e[0], "pos": _p([e[1], e[2]])})
	for e in raw.get("props", []):
		props.append({"name": e[0], "pos": _p([e[1], e[2]]), "fixed": e.size() > 3 and int(e[3]) == 1})
	for e in raw.get("border", []):
		border.append({"name": e[0], "pos": _p([e[1], e[2]])})
	for f in raw.get("farm", []):
		farm.append(_p(f))
	if raw.get("stall") != null:
		stall = _p(raw["stall"])
	if raw.get("board") != null:
		board = _p(raw["board"])
	var pn = raw.get("pen")
	if pn is Array and pn.size() == 4:
		# В файле прямоугольник от левого нижнего угла с осью y вверх
		pen = Rect2(pn[0], size.y - (pn[1] + pn[3]), pn[2], pn[3])
	for e in raw.get("stations", []):
		stations.append({"kind": e[0], "pos": _p([e[1], e[2]])})
	for e in raw.get("slots", []):
		slots.append({"id": e[0], "pos": _p([e[1], e[2]])})
	return true


## Точка из файла (y вверх) в координаты сцены (y вниз).
func _p(v: Array) -> Vector2:
	return Vector2(float(v[0]) if v.size() > 0 else 0.0, size.y - (float(v[1]) if v.size() > 1 else 0.0))


func _fallback(location: String) -> void:
	id = location
	cols = 36
	rows = 46
	cell = 32.0
	cells = PackedByteArray()
	cells.resize(cols * rows)
	for r in rows:
		for c in cols:
			var edge_cell := c < 2 or r < 2 or c >= cols - 2 or r >= rows - 2
			cells[r * cols + c] = Cell.BLOCKED if edge_cell else Cell.LAND
	base = Vector2(cols * cell / 2.0, size.y - 8 * cell)


## Клетка по столбцу и ряду (ряд 0 - верхний).
func at(c: int, r: int) -> int:
	if c < 0 or r < 0 or c >= cols or r >= rows:
		return Cell.VOID
	return cells[r * cols + c]


func col_row(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / cell), floori(p.y / cell))


func rect(c: int, r: int) -> Rect2:
	return Rect2(c * cell, r * cell, cell, cell)


func center(c: int, r: int) -> Vector2:
	return Vector2((c + 0.5) * cell, (r + 0.5) * cell)


func walkable_cell(c: int, r: int) -> bool:
	var v := at(c, r)
	return v == Cell.LAND or v == Cell.PATH or v == Cell.ICE


func walkable(p: Vector2) -> bool:
	var cr := col_row(p)
	return walkable_cell(cr.x, cr.y)


func is_water(c: int, r: int) -> bool:
	return at(c, r) == Cell.WATER


## Типы точек добычи на карте, по порядку появления.
func node_types() -> Array:
	var seen: Array = []
	for s in spots:
		if not s["type"] in seen:
			seen.append(s["type"])
	return seen
