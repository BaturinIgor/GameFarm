class_name PremiumSystem
extends RefCounted
## Покупки, Pro, сад, удача, билеты, экспедиции (порт Premium.swift, Expeditions.swift). Заглушка.

const PRO_OFFLINE_HOURS := 12.0
const STARTER_BACKPACK := 20
const CAPYBARA_YIELD := 0.1


func defaults(_save: Dictionary) -> void:
	pass


func owns(product: String) -> bool:
	return product in Game.save.get("purchases", []) or product in Game.save.get("granted", [])


func has_pro() -> bool:
	return owns("pro")


func luck_active() -> bool:
	return false


func in_expedition() -> bool:
	return false


## Множитель добычи в текущей экспедиции.
func expedition_yield_bonus(_location: String) -> float:
	return 1.0


## Во сколько раз быстрее восстанавливаются ресурсы в экспедиции.
func expedition_respawn_mult() -> float:
	return 1.0


func note_expedition_coins(_n: int) -> void:
	pass
