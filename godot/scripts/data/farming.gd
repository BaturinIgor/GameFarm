class_name Farming
## Огород: культуры, грядки, удобрения, лейка, лавка и бродячий торговец (порт Farming.swift).

## Культуры по порядку (CropID.allCases). Семена покупаются в лавке, растут по реальному времени.
const CROP_IDS := ["wheat", "carrot", "tomato", "potato", "strawberry", "corn", "cabbage", "eggplant",
	"pumpkin", "sunflower", "chili", "grapes"]

## Уровень, цена семян, время роста (с), урожай, что даёт, опыт.
const CROPS := {
	"wheat": {"level": 1, "seed_price": 4, "grow_time": 60.0, "yield": 3, "produce": "wheat", "xp": 4},
	"carrot": {"level": 2, "seed_price": 6, "grow_time": 120.0, "yield": 8, "produce": "carrots", "xp": 6},
	"tomato": {"level": 4, "seed_price": 10, "grow_time": 180.0, "yield": 4, "produce": "tomato", "xp": 8},
	"potato": {"level": 6, "seed_price": 14, "grow_time": 300.0, "yield": 5, "produce": "potato", "xp": 12},
	"strawberry": {"level": 8, "seed_price": 20, "grow_time": 480.0, "yield": 6, "produce": "strawberry", "xp": 18},
	"corn": {"level": 11, "seed_price": 30, "grow_time": 720.0, "yield": 4, "produce": "corn", "xp": 26},
	"cabbage": {"level": 14, "seed_price": 40, "grow_time": 900.0, "yield": 3, "produce": "cabbage", "xp": 32},
	"eggplant": {"level": 17, "seed_price": 55, "grow_time": 1200.0, "yield": 4, "produce": "eggplant", "xp": 42},
	"pumpkin": {"level": 20, "seed_price": 70, "grow_time": 1800.0, "yield": 2, "produce": "pumpkin", "xp": 60},
	"sunflower": {"level": 24, "seed_price": 90, "grow_time": 2700.0, "yield": 3, "produce": "sunflower", "xp": 85},
	"chili": {"level": 28, "seed_price": 120, "grow_time": 3600.0, "yield": 5, "produce": "chili", "xp": 110},
	"grapes": {"level": 33, "seed_price": 160, "grow_time": 5400.0, "yield": 4, "produce": "grapes", "xp": 160},
}

## Удобрения по порядку (FertilizerID.allCases).
const FERTILIZER_IDS := ["compost", "superGrow", "magic"]

## cut - какая доля оставшегося времени роста пропадает, extra - сколько урожая сверху.
const FERTILIZERS := {
	"compost": {"icon": "fert_compost", "cut": 0.4, "extra": 0, "level": 3,
		"recipe": {"coins": 10, "items": [["berries", 6], ["wood", 6], ["wheat", 3]]}},
	"superGrow": {"icon": "fert_super", "cut": 0.7, "extra": 1, "level": 10,
		"recipe": {"coins": 60, "items": [["fish", 5], ["mushrooms", 6], ["carrots", 6]]}},
	"magic": {"icon": "fert_magic", "cut": 0.85, "extra": 2, "level": 22,
		"recipe": {"coins": 400, "items": [["herbs", 10], ["honey", 3], ["crystal", 1]]}},
}

## Лейка: чем лучше, тем сильнее полив; с 3 уровня поливает весь огород сразу.
const CAN_MAX_LEVEL := 5
## Больше этой доли оставшегося времени полив не срезает.
const CAN_MAX_CUT := 0.75

## Грядки открываются с уровнем: 4 сразу и ещё по одной каждые 4 уровня.
const MAX_BEDS := 12
## Оранжерея: растения растут на 20% быстрее.
const GREENHOUSE_SPEED := 0.8
## С какого уровня строится оранжерея (HouseFloor.greenhouse.level).
const GREENHOUSE_LEVEL := 30

## Бродячий торговец: сколько секунд стоит в локации и какие редкие ресурсы продаёт.
const WANDERER_STAY := 180.0
const WANDERER_RARE := ["crystal", "ruby", "diamond", "pearl", "coral", "honey", "goldenApple", "obsidian"]


# MARK: Культуры

static func spec(crop: String) -> Dictionary:
	return CROPS.get(crop, CROPS["wheat"])


static func is_crop(crop: String) -> bool:
	return CROPS.has(crop)


static func name_of(crop: String) -> String:
	return Res.name_of(spec(crop)["produce"])


## Пиксельные спрайты: crop_<имя>_0...3 и иконка семян ic_seed_<имя>.
static func sprite(crop: String) -> String:
	return "crop_" + crop


static func seed_icon(crop: String) -> String:
	return "seed_" + crop


# MARK: Грядка
# Грядка в сохранении - словарь как Bed в Swift: crop, plantedAt (unix-секунды), boost (сколько секунд роста
# сэкономили полив и удобрения), watered, speed (множитель времени роста при посадке), fertilized, extra.

static func empty_bed() -> Dictionary:
	return {"boost": 0.0, "watered": false}


static func is_empty(bed: Dictionary) -> bool:
	return not CROPS.has(str(bed.get("crop", "")))


## Полное время роста с учётом оранжереи и полива.
static func grow_time(bed: Dictionary) -> float:
	if is_empty(bed):
		return 0.0
	return maxf(0.0, float(spec(bed["crop"])["grow_time"]) * float(bed.get("speed", 1.0)) - float(bed.get("boost", 0.0)))


## Когда созреет (unix-секунды) или -1, если ничего не растёт.
static func ready_at(bed: Dictionary) -> float:
	if is_empty(bed) or not bed.has("plantedAt"):
		return -1.0
	return float(bed["plantedAt"]) + grow_time(bed)


## Доля роста от 0 до 1.
static func progress(bed: Dictionary, now: float) -> float:
	if is_empty(bed) or not bed.has("plantedAt"):
		return 0.0
	return minf(1.0, maxf(0.0, (now - float(bed["plantedAt"])) / maxf(1.0, grow_time(bed))))


static func is_ripe(bed: Dictionary, now: float) -> bool:
	return not is_empty(bed) and progress(bed, now) >= 1.0


## Стадия спрайта: 0 росток ... 3 спелое.
static func stage(bed: Dictionary, now: float) -> int:
	var p := progress(bed, now)
	if p >= 1.0:
		return 3
	return mini(2, int(p * 3.0))


# MARK: Удобрения

static func fert_name(id: String) -> String:
	return L.t("fert." + id)


static func fert_icon(id: String) -> String:
	return FERTILIZERS[id]["icon"]


static func fert_effect_text(id: String) -> String:
	var f: Dictionary = FERTILIZERS[id]
	if int(f["extra"]) > 0:
		return L.t("fert.effect.extra", [Fmt.pct(f["cut"]), f["extra"]])
	return L.t("fert.effect", [Fmt.pct(f["cut"])])


# MARK: Лейка

static func can_boost(level: int) -> float:
	return 0.2 + 0.075 * float(maxi(1, mini(CAN_MAX_LEVEL, level)) - 1)


static func can_waters_all(level: int) -> bool:
	return level >= 3


static func can_required_level(next: int) -> int:
	match next:
		2: return 5
		3: return 12
		4: return 20
	return 28


static func can_cost(next: int) -> Dictionary:
	match next:
		2: return {"coins": 300, "items": [["iron", 10]]}
		3: return {"coins": 1500, "items": [["iron", 30], ["bamboo", 20]]}
		4: return {"coins": 5000, "items": [["gold", 20], ["ice", 20]]}
	return {"coins": 15000, "items": [["diamond", 6], ["crystal", 4]]}


# MARK: Грядки

static func beds_at(level: int) -> int:
	return mini(MAX_BEDS, 4 + level / 4)


## Уровень, на котором откроется грядка с номером index (с нуля).
static func level_for_bed(index: int) -> int:
	return maxi(1, (index - 3) * 4)


## Cost.scaled: монеты и ресурсы умножаются с округлением вверх.
static func scaled(cost: Dictionary, factor: float) -> Dictionary:
	var items: Array = []
	for it in cost.get("items", []):
		items.append([it[0], maxi(1, int(ceil(float(it[1]) * factor)))])
	return {"coins": int(ceil(float(cost.get("coins", 0)) * factor)), "items": items}


# MARK: Торговцы

## Карта сокровищ у бродячего торговца (TreasureMaps.wandererPrice).
static func wanderer_map_price(level: int) -> int:
	return 1500 + 120 * level


## Детерминированный генератор (xorshift64 как DayRandom в Swift), чтобы обмены дня были одинаковыми весь день.
## 64-битное беззнаковое состояние хранится двумя половинами по 32 бита: сдвиг отрицательных чисел
## в GDScript - ошибка, а переполнение при умножении лучше не допускать.
class DayRandom:
	const MASK := 0xFFFFFFFF
	const TWO32 := 4294967296

	var hi := 0
	var lo := 0

	func _init(value: int) -> void:
		# UInt64(truncatingIfNeeded: seed) &* 0x9E3779B97F4A7C15 &+ 0x2545F4914F6CDD1D
		lo = value & MASK
		hi = ((value - lo) / TWO32) & MASK
		_mul(0x9E3779B9, 0x7F4A7C15)
		_add(0x2545F491, 0x4F6CDD1D)

	## Следующее состояние (next() в Swift).
	func advance() -> void:
		_xor_shl(13)
		_xor_shr(7)
		_xor_shl(17)

	## next() % n
	func next_mod(n: int) -> int:
		advance()
		return ((hi % n) * (TWO32 % n) + lo % n) % n

	## Число от low до high включительно.
	func int_in(low: int, high: int) -> int:
		return low + next_mod(high - low + 1)

	func pick(items: Array) -> Variant:
		return items[next_mod(items.size())]

	# Умножение на 64-битное число по модулю 2^64 через 16-битные части.
	func _mul(bh: int, bl: int) -> void:
		var a0 := lo & 0xFFFF
		var a1 := lo >> 16
		var b0 := bl & 0xFFFF
		var b1 := bl >> 16
		var mid := a1 * b0 + a0 * b1
		var low := a0 * b0 + ((mid & 0xFFFF) << 16)
		var high := a1 * b1 + (mid >> 16) + (low >> 32) + _mul32(hi, bl) + _mul32(lo, bh)
		hi = high & MASK
		lo = low & MASK

	func _add(bh: int, bl: int) -> void:
		var l := lo + bl
		hi = (hi + bh + (l >> 32)) & MASK
		lo = l & MASK

	func _xor_shl(n: int) -> void:
		var nh := ((hi << n) | (lo >> (32 - n))) & MASK
		var nl := (lo << n) & MASK
		hi ^= nh
		lo ^= nl

	func _xor_shr(n: int) -> void:
		var nl := ((lo >> n) | (hi << (32 - n))) & MASK
		var nh := hi >> n
		hi ^= nh
		lo ^= nl

	## x * y по модулю 2^32 (x, y < 2^32).
	static func _mul32(x: int, y: int) -> int:
		var x0 := x & 0xFFFF
		var x1 := x >> 16
		var y0 := y & 0xFFFF
		var y1 := y >> 16
		return (x0 * y0 + (((x1 * y0 + x0 * y1) & 0xFFFF) << 16)) & MASK
