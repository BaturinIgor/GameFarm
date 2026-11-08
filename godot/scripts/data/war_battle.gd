class_name WarBattle
extends RefCounted
## Живой бой за клетку войны альянсов (без отрисовки - её делает BattleScene, а проверяют тесты).
## Лагерь монстров (ничья клетка): волны монстров, среди них заклинатели с тяжёлым ударом.
## Штурм базы (чужая клетка): ворота (их таранят нажатиями), башни-лучники, потом страж и защитники.
## Отряд бьёт выбранную цель; умения: залп по всем, щит (отбивает тяжёлый удар, обычные - вполсилы), ярость (двойной урон).
## Победил волны - решающая схватка (исход решает сервер, тактика даёт до +25% силы). Отряд разбит - поражение.

const PAR := 25.0
const MAX_TIME := 90.0
const UNIT_HP := 100.0
const UNIT_ATK := 10.0
const UNIT_EVERY := 1.0
const FOE_ATK := 6.0
const FOE_EVERY := 1.3
const HEAVY_EVERY := 6.0
const HEAVY_WIND := 1.5
## Тяжёлый удар бьёт всех в отряде.
const HEAVY_DMG := 18.0
const SKILLS := {"volley": 9.0, "shield": 7.0, "rage": 14.0}
const SHIELD_TIME := 2.5
const RAGE_TIME := 5.0
const VOLLEY_MULT := 3.0
const RAM_DMG := 5.0
const RAM_EVERY := 0.12
## Цель, выбранная игроком, получает больше урона.
const FOCUS_MULT := 1.25
## «Второе дыхание» (за кристаллы): разбитый отряд встаёт с такой долей здоровья, один раз за бой.
const REVIVE_HP := 0.6
## Перезарядок умения за кристаллы в одном бою.
const RECHARGE_MAX := 3

var mode := "camp"
var level := 1
var ratio := 1.0
var units: Array = []
var foes: Array = []
var waves: Array = []
var wave := 0
var wave_total := 0
var focus := -1
var cds := {"volley": 0.0, "shield": 0.0, "rage": 0.0}
var shield_t := 0.0
var rage_t := 0.0
var time := 0.0
var heavy_total := 0
var blocked := 0
var state := "fight"
## Почему проигран: dead - отряд разбит, time - время вышло, retreat - отступил.
var lost_by := ""
var revived := false
var recharged := 0
## События для отрисовки: [вид, данные]. Экран забирает их каждый кадр.
var events: Array = []
var _ram_cd := 0.0
var _rng := RandomNumberGenerator.new()


## mode: camp | siege. squad: id бойцов ("hero" и звери). monsters: виды монстров лагеря. guard: зверь в гарнизоне.
func setup(p_mode: String, p_level: int, power: int, defense: int, squad: Array, monsters: Array, guard := "", seed_value := 0) -> void:
	mode = p_mode
	level = clampi(p_level, 1, 5)
	ratio = clampf(float(maxi(1, power)) / float(maxi(1, defense)), 0.25, 4.0)
	_rng.seed = seed_value if seed_value != 0 else randi()
	units.clear()
	var n := clampi(squad.size(), 1, 5)
	for i in n:
		units.append({"id": str(squad[i]), "hp": UNIT_HP, "max": UNIT_HP, "cd": 0.2 * i, "x": (float(i) + 0.5) / float(n)})
	waves.clear()
	var hp_k := 1.0 + 0.08 * (level - 1)
	if mode == "siege":
		waves.append([_foe("gate", "gate", 420.0 * hp_k, 0.5, 0.36), _foe("tower", "tower", 170.0 * hp_k, 0.18, 0.22),
			_foe("tower", "tower", 170.0 * hp_k, 0.82, 0.22)])
		var second: Array = [_foe("skelSoldier", "mob", 120.0 * hp_k, 0.25, 0.4), _foe("skelSoldier", "mob", 120.0 * hp_k, 0.75, 0.4)]
		second.append(_foe(guard if guard != "" else "orcWarrior", "guard" if guard != "" else "heavy", 260.0 * hp_k, 0.5, 0.3))
		waves.append(second)
	else:
		var kinds: Array = monsters if not monsters.is_empty() else ["slimeGreen"]
		var mobs := 3 if level <= 2 else 4
		var w1: Array = []
		for i in mobs:
			w1.append(_foe(str(kinds[i % kinds.size()]), "mob", 360.0 * hp_k / mobs, (float(i) + 0.5) / mobs, 0.38 + 0.05 * (i % 2)))
		waves.append(w1)
		var w2: Array = []
		for i in mobs - 1:
			w2.append(_foe(str(kinds[(i + 1) % kinds.size()]), "mob", 420.0 * hp_k / (mobs - 1), (float(i) + 0.5) / (mobs - 1) * 0.8 + 0.1, 0.42))
		w2.append(_foe(str(kinds[kinds.size() - 1]), "heavy", 260.0 * hp_k, 0.5, 0.26))
		waves.append(w2)
		if level >= 4:
			waves.append([_foe(str(kinds[0]), "heavy", 220.0 * hp_k, 0.3, 0.3), _foe(str(kinds[1 % kinds.size()]), "heavy", 220.0 * hp_k, 0.7, 0.3)])
	wave_total = waves.size()
	wave = 0
	_next_wave()


func _foe(kind: String, role: String, hp: float, x: float, y: float) -> Dictionary:
	return {"kind": kind, "role": role, "hp": hp, "max": hp, "cd": _rng.randf_range(0.3, FOE_EVERY),
		"heavy": _rng.randf_range(2.0, HEAVY_EVERY) if role in ["heavy", "tower", "guard"] else -1.0, "wind": 0.0, "x": x, "y": y}


func _next_wave() -> void:
	foes = waves.pop_front()
	wave += 1
	focus = -1
	events.append(["wave", wave])


## Сила моего отряда и врагов от соотношения мощи: слабый отряд бьёт тише и получает больше.
func my_mult() -> float:
	return sqrt(ratio) * (2.0 if rage_t > 0.0 else 1.0)


func foe_mult() -> float:
	return pow(ratio, -0.85)


func alive_units() -> Array:
	return units.filter(func(u: Dictionary) -> bool: return float(u["hp"]) > 0.0)


func alive(i: int) -> bool:
	return i >= 0 and i < foes.size() and float(foes[i]["hp"]) > 0.0


## Кого бьёт отряд: выбранную цель, иначе первую живую (ворота - в последнюю очередь, если есть кто-то ещё).
func target() -> int:
	if alive(focus):
		return focus
	var best := -1
	for i in foes.size():
		if not alive(i):
			continue
		if best < 0 or (str(foes[best]["role"]) == "gate" and str(foes[i]["role"]) != "gate"):
			best = i
	return best


func pick(i: int) -> void:
	if not alive(i):
		return
	if str(foes[i]["role"]) == "gate" and focus == i and _ram_cd <= 0.0:
		_ram_cd = RAM_EVERY
		_hit(i, RAM_DMG * my_mult(), "ram")
	focus = i


func can_use(skill: String) -> bool:
	return state == "fight" and float(cds.get(skill, 1.0)) <= 0.0


func use(skill: String) -> void:
	if not can_use(skill):
		return
	cds[skill] = SKILLS[skill]
	match skill:
		"volley":
			for i in foes.size():
				if alive(i):
					_hit(i, UNIT_ATK * VOLLEY_MULT * my_mult(), "volley")
		"shield":
			shield_t = SHIELD_TIME
		"rage":
			rage_t = RAGE_TIME
	events.append(["skill", skill])


func _hit(i: int, dmg: float, how: String) -> void:
	var f: Dictionary = foes[i]
	f["hp"] = maxf(0.0, float(f["hp"]) - dmg)
	events.append(["hit", i, dmg, how])
	if float(f["hp"]) <= 0.0:
		f["wind"] = 0.0
		events.append(["dead", i])


func step(dt: float) -> void:
	if state != "fight":
		return
	time += dt
	_ram_cd -= dt
	shield_t = maxf(0.0, shield_t - dt)
	rage_t = maxf(0.0, rage_t - dt)
	for k in cds:
		cds[k] = maxf(0.0, float(cds[k]) - dt)
	# Отряд
	for ui in units.size():
		var u: Dictionary = units[ui]
		if float(u["hp"]) <= 0.0:
			continue
		u["cd"] = float(u["cd"]) - dt
		if float(u["cd"]) > 0.0:
			continue
		u["cd"] = UNIT_EVERY
		var t := target()
		if t < 0:
			break
		events.append(["shot", ui, t])
		_hit(t, UNIT_ATK * my_mult() * (FOCUS_MULT if t == focus else 1.0), "unit")
	# Враги
	for fi in foes.size():
		var f: Dictionary = foes[fi]
		if float(f["hp"]) <= 0.0 or str(f["role"]) == "gate":
			continue
		if float(f["heavy"]) >= 0.0:
			if float(f["wind"]) > 0.0:
				f["wind"] = float(f["wind"]) - dt
				if float(f["wind"]) <= 0.0:
					_heavy(fi)
			else:
				f["heavy"] = float(f["heavy"]) - dt
				if float(f["heavy"]) <= 0.0:
					f["heavy"] = HEAVY_EVERY
					f["wind"] = HEAVY_WIND
					events.append(["wind", fi])
		f["cd"] = float(f["cd"]) - dt
		if float(f["cd"]) <= 0.0:
			f["cd"] = FOE_EVERY
			var al := alive_units()
			if al.is_empty():
				break
			var u: Dictionary = al[_rng.randi_range(0, al.size() - 1)]
			var dmg := FOE_ATK * foe_mult() * (0.5 if shield_t > 0.0 else 1.0)
			u["hp"] = maxf(0.0, float(u["hp"]) - dmg)
			events.append(["hurt", units.find(u), dmg])
	if alive_units().is_empty():
		state = "lost"
		lost_by = "dead"
		events.append(["lost"])
		return
	if range(foes.size()).all(func(i: int) -> bool: return not alive(i)):
		if waves.is_empty():
			state = "won"
			events.append(["won"])
			return
		_next_wave()
	if time >= MAX_TIME:
		state = "lost"
		lost_by = "time"
		events.append(["lost"])


func _heavy(fi: int) -> void:
	heavy_total += 1
	if shield_t > 0.0:
		blocked += 1
		events.append(["blocked", fi])
		return
	for ui in units.size():
		var u: Dictionary = units[ui]
		if float(u["hp"]) > 0.0:
			u["hp"] = maxf(0.0, float(u["hp"]) - HEAVY_DMG * foe_mult())
	events.append(["slam", fi])


## Отступить: бой проигран, атака тратится.
func retreat() -> void:
	if state == "fight":
		state = "lost"
		lost_by = "retreat"
		events.append(["lost"])


## Можно ли поднять разбитый отряд (один раз, и только если его разбили, а не вышло время).
func can_revive() -> bool:
	return state == "lost" and lost_by == "dead" and not revived


func revive() -> void:
	if not can_revive():
		return
	revived = true
	state = "fight"
	lost_by = ""
	for u in units:
		u["hp"] = float(u["max"]) * REVIVE_HP
		u["cd"] = 0.3
	shield_t = SHIELD_TIME
	for f in foes:
		f["wind"] = 0.0
	events.append(["revive"])


func can_recharge(skill: String) -> bool:
	return state == "fight" and recharged < RECHARGE_MAX and float(cds.get(skill, 0.0)) > 0.0


## Сбросить перезарядку умения (за кристаллы - их списывает экран).
func recharge(skill: String) -> void:
	if not can_recharge(skill):
		return
	recharged += 1
	cds[skill] = 0.0
	events.append(["recharge", skill])


## Насколько хорошо сыгран бой, 0..1: сколько сил отряда сохранено, сколько тяжёлых ударов отбито щитом и как быстро.
func tactic() -> float:
	if state == "lost":
		return -1.0
	var hp := 0.0
	var mx := 0.0
	for u in units:
		hp += float(u["hp"])
		mx += float(u["max"])
	var keep := hp / maxf(1.0, mx) * (0.5 if revived else 1.0)
	var block := 1.0 if heavy_total == 0 else float(blocked) / float(heavy_total)
	var speed := clampf(1.5 - time / PAR, 0.0, 1.0)
	return clampf(0.4 * keep + 0.35 * block + 0.25 * speed, 0.0, 1.0)
