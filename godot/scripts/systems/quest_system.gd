class_name QuestSystem
extends RefCounted
## Задания и достижения (порт Quests.swift). Заглушка.


func defaults(_save: Dictionary) -> void:
	pass


## Слушает события игры (gather, harvest, deposit, sell, tame, ...).
func on_event(_name: String, _data: Dictionary) -> void:
	pass
