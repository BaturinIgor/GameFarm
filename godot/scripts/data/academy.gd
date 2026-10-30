class_name Academy
## Академия (документ "Новая экономика"): исследования - бонусы усадьбы, изучаются по таймеру по одному.
## Потолок уровня исследования - половина уровня академии (округлённая вверх), не больше 10.

const IDS := ["build", "storage", "orders", "towers", "squads"]
const MAX := 10
## Значок и шаг бонуса за уровень (доля).
const SPECS := {
	"build": {"icon": "hammer", "step": -0.05},
	"storage": {"icon": "chest", "step": 0.05},
	"orders": {"icon": "coins", "step": 0.05},
	"towers": {"icon": "sword", "step": 0.08},
	"squads": {"icon": "compass", "step": -0.05},
}


static func name_of(id: String) -> String:
	return L.t("academy." + id)


static func icon(id: String) -> String:
	return str(SPECS[id]["icon"])


## Множитель бонуса на уровне n (время - меньше 1, остальное - больше 1).
static func mult_at(id: String, n: int) -> float:
	return 1.0 + float(SPECS[id]["step"]) * float(n)


## Бонус в процентах для подписи: "-15%" или "+15%".
static func percent(id: String, n: int) -> String:
	var p := int(round(float(SPECS[id]["step"]) * float(n) * 100.0))
	return ("+%d%%" if p >= 0 else "%d%%") % p


## Цена уровня n: как стройка академии на несколько уровней выше.
static func cost(n: int) -> Dictionary:
	return Estate.build_cost("academy", n + 2)


## Время изучения уровня n в секундах (не ускоряется собственным исследованием стройки).
static func seconds(n: int) -> float:
	var m := float(n + 2)
	return (0.5 * pow(m, 3.0) + m) * 60.0 * 0.8
