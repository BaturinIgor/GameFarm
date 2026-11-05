class_name Chests
## Сундуки за ключи и общая шкала редкости (документ "Новые механики и сюжет").
## Редкость: 7 цветов по 1-3 звезды. Цвет решает, что выпадет, звёзды - сколько.
## Три сундука, у каждого свой ключ и гарант: если долго не везёт, следующий сундук даёт редкость не ниже гарантии.

const RARITIES := ["gray", "green", "blue", "purple", "gold", "red", "rainbow"]
## Цвет рамки (у радуги - первый цвет перелива, см. rainbow_color).
const COLORS := {
	"gray": Color("a7a39c"), "green": Color("5fc24a"), "blue": Color("3f9be6"), "purple": Color("a35bf0"),
	"gold": Color("f5c02e"), "red": Color("e8432f"), "rainbow": Color("ff6ad5"),
}
## Сколько раз сундук трясётся перед открытием: чем реже находка, тем дольше ожидание.
const SHAKES := {"gray": 1, "green": 1, "blue": 2, "purple": 2, "gold": 3, "red": 4, "rainbow": 5}
## Звёзды внутри цвета: вес выпадения и множитель награды.
const STAR_WEIGHTS := [70, 25, 5]
const STAR_MULT := [1.0, 1.6, 2.5]
## Ценность награды по редкости (множитель к базе от уровня).
const VALUE := {"gray": 1.0, "green": 2.0, "blue": 4.0, "purple": 8.0, "gold": 16.0, "red": 40.0, "rainbow": 100.0}

const IDS := ["wood", "silver", "ancient"]
## key - ключ, odds - шансы в процентах (сумма 100), pity - через сколько сундуков гарантия и какая,
## price - цена ключа в кристаллах, icon - значок сундука.
const SPECS := {
	"wood": {"key": "copper", "icon": "chest", "price": 20, "pity": 10, "pity_rarity": "blue",
		"odds": {"gray": 55.0, "green": 28.0, "blue": 12.0, "purple": 4.0, "gold": 0.9, "red": 0.09, "rainbow": 0.01}},
	"silver": {"key": "silver", "icon": "chest", "price": 80, "pity": 30, "pity_rarity": "gold",
		"odds": {"gray": 25.0, "green": 30.0, "blue": 25.0, "purple": 13.5, "gold": 5.0, "red": 1.3, "rainbow": 0.2}},
	"ancient": {"key": "star", "icon": "chest_gold", "price": 250, "pity": 50, "pity_rarity": "red",
		"odds": {"gray": 0.0, "green": 20.0, "blue": 35.0, "purple": 25.0, "gold": 14.0, "red": 5.0, "rainbow": 1.0}},
}
## Оттенок сундука и ключа на иконке (деревянный - без оттенка).
const TINT := {"wood": Color.WHITE, "silver": Color(0.72, 0.8, 1.0), "ancient": Color.WHITE}
const KEY_TINT := {"copper": Color(1.0, 0.72, 0.5), "silver": Color(0.85, 0.9, 1.0), "star": Color(1.0, 0.95, 0.55)}
const KEYS := ["copper", "silver", "star"]

## Какие награды бывают у каждого цвета.
const POOLS := {
	"gray": ["coins", "goods"],
	"green": ["coins", "goods", "energy"],
	"blue": ["goods", "crystals", "card", "energy", "egg"],
	"purple": ["goods", "crystals", "card", "egg"],
	"gold": ["crystals", "card", "ticket", "egg"],
	"red": ["crystals", "card", "egg", "shard"],
	"rainbow": ["skin", "shard"],
}
## Кристаллы по цвету.
const CRYSTALS := {"blue": 3, "purple": 6, "gold": 15, "red": 40, "rainbow": 100}
## Товары по цвету: простые доски и мука, дальше кирпич и слитки, у золота - самоцветы.
const GOODS := {
	"gray": ["planks", "slats", "flour"],
	"green": ["planks", "slats", "flour", "brick"],
	"blue": ["brick", "lime", "iron_bar", "cloth"],
	"purple": ["iron_bar", "cloth", "oil", "gold_bar"],
}


static func spec(id: String) -> Dictionary:
	return SPECS.get(id, SPECS["wood"])


static func key_of(chest: String) -> String:
	return str(spec(chest)["key"])


static func name_of(chest: String) -> String:
	return L.t("chest." + chest)


static func key_name(key: String) -> String:
	return L.t("chest.key." + key)


static func rarity_name(r: String) -> String:
	return L.t("rarity." + r)


static func rarity_index(r: String) -> int:
	return RARITIES.find(r)


## Цвет редкости; у радуги он переливается со временем t (секунды).
static func color(r: String, t := 0.0) -> Color:
	if r == "rainbow":
		return rainbow_color(t)
	return COLORS.get(r, COLORS["gray"])


static func rainbow_color(t: float) -> Color:
	return Color.from_hsv(fposmod(t * 0.35, 1.0), 0.6, 1.0)


## Случайная редкость по шансам сундука. at_least - не ниже этой (гарантия).
static func roll_rarity(chest: String, at_least := "") -> String:
	var odds: Dictionary = spec(chest)["odds"]
	var low := maxi(0, rarity_index(at_least))
	var total := 0.0
	for r in RARITIES:
		if rarity_index(r) >= low:
			total += float(odds.get(r, 0.0))
	var roll := randf() * total
	for r in RARITIES:
		if rarity_index(r) < low:
			continue
		roll -= float(odds.get(r, 0.0))
		if roll <= 0.0:
			return r
	return RARITIES[RARITIES.size() - 1]


static func roll_stars() -> int:
	var total := 0
	for w in STAR_WEIGHTS:
		total += int(w)
	var roll := randi() % total
	for i in STAR_WEIGHTS.size():
		roll -= int(STAR_WEIGHTS[i])
		if roll < 0:
			return i + 1
	return 1


## База ценности в монетах от уровня (как сундук целей дня).
static func base_value(level: int) -> float:
	return 100.0 + float(level * level) * 4.0
