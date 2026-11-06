class_name AcademySystem
extends RefCounted
## Бонусы усадьбы из ветки талантов "Усадьба" (бывшая академия).
## Старое сохранение academy = {levels: {id: n}, ...} один раз переносится в ранги талантов,
## а ранги выдаются бесплатно: за них добавляются бонусные очки талантов.


func defaults(save: Dictionary) -> void:
	var raw: Variant = save.get("academy")
	if raw is Dictionary and (raw as Dictionary).get("levels") is Dictionary:
		var levels: Dictionary = raw["levels"]
		if not (save.get("talents") is Dictionary):
			save["talents"] = {}
		var talents: Dictionary = save["talents"]
		var bonus := 0
		for id in Academy.TALENT:
			var tid := str(Academy.TALENT[id])
			var r := Academy.rank_from_level(id, int(levels.get(id, 0)))
			var have := int(talents.get(tid, 0))
			if r > have:
				bonus += (r - have) * Talents.cost(tid)
				talents[tid] = r
		save["bonusTalentPoints"] = int(save.get("bonusTalentPoints", 0)) + bonus
	save.erase("academy")


## Множитель бонуса сейчас (1 - нет бонуса). Для часов и шанса - сама величина (0 - нет бонуса).
func mult(id: String) -> float:
	var t: Variant = Game.save.get("talents")
	var n := int((t as Dictionary).get(str(Academy.TALENT.get(id, "")), 0)) if t is Dictionary else 0
	return Academy.mult_at(id, n)
