class_name AnimalSystem
extends RefCounted
## Звери (порт Animals.swift и части GameState). Заглушка.


func defaults(_save: Dictionary) -> void:
	pass


func stars(id: String) -> int:
	return int(Game.save.get("animals", {}).get(id, 0))


## Множитель пробуждения и редкого окраса.
func boost(_id: String) -> float:
	return 1.0


## Эффекты зверя: [{"type": "xp", "v": 0.1}, {"type": "yield", "cat": "wood", "v": 0.1}, ...].
func effects(_id: String) -> Array:
	return []
