class_name DungeonSystem
extends RefCounted
## Подземелья: забеги по этажам, волны, сундук, рекорды (порт части GameState: dungeonBest, startDungeon,
## goDeeper, leaveDungeon...). Забег не сохраняется: если закрыть игру, он прерывается.
## run - идущий забег: {dungeon, floor, wave, waves, cleared, chest_opened, kills, coins, essence} или null.
## report - итог последнего забега для окна после выхода: {dungeon, floor, won, first_clear, coins, essence,
## weapon ("" - без оружия), potions, maps} или null.

var run = null
var report = null
## Награда из сундука текущего этажа (уходит в отчёт при выходе).
var last_chest = null
## Куда вернуться из подземелья.
var dungeon_return := "meadow"
## Растёт при переходе на следующий этаж: сцена перестраивает арену.
var map_version := 0


func defaults(save: Dictionary) -> void:
	var best: Dictionary = save.get("dungeonBest", {})
	for k in best.keys():
		best[k] = int(best[k])
	save["dungeonBest"] = best
	# Забег не сохраняется: из подземелья просыпаемся на лугу
	if Locations.kind(str(save.get("current", "meadow"))) == "dungeon":
		save["current"] = "meadow"


## Забыть забег (копия из файла, перерождение).
func reset() -> void:
	run = null
	last_chest = null


func dungeon_best(id: String) -> int:
	return int(Game.save.get("dungeonBest", {}).get(id, 0))


func in_dungeon() -> bool:
	return Locations.kind(Game.current) == "dungeon" and run != null


func can_enter(id: String, floor_n: int) -> bool:
	return Game.level >= Dungeons.level(id) and floor_n >= 1 and floor_n <= mini(Dungeons.FLOORS, dungeon_best(id) + 1) \
		and Game.save.get("expedition") == null and run == null


func start_dungeon(id: String, floor_n: int) -> void:
	if not can_enter(id, floor_n):
		return
	if Game.backpack_count > 0:
		Game.deposit_backpack()
	var here := Locations.kind(Game.current)
	dungeon_return = Game.current if here == "world" or here == "garden" else "meadow"
	run = _new_run(id, floor_n)
	Game.arrival_gate = ""
	Game.save["current"] = Dungeons.location(id)
	Game.combat.heal_full()
	Game.mark_dirty()


func _new_run(id: String, floor_n: int, kills := 0, coins := 0, essence := 0) -> Dictionary:
	return {"dungeon": id, "floor": floor_n, "wave": 0, "waves": Dungeons.waves(floor_n), "cleared": false,
		"chest_opened": false, "kills": kills, "coins": coins, "essence": essence}


func set_dungeon_wave(wave: int) -> void:
	if run == null or int(run["wave"]) == wave:
		return
	run["wave"] = wave
	Game.changed.emit()


func dungeon_cleared() -> void:
	if run == null or run["cleared"]:
		return
	run["cleared"] = true
	Game.show_toast("px:trophy", L.t("toast.floorCleared", [run["floor"]]))
	Game.emit_event("dungeon", {"dungeon": run["dungeon"], "floor": run["floor"]})
	Game.changed.emit()


## Сундук после этажа: монеты, эссенция, зелья, карта и, может быть, оружие босса.
func open_dungeon_chest() -> void:
	if run == null or not run["cleared"] or run["chest_opened"]:
		return
	var id: String = run["dungeon"]
	var floor_n := int(run["floor"])
	var first := floor_n > dungeon_best(id)
	var bonus := 1.0 + Game.stats.dungeon_bonus
	var coins := int(float(Dungeons.coins(id, floor_n, first)) * bonus)
	var essence := int(round(float(Dungeons.essence(id, floor_n, first)) * bonus))
	Game.add_coins(coins)
	Game.add_to_storage("essence", essence, false)
	var potions := 2 if first else (1 if randf() < 0.3 else 0)
	Game.save["potions"] = int(Game.save.get("potions", 0)) + potions
	var weapon := ""
	var boss_weapon := Dungeons.weapon(id)
	if Dungeons.is_boss_floor(floor_n) and not Game.combat.owns_weapon(boss_weapon) \
			and randf() < Dungeons.weapon_chance(floor_n, first):
		Game.combat.grant_weapon(boss_weapon)
		weapon = boss_weapon
	if Game.collection.has_method("random_card"):
		Game.collection.call("random_card")
	Game.collection.roll_card("essence", 0.25)
	# Карта сокровищ: всегда за босса, иначе иногда (TreasureMaps.dungeonChance)
	var maps := 1 if Dungeons.is_boss_floor(floor_n) or randf() < 0.15 else 0
	Game.save["maps"] = int(Game.save.get("maps", 0)) + maps
	if first:
		var best: Dictionary = Game.save.get("dungeonBest", {})
		best[id] = floor_n
		Game.save["dungeonBest"] = best
		if Dungeons.is_boss_floor(floor_n):
			Game.recalc()
			Game.show_toast("px:star", L.t("toast.dungeonTalent"))
	run["chest_opened"] = true
	run["coins"] = int(run["coins"]) + coins
	run["essence"] = int(run["essence"]) + essence
	last_chest = {"dungeon": id, "floor": floor_n, "won": true, "first_clear": first, "coins": run["coins"],
		"essence": run["essence"], "weapon": weapon, "potions": potions, "maps": maps}
	Game.mark_dirty()
	Game.save_now()


## Следующий этаж открыт: можно идти дальше, не выходя из подземелья.
func can_go_deeper() -> bool:
	if run == null or not run["cleared"] or int(run["floor"]) >= Dungeons.FLOORS:
		return false
	return Game.level >= Dungeons.level(run["dungeon"])


## Сразу на следующий этаж: сундук открывается сам, добыча забега копится дальше.
func go_deeper() -> void:
	if not can_go_deeper():
		return
	if not run["chest_opened"]:
		open_dungeon_chest()
	var r: Dictionary = run
	run = _new_run(r["dungeon"], int(r["floor"]) + 1, int(r["kills"]), int(r["coins"]), int(r["essence"]))
	last_chest = null
	Game.combat.set_boss_info(null)
	Game.combat.heal(0.35)
	map_version += 1
	Game.show_toast("px:stairs", L.t("toast.deeper", [run["floor"]]))
	Game.mark_dirty()


## Выйти из подземелья: через портал после победы или раньше (тогда награды за этаж нет).
func leave_dungeon() -> void:
	if run == null:
		return
	if run["chest_opened"] and last_chest != null:
		report = last_chest
	else:
		report = {"dungeon": run["dungeon"], "floor": run["floor"], "won": false, "first_clear": false,
			"coins": run["coins"], "essence": run["essence"], "weapon": "", "potions": 0, "maps": 0}
	run = null
	last_chest = null
	Game.combat.set_boss_info(null)
	Game.arrival_gate = ""
	Game.save["current"] = dungeon_return
	Game.combat.heal_full()
	Game.mark_dirty()
	Game.save_now()


## Награда за убийство в подземелье копится в итоге забега.
func note_dungeon_kill(coins: int, essence: int) -> void:
	if run == null:
		return
	run["kills"] = int(run["kills"]) + 1
	run["coins"] = int(run["coins"]) + coins
	run["essence"] = int(run["essence"]) + essence
