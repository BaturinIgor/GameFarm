extends "res://tests/test_case.gd"
## Шахта Глубин: поле, взрывы, камни, фонари, награды.


func _board(cells: Array, floor_n := 1) -> MineBoard:
	var b := MineBoard.new()
	b.setup(floor_n, 7)
	for i in cells.size():
		b.cells[i] = cells[i]
	return b


func _ore(c: int) -> Dictionary:
	return {"k": "ore", "c": c, "hp": 0}


## Поле в шахматку из двух цветов: ни одной группы.
func _checker() -> Array:
	var out: Array = []
	for i in Mine.W * Mine.H:
		out.append(_ore((i % Mine.W + i / Mine.W) % 2))
	return out


func test_setup_has_rocks_and_moves() -> void:
	for f in [1, 9, 30, 55]:
		var b := MineBoard.new()
		b.setup(f, f)
		eq(b.rocks_left(), Mine.rocks(f), "камней на этаже %d" % f)
		check(b.has_moves(), "на этаже %d есть ход" % f)
		for c in b.cells:
			check(c != null, "поле заполнено")
			if c["k"] == "ore":
				check(int(c["c"]) < Mine.colors(f), "цвет руды в пределах")


func test_single_block_is_not_a_move() -> void:
	var cells := _checker()
	var b := _board(cells)
	check(b.tap(0).is_empty(), "одиночный блок не взрывается")


func test_pair_blasts_and_cracks_rock() -> void:
	var cells := _checker()
	# Внизу слева: пара цвета 2 и камень над ней
	var y := Mine.H - 1
	cells[y * Mine.W] = _ore(2)
	cells[y * Mine.W + 1] = _ore(2)
	cells[(y - 1) * Mine.W] = {"k": "rock", "c": -1, "hp": 1}
	var b := _board(cells)
	var res := b.tap(y * Mine.W)
	check(not res.is_empty(), "пара взорвалась")
	eq(int(res["ore"].get(2, 0)), 2, "две руды цвета 2")
	eq(res["broken"].size(), 1, "камень рядом разбит")
	eq(b.rocks_left(), 0)
	for c in b.cells:
		check(c != null, "после падения поле снова полное")


func test_rock_takes_one_hit_per_move() -> void:
	var cells := _checker()
	var y := Mine.H - 1
	# Камень с прочностью 3 между двумя клетками одной группы
	cells[y * Mine.W + 0] = _ore(3)
	cells[(y - 1) * Mine.W + 0] = _ore(3)
	cells[(y - 1) * Mine.W + 1] = _ore(3)
	cells[y * Mine.W + 1] = {"k": "rock", "c": -1, "hp": 3}
	var b := _board(cells)
	b.tap(y * Mine.W)
	var rock_hp := -1
	for c in b.cells:
		if c != null and c["k"] == "rock":
			rock_hp = int(c["hp"])
	eq(rock_hp, 2, "за ход камень теряет одну прочность")


func test_big_group_leaves_special() -> void:
	var cells := _checker()
	for x in Mine.TNT_AT:
		cells[(Mine.H - 1) * Mine.W + x] = _ore(4)
	var b := _board(cells)
	var res := b.tap((Mine.H - 1) * Mine.W)
	check(int(res["spawned"]) >= 0, "осталась особая клетка")
	var found := false
	for c in b.cells:
		if c != null and c["k"] == "tnt":
			found = true
	check(found, "группа из %d оставляет динамит" % Mine.TNT_AT)


func test_tnt_clears_area_and_hits_rocks() -> void:
	var cells := _checker()
	var mid := 4 * Mine.W + 3
	cells[mid] = {"k": "tnt", "c": -1, "hp": 0}
	cells[mid + 1] = {"k": "rock", "c": -1, "hp": 1}
	cells[mid + 2] = {"k": "rock", "c": -1, "hp": 1}
	var b := _board(cells)
	var res := b.tap(mid)
	check(not res.is_empty(), "динамит срабатывает от касания")
	eq(res["blasts"].size(), 1)
	eq(b.rocks_left(), 0, "камень под взрывом и камень рядом разбиты")


func test_orb_clears_color() -> void:
	var cells := _checker()
	cells[0] = {"k": "orb", "c": 1, "hp": 0}
	var b := _board(cells)
	var res := b.tap(0)
	var ones := 0
	for c in cells:
		if c["k"] == "ore" and int(c["c"]) == 1:
			ones += 1
	eq(int(res["ore"].get(1, 0)), ones, "граната сносит всю руду своего цвета")


func test_shuffle_finds_move() -> void:
	var b := _board(_checker())
	check(not b.has_moves(), "в шахматке хода нет")
	b.shuffle()
	check(b.has_moves(), "после перемешивания ход есть")


func test_lamps_spend_and_regen() -> void:
	set_level(Mine.MIN_LEVEL)
	eq(Game.mine.lamps(), Mine.LAMPS_MAX)
	for i in Mine.LAMPS_MAX:
		check(Game.mine.start(), "вход %d" % i)
	check(not Game.mine.start(), "без фонарей не войти")
	# Прошло полтора часа: три фонаря
	Game.save["mine"]["lampAt"] = Time.get_unix_time_from_system() - Mine.LAMP_SECONDS * 2.0 - 1.0
	eq(Game.mine.lamps(), 3, "фонари восстанавливаются")


func test_mine_locked_below_level() -> void:
	set_level(Mine.MIN_LEVEL - 1)
	check(not Game.mine.start(), "до уровня шахта закрыта")


func test_win_gives_floor_and_key() -> void:
	set_level(20)
	Game.save["mine"]["floor"] = 10
	var coins := int(Game.save["coins"])
	Game.mine.win(10)
	eq(Game.mine.floor_n(), 11, "следующий этаж")
	eq(Game.mine.best(), 10)
	check(int(Game.save["coins"]) > coins, "монеты за этаж")
	eq(Game.chests.keys("silver"), 1, "10-й этаж даёт серебряный ключ")


func test_ore_daily_cap() -> void:
	set_level(10)
	var cap := Mine.daily_ore(Game.level)
	var got := Game.mine.take_ore(1, {0: (cap + 50) * Mine.BLOCKS_PER_UNIT})
	var total := 0
	for k in got:
		total += int(got[k])
	check(total <= cap, "не больше дневного лимита")
	eq(Game.mine.ore_room(), cap - total)


func test_extra_moves_price_grows() -> void:
	set_level(Mine.MIN_LEVEL)
	Game.mine.start()
	var p1 := Game.mine.extra_price()
	Game.save["crystals"] = 1000
	check(Game.mine.buy_extra())
	check(Game.mine.extra_price() > p1, "вторая докупка дороже")


func test_keys_by_depth() -> void:
	eq(Mine.key_for(5), "copper")
	eq(Mine.key_for(10), "silver")
	eq(Mine.key_for(25), "star")
	eq(Mine.key_for(50), "star")
	eq(Mine.key_for(7), "")
	for f in [1, 11, 21, 31, 41, 51]:
		for c in Mine.colors(f):
			check(Mine.ore_of(f, c) in Res.KINDS, "руда этажа %d - известный ресурс" % f)
