class_name ResourceSpot
extends Node2D
## Точка ресурса на карте. Всегда на одном месте, после добычи восстанавливается.

var type := ""
var spec: Dictionary = {}
var style := "pop"
var hp := 1.0
var alive := true

var _respawn_left := 0.0
var _alive_art := Node2D.new()
var _dead_art := Node2D.new()
var _bar := HPBar.new()
var _flash: Sprite2D
var _bar_time := 0.0
var _crowns: Array = []
var _phase := randf() * TAU
var _state_tween: Tween
var _hit_tween: Tween


func _init(node_type: String) -> void:
	type = node_type
	spec = Nodes.spec(type)
	style = Nodes.style(type)
	hp = float(spec["hp"])
	add_child(_dead_art)
	add_child(_alive_art)
	_dead_art.modulate.a = 0.0
	_build_art()
	var r: float = float(spec["radius"])
	_flash = Fx.glow(Color(1, 1, 1), r * 5.0, float(spec["bar"]) * 0.4, 0.0)
	_flash.modulate.a = 0.0
	add_child(_flash)
	_bar.position = Vector2(0, -float(spec["bar"]))
	_bar.modulate.a = 0.0
	_bar.z_index = 20
	add_child(_bar)


var is_solid: bool:
	get: return bool(spec["blocking"]) and (alive or bool(spec["keeps_body"]))


var radius: float:
	get: return float(spec["radius"])


## Возвращает true, если ресурс только что вырос заново.
func tick(dt: float) -> bool:
	if _bar_time > 0.0:
		_bar_time -= dt
		if _bar_time <= 0.0:
			create_tween().tween_property(_bar, "modulate:a", 0.0, 0.25)
	for crown in _crowns:
		# Лёгкое "дыхание" кроны
		crown.scale.y = Sprites.SCALE * (1.0 + 0.0125 * (1.0 + sin(Time.get_ticks_msec() / 1000.0 * 3.2 + _phase)))
	if alive:
		return false
	_respawn_left -= dt
	if _respawn_left <= 0.0:
		_respawn()
		return true
	return false


func play_hit(strong: bool) -> void:
	if _hit_tween != null:
		_hit_tween.kill()
	_alive_art.position = Vector2.ZERO
	_alive_art.scale = Vector2.ONE
	var amp := 5.0 if strong else 3.0
	_hit_tween = create_tween()
	_hit_tween.tween_property(_alive_art, "position:x", amp, 0.03)
	_hit_tween.tween_property(_alive_art, "position:x", -amp, 0.05)
	_hit_tween.tween_property(_alive_art, "position:x", 0.0, 0.03)
	_hit_tween.parallel().tween_property(_alive_art, "scale", Vector2(1.1, 0.9), 0.05)
	_hit_tween.tween_property(_alive_art, "scale", Vector2(0.97, 1.04), 0.06)
	_hit_tween.tween_property(_alive_art, "scale", Vector2.ONE, 0.07)
	_flash.modulate.a = 0.75 if strong else 0.45
	create_tween().tween_property(_flash, "modulate:a", 0.0, 0.18)


func show_hp() -> void:
	_bar.set_fraction(hp / float(spec["hp"]))
	_bar.modulate.a = 1.0
	_bar_time = 1.6


func deplete(respawn_in: float, from: Vector2) -> void:
	alive = false
	hp = 0.0
	_respawn_left = respawn_in
	_bar_time = 0.0
	_bar.modulate.a = 0.0
	if _hit_tween != null:
		_hit_tween.kill()
	_alive_art.position = Vector2.ZERO
	_alive_art.scale = Vector2.ONE
	if _state_tween != null:
		_state_tween.kill()
	_state_tween = create_tween()
	match style:
		"fall":
			# Дерево падает в сторону от героя
			var dir := 1.0 if from.x <= position.x else -1.0
			_state_tween.tween_property(_alive_art, "rotation", dir * 1.45, 0.42).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
			_state_tween.tween_property(_alive_art, "rotation", dir * 1.32, 0.08)
			_state_tween.tween_property(_alive_art, "modulate:a", 0.0, 0.3)
			_state_tween.parallel().tween_property(_alive_art, "position:y", 4.0, 0.3)
		"crumble":
			_state_tween.tween_property(_alive_art, "scale", Vector2(1.15, 0.85), 0.06)
			_state_tween.tween_property(_alive_art, "modulate:a", 0.0, 0.16)
			_state_tween.parallel().tween_property(_alive_art, "scale", Vector2(1.3, 0.3), 0.16)
		"pop":
			_state_tween.tween_property(_alive_art, "scale", Vector2.ONE * 1.25, 0.08).set_ease(Tween.EASE_OUT)
			_state_tween.tween_property(_alive_art, "modulate:a", 0.0, 0.12)
			_state_tween.parallel().tween_property(_alive_art, "scale", Vector2.ONE * 0.2, 0.12)
		"splash":
			_state_tween.tween_property(_alive_art, "modulate:a", 0.0, 0.25)
			_state_tween.parallel().tween_property(_alive_art, "scale", Vector2.ONE * 1.4, 0.25)
		_:
			_state_tween.tween_property(_alive_art, "modulate:a", 0.0, 0.25)
	var dead_tween := create_tween()
	dead_tween.tween_interval(0.35 if style == "fall" else 0.05)
	dead_tween.tween_property(_dead_art, "modulate:a", 1.0, 0.2)


func _respawn() -> void:
	alive = true
	hp = float(spec["hp"])
	_bar.reset()
	if _state_tween != null:
		_state_tween.kill()
	_alive_art.rotation = 0.0
	_alive_art.modulate.a = 1.0
	_alive_art.scale = Vector2.ONE * 0.2
	_alive_art.position = Vector2.ZERO
	_state_tween = create_tween()
	_state_tween.tween_property(_alive_art, "scale", Vector2.ONE * 1.12, 0.24).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_state_tween.tween_property(_alive_art, "scale", Vector2.ONE, 0.14)
	create_tween().tween_property(_dead_art, "modulate:a", 0.0, 0.2)


# MARK: Вид точки (порт PixelNodeArt)

func _add(parent: Node2D, name: String, x := 0.0, y := 0.0) -> Sprite2D:
	var s := Sprites.make(name, Vector2(x, -y))
	if s != null:
		parent.add_child(s)
	return s


func _re_anchor(s: Sprite2D, a: Vector2) -> void:
	if s == null:
		return
	var fs := Vector2(s.texture.get_width() / float(s.hframes), s.texture.get_height() / float(s.vframes))
	s.offset = Sprites.anchor_offset(a, fs)


func _tree(name: String, dead_name: String, glow = null, glow_alpha := 0.4) -> void:
	var crown := Sprites.make(name)
	if crown == null:
		return
	var w := crown.texture.get_width() * Sprites.SCALE
	var h := crown.texture.get_height() * Sprites.SCALE
	if glow != null:
		_alive_art.add_child(Fx.glow(glow, w * 1.6, h * 0.5, glow_alpha))
	_alive_art.add_child(crown)
	_crowns.append(crown)
	_add(_dead_art, dead_name)


func _ore(name: String, chunk: String, glow = null, glow_alpha := 0.3) -> void:
	if glow != null:
		_alive_art.add_child(Fx.glow(glow, 76, 14, glow_alpha))
	if chunk != "":
		_add(_alive_art, chunk, 13, -3)
	_add(_alive_art, name, -4, 0)
	_add(_dead_art, "rubble")


func _fish(name: String, glow = null) -> void:
	if glow != null:
		_alive_art.add_child(Fx.glow(glow, 56, 0, 0.45))
	var shadow := Sprites.animated(name, 8.0)
	if shadow != null:
		_re_anchor(shadow, Vector2(0.5, 0.5))
		_alive_art.add_child(shadow)
	var ripple := RingFx.new()
	ripple.radius = 20.0
	ripple.scale = Vector2(1, 0.5)
	ripple.color = Color(1, 1, 1, 0.5)
	_alive_art.add_child(ripple)
	var calm := RingFx.new()
	calm.radius = 15.0
	calm.scale = Vector2(1, 0.5)
	calm.color = Color(1, 1, 1, 0.25)
	_dead_art.add_child(calm)


func _build_art() -> void:
	var purple := Color(0.62, 0.42, 1)
	match type:
		"tree": _tree("tree_oak" if randf() < 0.5 else "tree_fruit", "stump_oak")
		"pine": _tree("tree_spruce", "stump_spruce")
		"snowPine": _tree("tree_frost", "stump_frost")
		"glowTree": _tree("tree_glow", "stump_oak", purple, 0.45)
		"willow": _tree("tree_willow", "stump_fruit")
		"ashTree": _tree("tree_ash", "stump_ash", Color(1, 0.4, 0.1), 0.25)
		"skyTree": _tree("tree_sky", "stump_birch", Color(0.75, 0.85, 1), 0.4)
		"appleTree": _tree(["tree_apple", "tree_apple", "tree_cherry", "tree_peach", "tree_pear"].pick_random(), "tree_apple_bare")
		"goldenTree": _tree("tree_golden", "tree_golden_bare", Res.ore_color("goldenApple"), 0.35)
		"palm": _tree("palm", "stump_fruit")
		"bananaPalm": _tree("palm_banana", "stump_fruit")
		"bamboo": _tree("bamboo", "sprout")
		"cactus": _tree("cactus", "sprout")
		"bush":
			_add(_alive_art, "bush_berry")
			_add(_dead_art, "bush")
		"cloudBush":
			_add(_alive_art, "bush_cloud_star")
			_add(_dead_art, "bush_cloud")
		"grapeVine":
			_add(_alive_art, "grapes")
			_add(_dead_art, "grapes_bare")
		"beehive":
			_add(_alive_art, "beehive_full")
			_add(_dead_art, "beehive")
		"treasureChest":
			_alive_art.add_child(Fx.glow(Color(1, 0.85, 0.3), 70, 12, 0.4))
			_add(_alive_art, "chest_gold_anim")
			var open := _add(_dead_art, "chest_gold_anim")
			if open != null:
				open.frame = open.hframes * open.vframes - 1
		"mushroom":
			_add(_alive_art, "mushroom_red", -5)
			_add(_alive_art, "mushroom_tiny_red", 8, -3)
		"glowShroom":
			_alive_art.add_child(Fx.glow(Color(0.35, 0.95, 1), 60, 10, 0.55))
			_add(_alive_art, "mushroom_blue", -5)
			_add(_alive_art, "mushroom_tiny_blue", 8, -3)
		"carrot":
			_add(_alive_art, "carrot_ripe", -7)
			_add(_alive_art, "carrot_ripe", 8, 2)
			_add(_dead_art, "sprout")
		"herbPatch":
			_add(_alive_art, "leek", -4)
			_add(_alive_art, "flowers7", 9, -3)
			_add(_dead_art, "leek_young")
		"fireFlower":
			_alive_art.add_child(Fx.glow(Color(1, 0.45, 0.1), 60, 12, 0.55))
			_add(_alive_art, "flowers_red")
			_add(_dead_art, "tuft1")
		"pineapple":
			_add(_alive_art, "pineapple")
			_add(_dead_art, "sprout")
		"shells":
			_add(_alive_art, "shells")
		"rock": _ore("ore_stone", "chunk_stone")
		"boulder":
			_add(_alive_art, "boulder")
			_add(_dead_art, "rubble")
		"coalOre": _ore("ore_coal", "chunk_coal")
		"ironOre": _ore("ore_iron", "chunk_copper")
		"goldOre": _ore("ore_gold", "chunk_gold", Res.ore_color("gold"), 0.22)
		"diamondOre": _ore("ore_diamond", "chunk_diamond", Res.ore_color("diamond"), 0.3)
		"rubyOre": _ore("ore_ruby", "chunk_ruby", Res.ore_color("ruby"), 0.3)
		"obsidianOre": _ore("ore_obsidian", "chunk_obsidian")
		"crystalOre":
			_alive_art.add_child(Fx.glow(purple, 80, 16, 0.45))
			_add(_alive_art, "crystal_amethyst", -4)
			_add(_alive_art, "chunk_amethyst", 12, -3)
			_add(_dead_art, "rubble")
		"iceBlock": _ore("ice_block", "chunk_ice")
		"starRock": _ore("ore_star", "chunk_star", Color(1, 0.92, 0.5), 0.45)
		"sulfurVent": _ore("ore_sulfur", "chunk_sulfur", Res.ore_color("sulfur"), 0.25)
		"coral":
			_add(_alive_art, "coral")
			_add(_dead_art, "rubble")
		"clayPit":
			_re_anchor(_add(_alive_art, "clay_pit"), Vector2(0.5, 0.3))
			var low := _add(_dead_art, "clay_pit")
			if low != null:
				_re_anchor(low, Vector2(0.5, 0.3))
				low.modulate.a = 0.55
		"fishSpot", "oasisFish": _fish("fish_anim")
		"swampFish": _fish("fish_swamp_anim")
		"lavaFish": _fish("fish_lava_anim", Color(1, 0.5, 0.1))
		"starPond": _fish("fish_star_anim", Color(0.7, 0.6, 1))
		"iceHole":
			_re_anchor(_add(_alive_art, "ice_hole"), Vector2(0.5, 0.5))
			var shadow := Sprites.animated("fish_ice_anim", 8.0)
			if shadow != null:
				_re_anchor(shadow, Vector2(0.5, 0.5))
				shadow.scale *= 0.7
				_alive_art.add_child(shadow)
			_re_anchor(_add(_dead_art, "ice_hole"), Vector2(0.5, 0.5))
		"pumpkinPatch":
			_alive_art.add_child(Fx.glow(Color(1, 0.55, 0.1), 64, 8, 0.3))
			_add(_alive_art, "crop_pumpkin_3", -8)
			_add(_alive_art, "crop_pumpkin_3", 9, -4)
			_add(_dead_art, "crop_pumpkin_1")
		"giftBox":
			var colors := ["gift_red", "gift_blue", "gift_green"]
			colors.shuffle()
			_add(_alive_art, colors[0], -7)
			_add(_alive_art, colors[1], 8, -3)
			var top := _add(_alive_art, colors[2], -1, 12)
			if top != null:
				top.scale *= 0.8
			_add(_dead_art, "gift_paper")
		"sandCastle":
			_add(_alive_art, "sandcastle")
			_add(_dead_art, "sand_pile")
		"slimeCrystal":
			_alive_art.add_child(Fx.glow(Color(0.45, 1, 0.4), 84, 16, 0.5))
			_add(_alive_art, "crystal_slime", -4)
			_add(_alive_art, "slime_blob", 12, -3)
			_add(_dead_art, "rubble")
		"oyster":
			_re_anchor(_add(_alive_art, "oyster"), Vector2(0.5, 0.5))
			var calm := RingFx.new()
			calm.radius = 15.0
			calm.scale = Vector2(1, 0.5)
			calm.color = Color(1, 1, 1, 0.3)
			_dead_art.add_child(calm)
