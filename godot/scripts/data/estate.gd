class_name Estate
## Усадьба: здания, товары, рецепты и формулы стройки (документ "Новая экономика").
## Уровень главного дома ограничивает остальные здания, сам он открывается по уровню героя: 3 * (n - 1).
## Здание работает не выше уровня (уровень героя / 3 + 1) - так после перерождения доход растёт заново.

## Порядок - как в окне усадьбы.
const IDS := ["main", "storage", "barn", "board", "sawmill", "mill", "kiln", "smelter", "tower", "wall", "camp"]

## hero - с какого уровня героя открывается, time/cost - множители времени и цены, max - потолок уровня,
## sprite - картинка из пака, recipes - что производит (первый рецепт - по умолчанию).
const BUILDINGS := {
	"main": {"hero": 1, "time": 1.5, "cost": 1.6, "max": 20, "sprite": "house"},
	"storage": {"hero": 1, "time": 0.8, "cost": 0.8, "max": 20, "sprite": "chest_anim"},
	"barn": {"hero": 1, "time": 0.8, "cost": 0.7, "max": 20, "sprite": "hay_big"},
	"board": {"hero": 2, "time": 0.6, "cost": 0.7, "max": 10, "sprite": "quest_board"},
	"sawmill": {"hero": 3, "time": 1.0, "cost": 1.0, "max": 20, "sprite": "house_red", "recipes": ["planks", "slats"]},
	"mill": {"hero": 5, "time": 1.0, "cost": 1.0, "max": 20, "sprite": "windmill", "recipes": ["flour", "oil"]},
	"kiln": {"hero": 6, "time": 1.0, "cost": 1.0, "max": 20, "sprite": "clay_pit", "recipes": ["brick", "lime"]},
	"smelter": {"hero": 9, "time": 1.1, "cost": 1.1, "max": 20, "sprite": "anvil", "recipes": ["iron_bar", "gold_bar"]},
	# Защита от набегов: свои рисунки (tools/make_defense_art.py)
	"tower": {"hero": 10, "time": 1.0, "cost": 1.1, "max": 20, "sprite": "tower"},
	"wall": {"hero": 10, "time": 0.9, "cost": 0.9, "max": 20, "sprite": "palisade"},
	# Походный лагерь: отряды зверей для диких земель
	"camp": {"hero": 15, "time": 1.0, "cost": 1.0, "max": 20, "sprite": "tent"},
}

## Товары: из чего делаются. Цена товара - сырьё по цене продажи с наценкой за работу.
const RECIPES := {
	"planks": [["wood", 8]],
	"slats": [["bamboo", 6]],
	"brick": [["clay", 3], ["coal", 1]],
	"lime": [["stone", 6]],
	"iron_bar": [["iron", 3], ["coal", 1]],
	"gold_bar": [["gold", 3], ["coal", 1]],
	"flour": [["wheat", 4]],
	"oil": [["sunflower", 2]],
}
const GOODS := ["planks", "slats", "brick", "lime", "iron_bar", "gold_bar", "flour", "oil"]
const MARKUP := 1.25
## С какого уровня стройки нужны редкие материалы диких земель.
const RARE_FROM := [["copper", 12], ["amber", 15], ["amethyst", 17], ["emerald", 19]]

## Стройка: время (0.5 n^3 + n) минут * k, цена 300 * 1.48^(n-1) * k (половина монетами, половина товарами).
const BUILD_BASE := 300.0
const BUILD_GROWTH := 1.48
## Производство: ценность товара в час 25 * 1.17^(n-1).
const PROD_BASE := 25.0
const PROD_GROWTH := 1.17
## Как в Hay Day: два хранилища с общей вместимостью. Амбар - урожай, еда и продукты ферм, склад - всё остальное.
## Вместимость 1000 * 1.3^(n-1) у склада и 600 * 1.3^(n-1) у амбара.
const STORAGE_BASE := 1000.0
const BARN_BASE := 600.0
const STORAGE_GROWTH := 1.3
const BARN_CATEGORIES := ["crop", "food", "farm"]
## Сколько часов копит здание (Pro - больше).
const CAP_HOURS := 8.0
const CAP_HOURS_PRO := 12.0
## Строители: двое сразу, третий за кристаллы, ещё по одному у Pro и MAX.
const BUILDERS := 2
const BUILDER_CRYSTALS := 300
## Ускорение роликом и сколько раз в день.
const AD_SPEEDUP := 15.0 * 60.0
const AD_SPEEDUPS_PER_DAY := 5


static func spec(id: String) -> Dictionary:
	return BUILDINGS.get(id, {})


static func name_of(id: String) -> String:
	return L.t("estate." + id)


static func info(id: String) -> String:
	return L.t("estate." + id + ".info")


static func max_level(id: String) -> int:
	return int(spec(id).get("max", 20))


static func hero_level(id: String) -> int:
	return int(spec(id).get("hero", 1))


## С какого уровня героя можно строить главный дом уровня n.
static func main_hero_level(n: int) -> int:
	return maxi(1, 3 * (n - 1))


static func recipes(id: String) -> Array:
	return spec(id).get("recipes", [])


static func produces(id: String) -> bool:
	return not recipes(id).is_empty()


## Время стройки уровня n в секундах.
static func build_seconds(id: String, n: int) -> float:
	var k := float(spec(id).get("time", 1.0))
	return (0.5 * pow(float(n), 3.0) + float(n)) * 60.0 * k


## Ценность стройки уровня n (монеты + товары).
static func build_value(id: String, n: int) -> float:
	return BUILD_BASE * pow(BUILD_GROWTH, float(n - 1)) * float(spec(id).get("cost", 1.0))


## Цена уровня n: половина монетами, половина материалами (сначала сырьё, потом доски, кирпич, слитки).
static func build_cost(id: String, n: int) -> Dictionary:
	var value := build_value(id, n)
	var coins := int(round(value * 0.5 / 10.0) * 10.0)
	var share := value * 0.5
	var mats: Array = []
	if n <= 2:
		mats = [["wood", 0.6], ["stone", 0.4]]
	elif n <= 5:
		mats = [["planks", 0.6], ["stone", 0.4]]
	elif n <= 8:
		mats = [["planks", 0.5], ["brick", 0.5]]
	elif n <= 11:
		mats = [["planks", 0.35], ["brick", 0.35], ["iron_bar", 0.3]]
	else:
		mats = [["planks", 0.25], ["brick", 0.25], ["iron_bar", 0.25], ["lime", 0.1], ["gold_bar", 0.15]]
	var items: Array = []
	for m in mats:
		var kind: String = m[0]
		var n_items := maxi(1, int(ceil(share * float(m[1]) / float(price(kind)))))
		items.append([kind, n_items])
	# С 12 уровня - редкие материалы диких земель (немного, сверх основной цены)
	for r in RARE_FROM:
		if n >= int(r[1]):
			items.append([r[0], maxi(1, (n - int(r[1])) / 2 + 2)])
	return {"coins": coins, "items": items}


## Цена продажи товара (или сырья).
static func price(kind: String) -> int:
	if RECIPES.has(kind):
		var v := 0.0
		for it in RECIPES[kind]:
			v += float(Res.price(it[0])) * float(it[1])
		return maxi(1, int(round(v * MARKUP)))
	return Res.price(kind)


## Сколько товара в час делает здание уровня n.
static func per_hour(good: String, n: int) -> float:
	if n <= 0:
		return 0.0
	return PROD_BASE * pow(PROD_GROWTH, float(n - 1)) / float(price(good))


## Вместимость хранилища ("storage" или "barn") на уровне n.
static func capacity(store: String, n: int) -> int:
	var base := BARN_BASE if store == "barn" else STORAGE_BASE
	return int(round(base * pow(STORAGE_GROWTH, float(maxi(1, n) - 1)) / 10.0) * 10)


## В каком хранилище лежит ресурс.
static func store_of(kind: String) -> String:
	return "barn" if Res.category(kind) in BARN_CATEGORIES else "storage"


## Сколько кристаллов стоит ускорить оставшееся время (15 минут - 2, час - 3, 8 часов - 12).
static func speedup_crystals(seconds: float) -> int:
	if seconds <= 0.0:
		return 0
	return int(ceil(2.0 * pow(seconds / 3600.0, 0.8))) + 1


static func is_good(kind: String) -> bool:
	return kind in GOODS
