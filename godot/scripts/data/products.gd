class_name Products
## Встроенные покупки (порт ProductID из Premium.swift). В игре покупку зовут ключом (starter, pro, ...),
## в сохранении (purchases, granted) лежит идентификатор магазина, как в iOS.

const KEYS := ["starter", "pro", "skins", "garden", "tickets", "eventPass"]

## Идентификаторы магазина (rawValue ProductID).
const IDS := {
	"starter": "com.personal.gamefarm.starter",
	"pro": "com.personal.gamefarm.pro",
	"skins": "com.personal.gamefarm.skins",
	"garden": "com.personal.gamefarm.garden",
	"tickets": "com.personal.gamefarm.tickets5",
	"eventPass": "com.personal.gamefarm.eventpass",
}

## Цена до загрузки из магазина (и в тестовой сборке).
const PRICES := {
	"starter": "$1.99", "pro": "$4.99", "skins": "$2.99", "garden": "$3.99", "tickets": "$1.99", "eventPass": "$2.99",
}

## Цвет набора в магазине (Offers.tone).
const TONES := {
	"starter": "red", "pro": "purple", "garden": "orange", "skins": "green", "tickets": "blue", "eventPass": "gold",
}


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


## Расходуемая покупка: её можно купить снова.
static func consumable(product: String) -> bool:
	var k := key(product)
	return k == "tickets" or k == "eventPass"


static func title(product: String) -> String:
	return L.t("product." + key(product))


static func price(product: String) -> String:
	return str(PRICES.get(key(product), ""))


static func tone(product: String) -> String:
	return str(TONES.get(key(product), "orange"))
