class_name ShopSystem
extends RefCounted
## Кристаллы, подписка MAX, наборы по уровню, лавка за кристаллы, предложение дня, новые предложения.
## В Game.save: crystals, crystalFirst (пачки, купленные хотя бы раз), maxUntil, maxDailyDay, maxSkinMonth,
## ownedSkins (образы из коллекции, полученные по одному), bundleUntil {набор: unix}, offersSeen,
## offerPopupDay, dealDay, adCrystalsDay, adCrystals.

## Кристаллы за каждый уровень и сверху за каждый пятый.
const LEVEL_CRYSTALS := 3
const LEVEL5_CRYSTALS := 15
## Кристаллы за ролик: сколько и сколько раз в день.
const AD_CRYSTALS := 5
const AD_CRYSTALS_PER_DAY := 2
## MAX: кристаллы каждый день, места в рюкзаке, удача дольше.
const MAX_DAILY_CRYSTALS := 30
const MAX_BACKPACK := 20
const MAX_LUCK_MULT := 2.0
## Окно набора по уровню.
const BUNDLE_WINDOW := 48.0 * 3600.0
## Скидка предложения дня.
const DEAL_DISCOUNT := 0.4

## Лавка за кристаллы: цена и что даёт. Образы из коллекции добавляются отдельно (skin:<id>).
const MARKET := {
	"ticket1": {"price": 40, "icon": "ticket"},
	"ticket5": {"price": 170, "icon": "ticket"},
	"map1": {"price": 60, "icon": "tmap"},
	"luck30": {"price": 25, "icon": "clover"},
	"coins": {"price": 30, "icon": "moneybag"},
}
const SKIN_PRICE := 300
## Из чего выбирается предложение дня.
const DEAL_POOL := ["ticket5", "map1", "luck30", "coins", "skin"]


func defaults(save: Dictionary) -> void:
	save["crystals"] = maxi(0, int(save.get("crystals", 0))) if _num(save.get("crystals")) else 0
	for key in ["crystalFirst", "ownedSkins", "offersSeen"]:
		var list: Array = []
		var raw = save.get(key, [])
		if raw is Array:
			for v in raw:
				list.append(str(v))
		save[key] = list
	var until = save.get("bundleUntil", {})
	var clean := {}
	if until is Dictionary:
		for k in until:
			if _num(until[k]):
				clean[str(k)] = float(until[k])
	save["bundleUntil"] = clean
	for key in ["maxUntil"]:
		if not _num(save.get(key)):
			save.erase(key)
	for key in ["maxDailyDay", "maxSkinMonth", "offerPopupDay", "dealDay", "adCrystalsDay", "adCrystals"]:
		save[key] = int(save.get(key, 0)) if _num(save.get(key)) else 0


static func _num(v) -> bool:
	return v is float or v is int


static func _now() -> float:
	return Time.get_unix_time_from_system()


static func day_index() -> int:
	return int(House.start_of_day() / 86400.0)


# MARK: Кристаллы

func crystals() -> int:
	return int(Game.save.get("crystals", 0))


func add_crystals(n: int, toast := false) -> void:
	if n <= 0:
		return
	Game.save["crystals"] = crystals() + n
	if toast:
		Game.show_toast("px:gem", L.t("crystals.got", [n]))
	Game.mark_dirty()


func spend_crystals(n: int) -> bool:
	if n < 0 or crystals() < n:
		return false
	Game.save["crystals"] = crystals() - n
	Game.mark_dirty()
	return true


## Кристаллы за уровни с from+1 по to.
static func level_crystals(from: int, to: int) -> int:
	var n := 0
	for lv in range(from + 1, to + 1):
		n += LEVEL_CRYSTALS + (LEVEL5_CRYSTALS if lv % 5 == 0 else 0)
	return n


## Новый уровень: кристаллы и, может быть, набор по уровню.
func on_level_up(from: int, to: int) -> void:
	add_crystals(level_crystals(from, to))
	check_level_bundles()


# MARK: Покупки за деньги

## Выдать содержимое покупки (зовёт PremiumSystem.grant для новых видов покупок).
## Сохранение, звук и общий тост - там.
func grant(key: String) -> void:
	if Products.is_crystals(key):
		var n := int(Products.CRYSTAL_PACKS[key]["n"])
		var first: Array = Game.save["crystalFirst"]
		if not key in first:
			first.append(key)
			n *= 2
		add_crystals(n)
		Game.show_toast("px:gem", L.t("crystals.got", [Fmt.n(n)]))
	elif key == "max":
		_extend_max()
		Game.show_toast("px:crown", L.t("max.activated", [max_days_left()]))
	elif Products.is_level_bundle(key):
		var b: Dictionary = Products.LEVEL_BUNDLES[key]
		add_crystals(int(b["crystals"]))
		Game.add_coins(int(b["coins"]))
		Game.save["tickets"] = Game.premium.tickets() + int(b["tickets"])
		Game.save["maps"] = Game.premium.maps() + int(b["maps"])
		if bool(b["skin"]):
			var skin := random_missing_skin()
			if skin != "":
				give_skin(skin)
		Game.save["bundleUntil"].erase(key)
	elif key == "flash":
		_give_pack(Products.FLASH[day_index() % Products.FLASH.size()])
		Game.save["flashDay"] = day_index()
		Game.show_toast("px:chest_gold", L.t("toast.purchased", [Products.title(key)]))
	elif key in Products.STEPS:
		_give_pack(Products.STEPS[key])
	elif key == "stepsAll":
		var purchases: Array = Game.save.get("purchases", [])
		for k in Products.STEP_KEYS:
			_give_pack(Products.STEPS[k])
			if not Products.id(k) in purchases:
				purchases.append(Products.id(k))
		Game.save["purchases"] = purchases
	elif key == "energyPack":
		Game.energy.add(Products.ENERGY_PACK, true)
	elif key == "attemptsPack":
		Game.dungeons.add_tokens(Products.ATTEMPTS_PACK)
		Game.show_toast("px:key", L.t("toast.purchased", [Products.title(key)]))
	Game.mark_dirty()


## Содержимое набора: кристаллы, монеты, билеты, карты, энергия, бесконечная энергия, попытки, украшение.
func _give_pack(p: Dictionary) -> void:
	if p.has("crystals"):
		add_crystals(int(p["crystals"]))
	if p.has("coins"):
		Game.add_coins(int(p["coins"]))
	if p.has("tickets"):
		Game.save["tickets"] = Game.premium.tickets() + int(p["tickets"])
	if p.has("maps"):
		Game.save["maps"] = Game.premium.maps() + int(p["maps"])
	if p.has("energy"):
		Game.energy.add(int(p["energy"]))
	if p.has("infinite_hours"):
		Game.energy.add_infinite(float(p["infinite_hours"]) * 3600.0)
	if p.has("attempts"):
		Game.dungeons.add_tokens(int(p["attempts"]))
	if p.has("cosmetic"):
		var purchases: Array = Game.save.get("purchases", [])
		var id := Products.id(str(p["cosmetic"]))
		if not id in purchases:
			purchases.append(id)
		Game.save["purchases"] = purchases


## Предложение дня уже куплено сегодня.
func flash_bought() -> bool:
	return int(Game.save.get("flashDay", -1)) == day_index()


func flash_variant() -> Dictionary:
	return Products.FLASH[day_index() % Products.FLASH.size()]


## Следующая ступень набора ("" - все куплены).
func next_step() -> String:
	for k in Products.STEP_KEYS:
		if not Game.premium.owns(k):
			return k
	return ""


# MARK: Подписка MAX

func max_active() -> bool:
	var until = Game.save.get("maxUntil")
	return _num(until) and float(until) > _now()


func max_days_left() -> int:
	var until = Game.save.get("maxUntil")
	if not _num(until):
		return 0
	return maxi(0, int(ceil((float(until) - _now()) / 86400.0)))


func _extend_max() -> void:
	var until = Game.save.get("maxUntil")
	var from := maxf(_now(), float(until) if _num(until) else 0.0)
	Game.save["maxUntil"] = from + Products.MAX_DAYS * 86400.0
	# Пропуск текущего ивента - сразу
	Game.events.activate_vip()
	_max_month_skin()


## Образ месяца: раз в 30 дней подписки - образ из коллекции, которого ещё нет. Остаётся навсегда.
func _max_month_skin() -> void:
	var month := int(_now() / (Products.MAX_DAYS * 86400.0))
	if int(Game.save.get("maxSkinMonth", 0)) == month:
		return
	var skin := random_missing_skin()
	if skin == "":
		return
	Game.save["maxSkinMonth"] = month
	give_skin(skin)


# MARK: Ежедневный подарок

## Подарок дня без ролика: серия из 7 дней, седьмой - большой сундук. Пропуск дня начинает серию заново.
static func gift_reward(day_n: int) -> Dictionary:
	var coins := int(round(Game.level_coin_reward(Game.level) * 0.15 / 10.0)) * 10
	match day_n:
		1: return {"coins": coins}
		2: return {"energy": 100}
		3: return {"coins": coins * 2}
		4: return {"crystals": 3}
		5: return {"energy": 200}
		6: return {"coins": coins * 3, "tickets": 1}
	return {"crystals": 10, "energy": 300, "tickets": 1}


func gift_ready() -> bool:
	return int(Game.save.get("giftDay", -1)) != day_index()


## Какой день серии будет следующим (1-7).
func gift_next_day() -> int:
	var last := int(Game.save.get("giftDay", -1))
	var streak := int(Game.save.get("giftStreak", 0))
	if last == day_index():
		return streak
	if last == day_index() - 1 and streak < 7:
		return streak + 1
	return 1


func claim_gift() -> Dictionary:
	if not gift_ready():
		return {}
	var n := gift_next_day()
	Game.save["giftDay"] = day_index()
	Game.save["giftStreak"] = n
	var r := gift_reward(n)
	if r.has("coins"):
		Game.add_coins(int(r["coins"]))
	if r.has("energy"):
		Game.energy.add(int(r["energy"]))
	if r.has("crystals"):
		add_crystals(int(r["crystals"]))
	if r.has("tickets"):
		Game.save["tickets"] = Game.premium.tickets() + int(r["tickets"])
	Sound.play("treasure")
	Game.mark_dirty()
	Game.save_now()
	return r


## Секунд до следующего подарка (до начала нового дня).
static func next_day_in() -> float:
	return House.start_of_day() + 86400.0 - Time.get_unix_time_from_system()


func give_market_free(item: String) -> void:
	_give_market(item)
	Game.mark_dirty()


func max_daily_ready() -> bool:
	return max_active() and int(Game.save.get("maxDailyDay", 0)) != day_index()


func claim_max_daily() -> void:
	if not max_daily_ready():
		return
	Game.save["maxDailyDay"] = day_index()
	add_crystals(MAX_DAILY_CRYSTALS, true)
	Sound.play("coin")
	Game.save_now()


## Пропуск ивента с MAX: каждый ивент, пока подписка действует.
func sync_max() -> void:
	# Ключ ивента записываем, чтобы пропуск остался и после конца подписки
	if max_active() and Game.events.events_open() and not Events.current()["key"] in Game.save.get("vipKeys", []):
		Game.events.activate_vip()
	if max_active():
		_max_month_skin()


# MARK: Образы по одному

func owns_skin(skin: String) -> bool:
	return skin in Game.save.get("ownedSkins", [])


func give_skin(skin: String) -> void:
	var list: Array = Game.save["ownedSkins"]
	if skin in list:
		return
	list.append(skin)
	Game.show_toast("skin:" + skin, L.t("skins.gift", [Skins.name_of(skin)]))


## Образ из коллекции, которого у игрока нет ("" - все уже есть).
func random_missing_skin() -> String:
	var missing: Array = Skins.collection().filter(func(s: String) -> bool: return not Skins.is_unlocked(s))
	return "" if missing.is_empty() else str(missing.pick_random())


# MARK: Наборы по уровню

func bundle_available(key: String) -> bool:
	var until: Dictionary = Game.save.get("bundleUntil", {})
	return not Game.premium.owns(key) and float(until.get(key, 0.0)) > _now()


func bundle_until(key: String) -> float:
	return float(Game.save.get("bundleUntil", {}).get(key, 0.0))


## Дошли до уровня набора: он открывается на 48 часов (один раз). Если герой перескочил несколько
## таких уровней (например, обновился на 25 уровне), открывается только последний, остальные пропускаются.
func check_level_bundles() -> void:
	var until: Dictionary = Game.save["bundleUntil"]
	var top := ""
	for key in Products.LEVEL_BUNDLES:
		if Game.level >= int(Products.LEVEL_BUNDLES[key]["level"]) and not until.has(key) and not Game.premium.owns(key):
			if top != "":
				until[top] = 0.0
			top = key
	if top != "":
		until[top] = _now() + BUNDLE_WINDOW
		Game.mark_dirty()


func open_bundles() -> Array:
	return Products.LEVEL_BUNDLES.keys().filter(func(k: String) -> bool: return bundle_available(k))


# MARK: Новые предложения

## Предложения, которые сейчас есть: [{id, product}]. id меняется, когда появляется новое (новый ивент).
func current_offers() -> Array:
	var out: Array = []
	var p := Game.premium
	if p.starter_available():
		out.append({"id": "starter:%d" % int(Game.save.get("starterOffers", 0)), "product": "starter"})
	for key in open_bundles():
		out.append({"id": "bundle:" + key, "product": key})
	if Game.events.events_open() and not Game.events.has_vip():
		out.append({"id": "event:" + str(Events.current()["key"]), "product": "eventPass"})
	return out


## Предложения, которых игрок ещё не видел.
func new_offers() -> Array:
	var seen: Array = Game.save.get("offersSeen", [])
	return current_offers().filter(func(o: Dictionary) -> bool: return not o["id"] in seen)


func mark_seen(offer_id: String) -> void:
	var seen: Array = Game.save["offersSeen"]
	if offer_id in seen:
		return
	seen.append(offer_id)
	if seen.size() > 40:
		Game.save["offersSeen"] = seen.slice(seen.size() - 40)
	Game.mark_dirty()


func mark_all_seen() -> void:
	for o in new_offers():
		mark_seen(o["id"])


## Показать ли окно с новым предложением сейчас: не чаще раза в день, не в начале игры.
func popup_due() -> bool:
	if Game.level < PremiumSystem.STARTER_LEVEL or not bool(Game.save.get("tutorialDone", false)):
		return false
	if int(Game.save.get("offerPopupDay", 0)) == day_index():
		return false
	return not new_offers().is_empty()


func note_popup_shown(offer_id: String) -> void:
	Game.save["offerPopupDay"] = day_index()
	mark_seen(offer_id)


## Точка на кнопке магазина: новое предложение, кристаллы MAX или бесплатные кристаллы.
func has_news() -> bool:
	return not new_offers().is_empty() or max_daily_ready() or gift_ready() or Freebies.ready("market")


# MARK: Лавка за кристаллы

## Товары лавки: обычные и образы из коллекции, которых нет.
func market_items() -> Array:
	var out: Array = MARKET.keys()
	for skin in Skins.collection():
		if not Skins.is_unlocked(skin):
			out.append("skin:" + skin)
	return out


## Предложение дня (товар лавки со скидкой, один раз в день). "" - нечего предложить.
func daily_deal() -> String:
	var pool: Array = []
	for id in DEAL_POOL:
		if id == "skin":
			var missing: Array = Skins.collection().filter(func(s: String) -> bool: return not Skins.is_unlocked(s))
			if not missing.is_empty():
				pool.append("skin:" + str(missing[day_index() % missing.size()]))
		else:
			pool.append(id)
	if pool.is_empty():
		return ""
	return str(pool[day_index() % pool.size()])


func deal_bought() -> bool:
	return int(Game.save.get("dealDay", 0)) == day_index()


static func base_price(item: String) -> int:
	if item.begins_with("skin:"):
		return SKIN_PRICE
	return int(MARKET.get(item, {}).get("price", 0))


func deal_price(item: String) -> int:
	return int(round(float(base_price(item)) * (1.0 - DEAL_DISCOUNT)))


## Купить товар лавки. deal - по цене предложения дня.
func buy_market(item: String, deal := false) -> bool:
	if deal and (deal_bought() or item != daily_deal()):
		return false
	if item.begins_with("skin:") and Skins.is_unlocked(item.substr(5)):
		return false
	var price := deal_price(item) if deal else base_price(item)
	if price <= 0 or not spend_crystals(price):
		return false
	if deal:
		Game.save["dealDay"] = day_index()
	_give_market(item)
	Sound.play("purchase")
	Game.mark_dirty()
	Game.save_now()
	return true


func _give_market(item: String) -> void:
	var p := Game.premium
	if item.begins_with("skin:"):
		give_skin(item.substr(5))
		return
	match item:
		"ticket1":
			Game.save["tickets"] = p.tickets() + 1
			Game.show_toast("px:ticket", L.t("market.got.tickets", [1]))
		"ticket5":
			Game.save["tickets"] = p.tickets() + 5
			Game.show_toast("px:ticket", L.t("market.got.tickets", [5]))
		"map1":
			Game.save["maps"] = p.maps() + 1
			Game.show_toast("px:tmap", L.t("market.got.map"))
		"luck30":
			p.add_luck(30.0 * 60.0)
		"coins":
			var n := market_coins()
			Game.add_coins(n)
			Game.show_toast("px:coins", L.t("market.got.coins", [Fmt.n(n)]))


## Сколько монет в мешке: растёт с уровнем.
func market_coins() -> int:
	return 300 + Game.level * 150


# MARK: Кристаллы за ролик

func ad_crystals_left() -> int:
	if int(Game.save.get("adCrystalsDay", 0)) != day_index():
		return AD_CRYSTALS_PER_DAY
	return maxi(0, AD_CRYSTALS_PER_DAY - int(Game.save.get("adCrystals", 0)))


func claim_ad_crystals() -> void:
	if ad_crystals_left() <= 0:
		return
	var today := day_index()
	var used := int(Game.save.get("adCrystals", 0)) if int(Game.save.get("adCrystalsDay", 0)) == today else 0
	Game.save["adCrystalsDay"] = today
	Game.save["adCrystals"] = used + 1
	Game.save["adsWatched"] = int(Game.save.get("adsWatched", 0)) + 1
	add_crystals(AD_CRYSTALS, true)
	Game.save_now()
