class_name WorldFeature
extends RefCounted
## Часть игровой сцены (звери, монстры, огород, дом, клады, торговцы). World вызывает по порядку.


## Построить своё на только что собранной карте.
func build(_world: World) -> void:
	pass


## Каждый кадр (пока нет перехода между локациями).
func process(_world: World, _dt: float) -> void:
	pass


## Перед перестройкой карты: забыть ссылки на узлы.
func clear(_world: World) -> void:
	pass


## Дополнительные препятствия для героя.
func resolve(_world: World, p: Vector2, _radius: float) -> Vector2:
	return p


## Удар раньше добычи (бой с монстром). true - удар сделан, добычу в этот раз не трогаем.
func try_strike(_world: World, _stats: Stats) -> bool:
	return false
