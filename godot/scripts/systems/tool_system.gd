class_name ToolSystem
extends RefCounted
## Мастерская: улучшение инструментов и снаряжения (порт nextToolCost, canUpgradeNow, upgradeTool из GameState)
## и что дают ступени защиты (порт Hero из Monsters.swift).


func defaults(save: Dictionary) -> void:
	var tools: Dictionary = save.get("tools", {})
	for tool in Tools.UPGRADABLE:
		if not tools.has(tool):
			tools[tool] = 1
	save["tools"] = tools


## Цена следующей ступени со скидкой "Бережливого". Пустой словарь, если ступень последняя.
func next_cost(tool: String) -> Dictionary:
	var next := Game.tier(tool) + 1
	if next > Tools.MAX_TIER:
		return {}
	return Game.discounted(Tools.cost(tool, next))


## Почему нельзя улучшить: "" - можно, "max" - последняя ступень, "level" - мал уровень, "cost" - не хватает ресурсов.
func upgrade_block(tool: String) -> String:
	var next := Game.tier(tool) + 1
	if next > Tools.MAX_TIER:
		return "max"
	if Game.level < Tools.required_level(tool, next):
		return "level"
	if not Game.can_afford(next_cost(tool)):
		return "cost"
	return ""


## Можно улучшить прямо сейчас (для значков на вкладках и кнопке).
func can_upgrade(tool: String) -> bool:
	return upgrade_block(tool) == ""


func upgrade(tool: String) -> bool:
	if not can_upgrade(tool):
		return false
	var next := Game.tier(tool) + 1
	Game.pay(next_cost(tool))
	Game.save["tools"][tool] = next
	Game.recalc()
	Game.show_toast("px:" + Tools.icon_name(tool), L.t("toast.newTool", [Tools.tier_name(tool, next)]))
	Game.emit_event("upgrade", {"tool": tool, "tier": next})
	Game.mark_dirty()
	return true


## Сколько инструментов можно улучшить прямо сейчас (счётчик на кнопке, workshopBadge).
func upgradable_count() -> int:
	var n := 0
	for tool in Tools.UPGRADABLE:
		if can_upgrade(tool):
			n += 1
	return n


## Сколько можно улучшить среди этих инструментов (счётчики вкладок мастерской).
func upgradable_among(tools: Array) -> int:
	var n := 0
	for tool in tools:
		if can_upgrade(tool):
			n += 1
	return n


# MARK: Что дают ступени защиты и меча (Hero)

## Максимум здоровья: растёт с уровнем, бронёй и шлемом.
static func hero_max_hp(level: int, armor: int, helmet := 1) -> float:
	return 100.0 + float(level - 1) * 8.0 + float(armor - 1) * 45.0 + float(helmet - 1) * 20.0


## Шлем снижает входящий урон.
static func helmet_defense(helmet: int) -> float:
	return minf(0.36, 0.04 * float(helmet - 1))


## Сапоги: шанс увернуться и скорость.
static func boots_dodge(boots: int) -> float:
	return 0.015 * float(boots - 1)


static func boots_speed(boots: int) -> float:
	return 0.03 * float(boots - 1)


## Урон мечом за удар.
static func sword_damage(level: int, sword: int) -> float:
	return 7.0 * Tools.power(sword) * (1.0 + 0.02 * float(level - 1))


## Максимум здоровья героя (GameState.maxHP): ступени, бонусы снаряжения и таланты.
func max_hp() -> float:
	return hero_max_hp(Game.level, Game.tier("armor"), Game.tier("helmet")) * (1.0 + _gear("hp_bonus")) \
		* Game.stats.hp_mult


## Доля урона, которую гасит защита (GameState.defense).
func defense() -> float:
	return minf(0.65, helmet_defense(Game.tier("helmet")) + _gear("defense") + Game.stats.defense_bonus)


## Шанс увернуться (GameState.dodgeChance).
func dodge_chance() -> float:
	return minf(0.4, boots_dodge(Game.tier("boots")) + _gear("dodge") + Game.stats.dodge_bonus)


## Бонус ступеней снаряжения из последнего recalc() (GearPerks, ключи snake_case).
func _gear(key: String) -> float:
	return float(Game.combat.gear.get(key, 0.0))
