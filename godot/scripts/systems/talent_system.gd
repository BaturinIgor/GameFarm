class_name TalentSystem
extends RefCounted
## Таланты (порт Talents.swift и части GameState). Заглушка: заменяется полным портом.


func defaults(_save: Dictionary) -> void:
	pass


## Ранг таланта (0, если не изучен).
func rank(id: String) -> int:
	return int(Game.save.get("talents", {}).get(id, 0))
