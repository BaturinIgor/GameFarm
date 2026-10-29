class_name HouseSystem
extends RefCounted
## Дом, уют, кухня и блюда, календарь (порт House.swift и части GameState). Заглушка.


func defaults(_save: Dictionary) -> void:
	pass


func comfort() -> int:
	return 0


## Бонус уюта: +1% за очко, не больше 30%.
func comfort_bonus() -> float:
	return minf(0.3, comfort() * 0.01)


func is_built(_floor: String) -> bool:
	return false


## Блюда, которые сейчас действуют (id блюд).
func active_meals() -> Array:
	return []


## Что даёт блюдо: {"yield", "xp", "speed", "sell", "crit", "animals"}.
func meal_buff(_dish: String) -> Dictionary:
	return {}
