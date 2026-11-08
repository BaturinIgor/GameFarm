class_name Hall
## Ратуша и живой чат альянса: правила и награды. Сервер - docs/supabase/alliance_hall.sql (числа совпадают).

## Реакции на сообщения: id -> пиксельный значок.
const REACTS := ["heart", "fist", "star", "clover", "flame"]
## Стикеры: сообщение "::значок" рисуется большой картинкой вместо текста.
const STICKER := "::"
const STICKERS := ["heart", "star", "fist", "trophy", "flame", "clover", "goldenApple", "crown", "swords", "rainbow", "chest_gold", "sprout"]
## Помощь со стройкой: 10 помощей, каждая минус 3 минуты; помощнику монеты, до 20 помощей в день.
const HELP_NEED := 10
const HELP_SECONDS := 180.0
const HELPS_PER_DAY := 20
## Подарки альянсу: не больше 5 в день от одного игрока, живут 3 дня.
const GIFTS_PER_DAY := 5
## Онлайн - заходил за последние 15 минут.
const ONLINE_SECONDS := 900


static func goal(members: int) -> int:
	return mini(150, maxi(10, 3 * members))


static func is_sticker(body: String) -> bool:
	return body.begins_with(STICKER) and body.substr(STICKER.length()) in STICKERS


static func sticker_of(body: String) -> String:
	return body.substr(STICKER.length())


## Монеты помощнику за одну помощь.
static func help_coins(level: int) -> int:
	return Events.coins(60, level)


## Награда цели дня: серебряный ключ, монеты и 5 кристаллов.
static func goal_reward(level: int) -> Dictionary:
	return {"coins": Events.coins(800, level), "crystals": 5, "key": "silver"}


## Сундучок подарка по цене покупки: до $3 - медный ключ и монеты, до $10 - серебряный и кристаллы, дороже - звёздный.
static func gift_tier(product: String) -> int:
	var p := str(Products.PRICES.get(product, "$0")).trim_prefix("$").to_float()
	if p < 3.0:
		return 1
	if p < 10.0:
		return 2
	return 3


static func gift_reward(product: String, level: int) -> Dictionary:
	match gift_tier(product):
		1: return {"coins": Events.coins(300, level), "key": "copper"}
		2: return {"coins": Events.coins(600, level), "crystals": 3, "key": "silver"}
		_: return {"coins": Events.coins(1200, level), "crystals": 8, "key": "star"}
