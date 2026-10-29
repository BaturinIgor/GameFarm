class_name MonsterNode
extends Node2D
## Монстр (порт MonsterNode из CombatNodes.swift): бродит у логова, гонится за героем, замахивается и кусает.
## Особые свойства (крит, уклонение, щит, ярость...) видны значками над ним.
## Укус (MonsterBite) - словарь {damage, crit, traits}. Удар героя (MonsterHit) - Hit.

enum Hit { DODGED, DAMAGED, KILLED }

const WINDUP_TIME := 0.38
const BITE_RANGE := 34.0
## Перекраска как colorize в SpriteKit: цвет смешивается с рисунком.
const TINT_SHADER := """shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0);
uniform float blend = 0.0;
void fragment() {
	COLOR.rgb = mix(COLOR.rgb, tint.rgb, blend);
}
"""

static var _shader: Shader

var kind := ""
var level := 1
var stats: Dictionary = {}
var home := Vector2.ZERO
var traits: Array = []
var boss := false
var hp := 0.0
var alive := true
var attack_cooldown := 0.8
## В подземелье монстры видят героя через всю арену и не возвращаются домой.
var aggro_range := 150.0
var leash_range := 320.0
var shield := 0.0
var enraged := false

var _body := Sprite2D.new()
var _bar := HPBar.new()
var _shield_bar: HPBar
var _material := ShaderMaterial.new()
var _idle := PackedInt32Array()
var _move := PackedInt32Array()
var _hurt := PackedInt32Array()
var _death := PackedInt32Array()
var _goal := Vector2.ZERO
var _wait := randf_range(0.5, 2.5)
var _chasing := false
var _showing := -1
var _bar_time := 0.0
var _knock := Vector2.ZERO
var _base_scale := 1.0
var _flip := 1.0
var _tint = null              ## Color или null
# Кадры: что крутится сейчас
var _anim := PackedInt32Array()
var _anim_fps := 6.0
var _anim_loop := true
var _anim_clock := 0.0
var _hurt_left := 0.0
var _color_tween: Tween
var _move_tween: Tween
var _bar_tween: Tween
# Замах перед укусом: герой успевает отойти
var _windup := 0.0
# Щит, ярость, восстановление
var _shield_max := 0.0
var _since_hit := 99.0
# Эффекты от оружия героя
var _poison_left := 0.0
var _poison_dps := 0.0
var _dot_tick := 0.0
var _slow_left := 0.0
var _slow_factor := 1.0
var _stun_left := 0.0


func _init(monster: String, monster_level: int, point: Vector2, monster_traits: Array = [], is_boss := false,
		tint = null) -> void:
	kind = monster
	level = monster_level
	traits = monster_traits
	boss = is_boss
	_tint = tint
	stats = Monsters.stats(kind, level, boss, traits)
	hp = float(stats["hp"])
	home = point
	_goal = point
	position = point
	if _shader == null:
		_shader = Shader.new()
		_shader.code = TINT_SHADER
	_material.shader = _shader
	_body.material = _material
	_body.centered = false
	_base_scale = 1.8 if boss else 1.0
	var sh := Monsters.sheet(kind)
	var cell: float = sh["cell"]
	var tex := Sprites.texture(Monsters.sprite(kind))
	if tex != null:
		_body.texture = tex
		_body.hframes = maxi(1, int(tex.get_width() / cell))
		_body.vframes = maxi(1, int(tex.get_height() / cell))
		var total := _body.hframes * _body.vframes
		var cols := int(sh["cols"])
		_idle = _frames(sh["idle"], cols, total)
		_move = _frames(sh["move"], cols, total)
		if sh["hurt"] != null:
			_hurt = _frames(sh["hurt"], cols, total)
		_death = _frames(sh["death"], cols, total)
		_body.offset = Sprites.anchor_offset(Sprites.anchor(Monsters.sprite(kind)), Vector2(cell, cell))
		_body.scale = Vector2.ONE * Sprites.SCALE * _base_scale
	else:
		# Спрайта нет: значок вида
		var ic := Sprites.icon("slime" if Monsters.is_slime(kind) else "skull")
		_body.texture = ic
		if ic != null:
			_body.offset = Sprites.anchor_offset(Vector2(0.5, 0.1), ic.get_size())
			_body.scale = Vector2.ONE * 34.0 / float(maxi(1, ic.get_width())) * _base_scale
	add_child(_body)
	var rest := _rest()
	_material.set_shader_parameter("tint", rest[0])
	_material.set_shader_parameter("blend", rest[1])
	var k := 1.5 if boss else 1.0
	var bar_y: float = float(sh["bar"]) * _base_scale
	_bar.position = Vector2(0, -bar_y)
	_bar.modulate.a = 1.0 if boss or not traits.is_empty() else 0.0
	_bar.z_index = 5
	if boss:
		_bar.scale = Vector2.ONE * 1.5
	add_child(_bar)
	if "shield" in traits:
		_shield_max = float(stats["hp"]) * 0.25
		shield = _shield_max
		_shield_bar = HPBar.new()
		_shield_bar.fixed_color = Color(0.55, 0.8, 1)
		_shield_bar.position = Vector2(0, -(bar_y + 7.0 * k))
		_shield_bar.z_index = 5
		_shield_bar.scale = Vector2.ONE * k
		add_child(_shield_bar)
	# Значки свойств над полоской здоровья
	var count := float(traits.size())
	for i in traits.size():
		var itex := Sprites.icon(Monsters.trait_icon(traits[i]))
		if itex == null:
			continue
		var icon := Sprite2D.new()
		icon.texture = itex
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.scale = Vector2.ONE * 12.0 / float(maxi(1, itex.get_width()))
		icon.position = Vector2((float(i) - (count - 1.0) / 2.0) * 13.0, -(bar_y + (11.0 if _shield_bar == null else 18.0) * k))
		icon.z_index = 6
		add_child(icon)
	_play(_idle, 0, 6.0)
	scale = Vector2.ONE * 0.2


func _ready() -> void:
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.3)


static func _frames(spec: Dictionary, cols: int, total: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var start := int(spec["row"]) * cols
	var range_: Array = spec["frames"]
	for f in range(int(range_[0]), int(range_[1])):
		if start + f < total:
			out.append(start + f)
	return out


# MARK: Кадры и цвет

func _play(frames: PackedInt32Array, key: int, fps: float) -> void:
	if _showing == key or frames.is_empty():
		return
	_showing = key
	_set_anim(frames, fps, true)


func _set_anim(frames: PackedInt32Array, fps: float, loop: bool) -> void:
	_anim = frames
	_anim_fps = fps
	_anim_loop = loop
	_anim_clock = 0.0
	if not frames.is_empty():
		_body.frame = frames[0]


func _process(delta: float) -> void:
	if _hurt_left > 0.0:
		_hurt_left -= delta
	if _anim.size() <= 1:
		return
	_anim_clock += delta * _anim_fps
	var i := int(_anim_clock)
	if _anim_loop:
		i %= _anim.size()
	else:
		i = mini(i, _anim.size() - 1)
	_body.frame = _anim[i]


## Обычный цвет: окраска босса или без окраски.
func _rest() -> Array:
	return [_tint if _tint is Color else Color.WHITE, 0.55 if _tint is Color else 0.0]


## Цепочка перекрасок: [цвет, доля, секунды]; цвет null - пауза.
func _colorize(steps: Array) -> void:
	if not is_inside_tree():
		return
	if _color_tween != null and _color_tween.is_valid():
		_color_tween.kill()
	_color_tween = create_tween()
	for s in steps:
		if s[0] == null:
			_color_tween.tween_interval(float(s[2]))
			continue
		_color_tween.tween_property(_material, "shader_parameter/tint", s[0], float(s[2]))
		_color_tween.parallel().tween_property(_material, "shader_parameter/blend", float(s[1]), float(s[2]))


## Рывок рисунка: туда и обратно.
func _nudge(offset: Vector2, there: float, back: float) -> void:
	if not is_inside_tree():
		return
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	_body.position = Vector2.ZERO
	_move_tween = create_tween()
	_move_tween.tween_property(_body, "position", offset, there)
	_move_tween.tween_property(_body, "position", Vector2.ZERO, back)


func _show_bar() -> void:
	if _bar_tween != null and _bar_tween.is_valid():
		_bar_tween.kill()
	_bar.modulate.a = 1.0
	_bar_time = 2.0


func _speed_mult() -> float:
	var m := 1.0
	if "swift" in traits:
		m *= 1.4
	if enraged:
		m *= 1.3
	if _slow_left > 0.0:
		m *= _slow_factor
	return m


# MARK: Шаг

## Урон от яда и ожога за этот кадр (сцена списывает его как обычный урон).
func tick_effects(dt: float) -> float:
	if not alive:
		return 0.0
	_since_hit += dt
	_slow_left = maxf(0.0, _slow_left - dt)
	_stun_left = maxf(0.0, _stun_left - dt)
	var max_hp := float(stats["hp"])
	# Регенерация и щит восстанавливаются, если по монстру давно не били.
	if "regen" in traits and _since_hit > 2.0 and hp < max_hp:
		hp = minf(max_hp, hp + max_hp * 0.02 * dt)
		_bar.set_fraction(hp / max_hp)
	if _shield_max > 0.0 and _since_hit > 6.0 and shield < _shield_max:
		shield = minf(_shield_max, shield + _shield_max * 0.25 * dt)
		if _shield_bar != null:
			_shield_bar.set_fraction(shield / _shield_max)
	if _poison_left <= 0.0:
		return 0.0
	_poison_left -= dt
	_dot_tick -= dt
	if _dot_tick > 0.0:
		return 0.0
	_dot_tick = 0.5
	return _poison_dps * 0.5


## Шаг монстра. walkable(точка) -> bool проверяет, можно ли стоять в точке.
## Возвращает укус, если монстр закончил замах рядом с героем, иначе null.
func update(dt: float, hero: Vector2, walkable: Callable) -> Variant:
	if not alive:
		return null
	attack_cooldown -= dt
	if _bar_time > 0.0 and not boss and traits.is_empty():
		_bar_time -= dt
		if _bar_time <= 0.0:
			_bar_tween = create_tween()
			_bar_tween.tween_property(_bar, "modulate:a", 0.0, 0.3)
	if _stun_left > 0.0:
		return null
	var to_hero := position.distance_to(hero)
	var from_home := position.distance_to(home)

	# Замах: стоим и наливаемся красным, потом кусаем, если герой не отошёл.
	if _windup > 0.0:
		_windup -= dt
		if _windup <= 0.0:
			var rest := _rest()
			_colorize([[rest[0], rest[1], 0.08]])
			attack_cooldown = 1.1
			if to_hero >= BITE_RANGE + 10.0:
				return null
			var crit := "crit" in traits and randf() < 0.2
			var damage := float(stats["damage"]) * (1.5 if enraged else 1.0)
			if crit:
				damage *= 2.0
			_nudge((hero - position) * 0.15, 0.06, 0.1)
			return {"damage": damage, "crit": crit, "traits": traits}
		return null

	if _chasing:
		if from_home > leash_range or to_hero > aggro_range * 1.8:
			_chasing = false
			_goal = home
	elif to_hero < aggro_range and hero.distance_to(home) < leash_range:
		_chasing = true
	if _chasing:
		_goal = hero

	var step := Vector2.ZERO
	var d := position.distance_to(_goal)
	if d > (22.0 if _chasing else 4.0):
		var speed := float(stats["speed"]) * _speed_mult() * (1.25 if _chasing else 0.6)
		step = (_goal - position) / d * speed * dt
	elif not _chasing:
		_wait -= dt
		if _wait <= 0.0:
			_wait = randf_range(1.5, 4.0)
			var a := randf() * TAU
			var r := randf_range(20.0, 90.0)
			var p := home + Vector2(cos(a), sin(a)) * r
			if walkable.call(p):
				_goal = p
	# Отбрасывание после удара
	step += _knock * dt
	_knock *= exp(-dt * 10.0)
	var next := position + step
	if walkable.call(next):
		position = next
	var moving := step.length() > 0.2
	if _hurt_left <= 0.0:
		_play(_move if moving else _idle, 1 if moving else 0, 10.0 if moving else 6.0)
	if absf(step.x) > 0.1:
		_flip = -1.0 if step.x < 0.0 else 1.0
		_body.scale.x = absf(_body.scale.x) * _flip
	if _chasing and to_hero < BITE_RANGE and attack_cooldown <= 0.0:
		_windup = WINDUP_TIME
		_colorize([[Color(1, 0.25, 0.2), 0.7, WINDUP_TIME * 0.8]])
	return null


# MARK: Удары по монстру

## Получить урон. Уклонение и щит срабатывают здесь.
func hit(damage: float, from: Vector2, can_dodge := true) -> Hit:
	if not alive:
		return Hit.DAMAGED
	_since_hit = 0.0
	_chasing = true
	if can_dodge and "dodge" in traits and randf() < 0.2:
		_nudge(Vector2(8, 0), 0.06, 0.1)
		return Hit.DODGED
	var left := damage
	if shield > 0.0:
		var absorbed := minf(shield, left)
		shield -= absorbed
		left -= absorbed
		if _shield_bar != null:
			_shield_bar.set_fraction(shield / maxf(1.0, _shield_max))
	var max_hp := float(stats["hp"])
	hp -= left
	_bar.set_fraction(hp / max_hp)
	_show_bar()
	if "enrage" in traits and not enraged and hp < max_hp * 0.4 and hp > 0.0:
		enraged = true
		var red := RingFx.new()
		red.radius = 23.0 * _base_scale
		red.width = 3.0
		red.scale = Vector2(1.0, 22.0 / 46.0)
		red.color = Color(1, 0.2, 0.1)
		red.modulate.a = 0.6
		add_child(red)
		move_child(red, 0)
		var pulse := red.create_tween().set_loops()
		pulse.tween_property(red, "modulate:a", 0.2, 0.4)
		pulse.tween_property(red, "modulate:a", 0.6, 0.4)
	var d := maxf(1.0, from.distance_to(position))
	var push := 60.0 if boss else 260.0
	_knock = (position - from) / d * push
	if not _hurt.is_empty():
		_showing = -1
		_set_anim(_hurt, 1.0 / 0.06, false)
		_hurt_left = _hurt.size() * 0.06
	var rest := _rest()
	_colorize([[Color.WHITE, 0.8, 0.03], [rest[0], rest[1], 0.12]])
	if hp <= 0.0:
		_die()
		return Hit.KILLED
	return Hit.DAMAGED


func _die() -> void:
	alive = false
	_bar.queue_free()
	if _shield_bar != null:
		_shield_bar.queue_free()
		_shield_bar = null
	if _color_tween != null and _color_tween.is_valid():
		_color_tween.kill()
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	_hurt_left = 0.0
	var tw := create_tween()
	if _death.is_empty():
		_anim = PackedInt32Array()
		tw.tween_callback(func() -> void: _body.create_tween().tween_property(_body, "modulate:a", 0.0, 0.3))
	else:
		tw.tween_callback(func() -> void: _set_anim(_death, 1.0 / 0.08, false))
	tw.tween_interval(0.5)
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)


## Восстановить здоровье (вампиризм).
func heal(amount: float) -> void:
	if not alive:
		return
	hp = minf(float(stats["hp"]), hp + amount)
	_bar.set_fraction(hp / float(stats["hp"]))


func apply_poison(dps: float, seconds: float) -> void:
	_poison_dps = maxf(_poison_dps, dps)
	_poison_left = maxf(_poison_left, seconds)
	var rest := _rest()
	_colorize([[Color(0.4, 1, 0.3), 0.6, 0.1], [rest[0], rest[1], 0.4]])


func apply_slow(factor: float, seconds: float) -> void:
	_slow_factor = factor
	_slow_left = maxf(_slow_left, seconds)
	var rest := _rest()
	_colorize([[Color(0.5, 0.8, 1), 0.6, 0.1], [rest[0], rest[1], 0.6]])


func stun(seconds: float) -> void:
	_stun_left = maxf(_stun_left, seconds)
	_windup = 0.0


func hp_fraction() -> float:
	return maxf(0.0, hp / float(stats["hp"]))
