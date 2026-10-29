class_name QuestSystem
extends RefCounted
## Задания, достижения и клады (порт заданий, достижений и openTreasure из GameState).

## Шанс получить карту коллекции из клада.
const TREASURE_CARD_CHANCE := 0.35

## Сколько заданий на доске одновременно.
var quest_slots: int:
	get: return 4 if Game.premium.has_pro() else 3


func defaults(save: Dictionary) -> void:
	var list: Array = []
	var raw = save.get("quests", [])
	if raw is Array:
		for q in raw:
			if not (q is Dictionary) or not q.has("id") or not (str(q.get("type", "")) in Quests.TYPES):
				continue
			var out := {
				"id": str(q["id"]), "type": str(q["type"]), "target": int(q.get("target", 0)),
				"progress": int(q.get("progress", 0)), "coins": int(q.get("coins", 0)), "xp": int(q.get("xp", 0)),
			}
			if q.get("resource") is String:
				out["resource"] = q["resource"]
			list.append(out)
	save["quests"] = list
	var claimed: Array = []
	for id in save.get("claimed", []):
		claimed.append(str(id))
	save["claimed"] = claimed
	for key in ["questsDone", "treasures", "bonusTalentPoints"]:
		save[key] = int(save.get(key, 0))


# MARK: Задания

## Задания на доске (всегда полный набор).
func current_quests() -> Array:
	ensure_quests()
	return Game.save["quests"]


## Дополняет доску до нужного числа заданий, убирает сбор без ресурса.
func ensure_quests() -> void:
	var qs: Array = Game.save["quests"]
	var changed := false
	for i in range(qs.size() - 1, -1, -1):
		if qs[i]["type"] == "gather" and Quests.kind(qs[i]) == "":
			qs.remove_at(i)
			changed = true
	var slots := quest_slots
	if qs.size() > slots:
		qs.resize(slots)
		changed = true
	if qs.size() < slots:
		var available := gatherable_kinds()
		var producers := _producer_kinds()
		while qs.size() < slots:
			qs.append(Quests.make(Game.level, available, producers, qs))
		changed = true
	if changed:
		Game.mark_dirty()


## Слушает события игры (gather, harvest, deposit, sell, tame, treasure).
func on_event(name: String, data: Dictionary) -> void:
	match name:
		"gather": _progress("gather", str(data.get("kind", "")), int(data.get("amount", 0)))
		"harvest": _progress("harvest", "", int(data.get("amount", 1)))
		"sell": _progress("sell", "", int(data.get("amount", 0)))
		"deposit": _progress("deposit", "", int(data.get("amount", 0)))
		"tame": _progress("tame", "", 1)
		"treasure": _progress("treasure", "", 1)


func _progress(type: String, kind: String, amount: int) -> void:
	if amount <= 0:
		return
	var touched := false
	for q in Game.save.get("quests", []):
		if q["type"] != type or Quests.is_done(q):
			continue
		if type == "gather" and Quests.kind(q) != kind:
			continue
		q["progress"] = mini(int(q["target"]), int(q["progress"]) + amount)
		touched = true
		if Quests.is_done(q):
			Game.show_toast("px:quest", L.t("toast.questDone"))
	if touched:
		Game.mark_dirty()


func claimable_quests() -> int:
	return current_quests().filter(func(q: Dictionary) -> bool: return Quests.is_done(q)).size()


func _index(id: String) -> int:
	var qs: Array = Game.save["quests"]
	for i in qs.size():
		if qs[i]["id"] == id:
			return i
	return -1


func claim_quest(id: String) -> void:
	var index := _index(id)
	var qs: Array = Game.save["quests"]
	if index < 0 or not Quests.is_done(qs[index]):
		return
	var quest: Dictionary = qs[index]
	qs.remove_at(index)
	Game.add_coins(int(quest["coins"]))
	Game.save["questsDone"] = int(Game.save["questsDone"]) + 1
	var fresh := Quests.make(Game.level, gatherable_kinds(), _producer_kinds(), qs)
	qs.insert(mini(index, qs.size()), fresh)
	Game.gain_xp(int(quest["xp"]))
	Game.mark_dirty()


## Забрать все выполненные задания разом.
func claim_all_quests() -> void:
	var ids: Array = []
	for q in Game.save["quests"]:
		if Quests.is_done(q):
			ids.append(q["id"])
	for id in ids:
		claim_quest(id)


func reroll_cost() -> int:
	return 15 * Game.level


## Заменить задание другим: за монеты или бесплатно (в iOS - за рекламу, с Pro сразу).
func reroll_quest(id: String, free := false) -> void:
	var index := _index(id)
	if index < 0 or (not free and int(Game.save["coins"]) < reroll_cost()):
		return
	if free:
		Game.save["adsWatched"] = int(Game.save.get("adsWatched", 0)) + 1
	else:
		Game.save["coins"] = int(Game.save["coins"]) - reroll_cost()
	var qs: Array = Game.save["quests"]
	var others := qs.duplicate()
	others.remove_at(index)
	qs[index] = Quests.make(Game.level, gatherable_kinds(), _producer_kinds(), others + [qs[index]])
	Game.mark_dirty()


## Ресурсы, которые сейчас реально добыть: для заданий и находок.
func gatherable_kinds() -> Array:
	var out: Array = []
	for id in Game.save.get("unlocked", []):
		for type in MapLayout.load_layout(str(id)).node_types():
			var spec := Nodes.spec(type)
			if not Game.can_harvest(spec):
				continue
			for y in spec["yields"]:
				if float(y[3]) >= 0.5 and not y[0] in out:
					out.append(y[0])
	return out


func _producer_kinds() -> Array:
	var out: Array = []
	for p in Game.stats.producers:
		out.append(p["kind"])
	return out


# MARK: Достижения

func is_claimed(a: Dictionary) -> bool:
	return a["id"] in Game.save.get("claimed", [])


func can_claim(a: Dictionary) -> bool:
	return not is_claimed(a) and Quests.progress(a) >= int(a["target"])


func claimable_achievements() -> int:
	var n := 0
	for a in Quests.achievements():
		if can_claim(a):
			n += 1
	return n


func claim(a: Dictionary) -> void:
	if not can_claim(a):
		return
	Game.save["claimed"].append(a["id"])
	Game.add_coins(int(a["coins"]))
	var points := int(a["points"])
	Game.save["bonusTalentPoints"] = int(Game.save.get("bonusTalentPoints", 0)) + points
	if points > 0:
		Game.show_toast("px:star", L.t("toast.achievementPoints", [points]))
	Game.mark_dirty()


func claim_all_achievements() -> void:
	for a in Quests.achievements():
		if can_claim(a):
			claim(a)


## Награды, которые можно забрать: задания и достижения (охоты - вместе с боем).
func claimable_count() -> int:
	return claimable_quests() + claimable_achievements() + Game.combat.claimable_hunts()


# MARK: Клады

## Награда за клад зависит от уровня и открытых локаций: {coins, items: [[вид, n], ...]}.
func open_treasure() -> Dictionary:
	if randf() < TREASURE_CARD_CHANCE and Game.collection.has_method("random_card"):
		Game.collection.call("random_card")
	var level := Game.level
	var pro_bonus := 2.0 if Game.premium.has_pro() else 1.0
	var coins := int(float(40 + level * 25) * randf_range(0.8, 1.4) * pro_bonus)
	var items: Array = []
	var pool := gatherable_kinds()
	pool.shuffle()
	for kind in pool.slice(0, 2):
		var n := maxi(1, int(float(20 + level * 3) / pow(float(Res.price(kind)), 0.6) * randf_range(0.7, 1.3) * pro_bonus))
		items.append([kind, n])
	Game.add_coins(coins)
	for it in items:
		Game.add_to_storage(it[0], it[1])
	Game.save["treasures"] = int(Game.save.get("treasures", 0)) + 1
	Game.emit_event("treasure", {})
	Game.gain_xp(maxi(5, Game.xp_needed / 25))
	Game.mark_dirty()
	return {"coins": coins, "items": items}
