extends "res://tests/test_case.gd"
## Живой бой за клетку войны: уровни клеток, волны, умения, тактика и баланс по силе.


func _play(mode: String, ratio: float, smart: bool, seed_value: int) -> WarBattle:
	var b := WarBattle.new()
	b.setup(mode, 3, int(100000 * ratio), 100000, ["hero", "a", "b", "c", "d"], War.CAMP_MONSTERS[3], "", seed_value)
	while b.state == "fight":
		if smart:
			for i in b.foes.size():
				if b.alive(i) and float(b.foes[i]["wind"]) > 0.0 and float(b.foes[i]["wind"]) < 1.0:
					b.use("shield")
			b.use("volley")
			b.use("rage")
			for i in b.foes.size():
				if b.alive(i) and str(b.foes[i]["role"]) in ["heavy", "tower", "guard"]:
					b.pick(i)
					break
		b.step(0.05)
	return b


func test_levels() -> void:
	eq(War.level(0), 5, "замок")
	eq(War.level(1), 0, "база")
	eq(War.level(9), 1)
	eq(War.level(17), 2, "между базами")
	eq(War.level(25), 3)
	eq(War.level(33), 4)
	for l in range(1, 5):
		check(War.camp_power(l + 1) > War.camp_power(l), "лагерь сильнее с уровнем")


func test_waves_and_result() -> void:
	var b := _play("camp", 1.0, true, 7)
	eq(b.state, "won", "равный по силе и умелый отряд проходит лагерь")
	eq(b.wave, b.wave_total, "все волны пройдены")
	check(b.tactic() > 0.6, "хорошая тактика")
	var s := _play("siege", 1.0, true, 7)
	eq(s.state, "won", "штурм базы проходится")


func test_power_matters() -> void:
	var weak := 0
	var strong := 0
	for i in 10:
		if _play("camp", 0.3, true, i + 1).state == "won":
			weak += 1
		if _play("camp", 2.0, false, i + 1).state == "won":
			strong += 1
	eq(weak, 0, "слабому лагерь не по силам даже с умениями")
	eq(strong, 10, "сильный проходит и без умений")


func test_skills_help() -> void:
	var lazy := 0.0
	var smart := 0.0
	for i in 5:
		lazy += maxf(0.0, _play("camp", 1.0, false, i + 1).tactic())
		smart += maxf(0.0, _play("camp", 1.0, true, i + 1).tactic())
	check(smart > lazy + 1.0, "умения и щит поднимают тактику")


func test_retreat_and_chance() -> void:
	var b := WarBattle.new()
	b.setup("camp", 1, 100000, 100000, ["hero"], ["slimeGreen"], "", 3)
	b.retreat()
	eq(b.state, "lost")
	eq(b.tactic(), -1.0, "отступление - поражение")
	check(War.battle_chance(100000, 0, 100000, 1.0) > War.battle_chance(100000, 0, 100000, 0.0), "тактика поднимает шанс")
	near(War.battle_chance(100000, 0, 100000, 0.0), 0.5, 0.001)


func test_gate_ram() -> void:
	var b := WarBattle.new()
	b.setup("siege", 1, 100000, 100000, ["hero"], [], "cow", 5)
	var gate := -1
	for i in b.foes.size():
		if str(b.foes[i]["role"]) == "gate":
			gate = i
	check(gate >= 0, "в штурме есть ворота")
	var hp := float(b.foes[gate]["hp"])
	b.pick(gate)
	b.pick(gate)
	check(float(b.foes[gate]["hp"]) < hp, "второе нажатие по воротам - таран")


func test_trophies_in_power() -> void:
	fresh()
	var p0 := Power.total()
	Game.save["warTrophies"] = 10
	eq(Power.total() - p0, 10 * War.TROPHY_POWER)
	Game.save["warTrophies"] = 99999
	eq(int(Power.breakdown()["trophies"]), War.TROPHY_MAX * War.TROPHY_POWER, "трофеев не больше предела")
