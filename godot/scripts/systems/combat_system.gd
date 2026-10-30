class_name CombatSystem
extends RefCounted
## Бой и охота (порт extension GameState "Бой и охота"): здоровье героя, урон и лечение, обморок,
## особое оружие, зелья, награды за убийства и заказы стражника. Плюс GearPerks.collect из Gear.swift.

## Три заказа на день: сколько монстров в каждом.
const HUNT_TARGETS := [5, 8, 12]

## Бонусы ступеней снаряжения, собранные последним recalc() (поля GearPerks в snake_case).
var gear: Dictionary = {}
## Здоровье героя (не сохраняется: после запуска герой здоров).
var hp := 100.0
## Рядом монстры: показываем сердечки.
var in_combat := false
## Босс на арене для полоски сверху: {"name", "fraction"} или null.
var boss_info: Variant = null

## Действующие эликсиры: id -> когда кончатся (unix). Не сохраняются.
var buff_until: Dictionary = {}

var _last_second_wind := -1.0e9
var _last_stand_at := -1.0e9
var _last_potion := -1.0e9


func defaults(save: Dictionary) -> void:
	var weapons := {}
	var raw_weapons: Variant = save.get("weapons", {})
	if raw_weapons is Dictionary:
		for id in raw_weapons:
			if Weapons.is_valid(str(id)):
				weapons[str(id)] = int(raw_weapons[id])
	save["weapons"] = weapons
	var w := str(save.get("weapon", "forged"))
	if not Weapons.is_valid(w) or (w != "forged" and int(weapons.get(w, 0)) == 0):
		w = "forged"
	save["weapon"] = w
	# Королевский меч приходит вместе с садом
	if Game.premium.owns("garden") and int(weapons.get("royalSword", 0)) == 0:
		weapons["royalSword"] = Weapons.start_tier("royalSword")
	for key in ["potions", "huntDay", "kills", "bossKills"]:
		save[key] = int(save.get(key, 0))
	# Расходники, победы по видам монстров и забранные ступени бестиария
	for key in ["consumables", "killsBy", "bestiary"]:
		var clean := {}
		var raw: Variant = save.get(key, {})
		if raw is Dictionary:
			for k in raw:
				if raw[k] is float or raw[k] is int:
					clean[str(k)] = maxi(0, int(raw[k]))
		save[key] = clean
	# Как в iOS: если хоть один заказ не читается, список пустой
	var list: Array = []
	var raw_hunts: Variant = save.get("hunts", [])
	if raw_hunts is Array:
		for h in raw_hunts:
			if not (h is Dictionary) or not h.has("id") or not (str(h.get("monster", "")) in Monsters.KINDS):
				list = []
				break
			list.append({
				"id": str(h["id"]), "monster": str(h["monster"]), "target": int(h.get("target", 0)),
				"progress": int(h.get("progress", 0)), "coins": int(h.get("coins", 0)), "xp": int(h.get("xp", 0)),
				"ticket": bool(h.get("ticket", false)),
			})
	save["hunts"] = list


static func _now() -> float:
	return Time.get_unix_time_from_system()


# MARK: Здоровье

func max_hp() -> float:
	return Game.workshop.max_hp()


## Доля урона, которую гасит шлем.
func defense() -> float:
	return Game.workshop.defense()


## Шанс увернуться от укуса.
func dodge_chance() -> float:
	return Game.workshop.dodge_chance()


func hp_fraction() -> float:
	return clampf(hp / maxf(1.0, max_hp()), 0.0, 1.0)


func set_in_combat(v: bool) -> void:
	in_combat = v


func set_boss_info(info: Variant) -> void:
	boss_info = info


## Урон герою с учётом шлема. Возвращает, сколько здоровья ушло.
func hurt_hero(amount: float) -> float:
	var dealt := amount * (1.0 - defense())
	if buff_active("guard"):
		dealt *= 1.0 - float(Consumables.spec("guard")["power"])
	var top := max_hp()
	var next := maxf(0.0, minf(hp, top) - dealt)
	# Второе дыхание (броня 10 ступени): раз в 5 минут герой не падает.
	if next <= 0.0 and bool(gear.get("second_wind", false)) and _now() - _last_second_wind > 300.0:
		_last_second_wind = _now()
		next = top * 0.3
		Game.show_toast("px:heart_plus", L.t("toast.secondWind"))
	# Последний рубеж (талант): раз в 3 минуты.
	if next <= 0.0 and Game.stats.last_stand and _now() - _last_stand_at > 180.0:
		_last_stand_at = _now()
		next = top * 0.25
		Game.show_toast("px:heart_shield", L.t("toast.lastStand"))
	# Свиток второго шанса: срабатывает сам, если остальное не спасло
	if next <= 0.0 and consumable_count("revive") > 0:
		Game.save["consumables"]["revive"] = consumable_count("revive") - 1
		next = top * float(Consumables.spec("revive")["power"])
		Game.show_toast("px:scroll2", L.t("toast.revive"))
		Sound.play("success")
		Game.mark_dirty()
	hp = next
	return dealt


## Лечит на долю от максимума.
func heal(fraction: float) -> void:
	var top := max_hp()
	hp = minf(top, hp + top * fraction)


## Лечит на число единиц здоровья (вампиризм).
func heal_amount(amount: float) -> void:
	hp = minf(max_hp(), hp + amount)


func heal_full() -> void:
	hp = max_hp()


## Герой упал без сил: просыпается у склада и теряет часть рюкзака (немного). Возвращает, сколько потеряно.
func faint() -> int:
	var lost := 0
	# Суперталант "Странник ветров": рюкзак при обмороке не теряется.
	if not Game.stats.keep_pack:
		var pack: Dictionary = Game.save["backpack"]
		for kind in pack:
			var n := int(pack[kind])
			var drop := n * 15 / 100
			if drop > 0:
				pack[kind] = n - drop
				lost += drop
	hp = max_hp() * 0.6
	Game.mark_dirty()
	return lost


# MARK: Оружие

## Надетое оружие (WeaponID).
func weapon() -> String:
	return str(Game.save.get("weapon", "forged"))


func weapon_tier(id: String) -> int:
	return Game.tier("sword") if id == "forged" else int(Game.save["weapons"].get(id, 0))


func owns_weapon(id: String) -> bool:
	return weapon_tier(id) > 0


func equip(id: String) -> void:
	if not owns_weapon(id) or weapon() == id:
		return
	Game.save["weapon"] = id
	Game.recalc()
	Sound.play("tap")
	Game.mark_dirty()


## Урон текущим оружием за удар.
func weapon_damage(boss := false) -> float:
	var w := weapon()
	var s := Game.stats
	var base := ToolSystem.sword_damage(Game.level, effective_weapon_tier(w)) * Weapons.mult(w)
	var rage := 1.0 + s.berserk if hp_fraction() < 0.5 else 1.0
	var vs_boss := 1.0 + float(gear.get("boss_damage", 0.0)) + s.boss_bonus if boss else 1.0
	var elixir := 1.0 + float(Consumables.spec("strength")["power"]) if buff_active("strength") else 1.0
	return base * s.damage_mult * s.sword_mult * s.weapon_mult * rage * vs_boss * elixir


## Ступень оружия не выше той, что доступна кузнецу на текущем уровне:
## трофейный меч после перерождения не превращает новичка в чемпиона.
func effective_weapon_tier(id: String) -> int:
	var cap := 1
	for t in range(1, Tools.MAX_TIER + 1):
		if Tools.required_level("sword", t) <= Game.level:
			cap = t
	return mini(cap, maxi(1, weapon_tier(id)))


## Цена следующей ступени особого оружия со скидкой. Пустой словарь, если улучшать нечего.
func weapon_upgrade_cost(id: String) -> Dictionary:
	if id == "forged" or not owns_weapon(id) or weapon_tier(id) >= Tools.MAX_TIER:
		return {}
	return Game.discounted(Weapons.upgrade_cost(weapon_tier(id) + 1))


func can_upgrade_weapon(id: String) -> bool:
	var cost := weapon_upgrade_cost(id)
	if cost.is_empty():
		return false
	return Game.level >= Tools.required_level("sword", weapon_tier(id) + 1) and Game.can_afford(cost)


func upgrade_weapon(id: String) -> void:
	if not can_upgrade_weapon(id):
		return
	Game.pay(weapon_upgrade_cost(id))
	Game.save["weapons"][id] = weapon_tier(id) + 1
	Game.recalc()
	Sound.play("unlock")
	Game.show_toast("px:sword", L.t("toast.weaponUp", [Weapons.name_of(id), weapon_tier(id)]))
	Game.mark_dirty()
	Game.save_now()


## Получить особое оружие (с босса или за покупку).
func grant_weapon(id: String) -> void:
	if id == "forged" or not Weapons.is_valid(id) or owns_weapon(id):
		return
	Game.save["weapons"][id] = Weapons.start_tier(id)
	Game.show_toast("px:sword", L.t("toast.weaponNew", [Weapons.name_of(id)]))
	Game.mark_dirty()


# MARK: Зелья

func potions() -> int:
	return int(Game.save.get("potions", 0))


func potion_price(count: int) -> int:
	return Dungeons.potion_price(Game.level) * count


func buy_potions(count: int) -> void:
	var price := potion_price(count)
	if int(Game.save["coins"]) < price:
		return
	Game.save["coins"] = int(Game.save["coins"]) - price
	Game.save["potions"] = potions() + count
	Sound.play("purchase")
	Game.mark_dirty()


func potion_ready() -> bool:
	return potions() > 0 and _now() - _last_potion > Dungeons.POTION_COOLDOWN


func drink_potion() -> void:
	if not potion_ready() or hp >= max_hp():
		return
	Game.save["potions"] = potions() - 1
	_last_potion = _now()
	heal(Dungeons.POTION_HEAL + Game.stats.potion_bonus)
	Sound.play("success")
	Game.mark_dirty()


# MARK: Расходники

func consumable_count(id: String) -> int:
	return int(Game.save.get("consumables", {}).get(id, 0))


func consumable_open(id: String) -> bool:
	return Game.level >= Consumables.level(id)


func consumable_price(id: String, count: int) -> int:
	return Consumables.price(id, Game.level) * count


func buy_consumable(id: String, count: int) -> bool:
	var price := consumable_price(id, count)
	if not consumable_open(id) or int(Game.save["coins"]) < price:
		return false
	Game.save["coins"] = int(Game.save["coins"]) - price
	add_consumable(id, count)
	Sound.play("purchase")
	return true


func add_consumable(id: String, count: int) -> void:
	var c: Dictionary = Game.save["consumables"]
	c[id] = int(c.get(id, 0)) + count
	Game.mark_dirty()


func buff_active(id: String) -> bool:
	return float(buff_until.get(id, 0.0)) > _now()


func buff_left(id: String) -> float:
	return maxf(0.0, float(buff_until.get(id, 0.0)) - _now())


## Выпить эликсир или бросить бомбу. Эликсир того же вида продлевает действие.
func use_consumable(id: String) -> bool:
	if consumable_count(id) <= 0 or not Consumables.usable(id):
		return false
	if id == "bomb":
		if MonstersFeature.current == null or not MonstersFeature.current.throw_bomb():
			return false
	else:
		buff_until[id] = maxf(_now(), float(buff_until.get(id, 0.0))) + float(Consumables.spec(id)["duration"])
		Sound.play("luck")
	Game.save["consumables"][id] = consumable_count(id) - 1
	Game.emit_event("consumable", {"id": id})
	Game.mark_dirty()
	return true


# MARK: Бестиарий

func kills_of(kind: String) -> int:
	return int(Game.save.get("killsBy", {}).get(kind, 0))


## Сколько ступеней бестиария уже забрано по виду.
func bestiary_claimed(kind: String) -> int:
	return int(Game.save.get("bestiary", {}).get(kind, 0))


## Ступень, которую можно забрать (-1 - нечего).
func bestiary_ready(kind: String) -> int:
	var t := bestiary_claimed(kind)
	if t >= Consumables.BESTIARY_TIERS.size():
		return -1
	return t if kills_of(kind) >= int(Consumables.BESTIARY_TIERS[t]) else -1


func bestiary_ready_count() -> int:
	var n := 0
	for kind in Monsters.KINDS:
		if bestiary_ready(kind) >= 0:
			n += 1
	return n


func claim_bestiary(kind: String) -> void:
	var t := bestiary_ready(kind)
	if t < 0:
		return
	Game.save["bestiary"][kind] = t + 1
	Game.shop.add_crystals(int(Consumables.BESTIARY_CRYSTALS[t]), true)
	Sound.play("treasure")
	Game.save_now()


## Прибавка к урону по виду монстра от ступеней бестиария.
func bestiary_mult(kind: String) -> float:
	return 1.0 + Consumables.BESTIARY_DAMAGE * float(bestiary_claimed(kind))


# MARK: Убийства

## Монстр побеждён: опыт, монеты, трофеи, заказы стражника. Возвращает {coins, loot}.
## Карта коллекции и очки ивента - у их систем по событию kill.
func note_kill(kind: String, level: int, boss := false) -> Dictionary:
	var st: Dictionary = Monsters.stats(kind, level, boss, [])
	var coins := int(st.get("coins", 0))
	Game.save["kills"] = int(Game.save.get("kills", 0)) + 1
	var by: Dictionary = Game.save["killsBy"]
	by[kind] = int(by.get(kind, 0)) + 1
	if boss:
		Game.save["bossKills"] = int(Game.save.get("bossKills", 0)) + 1
	Game.add_coins(coins)
	var loot := randi_range(1, 4 if kind == "slimeGold" else 2)
	var dungeon := Game.dungeons.in_dungeon()
	var loot_kind: String = Monsters.loot(kind)
	var direct := dungeon or Game.premium.in_expedition()
	var added := Game.add_to_storage(loot_kind, loot) if direct else Game.add_to_backpack(loot_kind, loot)
	if dungeon:
		var essence := 1 if randf() < 0.2 else 0
		if essence > 0:
			Game.add_to_storage("essence", essence, false)
		Game.dungeons.note_dungeon_kill(coins, essence)
	Game.gain_xp(int(st.get("xp", 0)))
	if Game.stats.kill_heal > 0.0:
		heal(Game.stats.kill_heal)
	Game.emit_event("kill", {"monster": kind, "level": level, "boss": boss})
	ensure_hunts()
	for h in Game.save["hunts"]:
		if h["monster"] == kind and not hunt_done(h):
			h["progress"] = int(h["progress"]) + 1
			if hunt_done(h):
				Game.show_toast("px:sword", L.t("toast.huntDone", [Monsters.name_of(kind)]))
	Game.mark_dirty()
	return {"coins": coins, "loot": added}


# MARK: Охота

func hunts() -> Array:
	return Game.save.get("hunts", [])


static func hunt_done(h: Dictionary) -> bool:
	return int(h.get("progress", 0)) >= int(h.get("target", 0))


func _hunt_today() -> int:
	return int(House.start_of_day() / 86400.0)


## Когда появятся новые заказы (следующая местная полночь), unix-секунды.
func next_hunts_at() -> float:
	return House.start_of_day() + 86400.0


## Три заказа на день: монстры из уже открытых локаций.
func ensure_hunts() -> void:
	var today := _hunt_today()
	if int(Game.save.get("huntDay", 0)) == today and not hunts().is_empty():
		return
	Game.save["huntDay"] = today
	var kinds: Array = []
	for id in Game.save.get("unlocked", []):
		if Locations.kind(str(id)) != "world":
			continue
		for pair in Monsters.in_location(str(id)):
			if not pair[0] in kinds:
				kinds.append(pair[0])
	if kinds.is_empty():
		kinds = ["slimeGreen"]
	var rng := Farming.DayRandom.new(today * 131 + Game.level)
	var made: Array = []
	for i in HUNT_TARGETS.size():
		var kind: String = rng.pick(kinds)
		var target: int = HUNT_TARGETS[i]
		var homes: Array = Monsters.home_of(kind)
		var level := 3
		if not homes.is_empty():
			level = 1 << 30
			for loc in homes:
				level = mini(level, int(Monsters.level_in(loc)))
		var st: Dictionary = Monsters.stats(kind, level, false, [])
		made.append({
			"id": Quests.uuid(), "monster": kind, "target": target, "progress": 0,
			"coins": int(st.get("coins", 0)) * target * 3, "xp": int(st.get("xp", 0)) * target, "ticket": i == 2,
		})
	Game.save["hunts"] = made
	Game.mark_dirty()


func claimable_hunts() -> int:
	var n := 0
	for h in hunts():
		if hunt_done(h):
			n += 1
	return n


func claim_hunt(id: String) -> void:
	var list: Array = Game.save["hunts"]
	for i in list.size():
		var h: Dictionary = list[i]
		if h["id"] != id:
			continue
		if not hunt_done(h):
			return
		list.remove_at(i)
		Game.add_coins(int(h["coins"]))
		if bool(h.get("ticket", false)):
			Game.save["tickets"] = int(Game.save.get("tickets", 0)) + 1
		Game.gain_xp(int(h["xp"]))
		Sound.play("success")
		Game.mark_dirty()
		Game.save_now()
		return


func claim_all_hunts() -> void:
	var ids: Array = []
	for h in hunts():
		if hunt_done(h):
			ids.append(h["id"])
	for id in ids:
		claim_hunt(id)


# MARK: Снаряжение

## Порт GearPerks.collect: бонусы ступеней добычи и крита идут сразу в s,
## остальные возвращаются словарём (поля GearPerks в snake_case).
func collect_gear(s: Stats) -> Dictionary:
	var g := {
		"honey": 0.0, "golden_apple": 0.0, "chop_cleave": 0.0, "mine_cleave": 0.0, "ruby": 0.0, "stardust": 0.0,
		"coin_chest": 0.0, "double_catch": 0.0, "pearl": 0.0, "giant_fish": 0.0, "lifesteal": 0.0,
		"sword_cleave": 0.0, "boss_damage": 0.0, "stun": 0.0, "hp_bonus": 0.0, "combat_regen": 0.0, "thorns": 0.0,
		"second_wind": false, "defense": 0.0, "poison_immune": false, "slow_immune": false, "crit_immune": false,
		"dodge": 0.0, "speed": 0.0,
	}
	for tool in Tools.UPGRADABLE:
		var tier := Game.tier(tool)
		for perk in Tools.perks(tool):
			if tier < int(perk["tier"]):
				continue
			var kind: String = perk["kind"]
			var v: float = perk["v"]
			match kind:
				"yield":
					_add(s.yield_category, perk["cat"], v)
					if perk["cat"] == "stone":
						_add(s.yield_category, "ore", v)
				"fish": _add(s.yield_kind, "fish", v)
				"gem": s.gem_chance += v
				"crit": s.crit_chance += v
				"cleave": _add(g, "chop_cleave" if tool == "axe" else "mine_cleave", v)
				"swordCleave": g["sword_cleave"] = maxf(float(g["sword_cleave"]), v)
				"hp": _add(g, "hp_bonus", v)
				"secondWind", "poisonImmune", "slowImmune", "critImmune": g[kind.to_snake_case()] = true
				# honey, goldenApple, ruby, stardust, coinChest, doubleCatch, pearl, giantFish, lifesteal,
				# bossDamage, stun, combatRegen, thorns, defense, speed, dodge
				_: _add(g, kind.to_snake_case(), v)
	# Сцена (world.gd) читает бонусы добычи под именами из Swift
	for key in ["chop_cleave", "mine_cleave", "golden_apple", "double_catch", "coin_chest", "giant_fish"]:
		g[key.to_camel_case()] = g[key]
	return g


## Прибавка скорости от сапог.
func hero_speed(boots_tier: int) -> float:
	return ToolSystem.boots_speed(boots_tier)


static func _add(d: Dictionary, key: String, v: float) -> void:
	d[key] = float(d.get(key, 0.0)) + v
