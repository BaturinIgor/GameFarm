class_name LegacySystem
extends RefCounted
## Перерождение и наследие (порт Legacy.swift). Заглушка: заменяется полным портом.


func defaults(_save: Dictionary) -> void:
	pass


func rank(_perk: String) -> int:
	return 0


## Прибавка перка: ранг * прибавка за ранг.
func value(_perk: String) -> float:
	return 0.0
