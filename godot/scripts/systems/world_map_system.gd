class_name WorldMapSystem
extends RefCounted
## Проходы между локациями и карта мира (порт WorldGraph и части GameState). Заглушка.


func defaults(_save: Dictionary) -> void:
	pass


func is_gate_open(id: String) -> bool:
	return id in Game.save.get("openGates", [])
