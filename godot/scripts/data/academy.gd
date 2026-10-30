class_name Academy
## Академия (документ "Новая экономика"): дерево исследований - бонусы усадьбы, изучаются по таймеру по одному.
## Четыре колонки (хозяйство, оборона, походы, выносливость), ряды открываются уровнем академии.
## Узел открывается, когда его родитель изучен хотя бы до 2 уровня. Потолок уровня - половина уровня академии.

## col, row - место в дереве, parent - что нужно сначала, max - потолок,
## step - бонус за уровень, kind: pct (доля), hours (часы), chance (шанс, доля).
const NODES := {
	"build": {"col": 0, "row": 0, "parent": "", "max": 10, "step": -0.05, "kind": "pct", "icon": "hammer"},
	"storage": {"col": 1, "row": 0, "parent": "", "max": 10, "step": 0.05, "kind": "pct", "icon": "chest"},
	"orders": {"col": 2, "row": 0, "parent": "", "max": 10, "step": 0.05, "kind": "pct", "icon": "coins"},
	"stamina": {"col": 3, "row": 0, "parent": "", "max": 10, "step": 0.05, "kind": "pct", "icon": "bolt"},
	"workshops": {"col": 0, "row": 1, "parent": "build", "max": 10, "step": 0.05, "kind": "pct", "icon": "basket"},
	"towers": {"col": 1, "row": 1, "parent": "storage", "max": 10, "step": 0.08, "kind": "pct", "icon": "sword"},
	"squads": {"col": 2, "row": 1, "parent": "orders", "max": 10, "step": -0.05, "kind": "pct", "icon": "compass"},
	"recovery": {"col": 3, "row": 1, "parent": "stamina", "max": 10, "step": -0.04, "kind": "pct", "icon": "hourglass"},
	"stockpile": {"col": 0, "row": 2, "parent": "workshops", "max": 5, "step": 1.0, "kind": "hours", "icon": "stopwatch"},
	"fortify": {"col": 1, "row": 2, "parent": "towers", "max": 5, "step": 0.03, "kind": "pct", "icon": "shield"},
	"trackers": {"col": 2, "row": 2, "parent": "squads", "max": 5, "step": 0.08, "kind": "pct", "icon": "gem"},
	"thrift": {"col": 3, "row": 2, "parent": "recovery", "max": 10, "step": 0.02, "kind": "chance", "icon": "clover"},
	"insight": {"col": 0, "row": 3, "parent": "stockpile", "max": 5, "step": 0.04, "kind": "pct", "icon": "book"},
	"bargain": {"col": 3, "row": 3, "parent": "thrift", "max": 5, "step": -0.06, "kind": "pct", "icon": "coin"},
}
const IDS := ["build", "storage", "orders", "stamina", "workshops", "towers", "squads", "recovery",
	"stockpile", "fortify", "trackers", "thrift", "insight", "bargain"]
## С какого уровня академии открывается ряд.
const ROW_LEVEL := [1, 4, 10, 14]
## Колонки дерева: подписи.
const COLUMNS := ["economy", "defense", "trips", "energy"]
const MAX := 10


static func spec(id: String) -> Dictionary:
	return NODES.get(id, {})


static func name_of(id: String) -> String:
	return L.t("academy." + id)


static func icon(id: String) -> String:
	return str(spec(id).get("icon", "book"))


static func max_level(id: String) -> int:
	return int(spec(id).get("max", MAX))


static func row(id: String) -> int:
	return int(spec(id).get("row", 0))


static func parent(id: String) -> String:
	return str(spec(id).get("parent", ""))


## Множитель бонуса на уровне n (время - меньше 1, остальное - больше 1). Для часов и шанса - сама величина.
static func mult_at(id: String, n: int) -> float:
	var s := spec(id)
	if s.is_empty():
		return 1.0
	if str(s["kind"]) != "pct":
		return float(s["step"]) * float(n)
	return 1.0 + float(s["step"]) * float(n)


## Бонус для подписи: "-15%", "+2 ч", "6%".
static func bonus_text(id: String, n: int) -> String:
	var s := spec(id)
	match str(s.get("kind", "pct")):
		"hours":
			return "+" + L.t("time.hour", [int(float(s["step"]) * float(n))])
		"chance":
			return "%d%%" % int(round(float(s["step"]) * float(n) * 100.0))
	var p := int(round(float(s["step"]) * float(n) * 100.0))
	return ("+%d%%" if p >= 0 else "%d%%") % p


## Цена уровня n: как стройка академии на несколько уровней выше, дальние ряды дороже.
static func cost(id: String, n: int) -> Dictionary:
	return Estate.build_cost("academy", n + 2 + row(id) * 2)


## Время изучения уровня n в секундах (не ускоряется исследованием стройки).
static func seconds(id: String, n: int) -> float:
	var m := float(n + 2 + row(id))
	return (0.5 * pow(m, 3.0) + m) * 60.0 * 0.8
