class_name LegacySystem
extends RefCounted
## Наследие: вечные бонусы за искры. Перерождения больше нет (его место занял Алтарь Древних),
## купленные ранги остаются. Искры дают Сердца земли и ивенты.
## save: sparks, sparksEarned, legacy {перк: ранг}; rebirths - старый счётчик, только для чтения.


func defaults(save: Dictionary) -> void:
	var known := {}
	var refund := 0
	var raw = save.get("legacy", {})
	if raw is Dictionary:
		for perk in raw:
			if str(perk) in Legacy.PERKS:
				known[str(perk)] = int(raw[perk])
			elif str(perk) in Legacy.RETIRED:
				for r in clampi(int(raw[perk]), 0, Legacy.max_rank(str(perk))):
					refund += Legacy.cost(str(perk), r)
	save["legacy"] = known
	for key in ["rebirths", "sparks", "sparksEarned"]:
		save[key] = maxi(0, int(save.get(key, 0)))
	save["sparks"] = int(save["sparks"]) + refund


func rank(perk: String) -> int:
	return int(Game.save.get("legacy", {}).get(perk, 0))


## Прибавка перка: ранг * прибавка за ранг.
func value(perk: String) -> float:
	return float(rank(perk)) * Legacy.per_rank(perk)


func sparks() -> int:
	return int(Game.save.get("sparks", 0))


func rebirths() -> int:
	return int(Game.save.get("rebirths", 0))


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
