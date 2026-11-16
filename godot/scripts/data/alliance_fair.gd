class_name AllianceFair
## Ярмарка альянса (docs/supabase/alliance_fair.sql): участники выставляют ресурсы со склада, остальные покупают
## за монеты. Прилавок живёт неделю, непроданное возвращается. Второй прилавок - за кристаллы, навсегда.

const SLOTS := 1
const MAX_SLOTS := 2
const SLOT_CRYSTALS := 300
const MAX_QTY := 500
## Цена лота: от половины до трёх базовых цен (Res.price), по умолчанию полторы - выгоднее, чем продать торговцу.
const MIN_MULT := 0.5
const MAX_MULT := 3.0
const DEFAULT_MULT := 1.5


static func base(kind: String, qty: int) -> int:
	return maxi(1, Res.price(kind) * maxi(1, qty))


static func min_price(kind: String, qty: int) -> int:
	return maxi(1, int(floor(base(kind, qty) * MIN_MULT)))


static func max_price(kind: String, qty: int) -> int:
	return maxi(min_price(kind, qty), int(ceil(base(kind, qty) * MAX_MULT)))


static func default_price(kind: String, qty: int) -> int:
	return clampi(int(round(base(kind, qty) * DEFAULT_MULT)), min_price(kind, qty), max_price(kind, qty))


static func clamp_price(kind: String, qty: int, price: int) -> int:
	return clampi(price, min_price(kind, qty), max_price(kind, qty))


## Шаг кнопок цены: десятая часть базовой цены лота, не меньше 1.
static func price_step(kind: String, qty: int) -> int:
	return maxi(1, int(round(base(kind, qty) * 0.1)))


static func valid_kind(kind: String) -> bool:
	return kind in Res.KINDS
