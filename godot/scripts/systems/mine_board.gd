class_name MineBoard
extends RefCounted
## Поле Шахты Глубин без отрисовки (логика отдельно, чтобы её проверяли тесты).
## Клетка - null (пусто) или {k, c, hp}: k = "ore" (руда цвета c), "rock" (камень с прочностью hp),
## "tnt" (динамит: взрыв 3x3), "drill" (бур: весь столбец), "orb" (граната Древних: вся руда цвета c).
## Клетки по строкам сверху вниз: индекс = y * W + x.

var w := Mine.W
var h := Mine.H
var colors := 4
var cells: Array = []
var rng := RandomNumberGenerator.new()


func setup(floor_n: int, seed_value := -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	colors = Mine.colors(floor_n)
	cells.clear()
	cells.resize(w * h)
	for i in cells.size():
		cells[i] = _new_ore()
	# Камни - в нижней половине поля: туда и "пробиваемся"
	var spots: Array = []
	for y in range(h / 2, h):
		for x in w:
			spots.append(y * w + x)
	spots.shuffle()
	for i in mini(Mine.rocks(floor_n), spots.size()):
		cells[spots[i]] = {"k": "rock", "c": -1, "hp": Mine.rock_hp(floor_n, rng)}
	if not has_moves():
		shuffle()


func _new_ore() -> Dictionary:
	return {"k": "ore", "c": rng.randi_range(0, colors - 1), "hp": 0}


func at(x: int, y: int) -> Variant:
	if x < 0 or y < 0 or x >= w or y >= h:
		return null
	return cells[y * w + x]


func rocks_left() -> int:
	var n := 0
	for c in cells:
		if c != null and c["k"] == "rock":
			n += 1
	return n


## Группа одинаковой руды, связанная по сторонам, начиная с клетки (индексы).
func group(i: int) -> Array:
	var start: Variant = cells[i]
	if start == null or start["k"] != "ore":
		return []
	var c := int(start["c"])
	var seen := {i: true}
	var stack := [i]
	var out: Array = []
	while not stack.is_empty():
		var j: int = stack.pop_back()
		out.append(j)
		for n in _neighbors(j):
			if seen.has(n):
				continue
			var cell: Variant = cells[n]
			if cell != null and cell["k"] == "ore" and int(cell["c"]) == c:
				seen[n] = true
				stack.append(n)
	return out


func _neighbors(i: int) -> Array:
	var x := i % w
	var y := i / w
	var out: Array = []
	if x > 0: out.append(i - 1)
	if x < w - 1: out.append(i + 1)
	if y > 0: out.append(i - w)
	if y < h - 1: out.append(i + w)
	return out


## Можно ли сходить на этом поле: есть особый блок или группа из 2+.
func has_moves() -> bool:
	for i in cells.size():
		var c: Variant = cells[i]
		if c == null:
			continue
		if c["k"] in ["tnt", "drill", "orb"]:
			return true
		if c["k"] == "ore":
			for n in _neighbors(i):
				var o: Variant = cells[n]
				if o != null and o["k"] == "ore" and int(o["c"]) == int(c["c"]):
					return true
	return false


## Перемешать руду (камни и особые блоки остаются на местах), пока не появится ход.
func shuffle() -> void:
	for attempt in 30:
		var ore_idx: Array = []
		var ore_cells: Array = []
		for i in cells.size():
			if cells[i] != null and cells[i]["k"] == "ore":
				ore_idx.append(i)
				ore_cells.append(cells[i])
		ore_cells.shuffle()
		for j in ore_idx.size():
			cells[ore_idx[j]] = ore_cells[j]
		if has_moves():
			return
		# Совсем не выходит - перекрасить одну клетку под соседа
		if attempt == 29 and ore_idx.size() >= 2:
			var a: int = ore_idx[0]
			for n in _neighbors(a):
				if cells[n] != null and cells[n]["k"] == "ore":
					cells[n]["c"] = cells[a]["c"]
					return


## Ход по клетке i. Возвращает {} (хода нет) или {removed: [индексы], ore: {цвет: сколько}, hits: [индексы камней],
## broken: [индексы разбитых камней], blasts: [[индекс, вид]], spawned: индекс особого блока или -1,
## falls: [[из, в]], fresh: [индексы новых клеток]}.
func tap(i: int) -> Dictionary:
	var cell: Variant = cells[i]
	if cell == null:
		return {}
	var kill := {}
	var blasts: Array = []
	var spawn: Dictionary = {}
	match str(cell["k"]):
		"ore":
			var g := group(i)
			if g.size() < 2:
				return {}
			for j in g:
				kill[j] = true
			if g.size() >= Mine.ORB_AT:
				spawn = {"k": "orb", "c": int(cell["c"]), "hp": 0}
			elif g.size() >= Mine.DRILL_AT:
				spawn = {"k": "drill", "c": -1, "hp": 0}
			elif g.size() >= Mine.TNT_AT:
				spawn = {"k": "tnt", "c": -1, "hp": 0}
		"tnt", "drill", "orb":
			_detonate(i, kill, blasts)
		_:
			return {}
	# Особые блоки, попавшие под взрыв, тоже срабатывают
	var direct := {}
	var queue: Array = kill.keys()
	while not queue.is_empty():
		var j: int = queue.pop_back()
		var c: Variant = cells[j]
		if j != i and c != null and str(c["k"]) in ["tnt", "drill", "orb"] and not _blasted(blasts, j):
			var before := kill.size()
			_detonate(j, kill, blasts)
			if kill.size() != before:
				queue = kill.keys()
	# Камни: по одному удару от взрыва рядом (за ход - не больше одного), под самим взрывом - тоже один
	var hits: Array = []
	var broken: Array = []
	var hit_once := {}
	for j in kill.keys():
		var c: Variant = cells[j]
		if c != null and c["k"] == "rock":
			direct[j] = true
			hit_once[j] = true
	for j in kill.keys():
		if direct.has(j):
			continue
		for n in _neighbors(j):
			var c: Variant = cells[n]
			if c != null and c["k"] == "rock":
				hit_once[n] = true
	for j in hit_once.keys():
		var r: Dictionary = cells[j]
		r["hp"] = int(r["hp"]) - 1
		hits.append(j)
		if int(r["hp"]) <= 0:
			broken.append(j)
	var ore := {}
	var removed: Array = []
	for j in kill.keys():
		var c: Variant = cells[j]
		if c == null:
			continue
		if c["k"] == "rock":
			continue
		if c["k"] == "ore":
			ore[int(c["c"])] = int(ore.get(int(c["c"]), 0)) + 1
		removed.append(j)
		cells[j] = null
	for j in broken:
		cells[j] = null
		removed.append(j)
	var spawned := -1
	if not spawn.is_empty():
		cells[i] = spawn
		removed.erase(i)
		spawned = i
	var fall := _gravity()
	return {"removed": removed, "ore": ore, "hits": hits, "broken": broken, "blasts": blasts,
		"spawned": spawned, "falls": fall[0], "fresh": fall[1]}


func _blasted(blasts: Array, j: int) -> bool:
	for b in blasts:
		if int(b[0]) == j:
			return true
	return false


## Взрыв особого блока: что он сносит (добавляет в kill).
func _detonate(i: int, kill: Dictionary, blasts: Array) -> void:
	var c: Dictionary = cells[i]
	var kind := str(c["k"])
	blasts.append([i, kind])
	kill[i] = true
	var x := i % w
	var y := i / w
	match kind:
		"tnt":
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nx := x + dx
					var ny := y + dy
					if nx >= 0 and ny >= 0 and nx < w and ny < h:
						kill[ny * w + nx] = true
		"drill":
			for ny in h:
				kill[ny * w + x] = true
		"orb":
			# Цвет гранаты; если её цвета на поле нет - самая частая руда
			var col := int(c["c"])
			if col < 0 or not _has_color(col):
				col = _most_common()
			for j in cells.size():
				var o: Variant = cells[j]
				if o != null and o["k"] == "ore" and int(o["c"]) == col:
					kill[j] = true


func _has_color(col: int) -> bool:
	for o in cells:
		if o != null and o["k"] == "ore" and int(o["c"]) == col:
			return true
	return false


func _most_common() -> int:
	var count := {}
	for o in cells:
		if o != null and o["k"] == "ore":
			count[int(o["c"])] = int(count.get(int(o["c"]), 0)) + 1
	var best := 0
	var top := -1
	for k in count:
		if int(count[k]) > top:
			top = int(count[k])
			best = int(k)
	return best


## Всё падает вниз, сверху появляется новая руда. [[из, в]...], [новые индексы].
func _gravity() -> Array:
	var falls: Array = []
	var fresh: Array = []
	for x in w:
		var write := h - 1
		for y in range(h - 1, -1, -1):
			var i := y * w + x
			if cells[i] == null:
				continue
			var to := write * w + x
			if to != i:
				cells[to] = cells[i]
				cells[i] = null
				falls.append([i, to])
			write -= 1
		for y in range(write, -1, -1):
			var i := y * w + x
			cells[i] = _new_ore()
			fresh.append(i)
	return [falls, fresh]
