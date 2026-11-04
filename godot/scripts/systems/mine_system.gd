class_name MineSystem
extends RefCounted
## Шахта Глубин (данные - data/mine.gd, поле - mine_board.gd).
## В Game.save: mine = {floor, best, lamps, lampAt, day, ore, runs, extra}.
## floor - этаж, на который идёт игрок; best - глубже всего пройдено; lampAt - когда восстановится следующий фонарь;
## day/ore - сколько руды унесено сегодня (дневной лимит); extra - сколько раз за этаж докупали удары.


func defaults(save: Dictionary) -> void:
	var raw: Dictionary = save.get("mine", {}) if save.get("mine") is Dictionary else {}
	save["mine"] = {
		"floor": maxi(1, int(raw.get("floor", 1))),
		"best": maxi(0, int(raw.get("best", 0))),
		"lamps": clampi(int(raw.get("lamps", Mine.LAMPS_MAX)), 0, Mine.LAMPS_MAX * 3),
		"lampAt": float(raw.get("lampAt", 0.0)),
		"day": int(raw.get("day", -1)),
		"ore": maxi(0, int(raw.get("ore", 0))),
		"runs": maxi(0, int(raw.get("runs", 0))),
		"extra": maxi(0, int(raw.get("extra", 0))),
	}


func _m() -> Dictionary:
	return Game.save["mine"]


static func _now() -> float:
	return Time.get_unix_time_from_system()


func open() -> bool:
	return Game.level >= Mine.MIN_LEVEL


func floor_n() -> int:
	return int(_m()["floor"])


func best() -> int:
	return int(_m()["best"])


# MARK: Фонари

## Фонари с учётом восстановления за прошедшее время.
func lamps() -> int:
	_regen()
	return int(_m()["lamps"])


func _regen() -> void:
	var m := _m()
	var n := int(m["lamps"])
	if n >= Mine.LAMPS_MAX:
		m["lampAt"] = 0.0
		return
	var at := float(m["lampAt"])
	var now := _now()
	if at <= 0.0:
		m["lampAt"] = now + Mine.LAMP_SECONDS
		return
	while n < Mine.LAMPS_MAX and at <= now:
		n += 1
		at += Mine.LAMP_SECONDS
	m["lamps"] = n
	m["lampAt"] = at if n < Mine.LAMPS_MAX else 0.0


## Секунд до следующего фонаря (0 - запас полный).
func lamp_left() -> float:
	_regen()
	if int(_m()["lamps"]) >= Mine.LAMPS_MAX:
		return 0.0
	return maxf(0.0, float(_m()["lampAt"]) - _now())


func buy_lamps() -> bool:
	if lamps() >= Mine.LAMPS_MAX:
		return false
	if not Game.shop.spend_crystals(Mine.LAMPS_PRICE):
		return false
	_m()["lamps"] = Mine.LAMPS_MAX
	_m()["lampAt"] = 0.0
	Sound.play("purchase")
	Game.save_now()
	Game.changed.emit()
	return true


## Начать этаж: тратит фонарь. false - фонарей нет.
func start() -> bool:
	if not open() or lamps() <= 0:
		return false
	var m := _m()
	m["lamps"] = int(m["lamps"]) - 1
	if float(m["lampAt"]) <= 0.0:
		m["lampAt"] = _now() + Mine.LAMP_SECONDS
	m["runs"] = int(m["runs"]) + 1
	m["extra"] = 0
	Game.mark_dirty()
	Game.changed.emit()
	return true


# MARK: Удары

func extra_price() -> int:
	return Mine.EXTRA_PRICE + Mine.EXTRA_STEP * int(_m()["extra"])


func buy_extra() -> bool:
	if not Game.shop.spend_crystals(extra_price()):
		return false
	_m()["extra"] = int(_m()["extra"]) + 1
	Game.mark_dirty()
	return true


# MARK: Награды

## Сколько руды ещё можно унести сегодня.
func ore_room() -> int:
	var m := _m()
	if int(m["day"]) != ShopSystem.day_index():
		m["day"] = ShopSystem.day_index()
		m["ore"] = 0
	return maxi(0, Mine.daily_ore(Game.level) - int(m["ore"]))


## Руда с этажа на склад: блоки по видам -> единицы, не больше дневного лимита. Возвращает {вид: сколько}.
func take_ore(floor_n: int, blocks: Dictionary) -> Dictionary:
	var out := {}
	var room := ore_room()
	for c in blocks:
		var units := int(blocks[c]) / Mine.BLOCKS_PER_UNIT
		units = mini(units, room)
		if units <= 0:
			continue
		var kind := Mine.ore_of(floor_n, int(c))
		var put := Game.add_to_storage(kind, units)
		if put > 0:
			out[kind] = int(out.get(kind, 0)) + put
			room -= put
			_m()["ore"] = int(_m()["ore"]) + put
	Game.mark_dirty()
	return out


## Этаж пройден: монеты, ключ по глубине, следующий этаж.
func win(floor_n: int) -> void:
	var m := _m()
	Game.add_coins(Mine.coins(floor_n, Game.level))
	var key := Mine.key_for(floor_n)
	if key != "":
		Game.chests.add_keys(key, 1, false)
	if floor_n >= int(m["floor"]):
		m["floor"] = floor_n + 1
	m["best"] = maxi(int(m["best"]), floor_n)
	Game.emit_event("mine", {"floor": floor_n})
	Game.recalc()
	Game.save_now()
	Game.changed.emit()


## Для отметки на вкладке: фонари полные - пора спускаться.
func ready_count() -> int:
	return 1 if open() and lamps() >= Mine.LAMPS_MAX else 0


func on_event(_name: String, _data: Dictionary) -> void:
	pass
