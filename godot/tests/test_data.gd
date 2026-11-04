extends "res://tests/test_case.gd"
## Таблицы данных: ссылки между ними, достижимость по уровню, цены.


func test_resources_have_category_and_price() -> void:
	var seen := {}
	for kind in Res.KINDS:
		check(not seen.has(kind), "ресурс %s повторяется" % kind)
		seen[kind] = true
		check(Res.category(kind) in Res.CATEGORIES, "у %s нет категории" % kind)
		check(Res.price(kind) > 0, "у %s нет цены" % kind)


func test_talent_tree_links() -> void:
	for id in Talents.ids():
		check(Talents.branch(id) in Talents.BRANCHES, "%s: неизвестная ветка" % id)
		check(Talents.max_rank(id) >= 1, "%s: ранг" % id)
		check(Talents.tier(id) >= 0 and Talents.tier(id) < Talents.TIER_LEVELS.size(), "%s: ряд" % id)
		check(Talents.required_level(id) <= Game.MAX_LEVEL, "%s: недостижимый уровень" % id)
		for p in Talents.parents(id):
			if not check(Talents.exists(p), "%s: нет родителя %s" % [id, p]):
				continue
			check(Talents.tier(p) < Talents.tier(id), "%s: родитель %s не выше по дереву" % [id, p])


func test_tool_costs_use_known_resources() -> void:
	for tool in Tools.UPGRADABLE:
		for t in range(2, Tools.MAX_TIER + 1):
			for it in Tools.cost(tool, t)["items"]:
				check(it[0] in Res.KINDS, "%s %d: неизвестный ресурс %s" % [tool, t, it[0]])


func test_animals_data() -> void:
	for id in Animals.IDS:
		check(not Animals.spec(id).is_empty(), "нет описания зверя " + id)
		var cost := Animals.wild_cost(id)
		for it in cost.get("items", []):
			check(it[0] in Res.KINDS, "%s: неизвестный ресурс в приручении %s" % [id, it[0]])
		if Animals.shop_level(id) >= 0:
			check(Animals.shop_level(id) <= Game.MAX_LEVEL, "%s: недостижим в лавке" % id)
		for e in Animals.effects(id):
			if e["type"] == "produce":
				check(str(e["kind"]) in Res.KINDS, "%s производит неизвестное %s" % [id, e["kind"]])
				check(float(e["interval"]) > 0.0, "%s: интервал" % id)
	for old in Animals.MIGRATION:
		check(str(Animals.MIGRATION[old]) in Animals.IDS, "старый зверь %s переходит в неизвестного" % old)


func test_locations_reachable() -> void:
	for id in Locations.IDS:
		var s := Locations.spec(id)
		check(not s.is_empty(), "нет описания локации " + id)
		check(int(s.get("level", 1)) <= Game.MAX_LEVEL, "%s открывается выше максимума" % id)
		for w in s.get("wild", []):
			check(str(w) in Animals.IDS, "%s: неизвестный дикий зверь %s" % [id, w])


func test_layouts_present() -> void:
	# Карты копирует tools/godot_sync.sh: без них мир пустой
	check(DirAccess.get_files_at("res://data/layouts").size() > 0, "нет раскладок карт")
