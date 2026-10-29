class_name Res
## Ресурсы: группы, базовые цены, иконки. Идентификаторы - строки, как в iOS-версии и в сохранениях.

const CATEGORIES := ["wood", "stone", "ore", "gem", "food", "crop", "farm", "treasure", "loot"]

const KINDS := [
	"wood", "bamboo", "stone", "clay", "coal", "iron", "gold", "sulfur", "obsidian", "ice", "diamond", "crystal", "ruby",
	"berries", "apples", "mushrooms", "carrots", "herbs", "fish", "cactus", "coconut", "banana", "pineapple", "goldenApple",
	"egg", "milk", "wool", "honey", "feather",
	"shell", "coral", "pearl", "cloud", "stardust",
	"wheat", "tomato", "potato", "strawberry", "corn", "cabbage", "eggplant", "pumpkin", "sunflower", "chili", "grapes",
	"slime", "bone", "tusk", "essence",
]

const CATEGORY := {
	"wood": "wood", "bamboo": "wood",
	"stone": "stone", "clay": "stone", "ice": "stone",
	"coal": "ore", "iron": "ore", "gold": "ore", "sulfur": "ore", "obsidian": "ore",
	"diamond": "gem", "crystal": "gem", "ruby": "gem",
	"berries": "food", "apples": "food", "mushrooms": "food", "carrots": "food", "herbs": "food", "fish": "food",
	"cactus": "food", "coconut": "food", "banana": "food", "pineapple": "food", "goldenApple": "food",
	"egg": "farm", "milk": "farm", "wool": "farm", "honey": "farm", "feather": "farm",
	"shell": "treasure", "coral": "treasure", "pearl": "treasure", "cloud": "treasure", "stardust": "treasure",
	"wheat": "crop", "tomato": "crop", "potato": "crop", "strawberry": "crop", "corn": "crop", "cabbage": "crop",
	"eggplant": "crop", "pumpkin": "crop", "sunflower": "crop", "chili": "crop", "grapes": "crop",
	"slime": "loot", "bone": "loot", "tusk": "loot", "essence": "loot",
}

## Базовая цена продажи в монетах.
const PRICE := {
	"wood": 1, "bamboo": 3, "stone": 1, "clay": 3, "coal": 3, "iron": 6, "gold": 15, "sulfur": 20, "obsidian": 30,
	"ice": 8, "diamond": 60, "crystal": 120, "ruby": 150,
	"berries": 1, "apples": 2, "mushrooms": 2, "carrots": 2, "herbs": 3, "fish": 4, "cactus": 5, "coconut": 6,
	"banana": 8, "pineapple": 10, "goldenApple": 60,
	"egg": 4, "milk": 6, "wool": 8, "honey": 12, "feather": 5,
	"shell": 10, "coral": 25, "pearl": 90, "cloud": 40, "stardust": 220,
	"wheat": 3, "tomato": 7, "potato": 8, "strawberry": 10, "corn": 25, "cabbage": 45, "eggplant": 45,
	"pumpkin": 140, "sunflower": 130, "chili": 110, "grapes": 210,
	"slime": 6, "bone": 14, "tusk": 30, "essence": 120,
}

## Основной цвет для руды и самоцветов (вспышки, осколки).
const ORE_COLOR := {
	"coal": Color(0.13, 0.13, 0.16), "iron": Color(0.86, 0.52, 0.32), "gold": Color(1.0, 0.82, 0.18),
	"sulfur": Color(0.95, 0.92, 0.25), "obsidian": Color(0.3, 0.18, 0.45), "crystal": Color(0.72, 0.45, 1.0),
	"diamond": Color(0.45, 0.9, 1.0), "ruby": Color(0.95, 0.15, 0.3), "pearl": Color(0.96, 0.94, 0.98),
	"goldenApple": Color(1.0, 0.8, 0.2),
}


static func name_of(kind: String) -> String:
	return L.t("res." + kind)


static func category(kind: String) -> String:
	return CATEGORY.get(kind, "loot")


static func price(kind: String) -> int:
	return PRICE.get(kind, 1)


static func ore_color(kind: String) -> Color:
	return ORE_COLOR.get(kind, Color(0.6, 0.6, 0.6))


static func in_category(cat: String) -> Array:
	return KINDS.filter(func(k: String) -> bool: return category(k) == cat)


static func icon(kind: String) -> Texture2D:
	return Sprites.icon(kind)
