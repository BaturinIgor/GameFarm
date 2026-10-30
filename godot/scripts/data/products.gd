class_name Products
## Встроенные покупки (порт ProductID из Premium.swift и новые наборы). В игре покупку зовут ключом
## (starter, pro, ...), в сохранении (purchases, granted) лежит идентификатор магазина, как в iOS.

const KEYS := [
	"starter", "pro", "skins", "garden", "tickets", "eventPass",
	"max",
	"crystals1", "crystals2", "crystals3", "crystals4", "crystals5",
	"traveler", "explorer", "master",
]

## Идентификаторы магазина (rawValue ProductID).
const IDS := {
	"starter": "com.personal.gamefarm.starter",
	"pro": "com.personal.gamefarm.pro",
	"skins": "com.personal.gamefarm.skins",
	"garden": "com.personal.gamefarm.garden",
	"tickets": "com.personal.gamefarm.tickets5",
	"eventPass": "com.personal.gamefarm.eventpass",
	"max": "com.personal.gamefarm.max.monthly",
	"crystals1": "com.personal.gamefarm.crystals80",
	"crystals2": "com.personal.gamefarm.crystals450",
	"crystals3": "com.personal.gamefarm.crystals1000",
	"crystals4": "com.personal.gamefarm.crystals2200",
	"crystals5": "com.personal.gamefarm.crystals6000",
	"traveler": "com.personal.gamefarm.traveler",
	"explorer": "com.personal.gamefarm.explorer",
	"master": "com.personal.gamefarm.master",
}

## Цена до загрузки из магазина (и в тестовой сборке).
const PRICES := {
	"starter": "$1.99", "pro": "$4.99", "skins": "$2.99", "garden": "$3.99", "tickets": "$1.99", "eventPass": "$2.99",
	"max": "$7.99",
	"crystals1": "$0.99", "crystals2": "$4.99", "crystals3": "$9.99", "crystals4": "$19.99", "crystals5": "$49.99",
	"traveler": "$2.99", "explorer": "$4.99", "master": "$9.99",
}

## Цвет набора в магазине (Offers.tone).
const TONES := {
	"starter": "red", "pro": "purple", "garden": "orange", "skins": "green", "tickets": "blue", "eventPass": "gold",
	"max": "gold",
	"crystals1": "purple", "crystals2": "purple", "crystals3": "purple", "crystals4": "purple", "crystals5": "purple",
	"traveler": "blue", "explorer": "green", "master": "red",
}

## Пачки кристаллов: сколько кристаллов и сколько процентов сверху по сравнению с самой маленькой.
## Первая покупка каждой пачки - вдвое больше.
const CRYSTAL_PACKS := {
	"crystals1": {"n": 80, "bonus": 0},
	"crystals2": {"n": 450, "bonus": 10},
	"crystals3": {"n": 1000, "bonus": 25},
	"crystals4": {"n": 2200, "bonus": 35},
	"crystals5": {"n": 6000, "bonus": 50},
}

## Наборы по уровню: открываются на 48 часов, когда герой доходит до уровня. Покупаются один раз.
## Монеты растут с уровнем героя на момент покупки не нужно: набор сразу считается по своему уровню.
const LEVEL_BUNDLES := {
	"traveler": {"level": 10, "crystals": 250, "coins": 5000, "tickets": 5, "maps": 0, "skin": false},
	"explorer": {"level": 20, "crystals": 500, "coins": 20000, "tickets": 10, "maps": 3, "skin": false},
	"master": {"level": 30, "crystals": 1000, "coins": 60000, "tickets": 10, "maps": 5, "skin": true},
}

## Сколько дней даёт одна покупка подписки MAX.
const MAX_DAYS := 30


## Ключ покупки по ключу или идентификатору магазина ("" - неизвестная покупка).
static func key(product: String) -> String:
	if product in KEYS:
		return product
	for k in IDS:
		if IDS[k] == product:
			return k
	return ""


## Идентификатор магазина по ключу (или уже идентификатор).
static func id(product: String) -> String:
	var k := key(product)
	return IDS[k] if k != "" else product


## Расходуемая покупка: её можно купить снова (билеты, пропуск, кристаллы, продление MAX).
static func consumable(product: String) -> bool:
	var k := key(product)
	return k == "tickets" or k == "eventPass" or k == "max" or k in CRYSTAL_PACKS


static func is_crystals(product: String) -> bool:
	return key(product) in CRYSTAL_PACKS


static func is_level_bundle(product: String) -> bool:
	return key(product) in LEVEL_BUNDLES


static func title(product: String) -> String:
	var k := key(product)
	if k in CRYSTAL_PACKS:
		return L.t("crystals.pack", [Fmt.n(int(CRYSTAL_PACKS[k]["n"]))])
	return L.t("product." + k)


static func price(product: String) -> String:
	return str(PRICES.get(key(product), ""))


static func tone(product: String) -> String:
	return str(TONES.get(key(product), "orange"))
