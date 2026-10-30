class_name Wild
## Дикие земли (документ "Новая экономика"): четыре кольца секторов вокруг усадьбы.
## Сектора обновляются раз в неделю по номеру недели (как сделки лавки), сервер не нужен.
## Виды: месторождение (отряд зверей приносит редкий материал), логово (подземелье с наградой),
## руины (экспедиция за билеты), тайник (сундук за разведку).

## Кольца: уровень героя, редкий материал, длина похода в часах [от, до], подземелье логова и этаж.
const RINGS := [
	{"level": 15, "rare": "copper", "hours": [0.25, 1.0], "dungeon": "boneCrypt", "floor": 2},
	{"level": 30, "rare": "amber", "hours": [1.0, 3.0], "dungeon": "frostHollow", "floor": 2},
	{"level": 45, "rare": "amethyst", "hours": [3.0, 6.0], "dungeon": "fireDepths", "floor": 3},
	{"level": 54, "rare": "emerald", "hours": [6.0, 8.0], "dungeon": "fireDepths", "floor": 5},
]
## Секторов в кольце.
const SECTORS := 5
## Сколько зверей в отряде.
const SQUAD_SIZE := 3
## Обычные ресурсы, которые отряд несёт вместе с редким, по кольцам.
const COMMON := [["stone", "coal", "iron"], ["iron", "gold", "ice"], ["gold", "obsidian", "sulfur"], ["diamond", "crystal", "gold"]]


static func week() -> int:
	return int(floor(float(ShopSystem.day_index()) / 7.0))


## Сектора кольца на этой неделе: [{id, kind, ring, hours, expedition}]. Один и тот же набор у всех в эту неделю.
static func sectors(ring: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("wild|%d|%d" % [week(), ring])
	var spec: Dictionary = RINGS[ring]
	var h: Array = spec["hours"]
	var out: Array = []
	var expeditions := Expeditions.ids()
	for i in SECTORS:
		var roll := rng.randf()
		var kind := "deposit"
		# Первые два сектора кольца - всегда месторождения, остальные - что выпадет
		if i >= 2:
			kind = "lair" if roll < 0.3 else ("ruins" if roll < 0.6 else ("cache" if roll < 0.85 else "deposit"))
		var hours := snappedf(rng.randf_range(float(h[0]), float(h[1])), 0.25)
		var exp_id := ""
		if kind == "ruins" and not expeditions.is_empty():
			exp_id = expeditions[rng.randi() % expeditions.size()]
		out.append({"id": "%d_%d" % [ring, i], "kind": kind, "ring": ring, "hours": hours, "expedition": exp_id})
	return out


static func sector(id: String) -> Dictionary:
	var parts := id.split("_")
	if parts.size() != 2:
		return {}
	var ring := int(parts[0])
	if ring < 0 or ring >= RINGS.size():
		return {}
	for s in sectors(ring):
		if s["id"] == id:
			return s
	return {}


## Сколько отрядов даёт лагерь уровня n: 1 сразу, 4 к 15 уровню.
static func squads(n: int) -> int:
	return 0 if n <= 0 else mini(4, 1 + n / 5)


## Добыча месторождения: редкий материал растёт со звёздами зверей отряда и длиной похода.
static func deposit_loot(ring: int, hours: float, stars: int) -> Dictionary:
	var rare: String = RINGS[ring]["rare"]
	var mult := 1.0 + 0.15 * float(stars)
	var loot := {rare: maxi(1, int(round((1.5 + hours * 1.2) * mult)))}
	var common: Array = COMMON[ring]
	for i in common.size():
		var k: String = common[i]
		loot[k] = int(loot.get(k, 0)) + maxi(1, int(round((12.0 + hours * 10.0) * mult / float(i + 1) / maxf(1.0, float(Res.price(k)) / 6.0))))
	return loot


## Награда за логово: эссенция и кристаллы.
static func lair_reward(ring: int) -> Dictionary:
	return {"essence": 2 + 2 * ring, "crystals": 2 + ring}


## Тайник: монеты по уровню и немного редкого материала.
static func cache_reward(ring: int) -> Dictionary:
	return {"coins": int(round(Game.level_coin_reward(int(RINGS[ring]["level"])) * 0.3 / 10.0)) * 10,
		"rare": RINGS[ring]["rare"], "n": 1 + ring}


static func kind_icon(kind: String) -> String:
	match kind:
		"deposit": return "px:hammer"
		"lair": return "px:skull"
		"ruins": return "px:tmap"
		"cache": return "px:chest_gold"
	return "px:compass"
