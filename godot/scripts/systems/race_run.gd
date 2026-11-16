class_name RaceRun
extends RefCounted
## Один забег гонки (правила без отрисовки, их проверяют тесты). Данные - словарь d, он же лежит в
## Game.save["raceRun"], поэтому гонку можно закрыть и вернуться, пока идёт время:
## {seat, start (unix), seed, coins, xp, tool, bag {ресурс: n}, gates [3], shards [3], sold {ресурс: давление},
##  sold_at, finish (секунды от старта или -1), bots [{name, seat, skin, pace}], name, times [секунды этапов],
##  room (id комнаты на сервере, 0 - гонка без сети)}.
## Живой соперник лежит в bots на своём месте с human = true, times (его этапы от его старта), age (с от его
## входа на момент ответа сервера), age_at (когда пришёл ответ), done (его итог известен).
## Время всегда передаётся снаружи (now - unix-секунды), чтобы тесты могли его двигать.

var d: Dictionary


func _init(data: Dictionary = {}) -> void:
	d = data


## Новый забег: место игрока и три странника на остальных местах.
static func create(seat: int, now: float, seed_value: int, name: String) -> RaceRun:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# Странники по всем 4 местам из seed (у всех в комнате одинаковые), своё место пропускаем
	var bots: Array = []
	var paces: Array = Race.BOT_PACES.duplicate()
	var shift := rng.randi_range(0, paces.size() - 1)
	for s in Race.SEATS:
		var pace: float = paces[(s + shift) % paces.size()] * rng.randf_range(0.93, 1.07)
		var bot := {"name": "Farmer%04d" % rng.randi_range(0, 9999), "seat": s,
			"skin": Race.BOT_SKINS[rng.randi_range(0, Race.BOT_SKINS.size() - 1)], "pace": pace}
		if s != seat:
			bots.append(bot)
	return RaceRun.new({"seat": seat, "start": now, "seed": seed_value, "name": name, "coins": 0, "xp": 0, "tool": 1,
		"bag": {}, "gates": [false, false, false], "shards": [false, false, false], "sold": {}, "sold_at": now,
		"finish": -1.0, "bots": bots, "times": [], "room": 0})


## Забег из сохранения (числа из JSON дробные - приводим).
static func from_save(raw: Variant) -> RaceRun:
	if not raw is Dictionary or not (raw as Dictionary).has("start"):
		return null
	var r := RaceRun.new((raw as Dictionary).duplicate(true))
	var bag := {}
	for k in r.d.get("bag", {}):
		bag[k] = int(r.d["bag"][k])
	r.d["bag"] = bag
	for key in ["seat", "coins", "xp", "tool", "seed"]:
		r.d[key] = int(r.d.get(key, 0))
	r.d["tool"] = clampi(int(r.d["tool"]), 1, Race.TOOL_POWER.size())
	for key in ["gates", "shards"]:
		var a: Array = r.d.get(key, [])
		var out: Array = []
		for i in 3:
			out.append(bool(a[i]) if i < a.size() else false)
		r.d[key] = out
	r.d["finish"] = float(r.d.get("finish", -1.0))
	r.d["start"] = float(r.d["start"])
	r.d["room"] = int(r.d.get("room", 0))
	r.d["times"] = _floats(r.d.get("times", []))
	for b in r.d.get("bots", []):
		if b.has("times"):
			b["times"] = _floats(b["times"])
	return r


static func _floats(a: Variant) -> Array:
	var out: Array = []
	if a is Array:
		for x in a:
			out.append(float(x))
	return out


# MARK: Время

func elapsed(now: float) -> float:
	return maxf(0.0, now - float(d["start"]))


func left(now: float) -> float:
	return maxf(0.0, float(Race.DURATION) - elapsed(now))


func finished() -> bool:
	return float(d["finish"]) >= 0.0


## Мой путь окончен: дошёл до центра или время вышло.
func ended(now: float) -> bool:
	return finished() or elapsed(now) >= float(Race.DURATION)


## Секунда гонки, на которой окончен мой путь.
func end_time() -> float:
	return float(d["finish"]) if finished() else float(Race.DURATION)


## Итог известен: мой путь окончен и ни один живой соперник уже не обгонит (дошёл, время вышло или он
## уже прошёл больше моего времени). Без связи ждём не дольше RESULT_WAIT.
func decided(now: float) -> bool:
	if not ended(now):
		return false
	if room() == 0 or elapsed(now) >= end_time() + Race.RESULT_WAIT:
		return true
	for b in d["bots"]:
		if bool(b.get("human", false)) and not bool(b.get("done", false)) and human_age(b, now) < end_time():
			return false
	return true


func room() -> int:
	return int(d.get("room", 0))


## Сколько секунд идёт гонка живого соперника к моменту now.
static func human_age(b: Dictionary, now: float) -> float:
	return float(b.get("age", 0.0)) + maxf(0.0, now - float(b.get("age_at", now)))


## Отметить пройденные этапы (секунда гонки каждого) - их видят соперники.
func mark(now: float) -> void:
	var t: Array = d["times"]
	while t.size() < my_steps():
		var at := minf(elapsed(now), float(Race.DURATION))
		if t.size() == 6 and finished():
			at = float(d["finish"])
		var prev: float = float(t[-1]) if not t.is_empty() else 0.0
		t.append(snappedf(maxf(maxf(prev, 10.0), at), 0.1))


## Живые соперники из ответа сервера: [{seat, name, skin, times, age, done}] - встают на место странника.
func apply_humans(seats: Array, now: float) -> bool:
	var changed := false
	for raw in seats:
		if not raw is Dictionary:
			continue
		var s := int(raw.get("seat", -1))
		for b in d["bots"]:
			if int(b["seat"]) != s:
				continue
			if not bool(b.get("human", false)):
				changed = true
			b["human"] = true
			b["name"] = str(raw.get("name", b["name"]))
			if str(raw.get("skin", "")) != "":
				b["skin"] = str(raw["skin"])
			b["times"] = _floats(raw.get("times", []))
			b["age"] = float(raw.get("age", 0.0))
			b["age_at"] = now
			b["done"] = bool(raw.get("done", false))
	return changed


# MARK: Уровень, инструмент, сумка

var seat: int:
	get: return int(d["seat"])


var biome: String:
	get: return str(Race.CORNERS[seat]["biome"])


func level() -> int:
	return Race.level_of(int(d["xp"]))


func add_xp(n: int) -> int:
	var before := level()
	d["xp"] = int(d["xp"]) + n
	return level() - before


func tool() -> int:
	return int(d["tool"])


func power() -> float:
	return float(Race.TOOL_POWER[tool() - 1])


func have(kind: String) -> int:
	return int(d["bag"].get(kind, 0))


func coins() -> int:
	return int(d["coins"])


func hero_hp() -> float:
	return float(Race.HERO_HP[level() - 1])


func hero_hit() -> float:
	return float(Race.HERO_HIT[level() - 1])


## Можно ли добывать точку (ступень инструмента).
func can_mine(node: String) -> bool:
	return tool() >= int(Race.NODES[node]["tier"])


## Сколько ударов нужно на точку.
func hits_for(node: String) -> int:
	return int(ceil(float(Race.NODES[node]["hp"]) / power() - 0.0001))


## Добыча с точки: base единиц с учётом догоняния. Возвращает, сколько легло в сумку.
func gather(kind: String, base: int, now: float) -> int:
	var k := 1.0 + Race.CATCH_UP * float(behind(now))
	var n := int(floor(float(base) * k))
	if randf() < float(base) * k - float(n):
		n += 1
	if n <= 0:
		return 0
	d["bag"][kind] = have(kind) + n
	return n


func _take(items: Array) -> void:
	for it in items:
		d["bag"][it[0]] = have(it[0]) - int(it[1])
		if int(d["bag"][it[0]]) <= 0:
			d["bag"].erase(it[0])


func has_items(items: Array) -> bool:
	for it in items:
		if have(it[0]) < int(it[1]):
			return false
	return true


# MARK: Торговец

## Давление продаж на ресурс к моменту now (каждая единица - PRICE_DROP, со временем уходит).
func _pressure(kind: String, now: float) -> float:
	var p := float(d["sold"].get(kind, 0.0))
	var since := maxf(0.0, now - float(d.get("sold_at", now)))
	return maxf(0.0, p - since / Race.PRICE_RECOVER * Race.PRICE_DROP)


func _settle(now: float) -> void:
	for k in d["sold"].keys():
		var p := _pressure(k, now)
		if p <= 0.0:
			d["sold"].erase(k)
		else:
			d["sold"][k] = p
	d["sold_at"] = now


## Цена единицы сейчас.
func price(kind: String, now: float) -> float:
	var base := float(Race.PRICES.get(kind, 1))
	return base * maxf(Race.PRICE_FLOOR, 1.0 - _pressure(kind, now))


## Продать n единиц: цена падает с каждой. Возвращает монеты.
func sell(kind: String, n: int, now: float) -> int:
	n = mini(n, have(kind))
	if n <= 0:
		return 0
	_settle(now)
	var total := 0.0
	for i in n:
		total += float(Race.PRICES.get(kind, 1)) * maxf(Race.PRICE_FLOOR, 1.0 - float(d["sold"].get(kind, 0.0)))
		d["sold"][kind] = float(d["sold"].get(kind, 0.0)) + Race.PRICE_DROP
	_take([[kind, n]])
	var got := int(round(total))
	d["coins"] = coins() + got
	return got


## Продать всё, что не нужно для ближайших ворот и старца. Возвращает монеты.
func sell_spare(now: float) -> int:
	var keep := {}
	var need: Array = []
	var next := next_gate()
	if next >= 0:
		need.append_array(Race.gate_items(seat, next))
	if not bool(d["shards"][2]):
		need.append_array(Race.ELDER)
	for it in need:
		keep[it[0]] = maxi(int(keep.get(it[0], 0)), int(it[1]))
	var got := 0
	for kind in d["bag"].keys():
		var spare := have(kind) - int(keep.get(kind, 0))
		if spare > 0:
			got += sell(kind, spare, now)
	return got


func upgrade_price() -> int:
	return int(Race.TOOL_PRICE[tool()]) if tool() < Race.TOOL_POWER.size() else 0


func can_upgrade() -> bool:
	return tool() < Race.TOOL_POWER.size() and coins() >= upgrade_price()


func upgrade() -> bool:
	if not can_upgrade():
		return false
	d["coins"] = coins() - upgrade_price()
	d["tool"] = tool() + 1
	return true


# MARK: Ворота, осколки, финиш

## Первые закрытые ворота (-1 - все открыты).
func next_gate() -> int:
	for i in 3:
		if not bool(d["gates"][i]):
			return i
	return -1


func gate_open(i: int) -> bool:
	return bool(d["gates"][i])


func gates_open() -> int:
	var n := 0
	for g in d["gates"]:
		n += 1 if g else 0
	return n


func shards() -> int:
	var n := 0
	for s in d["shards"]:
		n += 1 if s else 0
	return n


## Открыть ворота способом way: "items" (ресурсы), "coins" (монеты гонки), "guard" (страж побеждён).
func can_open(i: int, way: String) -> bool:
	if i != next_gate():
		return false
	match way:
		"items": return has_items(Race.gate_items(seat, i))
		"coins": return coins() >= int(Race.GATES[i]["coins"])
		"guard": return true
	return false


func open_gate(i: int, way: String) -> bool:
	if not can_open(i, way):
		return false
	match way:
		"items": _take(Race.gate_items(seat, i))
		"coins": d["coins"] = coins() - int(Race.GATES[i]["coins"])
		"guard": add_xp(int(Race.GUARDS[i]["xp"]))
	d["gates"][i] = true
	return true


## Жила Древних добыта: осколок 0 или 1.
func take_vein(i: int) -> bool:
	if bool(d["shards"][i]) or tool() < int(Race.VEINS[i]["tier"]):
		return false
	d["shards"][i] = true
	add_xp(int(Race.VEINS[i]["xp"]))
	return true


func can_elder() -> bool:
	return not bool(d["shards"][2]) and has_items(Race.ELDER)


func give_elder() -> bool:
	if not can_elder():
		return false
	_take(Race.ELDER)
	d["shards"][2] = true
	add_xp(10)
	return true


## Войти в Сердце можно, когда открыты ворота 3 и собраны все осколки.
func can_finish() -> bool:
	return gate_open(2) and shards() == 3 and not finished()


func finish(now: float) -> bool:
	if not can_finish() or elapsed(now) >= float(Race.DURATION):
		return false
	d["finish"] = elapsed(now)
	return true


# MARK: Соперники и места

## Этапов пройдено (из 7: трое ворот, три осколка, финиш) - для полоски прогресса.
func my_steps() -> int:
	return gates_open() + shards() + (1 if finished() else 0)


## Сколько этапов прошёл странник (или живой соперник) к секунде t от старта.
static func bot_steps(bot: Dictionary, t: float) -> int:
	if bool(bot.get("human", false)):
		var k := 0
		for x in bot.get("times", []):
			if float(x) <= t:
				k += 1
		return k
	var f := t / maxf(1.0, float(bot["pace"]))
	var n := 0
	for s in Race.BOT_STEPS:
		if f >= float(s):
			n += 1
	return n + (1 if f >= 1.0 else 0)


## Ворота странника (по порядку этапов BOT_STEPS: 0 - ворота 1, 3 - ворота 2, 5 - ворота 3).
static func bot_gates(bot: Dictionary, t: float) -> int:
	if bool(bot.get("human", false)):
		var k := bot_steps(bot, t)
		return (1 if k >= 1 else 0) + (1 if k >= 4 else 0) + (1 if k >= 6 else 0)
	var f := t / maxf(1.0, float(bot["pace"]))
	var n := 0
	for idx in [0, 3, 5]:
		if f >= float(Race.BOT_STEPS[idx]):
			n += 1
	return n


## Доля пути странника 0..1.
static func bot_fraction(bot: Dictionary, t: float) -> float:
	if bool(bot.get("human", false)):
		# Живой: доля по пройденным этапам, между этапами - понемногу вперёд (до 0,9 отрезка)
		var k := bot_steps(bot, t)
		if k >= 7:
			return 1.0
		var marks: Array = [0.0] + Race.BOT_STEPS + [1.0]
		var times: Array = bot.get("times", [])
		var since := t - (float(times[k - 1]) if k > 0 else 0.0)
		return float(marks[k]) + (float(marks[k + 1]) - float(marks[k])) * clampf(since / 90.0, 0.0, 0.9)
	return clampf(t / maxf(1.0, float(bot["pace"])), 0.0, 1.0)


## На сколько ворот отстаём от лидера.
func behind(now: float) -> int:
	var t := elapsed(now)
	var best := gates_open()
	for b in d["bots"]:
		best = maxi(best, bot_gates(b, t))
	return best - gates_open()


## Таблица мест к моменту now: [{name, seat, me, bot, skin, steps, finish (с или -1)}], первым - лучший.
## Дошедшие - по времени, остальные - по этапам (при равенстве игрок выше: он ещё в пути).
func standings(now: float) -> Array:
	var t := minf(elapsed(now), float(Race.DURATION))
	var rows: Array = [{"name": str(d.get("name", "")), "seat": seat, "me": true, "bot": false,
		"skin": "", "steps": my_steps(), "finish": float(d["finish"])}]
	for b in d["bots"]:
		var human := bool(b.get("human", false))
		var fin := float(b["pace"])
		if human:
			var times: Array = b.get("times", [])
			fin = float(times[6]) if times.size() >= 7 else INF
		var done := t >= fin and fin <= float(Race.DURATION)
		rows.append({"name": str(b["name"]), "seat": int(b["seat"]), "me": false, "bot": not human, "skin": str(b["skin"]),
			"steps": bot_steps(b, t), "finish": fin if done else -1.0})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var fa := float(a["finish"])
		var fb := float(b["finish"])
		if fa >= 0.0 and fb >= 0.0:
			return fa < fb
		if (fa >= 0.0) != (fb >= 0.0):
			return fa >= 0.0
		if int(a["steps"]) != int(b["steps"]):
			return int(a["steps"]) > int(b["steps"])
		return bool(a["me"]))
	return rows


## Место игрока (1..4) к моменту now. Дошёл - место среди уже дошедших странников на момент финиша.
func place(now: float) -> int:
	var at := now
	if finished():
		at = float(d["start"]) + float(d["finish"])
	var rows := standings(at)
	for i in rows.size():
		if bool(rows[i]["me"]):
			return i + 1
	return Race.SEATS
