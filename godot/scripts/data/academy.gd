class_name Academy
## Бывшая академия усадьбы. Её исследования теперь ветка талантов "Усадьба" (Talents, ветка estate),
## а здесь только связь старых бонусов с талантами и перенос старых уровней исследований.

## Бонус усадьбы -> талант.
const TALENT := {
	"build": "estBuild", "storage": "estStorage", "orders": "estOrders", "stamina": "estStamina",
	"workshops": "estWorkshops", "towers": "estTowers", "squads": "estSquads", "recovery": "estRecovery",
	"stockpile": "estStockpile", "fortify": "estFortify", "trackers": "estTrackers", "thrift": "estThrift",
	"insight": "estInsight", "bargain": "estBargain",
}
## Бонусы, которые уменьшают величину (время, цену).
const LESS := ["build", "squads", "recovery", "bargain"]
## Бонусы-величины (часы, шанс), а не множители.
const PLAIN := ["stockpile", "thrift"]


## Множитель бонуса при ранге таланта n (1 - нет бонуса). Для часов и шанса - сама величина (0 - нет бонуса).
static func mult_at(id: String, n: int) -> float:
	var tid := str(TALENT.get(id, ""))
	if tid == "":
		return 1.0
	var v := Talents.per_rank(tid) * float(n) * (-1.0 if id in LESS else 1.0)
	return v if id in PLAIN else 1.0 + v


## Старый уровень исследования -> ранг таланта (у талантов рангов меньше, а шаг крупнее).
static func rank_from_level(id: String, level: int) -> int:
	return clampi((level + 1) / 2, 0, Talents.max_rank(str(TALENT[id])))
