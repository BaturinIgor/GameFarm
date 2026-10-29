class_name CollectionSystem
extends RefCounted
## Карты и созвездия (порт Collection.swift). Заглушка.


func defaults(_save: Dictionary) -> void:
	pass


func constellation_bonus(_id: String) -> float:
	return 0.0


## Шанс получить карту за добычу ресурса (порт rollCard(for: ResourceKind)).
func roll_card(_kind: String, _chance := 0.02) -> void:
	pass
