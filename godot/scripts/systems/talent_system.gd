class_name TalentSystem
extends RefCounted
## Таланты (порт части GameState): ранги, очки, изучение, сброс.


func defaults(save: Dictionary) -> void:
	# Как при чтении в iOS: неизвестные таланты отбрасываются
	var known: Dictionary = {}
	var raw: Dictionary = save.get("talents", {})
	for id in raw:
		if Talents.exists(str(id)):
			known[str(id)] = int(raw[id])
	save["talents"] = known
	save["bonusTalentPoints"] = int(save.get("bonusTalentPoints", 0))


## Ранг таланта (0, если не изучен).
func rank(id: String) -> int:
	return int(Game.save.get("talents", {}).get(id, 0))


func points_total() -> int:
	return Game.talent_points_at(Game.level) + int(Game.save.get("bonusTalentPoints", 0)) \
		+ int(Game.legacy.value("talent")) + dungeon_points()


## Очко таланта за первую победу над каждым боссом подземелий (этажи 5 и 10).
func dungeon_points() -> int:
	var sum := 0
	var best: Dictionary = Game.save.get("dungeonBest", {})
	for id in best:
		var floor_n := int(best[id])
		sum += (1 if floor_n >= 5 else 0) + (1 if floor_n >= 10 else 0)
	return sum


func points_spent() -> int:
	var sum := 0
	var t: Dictionary = Game.save.get("talents", {})
	for id in t:
		if Talents.exists(id):
			sum += int(t[id]) * Talents.cost(id)
	return sum


func points_free() -> int:
	return maxi(0, points_total() - points_spent())


## Сколько очков вложено в ветку.
func points_in(branch: String) -> int:
	var sum := 0
	for id in Talents.in_branch(branch):
		sum += rank(id) * Talents.cost(id)
	return sum


func is_maxed(id: String) -> bool:
	return rank(id) >= Talents.max_rank(id)


## Открыт ли талант: уровень и родители (для суперталанта - родители на максимуме).
func available(id: String) -> bool:
	if Game.level < Talents.required_level(id):
		return false
	return missing_parents(id).is_empty()


## Родители, которых не хватает: не изучены, а для суперталанта - не прокачаны до конца.
func missing_parents(id: String) -> Array:
	var sup := Talents.is_super(id)
	return Talents.parents(id).filter(func(p: String) -> bool:
		return rank(p) < Talents.max_rank(p) if sup else rank(p) == 0)


func can_learn(id: String) -> bool:
	return block_reason(id) == ""


## Почему нельзя изучить: "maxed", "level", "parents", "points" или "" (можно).
func block_reason(id: String) -> String:
	if is_maxed(id):
		return "maxed"
	if Game.level < Talents.required_level(id):
		return "level"
	if not missing_parents(id).is_empty():
		return "parents"
	if points_free() < Talents.cost(id):
		return "points"
	return ""


func learn(id: String) -> bool:
	if not can_learn(id):
		return false
	Game.save["talents"][id] = rank(id) + 1
	Game.recalc()
	Game.mark_dirty()
	Game.emit_event("learn", {"talent": id})
	return true


## Цена сброса талантов в монетах.
func respec_cost() -> int:
	return 50 * Game.level


func can_reset() -> bool:
	return points_spent() > 0 and int(Game.save["coins"]) >= respec_cost()


func reset_talents() -> bool:
	if not can_reset():
		return false
	Game.save["coins"] = int(Game.save["coins"]) - respec_cost()
	Game.save["talents"] = {}
	# Без "Повелителя зверей" одно место для зверя пропадает
	var max_active: int = Game.animals.max_active()
	var active: Array = Game.save.get("active", [])
	if active.size() > max_active:
		Game.save["active"] = active.slice(0, max_active)
	Game.recalc()
	Game.mark_dirty()
	return true
