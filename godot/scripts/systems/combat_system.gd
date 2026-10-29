class_name CombatSystem
extends RefCounted
## Здоровье, снаряжение, оружие, монстры, охота, подземелья (порт Gear, Monsters, Dungeons). Заглушка.

## Бонусы ступеней снаряжения, собранные последним recalc().
var gear: Dictionary = {}


func defaults(_save: Dictionary) -> void:
	pass


## Порт GearPerks.collect: добавляет бонусы ступеней в s и возвращает словарь бонусов (в т.ч. "speed").
func collect_gear(_s: Stats) -> Dictionary:
	return {"speed": 0.0}


## Прибавка скорости от сапог.
func hero_speed(boots_tier: int) -> float:
	return ToolSystem.boots_speed(boots_tier)
