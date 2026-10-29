class_name Stats
extends RefCounted
## Итоговые характеристики героя: уровень, таланты, инструменты, звери, наследие и так далее.
## Считаются в Game.recalc(), читаются сценой и окнами.

const BASE_SPEED := 165.0
const BASE_REACH := 46.0
## Скорость героя не выше тройной: иначе за кадр он перескакивает стены.
const MAX_SPEED_MULT := 3.0

var damage_mult := 1.0
var wood_bonus := 0.0
var stone_bonus := 0.0
var high_tier_bonus := 0.0
var hand_mult := 1.0
var hit_interval := 0.55
var crit_chance := 0.0
var crit_mult := 2.0
var shatter_chance := 0.0
var double_strike_chance := 0.0
var execute_threshold := 0.0
var quake := false
var quake_power := 0.4
var quake_radius := 110.0
var tool_bonus := 0
var yield_all := 0.0
var yield_category: Dictionary = {}
var yield_kind: Dictionary = {}
var double_chance := 0.0
var triple_chance := 0.0
var finder_chance := 0.0
var respawn_mult := 1.0
var regrow_chance := 0.0
var xp_mult := 1.0
var sell_mult := 1.0
var sell_category: Dictionary = {}
var golden_touch := false
var gold_mult := 1.0
var gem_chance := 0.0
var speed := BASE_SPEED
var capacity := 35
var reach := BASE_REACH
var deposit_radius := 92.0
var tame_mult := 1.0
var shop_mult := 1.0
var spawn_mult := 1.0
var storekeeper_xp := 0
var helper_mult := 1.0
var helper_speed := 1.0
var helper_range := 260.0
var helper_tier_bonus := 0
var helper_yield := 1.0
var producer_mult := 1.0
var sword_mult := 1.0
var double_product_chance := 0.0
var offline_hours := 6.0
var star_step := 0.25
var double_star_chance := 0.0
var discount := 1.0
var auto_deposit := false
var animal_mult := 1.0
var producers: Array = []   ## {animal, kind, interval}
var helpers: Array = []     ## {animal, spec, damage}
# Огород
var grow_mult := 1.0
var extra_crop_chance := 0.0
var seed_back_chance := 0.0
var water_mult := 1.0
var fert_save_chance := 0.0
var fert_extra := 0
var meal_mult := 1.0
var cook_mult := 1.0
var seed_mult := 1.0
var golden_harvest := false
var harvest_xp_mult := 1.0
# Бой
var hp_mult := 1.0
var weapon_mult := 1.0
var defense_bonus := 0.0
var dodge_bonus := 0.0
var lifesteal := 0.0
var potion_bonus := 0.0
var berserk := 0.0
var boss_bonus := 0.0
var last_stand := false
var dungeon_bonus := 0.0
var regen := 0.0
# Суперталанты
var titan := false
var node_mult := 1.0
var cornucopia := false
var keep_pack := false
var kill_heal := 0.0


func yield_multiplier(kind: String) -> float:
	return 1.0 + yield_all + float(yield_category.get(Res.category(kind), 0.0)) + float(yield_kind.get(kind, 0.0))


func star_multiplier(stars: int) -> float:
	return 1.0 + star_step * float(maxi(1, stars) - 1)
