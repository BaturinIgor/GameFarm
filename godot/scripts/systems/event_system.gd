class_name EventSystem
extends RefCounted
## Ивенты, пропуск, этапы и усиления (порт Events.swift). Заглушка.


func defaults(_save: Dictionary) -> void:
	pass


## Сила усиления этапа: ранг * прибавка за ранг.
func boon(_id: String) -> float:
	return 0.0


## Очки ивента за точку добычи этого типа (0, если точка не ивентовая).
func points_for_node(_type: String) -> int:
	return 0


## Начислить очки ивента; возвращает, сколько начислено.
func add_points(n: int) -> int:
	return n
