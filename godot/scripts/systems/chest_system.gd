class_name ChestSystem
extends RefCounted
## Сундуки и ключи (данные - data/chests.gd).
## В Game.save: chests = {keys: {copper, silver, star}, pity: {wood, silver, ancient}, opened: n, best: редкость}.
## pity - сколько сундуков подряд без редкости гарантии; на pity-м сундуке редкость не ниже гарантии.
## Ключи: сундук целей дня - медный, недели - серебряный, главы жителей - серебряный,
## боссы, клады, подземелья и набеги - медные с шансом. Ключи покупаются за кристаллы.

## Шансы ключа с событий.
const BOSS_COPPER := 1.0
const BOSS_SILVER := 0.15
const TREASURE_COPPER := 0.3
const DUNGEON_COPPER := 0.25
const RAID_COPPER := 1.0
## Сколько сундуков открывается за раз кнопкой "Открыть 10".
const MULTI := 10


func defaults(save: Dictionary) -> void:
	var raw: Dictionary = save.get("chests", {}) if save.get("chests") is Dictionary else {}
	var keys := {}
	var raw_keys: Dictionary = raw.get("keys", {}) if raw.get("keys") is Dictionary else {}
	for k in Chests.KEYS:
		keys[k] = maxi(0, int(raw_keys.get(k, 0)))
	var pity := {}
	var raw_pity: Dictionary = raw.get("pity", {}) if raw.get("pity") is Dictionary else {}
	for c in Chests.IDS:
		pity[c] = maxi(0, int(raw_pity.get(c, 0)))
	save["chests"] = {"keys": keys, "pity": pity, "opened": int(raw.get("opened", 0)),
		"best": str(raw.get("best", ""))}


func _c() -> Dictionary:
	return Game.save["chests"]


# MARK: Ключи

func keys(key: String) -> int:
	return int(_c()["keys"].get(key, 0))


func add_keys(key: String, n := 1, toast := true) -> void:
	if n <= 0 or not key in Chests.KEYS:
		return
	_c()["keys"][key] = keys(key) + n
	if toast:
		Game.show_toast("px:key", L.t("chest.keyGot", [Chests.key_name(key), n]))
	Game.mark_dirty()
	Game.changed.emit()


## Всего ключей (для красной точки на кнопке).
func total_keys() -> int:
	var n := 0
	for k in Chests.KEYS:
		n += keys(k)
	return n


func key_price(chest: String) -> int:
	return int(Chests.spec(chest)["price"])


func buy_key(chest: String) -> bool:
	if not Game.shop.spend_crystals(key_price(chest)):
		return false
	add_keys(Chests.key_of(chest), 1, false)
	Sound.play("coin")
	return true


## Сколько сундуков до гарантии.
func pity_left(chest: String) -> int:
	return maxi(1, int(Chests.spec(chest)["pity"]) - int(_c()["pity"].get(chest, 0)))


# MARK: Открытие

## Открыть сундук count раз (сколько хватит ключей). Возвращает список наград по порядку.
## Награда: {rarity, stars, type, kind, n, icon, text}.
func open(chest: String, count := 1) -> Array:
	var key := Chests.key_of(chest)
	var out: Array = []
	for i in mini(count, keys(key)):
		_c()["keys"][key] = keys(key) - 1
		out.append(_open_one(chest))
	if out.is_empty():
		return out
	Game.recalc()
	Game.save_now()
	Game.changed.emit()
	return out


func _open_one(chest: String) -> Dictionary:
	var sp := Chests.spec(chest)
	var pity: Dictionary = _c()["pity"]
	var guard := str(sp["pity_rarity"])
	var forced := int(pity.get(chest, 0)) + 1 >= int(sp["pity"])
	var rarity := Chests.roll_rarity(chest, guard if forced else "")
	if Chests.rarity_index(rarity) >= Chests.rarity_index(guard):
		pity[chest] = 0
	else:
		pity[chest] = int(pity.get(chest, 0)) + 1
	_c()["opened"] = int(_c()["opened"]) + 1
	var best := str(_c().get("best", ""))
	if Chests.rarity_index(rarity) > Chests.rarity_index(best):
		_c()["best"] = rarity
	var reward := make_reward(rarity, Chests.roll_stars(), Game.level)
	give(reward)
	Game.emit_event("chest", {"chest": chest, "rarity": rarity})
	return reward


## Награда данной редкости и звёзд (без выдачи). Отдельно - для проверки и тестов.
static func make_reward(rarity: String, stars: int, level: int) -> Dictionary:
	var mult: float = float(Chests.VALUE[rarity]) * float(Chests.STAR_MULT[clampi(stars - 1, 0, 2)])
	var value := Chests.base_value(level) * mult
	var pool: Array = Chests.POOLS[rarity]
	var type: String = pool.pick_random()
	var r := {"rarity": rarity, "stars": stars, "type": type, "kind": "", "n": 0}
	match type:
		"coins":
			r["n"] = int(round(value / 10.0)) * 10
		"goods":
			var kinds: Array = Chests.GOODS.get(rarity, Chests.GOODS["purple"])
			var kind: String = kinds.pick_random()
			r["kind"] = kind
			r["n"] = maxi(1, int(round(value / float(maxi(1, Res.price(kind))))))
		"crystals":
			r["n"] = int(round(float(Chests.CRYSTALS.get(rarity, 3)) * float(Chests.STAR_MULT[clampi(stars - 1, 0, 2)])))
		"energy":
			r["n"] = int(round((40.0 if rarity == "green" else 80.0) * float(Chests.STAR_MULT[clampi(stars - 1, 0, 2)])))
		"card":
			r["n"] = 1 if stars < 3 else 2
		"ticket":
			r["n"] = stars
		"skin":
			r["n"] = 1
	return r


## Выдать награду. Товар, которому нет места на складе, превращается в монеты.
func give(r: Dictionary) -> void:
	var n := int(r["n"])
	match str(r["type"]):
		"coins":
			Game.add_coins(n)
		"goods":
			var kind := str(r["kind"])
			var added := Game.add_to_storage(kind, n, false)
			if added < n:
				var coins := (n - added) * maxi(1, Res.price(kind))
				Game.add_coins(coins)
				r["overflow"] = coins
		"crystals":
			Game.shop.add_crystals(n)
		"energy":
			Game.energy.add(float(n))
		"card":
			var cards: Array = []
			for i in n:
				var card: String = Cards.IDS.pick_random()
				Game.collection.gain_card(card)
				cards.append(card)
			r["cards"] = cards
		"ticket":
			Game.save["tickets"] = int(Game.save.get("tickets", 0)) + n
		"skin":
			var skin := Game.shop.random_missing_skin()
			if skin == "":
				# Все образы уже есть: радуга даёт много кристаллов
				r["type"] = "crystals"
				r["n"] = int(Chests.CRYSTALS["rainbow"])
				Game.shop.add_crystals(int(r["n"]))
			else:
				r["kind"] = skin
				Game.shop.give_skin(skin)
	Game.mark_dirty()


## Иконка награды для icon_any.
static func reward_icon(r: Dictionary) -> String:
	match str(r["type"]):
		"coins": return "px:coins"
		"goods": return "res:" + str(r["kind"])
		"crystals": return "px:gem"
		"energy": return "px:bolt"
		"card": return "px:cards"
		"ticket": return "px:ticket"
		"skin": return "skin:" + str(r["kind"])
	return "px:chest"


## Подпись награды: "Доски x12".
static func reward_text(r: Dictionary) -> String:
	var n := int(r["n"])
	match str(r["type"]):
		"coins": return L.t("chest.reward.coins", [Fmt.n(n)])
		"goods": return "%s x%s" % [Res.name_of(str(r["kind"])), Fmt.n(n)]
		"crystals": return L.t("chest.reward.crystals", [n])
		"energy": return L.t("chest.reward.energy", [n])
		"card":
			var cards: Array = r.get("cards", [])
			if cards.size() == 1:
				return L.t("chest.reward.card", [Cards.name_of(str(cards[0]))])
			return L.t("chest.reward.cards", [n])
		"ticket": return L.t("chest.reward.tickets", [n])
		"skin": return L.t("chest.reward.skin", [Skins.name_of(str(r["kind"]))])
	return ""


# MARK: Откуда ключи

func on_event(name: String, data: Dictionary) -> void:
	match name:
		"kill":
			if bool(data.get("boss", false)):
				if randf() < BOSS_SILVER:
					add_keys("silver")
				elif randf() < BOSS_COPPER:
					add_keys("copper")
		"treasure":
			if randf() < TREASURE_COPPER:
				add_keys("copper")
		"dungeon":
			if randf() < DUNGEON_COPPER:
				add_keys("copper")
		"raid":
			if bool(data.get("win", false)) and randf() < RAID_COPPER:
				add_keys("copper")
		"story":
			add_keys("silver")
