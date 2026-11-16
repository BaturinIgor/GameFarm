class_name Race
## Гонка к Сердцу долины: четверо стартуют в углах карты, кто первым дойдёт до центра - победил.
## Карта - сетка 3x3 квадратов: углы (лагеря игроков), между ними перешейки, в середине ядро с Сердцем.
## Путь игрока: свой угол -> свой перешеек (ворота 1) -> ядро (ворота 2) -> Сердце (ворота 3 и ключ из 3 осколков).
## Экономика гонки своя (ресурсы, монеты, уровень, инструмент) и сгорает в конце: прогресс фермы не помогает.
## Правила - RaceRun, сохранение и награды - RaceSystem (Game.race), поле - RaceScene.

const MIN_LEVEL := 10
## Длина гонки, секунды.
const DURATION := 15 * 60
const SEATS := 4

## Флажки: попытки гонки. Восстанавливаются по одному.
const FLAGS_MAX := 5
const FLAG_EVERY := 3600
## Флажки за рекламу: сколько в день.
const AD_FLAGS := 3
## Сколько секунд после своего конца ждём итога живых соперников, если нет связи.
const RESULT_WAIT := 90
## Как часто спрашивать сервер о ходе соперников (с).
const SYNC_EVERY := 4.0

# MARK: Карта

## Сторона квадрата сетки (точки) и всей карты.
const TILE := 640.0
const SIZE := TILE * 3.0
## Ширина прохода в воротах.
const GAP := 150.0
## Радиус Сердца в центре ядра.
const HEART_R := 120.0

## Углы по местам: клетка сетки и биом. Перешеек идёт по часовой стрелке от угла.
const CORNERS := [
	{"cell": Vector2i(0, 0), "biome": "meadow", "arm": Vector2i(1, 0)},
	{"cell": Vector2i(2, 0), "biome": "desert", "arm": Vector2i(2, 1)},
	{"cell": Vector2i(2, 2), "biome": "snow", "arm": Vector2i(1, 2)},
	{"cell": Vector2i(0, 2), "biome": "island", "arm": Vector2i(0, 1)},
]
const CORE := Vector2i(1, 1)
## Земля перешейков и ядра (картинки локаций фермы).
const ARM_GROUND := "hills"
const CORE_GROUND := "garden"

## Точки добычи угла по биому: [дерево, еда, камень] - вид точки (рисунок) и что даёт.
const CORNER_NODES := {
	"meadow": [["tree", "wood"], ["bush", "berries"], ["rock", "stone"]],
	"desert": [["palm", "wood"], ["cactus", "cactus"], ["rock", "stone"]],
	"snow": [["snowPine", "wood"], ["iceBlock", "ice"], ["rock", "stone"]],
	"island": [["palm", "wood"], ["pineapple", "pineapple"], ["rock", "stone"]],
}
const FOOD := {"meadow": "berries", "desert": "cactus", "snow": "ice", "island": "pineapple"}

## Точки гонки: рисунок (вид точки фермы), инструмент, нужная ступень инструмента гонки, прочность в ударах
## инструмента 1, сколько даёт, опыт, восстановление (с).
const NODES := {
	"corner": {"tool": "axe", "tier": 1, "hp": 2.0, "min": 2, "max": 3, "xp": 2, "respawn": 18.0},
	"coal": {"type": "coalOre", "kind": "coal", "tool": "pickaxe", "tier": 2, "hp": 4.0, "min": 2, "max": 3, "xp": 3, "respawn": 20.0},
	"iron": {"type": "ironOre", "kind": "iron", "tool": "pickaxe", "tier": 2, "hp": 6.0, "min": 2, "max": 3, "xp": 3, "respawn": 20.0},
	"gold": {"type": "goldOre", "kind": "gold", "tool": "pickaxe", "tier": 3, "hp": 6.0, "min": 1, "max": 2, "xp": 4, "respawn": 22.0},
	"diamond": {"type": "diamondOre", "kind": "diamond", "tool": "pickaxe", "tier": 3, "hp": 9.0, "min": 1, "max": 2, "xp": 4, "respawn": 24.0},
	"crystal": {"type": "crystalOre", "kind": "crystal", "tool": "pickaxe", "tier": 3, "hp": 12.0, "min": 1, "max": 2, "xp": 4, "respawn": 26.0},
}
## Жилы Древних: осколок 1 в углу, осколок 2 в перешейке. Ступень инструмента и прочность.
const VEINS := [
	{"tier": 2, "hp": 8.0, "xp": 10},
	{"tier": 3, "hp": 12.0, "xp": 10},
]

## Сила удара инструмента по ступени (ступень 1 - один удар на единицу прочности).
const TOOL_POWER := [1.0, 2.0, 3.0]
const TOOL_PRICE := [0, 90, 260]
const HIT_EVERY := 0.5

# MARK: Ворота и осколки

## Ворота: [ресурсы], монеты гонки, уровень стража. "food" - еда своего угла.
const GATES := [
	{"items": [["wood", 22], ["food", 22], ["stone", 22]], "coins": 130, "guard": 2},
	{"items": [["coal", 28], ["iron", 28]], "coins": 320, "guard": 3},
	{"items": [["crystal", 12]], "coins": 600, "guard": 5},
]
## Старец в ядре даёт третий осколок за набор ресурсов.
const ELDER := [["gold", 12], ["diamond", 6]]

## Стражи ворот: здоровье, урон в секунду, вид монстра, опыт за победу.
const GUARDS := [
	{"hp": 24.0, "dps": 2.6, "kind": "slimeGreen", "xp": 15},
	{"hp": 44.0, "dps": 2.8, "kind": "skeleton", "xp": 25},
	{"hp": 96.0, "dps": 3.5, "kind": "orcWarrior", "xp": 40},
]
## Раз в сколько секунд бьёт страж.
const GUARD_EVERY := 1.2

# MARK: Уровень и бой

## Опыт до уровня (накопленный): уровень 1..5.
const LEVEL_XP := [0, 25, 70, 140, 240]
const MAX_LEVEL := 5
## Здоровье и урон героя в бою по уровню (урон за удар раз в HIT_EVERY).
const HERO_HP := [20.0, 30.0, 40.0, 50.0, 60.0]
const HERO_HIT := [1.0, 1.5, 2.2, 3.0, 4.0]
## За сколько секунд вне боя здоровье восстанавливается полностью.
const HEAL_TIME := 5.0

# MARK: Торговец

## Цена единицы в монетах гонки.
const PRICES := {"wood": 2, "berries": 2, "cactus": 2, "ice": 2, "pineapple": 2, "stone": 2,
	"coal": 3, "iron": 4, "gold": 6, "diamond": 9, "crystal": 12}
## Каждая проданная единица снижает цену этого ресурса на 1% (не ниже половины), за 3 с цена отходит на 1%.
const PRICE_DROP := 0.01
const PRICE_FLOOR := 0.5
const PRICE_RECOVER := 3.0

## Догоняние: за каждые ворота отставания от лидера добыча больше на 15%.
const CATCH_UP := 0.15

# MARK: Соперники

## Темп странников (ботов): за сколько секунд доходят до центра (разброс +-7%).
const BOT_PACES := [570.0, 660.0, 810.0]
## Доли пути, на которых странник проходит этапы: ворота 1, осколок 1, осколок 2, ворота 2, осколок 3, ворота 3.
const BOT_STEPS := [0.28, 0.32, 0.58, 0.62, 0.85, 0.95]
const BOT_SKINS := ["farmerWoman", "farmerMan", "cowboy", "builder", "elf", "detective"]

# MARK: Награды

const TROPHIES := [30, 18, 10, 4]
const CRYSTALS := [10, 5, 3, 1]
## Ключ от сундука за место ("" - без ключа).
const KEYS := ["silver", "copper", "", ""]

# MARK: Уютные действия

## Маяк: первый дошедший до Сердца зажигает его, остальным на BEACON_TIME секунд добыча +BEACON_BOOST.
const BEACON_TIME := 120.0
const BEACON_BOOST := 0.5
## «Подбодрить»: отстающему CHEER_COST своих ресурсов, мне очко дружбы (+1 трофей), не больше CHEER_MAX за гонку.
const CHEER_COST := 5
const CHEER_MAX := 3
## Смайлики над бегуном (значки Sprites, тот же список - в race_emote на сервере). Не чаще раза в EMOTE_EVERY с.
const EMOTES := ["heart", "star", "flame", "clover", "fist", "trophy"]
const EMOTE_EVERY := 3.0
const EMOTE_SHOW := 4.0

# MARK: Рейтинг

## Награда за место в рейтинге дня (топ-10): кристаллы.
const DAY_PRIZES := [50, 35, 25, 10]
## Награда за место в рейтинге месяца (топ-100): кристаллы; первым трём - титул чемпиона, топ-10 - призёра.
const MONTH_PRIZES := [500, 300, 200, 100, 30]

## Лиги по трофеям: порог и разовая награда кристаллами.
const LEAGUES := [
	{"id": "wood", "from": 0, "crystals": 0},
	{"id": "bronze", "from": 100, "crystals": 20},
	{"id": "silver", "from": 300, "crystals": 40},
	{"id": "gold", "from": 700, "crystals": 80},
	{"id": "emerald", "from": 1500, "crystals": 150},
	{"id": "diamond", "from": 3000, "crystals": 300},
]


## Цвет лиги: имя бегуна, знамя (с Серебра), след (с Золота).
const LEAGUE_COLORS := ["c9a27a", "d08a4a", "dfe6ee", "ffd54a", "5fd39a", "9fe8ff"]
const BANNER_FROM := 2
const TRAIL_FROM := 3


static func league_color(i: int) -> Color:
	return Color(LEAGUE_COLORS[clampi(i, 0, LEAGUE_COLORS.size() - 1)])


## Кристаллы за место в рейтинге дня (0 - вне топ-10).
static func day_prize(place: int) -> int:
	if place < 1 or place > 10:
		return 0
	return int(DAY_PRIZES[mini(place, DAY_PRIZES.size()) - 1])


## Кристаллы за место в рейтинге месяца (0 - вне топ-100).
static func month_prize(place: int) -> int:
	if place < 1 or place > 100:
		return 0
	if place <= 3:
		return int(MONTH_PRIZES[place - 1])
	return int(MONTH_PRIZES[3]) if place <= 10 else int(MONTH_PRIZES[4])


## Титул за место в рейтинге месяца: champion (1-3), medalist (4-10), top100, "" - нет.
static func month_title(place: int) -> String:
	if place < 1 or place > 100:
		return ""
	return "champion" if place <= 3 else ("medalist" if place <= 10 else "top100")


## Название месяца по номеру (год * 12 + месяц - 1, как month_key на сервере): "11.2026".
static func month_label(key: int) -> String:
	return "%02d.%d" % [key % 12 + 1, key / 12]


## Дата дня по номеру (дни от 1970-01-01, как day_key на сервере): "15.11".
static func day_label(key: int) -> String:
	var d := Time.get_date_dict_from_unix_time(key * 86400)
	return "%02d.%02d" % [int(d["day"]), int(d["month"])]


## Время гонки как на секундомере: "8:05".
static func clock(sec: float) -> String:
	var t := maxi(0, int(ceilf(sec)))
	return "%d:%02d" % [t / 60, t % 60]


static func league_of(trophies: int) -> int:
	var out := 0
	for i in LEAGUES.size():
		if trophies >= int(LEAGUES[i]["from"]):
			out = i
	return out


static func league_name(i: int) -> String:
	return L.t("race.league." + str(LEAGUES[clampi(i, 0, LEAGUES.size() - 1)]["id"]))


static func level_of(xp: int) -> int:
	var lv := 1
	for i in LEVEL_XP.size():
		if xp >= int(LEVEL_XP[i]):
			lv = i + 1
	return mini(lv, MAX_LEVEL)


## Центр клетки сетки (точки).
static func cell_center(c: Vector2i) -> Vector2:
	return Vector2((c.x + 0.5) * TILE, (c.y + 0.5) * TILE)


static func cell_rect(c: Vector2i) -> Rect2:
	return Rect2(Vector2(c.x * TILE, c.y * TILE), Vector2(TILE, TILE))


static func cell_at(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(p.x / TILE), 0, 2), clampi(int(p.y / TILE), 0, 2))


static func heart_center() -> Vector2:
	return cell_center(CORE)


## Середина общей стороны двух соседних клеток.
static func edge_mid(a: Vector2i, b: Vector2i) -> Vector2:
	return (cell_center(a) + cell_center(b)) / 2.0


## Ворота места: [угол, перешеек] для ворот 1, [перешеек, ядро] для ворот 2.
static func gate_cells(seat: int, gate: int) -> Array:
	var c: Dictionary = CORNERS[seat]
	return [c["cell"], c["arm"]] if gate == 0 else [c["arm"], CORE]


## Где стоят ворота места (середина прохода). Ворота 3 - на краю Сердца со стороны перешейка.
static func gate_pos(seat: int, gate: int) -> Vector2:
	if gate < 2:
		var cells := gate_cells(seat, gate)
		return edge_mid(cells[0], cells[1])
	var arm: Vector2i = CORNERS[seat]["arm"]
	var dir := (cell_center(arm) - heart_center()).normalized()
	return heart_center() + dir * HEART_R


## Ворота вертикальные (проход слева направо), если клетки соседи по горизонтали.
static func gate_vertical(seat: int, gate: int) -> bool:
	if gate == 2:
		var arm: Vector2i = CORNERS[seat]["arm"]
		return arm.y == CORE.y
	var cells := gate_cells(seat, gate)
	return (cells[0] as Vector2i).y == (cells[1] as Vector2i).y


## Ресурс ворот с учётом еды своего угла.
static func gate_items(seat: int, gate: int) -> Array:
	var out: Array = []
	for it in GATES[gate]["items"]:
		out.append([FOOD[CORNERS[seat]["biome"]] if it[0] == "food" else it[0], int(it[1])])
	return out


## Раскладка точек добычи места: [{id, node, type, kind, pos}]. Одна и та же для всех мест с точностью до поворота,
## чтобы ни у кого не было короче пути.
static func spots(seat: int) -> Array:
	var out: Array = []
	var biome: String = CORNERS[seat]["biome"]
	var corner: Vector2i = CORNERS[seat]["cell"]
	var arm: Vector2i = CORNERS[seat]["arm"]
	var defs: Array = CORNER_NODES[biome]
	# Угол: по 6 точек каждого вида кольцом вокруг лагеря
	for i in 18:
		var d: Array = defs[i % 3]
		var a := TAU * float(i) / 18.0 + 0.2
		var r := 150.0 + 70.0 * float(i % 2) + 40.0 * float((i / 2) % 2)
		out.append({"id": "c%d" % i, "node": "corner", "type": d[0], "kind": d[1],
			"pos": _local(seat, corner, Vector2(cos(a), sin(a)) * r)})
	# Перешеек: уголь и железо, немного дерева и камня
	var arm_list := ["coal", "iron", "coal", "iron", "coal", "iron", "coal", "iron", "coal", "iron"]
	for i in arm_list.size():
		var x := -230.0 + 51.0 * float(i)
		var y := -120.0 if i % 2 == 0 else 120.0
		var n: Dictionary = NODES[arm_list[i]]
		out.append({"id": "a%d" % i, "node": arm_list[i], "type": n["type"], "kind": n["kind"],
			"pos": _local(seat, arm, Vector2(x, y + 30.0 * float((i / 2) % 2)))})
	for i in 4:
		var d: Array = defs[0] if i % 2 == 0 else defs[2]
		out.append({"id": "aw%d" % i, "node": "corner", "type": d[0], "kind": d[1],
			"pos": _local(seat, arm, Vector2(-180.0 + 120.0 * float(i), 0.0 if i % 2 == 0 else 10.0))})
	# Ядро: золото, алмазы и кристаллы кольцом вокруг Сердца (общее для всех, своё у каждого игрока)
	var core_list := ["gold", "diamond", "crystal"]
	for i in 18:
		var kind: String = core_list[i % 3]
		var a := TAU * float(i) / 18.0
		var r := 245.0 + 40.0 * float(i % 2)
		var n: Dictionary = NODES[kind]
		out.append({"id": "k%d" % i, "node": kind, "type": n["type"], "kind": n["kind"],
			"pos": heart_center() + Vector2(cos(a), sin(a)) * r})
	return out


## Жила Древних (осколок 1 в углу, 2 в перешейке).
static func vein_pos(seat: int, i: int) -> Vector2:
	var c: Dictionary = CORNERS[seat]
	return _local(seat, c["cell"], Vector2(-210, -210)) if i == 0 else _local(seat, c["arm"], Vector2(240, -200))


## Лагерь (место старта и торговец угла).
static func camp_pos(seat: int) -> Vector2:
	return _local(seat, CORNERS[seat]["cell"], Vector2(0, 0))


static func trader_pos(seat: int, zone: int) -> Vector2:
	match zone:
		0: return _local(seat, CORNERS[seat]["cell"], Vector2(70, 40))
		1: return _local(seat, CORNERS[seat]["arm"], Vector2(0, -230))
	return heart_center() + (cell_center(CORNERS[seat]["arm"]) - heart_center()).normalized() * 175.0 \
		+ (cell_center(CORNERS[seat]["arm"]) - heart_center()).normalized().orthogonal() * 120.0


static func elder_pos(seat: int) -> Vector2:
	return heart_center() + (cell_center(CORNERS[seat]["arm"]) - heart_center()).normalized().orthogonal() * -175.0 \
		+ (cell_center(CORNERS[seat]["arm"]) - heart_center()).normalized() * 120.0


## Точка внутри клетки в системе места: у всех мест раскладка повёрнута одинаково относительно пути к центру.
static func _local(seat: int, cell: Vector2i, off: Vector2) -> Vector2:
	return cell_center(cell) + off.rotated(PI / 2.0 * float(seat))
