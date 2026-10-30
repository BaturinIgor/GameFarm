class_name Expeditions
## Экспедиции по билетам (порт Expedition из Expeditions.swift): цена в билетах и картах сокровищ,
## длительность, бонус добычи. Бесплатный билет раз в сутки.

## Базовая длительность вылазки, секунды.
const DURATION := 4.0 * 60.0
## Бесплатный билет раз в столько секунд.
const FREE_TICKET_EVERY := 20.0 * 3600.0
const MAX_TICKETS := 9
const TICKET_PACK := 5
## Ресурсы восстанавливаются быстрее.
const RESPAWN_MULT := 0.35


## Локации экспедиций по порядку.
static func ids() -> Array:
	return Locations.IDS.filter(func(id: String) -> bool: return Locations.kind(id) == "expedition")


## Сколько билетов стоит вылазка: чем ценнее место, тем дороже.
static func cost(id: String) -> int:
	match id:
		"treasureIsland", "crystalCaves": return 2
		"luckyMeadow", "skyIsles": return 3
	return 1


## Самые ценные экспедиции требуют ещё и карты сокровищ.
static func maps(id: String) -> int:
	match id:
		"crystalCaves": return 1
		"skyIsles": return 2
	return 0


## Каких инструментов не хватает, чтобы добыть всё в экспедиции: [{tool, need, have}] и сколько ресурсов
## не получится добыть: {"missing": [...], "blocked": n, "total": m}.
static func gear(id: String) -> Dictionary:
	var need := {}
	var blocked := 0
	var total := 0
	for s in MapLayout.load_layout(id).spots:
		var spec := Nodes.spec(str(s["type"]))
		var tool := str(spec.get("tool", "hand"))
		if not tool in Tools.GATHERING:
			continue
		total += 1
		var tier := int(spec.get("tier", 1))
		need[tool] = maxi(int(need.get(tool, 0)), tier)
		if not Game.can_harvest(spec):
			blocked += 1
	var missing: Array = []
	for t in Tools.GATHERING:
		if need.has(t) and Game.effective_tier(t) < int(need[t]):
			missing.append({"tool": t, "need": int(need[t]), "have": Game.effective_tier(t)})
	return {"missing": missing, "blocked": blocked, "total": total}


## Дорогие вылазки длятся дольше: на каждый билет сверху ещё минута.
static func duration(id: String) -> float:
	return DURATION + float(cost(id) - 1 + maps(id)) * 60.0


## Иконка экспедиции в списке.
static func icon(id: String) -> String:
	match id:
		"goldMine": return "gold"
		"treasureIsland": return "chest_gold"
		"luckyMeadow": return "goldenApple"
		"crystalCaves": return "gem"
		"skyIsles": return "stardust"
	return "compass"


## Чем особенна каждая экспедиция.
static func perk(id: String) -> String:
	return L.t("exp." + id + ".perk")


## Во сколько раз больше добычи в экспедиции.
static func yield_bonus(id: String) -> float:
	match id:
		"goldMine": return 1.5
		"treasureIsland": return 2.0
		"luckyMeadow": return 3.0
		"crystalCaves": return 3.0
		"skyIsles": return 4.0
	return 1.0
