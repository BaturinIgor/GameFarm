class_name CollectionSystem
extends RefCounted
## Карты и созвездия (порт extension GameState "Коллекция" и rollCard).
## save["cards"]: сколько копий каждой карты. Копии поднимают звёзды карты,
## полное созвездие даёт вечный бонус (его берёт Game.recalc) и образ героя.

## Шанс карты с монстра.
const MONSTER_CHANCE := 0.05


func defaults(save: Dictionary) -> void:
	var cards := {}
	var raw = save.get("cards", {})
	if raw is Dictionary:
		for id in raw:
			if Cards.is_valid(str(id)):
				cards[str(id)] = int(raw[id])
	save["cards"] = cards
	save["collectorClaimed"] = maxi(0, int(save.get("collectorClaimed", 0)))


## Карты за монстров (rollCard(for: MonsterKind)): CombatSystem.note_kill шлёт событие kill.
func on_event(name: String, data: Dictionary) -> void:
	if name == "kill":
		roll_monster_card(str(data.get("monster", "")))


func card_count(card: String) -> int:
	return int(Game.save.get("cards", {}).get(card, 0))


func card_stars(card: String) -> int:
	return Cards.stars(card_count(card))


func is_complete(c: String) -> bool:
	if not Cards.SETS.has(c):
		return false
	for card in Cards.cards_of(c):
		if card_count(card) <= 0:
			return false
	return true


## Звёзды самой слабой карты созвездия.
func min_stars(c: String) -> int:
	var cards := Cards.cards_of(c)
	if cards.is_empty():
		return 0
	var low := Cards.THRESHOLDS.size()
	for card in cards:
		low = mini(low, card_stars(card))
	return low


func constellation_bonus(c: String) -> float:
	return Cards.bonus(min_stars(c)) if is_complete(c) else 0.0


func cards_owned() -> int:
	var n := 0
	for card in Cards.IDS:
		if card_count(card) > 0:
			n += 1
	return n


func complete_count() -> int:
	var n := 0
	for c in Cards.CONSTELLATIONS:
		if is_complete(c):
			n += 1
	return n


## Новая карта (или копия, которая поднимает звёзды).
func gain_card(card: String) -> void:
	if not Cards.is_valid(card):
		return
	var c := Cards.constellation_of(card)
	var was_complete := is_complete(c)
	var before := card_stars(card)
	var cards: Dictionary = Game.save.get("cards", {})
	cards[card] = card_count(card) + 1
	Game.save["cards"] = cards
	var after := card_stars(card)
	if before == 0:
		Game.show_toast("px:cards", L.t("toast.card", [Cards.name_of(card)]))
	elif after > before:
		# Звезда - иконкой тоста: значка ★ в шрифте нет
		Game.show_toast("px:star", L.t("toast.cardStar", [Cards.name_of(card), after]).replace("★", ""))
	if not was_complete and is_complete(c):
		Game.show_toast("px:spark", L.t("toast.constellation", [Cards.constellation_name(c)]))
		Sound.play("unlock")
	Game.recalc()
	Game.mark_dirty()


## Шанс карты при добыче ресурса.
func roll_card(kind: String, chance := 0.012) -> void:
	var card := Cards.for_resource(kind)
	if card == "" or randf() >= chance:
		return
	gain_card(card)


func roll_monster_card(kind: String) -> void:
	var card := Cards.for_monster(kind)
	if card == "" or randf() >= MONSTER_CHANCE:
		return
	gain_card(card)


## Карта зверя при приручении (шанс бросает AnimalSystem.tame).
func gain_animal_card(id: String) -> void:
	var card := Cards.for_animal(id)
	if card != "":
		gain_card(card)


func random_card() -> void:
	gain_card(Cards.IDS[randi() % Cards.IDS.size()])


# MARK: Уровень коллекционера (Коллекции 2.0)
## Очки за всё найденное: карты, звери, редкие окраски, гибриды, трофеи.
## Каждые COLLECTOR_STEP очков - уровень, за уровень ключ: медный, каждый 5-й серебряный, каждый 10-й звёздный.

const COLLECTOR_STEP := 6
const COLLECTOR_POINTS := {"card": 1, "animal": 2, "shiny": 2, "hybrid": 3, "trophy": 3, "page": 1}


func collector_parts() -> Dictionary:
	var a := Game.animals
	var hybrids := 0
	var shiny := 0
	for id in a.owned():
		if Animals.is_hybrid(id):
			hybrids += 1
		if a.is_shiny(id):
			shiny += 1
	var trophies := 0
	for t in Trophies.IDS:
		if Trophies.is_earned(t):
			trophies += 1
	return {"card": cards_owned(), "animal": a.owned().size(), "shiny": shiny, "hybrid": hybrids, "trophy": trophies,
		"page": Game.story.pages_total()}


func collector_points() -> int:
	var parts := collector_parts()
	var n := 0
	for k in parts:
		n += int(parts[k]) * int(COLLECTOR_POINTS.get(k, 1))
	return n


func collector_level() -> int:
	return collector_points() / COLLECTOR_STEP


## Очков до следующего уровня и сколько уже набрано внутри уровня.
func collector_progress() -> Array:
	return [collector_points() % COLLECTOR_STEP, COLLECTOR_STEP]


func collector_claimed() -> int:
	return int(Game.save.get("collectorClaimed", 0))


func collector_ready() -> int:
	return maxi(0, collector_level() - collector_claimed())


static func collector_reward(lvl: int) -> String:
	if lvl % 10 == 0:
		return "star"
	if lvl % 5 == 0:
		return "silver"
	return "copper"


## Забрать награды всех новых уровней. Возвращает {ключ: сколько}.
func claim_collector() -> Dictionary:
	var out := {}
	var top := collector_level()
	for lvl in range(collector_claimed() + 1, top + 1):
		var k := collector_reward(lvl)
		out[k] = int(out.get(k, 0)) + 1
	if out.is_empty():
		return out
	for k in out:
		Game.chests.add_keys(k, int(out[k]), false)
	Game.save["collectorClaimed"] = top
	Sound.play("success")
	Game.save_now()
	Game.changed.emit()
	return out
