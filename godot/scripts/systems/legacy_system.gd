class_name LegacySystem
extends RefCounted
## Перерождение и наследие (порт части GameState "Перерождение" и Legacy.swift).
## save: rebirths, sparks, sparksEarned, legacy {перк: ранг}. Всё это переживает перерождение.

## Что переносится в новое сохранение при перерождении (как в iOS rebirth()): покупки, билеты, искры, наследие,
## образ, календарь, карты, редкие окраски, ивент, зелья, рекорды подземелий и оружие.
const KEEP := [
	"purchases", "granted", "consumed", "maps", "lastFreeTicket", "gardenChestAt", "starterOfferUntil",
	"starterOffers", "luckUntil", "luckReadyAt", "adsWatched", "skin", "legacy", "loginDay", "loginClaims",
	"cards", "shiny", "eventKey", "eventPoints", "eventFree", "eventVip", "eventBonus", "vipKeys", "eventSeen",
	"eventDecor", "eventSkins", "eventStage", "eventProgress", "eventBest", "eventBoons", "eventChoice",
	"potions", "dungeonBest", "weapon",
	# Новое: кристаллы и магазин, усадьба, бестиарий - остаются после перерождения
	"crystals", "crystalFirst", "maxUntil", "maxDailyDay", "maxSkinMonth", "ownedSkins", "bundleUntil", "offersSeen",
	"offerPopupDay", "dealDay", "adCrystalsDay", "adCrystals", "estate", "residents", "raid", "builder3", "speedAds", "killsBy", "bestiary",
	"bossKills", "economy", "daily", "settings",
]


func defaults(save: Dictionary) -> void:
	var known := {}
	var raw = save.get("legacy", {})
	if raw is Dictionary:
		for perk in raw:
			if str(perk) in Legacy.PERKS:
				known[str(perk)] = int(raw[perk])
	save["legacy"] = known
	for key in ["rebirths", "sparks", "sparksEarned"]:
		save[key] = int(save.get(key, 0))


func rank(perk: String) -> int:
	return int(Game.save.get("legacy", {}).get(perk, 0))


## Прибавка перка: ранг * прибавка за ранг.
func value(perk: String) -> float:
	return float(rank(perk)) * Legacy.per_rank(perk)


func sparks() -> int:
	return int(Game.save.get("sparks", 0))


func rebirths() -> int:
	return int(Game.save.get("rebirths", 0))


## Сколько искр даст перерождение прямо сейчас.
func rebirth_reward() -> int:
	return Legacy.sparks(Game.level, Game.save.get("claimed", []).size(), Game.save.get("openGates", []).size())


## Искры из наград (ивент и т.п.).
func add_sparks(n: int) -> void:
	if n <= 0:
		return
	Game.save["sparks"] = sparks() + n
	Game.save["sparksEarned"] = int(Game.save.get("sparksEarned", 0)) + n
	Game.mark_dirty()


func can_buy_legacy(perk: String) -> bool:
	var r := rank(perk)
	return perk in Legacy.PERKS and r < Legacy.max_rank(perk) and sparks() >= Legacy.cost(perk, r)


func buy_legacy(perk: String) -> bool:
	if not can_buy_legacy(perk):
		return false
	var r := rank(perk)
	Game.save["sparks"] = sparks() - Legacy.cost(perk, r)
	var ranks: Dictionary = Game.save.get("legacy", {})
	ranks[perk] = r + 1
	Game.save["legacy"] = ranks
	if perk == "tools":
		for tool in Tools.UPGRADABLE:
			Game.save["tools"][tool] = maxi(Game.tier(tool), mini(Tools.MAX_TIER, 1 + r + 1))
	Game.recalc()
	Sound.play("unlock")
	Game.mark_dirty()
	return true


## Начать заново: уровень, ресурсы, звери, таланты и проходы обнуляются,
## а покупки, билеты, искры и наследие остаются. За забег начисляются искры.
func rebirth() -> void:
	var old: Dictionary = Game.save
	var reward := rebirth_reward()
	var s: Dictionary = Game.default_save()
	s["tutorialDone"] = true
	for key in KEEP:
		if old.has(key) and old[key] != null:
			s[key] = old[key]
	s["tickets"] = maxi(int(old.get("tickets", 1)), 1)
	s["bestLevel"] = maxi(int(old.get("bestLevel", 1)), int(old.get("level", 1)))
	# Оружие остаётся, но с начальной ступенью
	var weapons := {}
	var old_weapons = old.get("weapons", {})
	if old_weapons is Dictionary:
		for id in old_weapons:
			if Weapons.is_valid(str(id)):
				weapons[str(id)] = Weapons.start_tier(str(id))
	s["weapons"] = weapons
	s["rebirths"] = int(old.get("rebirths", 0)) + (1 if reward > 0 else 0)
	s["sparks"] = int(old.get("sparks", 0)) + reward
	s["sparksEarned"] = int(old.get("sparksEarned", 0)) + reward
	Game.save = s
	Game.dungeons.reset()
	Game.animals.offline_report = {}
	Game.premium.expedition_report = null
	Game.arrival_gate = ""
	Game.arrival_station = ""
	Game.arrive_at_door = false
	# Значения по умолчанию для всех систем в новом сохранении
	for sys in Game.systems:
		sys.defaults(s)
	s["coins"] = int(s["coins"]) + rank("capital") * int(Legacy.per_rank("capital"))
	var tool_tier := mini(Tools.MAX_TIER, 1 + rank("tools"))
	for tool in Tools.UPGRADABLE:
		s["tools"][tool] = tool_tier
	if Game.premium.owns("starter"):
		s["animals"]["duckHat"] = 1
		s["active"] = ["duckHat"]
	# Верные звери (наследие): лучшие звери остаются с одной звездой
	var keep := rank("companions")
	if keep > 0:
		var best: Array = []
		var old_animals = old.get("animals", {})
		if old_animals is Dictionary:
			for id in old_animals:
				if str(id) != "duckHat" and int(old_animals[id]) > 0:
					best.append([str(id), int(old_animals[id])])
		best.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
		for i in mini(keep, best.size()):
			var id: String = best[i][0]
			s["animals"][id] = 1
			if s["active"].size() < Game.animals.max_active() and not id in s["active"]:
				s["active"].append(id)
	if Game.world_map.has_method("refresh_reachable"):
		Game.world_map.call("refresh_reachable")
	Game.recalc()
	if not Skins.is_unlocked(str(s.get("skin", ""))):
		s["skin"] = "farmer"
	Game.quests.ensure_quests()
	Game.mark_dirty()
	Game.save_now()
	if reward > 0:
		Sound.play("levelUp")
		Game.show_toast("px:spark", L.t("rebirth.toast", [reward]))
