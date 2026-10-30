class_name House
## Дом: этажи, станции, украшения, кухня и блюда, календарь наград за вход (порт House.swift).

# MARK: Этажи

## Этажи сверху вниз (HouseFloor.allCases). Первый есть сразу, остальные строятся.
const FLOORS := ["greenhouse", "attic", "upper", "ground", "basement"]

const FLOOR_LEVEL := {"ground": 1, "upper": 8, "basement": 14, "attic": 22, "greenhouse": 30}

const FLOOR_COST := {
	"ground": {"coins": 0, "items": []},
	"upper": {"coins": 1500, "items": [["wood", 60], ["stone", 40]]},
	"basement": {"coins": 4000, "items": [["stone", 120], ["iron", 30]]},
	"attic": {"coins": 10000, "items": [["wood", 200], ["gold", 15]]},
	"greenhouse": {"coins": 25000, "items": [["ice", 60], ["crystal", 10], ["pumpkin", 10]]},
}

## Локация этажа, по которой ходит герой.
const FLOOR_LOCATION := {
	"ground": "homeGround", "upper": "homeUpper", "basement": "homeBasement",
	"attic": "homeAttic", "greenhouse": "homeGreenhouse",
}

## Куда ведут лестницы.
const FLOOR_UP := {"basement": "ground", "ground": "upper", "upper": "attic", "attic": "greenhouse"}
const FLOOR_DOWN := {"ground": "basement", "upper": "ground", "attic": "upper", "greenhouse": "attic"}


static func floor_title(f: String) -> String:
	return L.t("house.floor." + f)


static func floor_room(f: String) -> String:
	return L.t("house.room." + f)


static func floor_perk(f: String) -> String:
	return L.t("house.perk." + f)


static func floor_level(f: String) -> int:
	return int(FLOOR_LEVEL.get(f, 1))


static func floor_cost(f: String) -> Dictionary:
	return FLOOR_COST.get(f, {"coins": 0, "items": []})


static func floor_location(f: String) -> String:
	return str(FLOOR_LOCATION.get(f, "homeGround"))


## Этаж по локации ("" - не дом).
static func floor_of(location: String) -> String:
	for f in FLOOR_LOCATION:
		if FLOOR_LOCATION[f] == location:
			return f
	return ""


static func floor_up(f: String) -> String:
	return str(FLOOR_UP.get(f, ""))


static func floor_down(f: String) -> String:
	return str(FLOOR_DOWN.get(f, ""))


## Места для украшений на этаже: по три в каждой комнате.
static func slots(f: String) -> Array:
	var out: Array = []
	for i in 6:
		out.append("%s_%d" % [f, i])
	return out


# MARK: Станции

## Пиксельная иконка станции для карточки (ic_<имя>).
const STATION_ICON := {
	"exit": "door", "up": "stairs", "down": "stairs", "trophies": "trophy", "plan": "plan", "stove": "stove",
	"calendar": "calendar", "bed": "bed", "wardrobe": "wardrobe", "desk": "book", "lectern": "spark",
	"pantry": "chest", "workbench": "hammer", "anvil": "hammer", "telescope": "telescope", "chest": "ticket",
	"map": "map", "compost": "compost", "seedlings": "seed_wheat",
}

## Какое окно открывает станция (id окна: файл scripts/ui/<id>_panel.gd).
const STATION_WINDOW := {
	"stove": "kitchen", "calendar": "calendar", "trophies": "trophies", "plan": "house", "wardrobe": "wardrobe",
	"desk": "talents", "lectern": "legacy", "pantry": "storage", "workbench": "workshop", "anvil": "workshop",
	"telescope": "collection", "map": "map", "compost": "garden", "seedlings": "trader",
}


## Переход между этажами или выход: срабатывает, когда герой подходит вплотную.
static func is_passage(kind: String) -> bool:
	return kind == "exit" or kind == "up" or kind == "down"


static func station_title(kind: String) -> String:
	return L.t("home." + kind)


static func station_hint(kind: String) -> String:
	return L.t("home." + kind + ".hint")


static func station_icon(kind: String) -> String:
	return str(STATION_ICON.get(kind, "plan"))


# MARK: Кухня

## Кухня прокачивается: больше плит, готовка быстрее, больше блюд сразу.
const KITCHEN_MAX := 5


static func kitchen_slots(level: int) -> int:
	return maxi(1, mini(KITCHEN_MAX, level))


## Множитель времени готовки.
static func kitchen_speed(level: int) -> float:
	return 1.0 - 0.08 * float(maxi(1, level) - 1)


static func kitchen_meal_slots(level: int) -> int:
	return 3 + (1 if level >= 3 else 0) + (1 if level >= 5 else 0)


static func kitchen_required_level(next: int) -> int:
	match next:
		2: return 6
		3: return 14
		4: return 24
	return 34


static func kitchen_cost(next: int) -> Dictionary:
	match next:
		2: return {"coins": 800, "items": [["wood", 80], ["stone", 40]]}
		3: return {"coins": 3000, "items": [["iron", 40], ["clay", 30]]}
		4: return {"coins": 9000, "items": [["gold", 30], ["ice", 30]]}
	return {"coins": 25000, "items": [["diamond", 10], ["crystal", 10]]}


# MARK: Украшения

## Украшения дают уют, а уют прибавляет добычу и опыт (порядок DecorID.allCases).
const DECOR := [
	"potGreen", "potRed", "potBlue", "lantern", "clock", "painting", "stool", "table", "bench", "rug", "bookshelf",
	"barrel", "anvil", "hay", "plantPink", "plantFern", "plantLush", "redStool", "roundTable", "greenRug", "sofa",
	"displayCase", "cupboard", "bathtub",
	# Награды ивентов
	"jackLantern", "slimeLamp", "snowman", "sandcastle",
]

const DECOR_SPRITE := {
	"potGreen": "pot_green", "potRed": "pot_red", "potBlue": "pot_blue", "table": "table_small",
	"barrel": "barrel_berries", "hay": "hay_big", "jackLantern": "jack_lantern", "slimeLamp": "slime_lamp",
	"plantPink": "hm_plant_pink", "plantFern": "hm_plant_fern", "plantLush": "hm_plant_big", "redStool": "hm_stool_red",
	"roundTable": "hm_table_round", "greenRug": "hm_rug_green", "sofa": "hm_sofa", "displayCase": "hm_display",
	"cupboard": "hm_cupboard", "bathtub": "hm_bath",
}

const DECOR_COMFORT := {
	"potGreen": 1, "potRed": 1, "potBlue": 1, "stool": 1, "hay": 1, "redStool": 1,
	"lantern": 2, "clock": 2, "barrel": 2, "table": 2, "plantPink": 2, "plantFern": 2,
	"painting": 3, "bench": 3, "anvil": 3, "plantLush": 3, "roundTable": 3,
	"rug": 4, "bookshelf": 4, "greenRug": 4, "cupboard": 4,
	"sofa": 6, "displayCase": 6,
	"bathtub": 8,
	"jackLantern": 5, "slimeLamp": 5, "snowman": 5, "sandcastle": 5,
}

const DECOR_COST := {
	"potGreen": {"coins": 120, "items": [["berries", 10]]},
	"potRed": {"coins": 150, "items": [["berries", 15]]},
	"potBlue": {"coins": 180, "items": [["berries", 20]]},
	"stool": {"coins": 100, "items": [["wood", 15]]},
	"hay": {"coins": 120, "items": [["wheat", 10]]},
	"lantern": {"coins": 400, "items": [["iron", 5]]},
	"clock": {"coins": 500, "items": [["wood", 20], ["iron", 4]]},
	"barrel": {"coins": 350, "items": [["wood", 30]]},
	"table": {"coins": 450, "items": [["wood", 40]]},
	"painting": {"coins": 1200, "items": [["wood", 20], ["gold", 2]]},
	"bench": {"coins": 1000, "items": [["wood", 60]]},
	"anvil": {"coins": 1500, "items": [["iron", 20]]},
	"rug": {"coins": 2500, "items": [["wool", 15]]},
	"bookshelf": {"coins": 3000, "items": [["wood", 120]]},
	"redStool": {"coins": 150, "items": [["wood", 10]]},
	"plantPink": {"coins": 400, "items": [["berries", 20], ["clay", 4]]},
	"plantFern": {"coins": 450, "items": [["herbs", 10], ["clay", 4]]},
	"plantLush": {"coins": 1100, "items": [["herbs", 20], ["clay", 10]]},
	"roundTable": {"coins": 1200, "items": [["wood", 80]]},
	"greenRug": {"coins": 2800, "items": [["wool", 20], ["herbs", 10]]},
	"cupboard": {"coins": 3500, "items": [["wood", 150], ["iron", 10]]},
	"sofa": {"coins": 6000, "items": [["wool", 40], ["wood", 100]]},
	"displayCase": {"coins": 9000, "items": [["ice", 30], ["gold", 10]]},
	"bathtub": {"coins": 15000, "items": [["iron", 80], ["pearl", 3]]},
}

## Ивент, за который выдаётся украшение (его нельзя купить).
const DECOR_EVENT := {
	"jackLantern": "harvestFest", "slimeLamp": "slimeNight", "snowman": "winterTale", "sandcastle": "beachParty",
}


static func decor_name(id: String) -> String:
	return L.t("decor." + id)


static func decor_sprite(id: String) -> String:
	return str(DECOR_SPRITE.get(id, id))


static func decor_comfort(id: String) -> int:
	return int(DECOR_COMFORT.get(id, 0))


static func decor_cost(id: String) -> Dictionary:
	return DECOR_COST.get(id, {"coins": 0, "items": []})


## Ивент украшения ("" - обычное, продаётся).
static func decor_event(id: String) -> String:
	return str(DECOR_EVENT.get(id, ""))


## Уют: +1% к добыче и опыту за очко, не больше 30%.
static func comfort_bonus(points: int) -> float:
	return minf(0.3, float(points) * 0.01)


# MARK: Блюда

const DISHES := ["bread", "omelette", "salad", "soup", "pancakes", "pie", "pumpkinSoup", "popcorn", "stew", "juice"]

const DISH_INGREDIENTS := {
	"bread": [["wheat", 3]],
	"omelette": [["egg", 2], ["milk", 1]],
	"salad": [["tomato", 2], ["cabbage", 1]],
	"soup": [["carrots", 3], ["potato", 2]],
	"pancakes": [["wheat", 2], ["egg", 1], ["milk", 1], ["honey", 1]],
	"pie": [["strawberry", 3], ["wheat", 2], ["egg", 1]],
	"pumpkinSoup": [["pumpkin", 1], ["milk", 2]],
	"popcorn": [["corn", 3]],
	"stew": [["chili", 2], ["eggplant", 2], ["potato", 2]],
	"juice": [["grapes", 3]],
}

## Время готовки в секундах.
const DISH_COOK_TIME := {
	"bread": 20.0, "omelette": 20.0, "salad": 30.0, "soup": 40.0, "pancakes": 40.0, "popcorn": 45.0,
	"pie": 60.0, "pumpkinSoup": 60.0, "juice": 60.0, "stew": 75.0,
}

## Сколько действует, в секундах.
const DISH_DURATION := {
	"bread": 600.0, "omelette": 600.0, "salad": 600.0,
	"soup": 900.0, "pancakes": 900.0, "pie": 900.0, "popcorn": 900.0,
	"pumpkinSoup": 1200.0, "stew": 1200.0, "juice": 1200.0,
}

## Что даёт блюдо, пока действует (MealBuff).
const DISH_BUFF := {
	"bread": {"xp": 0.15},
	"omelette": {"speed": 0.15},
	"salad": {"yield": 0.15},
	"soup": {"yield": 0.2},
	"pancakes": {"xp": 0.25},
	"pie": {"sell": 0.2},
	"pumpkinSoup": {"yield": 0.3},
	"popcorn": {"crit": 0.1},
	"stew": {"animals": 0.25},
	"juice": {"yield": 0.15, "xp": 0.15},
}

const BUFF_KEYS := ["yield", "xp", "speed", "sell", "crit", "animals"]


static func dish_name(dish: String) -> String:
	return L.t("dish." + dish)


static func dish_icon(dish: String) -> String:
	return "dish_" + dish


static func dish_cost(dish: String) -> Dictionary:
	return {"coins": 0, "items": DISH_INGREDIENTS.get(dish, [])}


static func dish_cook_time(dish: String) -> float:
	return float(DISH_COOK_TIME.get(dish, 20.0))


static func dish_duration(dish: String) -> float:
	return float(DISH_DURATION.get(dish, 600.0))


## Полный MealBuff: все ключи, нули там, где блюдо ничего не даёт.
static func dish_buff(dish: String) -> Dictionary:
	var b: Dictionary = DISH_BUFF.get(dish, {})
	var out := {}
	for k in BUFF_KEYS:
		out[k] = float(b.get(k, 0.0))
	return out


## Описание эффекта для списка рецептов.
static func effect_text(dish: String) -> String:
	var b := dish_buff(dish)
	var parts: Array[String] = []
	for k in BUFF_KEYS:
		if float(b[k]) > 0.0:
			parts.append(L.t("meal." + k, [Fmt.pct(float(b[k]))]))
	return ", ".join(parts)


# MARK: Календарь наград за вход

const LOGIN_DAYS := 7
## Культуры и уровень, с которого они сажаются (CropID.allCases и CropSpec.level): лучшие семена в награду.
const CROP_LEVELS := [
	["wheat", 1], ["carrot", 2], ["tomato", 4], ["potato", 6], ["strawberry", 8], ["corn", 11], ["cabbage", 14],
	["eggplant", 17], ["pumpkin", 20], ["sunflower", 24], ["chili", 28], ["grapes", 33],
]
const LOGIN_DISHES := ["bread", "omelette", "salad", "soup"]


## Награда за заход номер claim (с нуля). Неделя повторяется, а монет становится больше с уровнем.
## {"type": coins|seeds|tickets|coinsAndWood|dish|resource|chest, ...}
static func login_reward(claim: int, level: int) -> Dictionary:
	var m := 1.0 + float(level) / 10.0
	var best := "wheat"
	for c in CROP_LEVELS:
		if int(c[1]) <= level:
			best = c[0]
	match claim % LOGIN_DAYS:
		0: return {"type": "coins", "coins": int(round(150.0 * m))}
		1: return {"type": "seeds", "crop": best, "n": 4}
		2: return {"type": "tickets", "n": 1}
		3: return {"type": "coinsAndWood", "coins": int(round(400.0 * m)), "wood": 30}
		4: return {"type": "dish", "dish": LOGIN_DISHES[(claim / LOGIN_DAYS) % LOGIN_DISHES.size()]}
		5: return {"type": "resource", "kind": "iron" if level >= 12 else "stone", "n": 20}
	return {"type": "chest", "tickets": 2, "coins": int(round(800.0 * m)), "crystals": 20}


# MARK: Время

## Обратный отсчёт: "м:сс" или "ч:мм:сс" (Countdown.text).
static func countdown(seconds: float) -> String:
	var s := maxi(0, int(seconds))
	var h := s / 3600
	var m := (s % 3600) / 60
	var sec := s % 60
	if h > 0:
		return "%d:%02d:%02d" % [h, m, sec]
	return "%d:%02d" % [m, sec]


## Начало сегодняшнего дня по местному времени (unix-секунды).
static func start_of_day() -> float:
	var now := floorf(Time.get_unix_time_from_system())
	var t := Time.get_time_dict_from_system()
	return now - float(int(t["hour"]) * 3600 + int(t["minute"]) * 60 + int(t["second"]))
