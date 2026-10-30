class_name CosmeticsFeature
extends WorldFeature
## Украшения за покупки: сияние вокруг героя и светящийся след (aura), переливающаяся одежда (rainbow),
## подсветка питомцев (petGlow). Светящаяся ночная поляна (glowMeadow) - в AtmosphereFeature.
## Раз в секунду сверяется с настройками, чтобы включение и выключение работало сразу.

const RAINBOW_SHADER := """shader_type canvas_item;
uniform float speed = 0.35;
vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}
vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}
void fragment() {
	vec4 col = texture(TEXTURE, UV);
	vec3 hsv = rgb2hsv(col.rgb);
	// Переливаются только яркие цветные пиксели (одежда), кожа и контур почти не меняются
	float w = smoothstep(0.42, 0.62, hsv.y) * step(0.25, hsv.z);
	vec3 shifted = hsv2rgb(vec3(fract(hsv.x + TIME * speed + UV.y * 1.5), max(hsv.y, 0.6), hsv.z));
	COLOR = vec4(mix(col.rgb, shifted, w), col.a);
}
"""

var _key := ""
var _aura: Node2D
var _tick := 0.0
static var _rainbow: ShaderMaterial


func build(world: World) -> void:
	_key = ""
	_aura = null
	_apply(world)


func clear(_w: World) -> void:
	_aura = null
	_key = ""


func process(world: World, dt: float) -> void:
	_tick -= dt
	if _tick > 0.0:
		return
	_tick = 1.0
	_apply(world)


func _apply(world: World) -> void:
	var aura := Settings.cosmetic("aura")
	var rainbow := Settings.cosmetic("rainbow")
	var pets := Settings.cosmetic("petGlow")
	var key := "%s|%s|%s" % [aura, rainbow, pets]
	if key != _key:
		_key = key
		_set_aura(world, aura)
		world.player.body.material = _rainbow_material() if rainbow else null
		for n in world.entities.get_children():
			if n is CompanionNode and n.has_meta("glow") and not pets:
				var g: Node = n.get_meta("glow")
				if is_instance_valid(g):
					g.queue_free()
				n.remove_meta("glow")
	# Новые питомцы появляются по ходу игры
	if pets:
		for n in world.entities.get_children():
			if n is CompanionNode and not n.has_meta("glow"):
				var g := Fx.glow(Color(0.55, 1.0, 0.75), 70.0, -8.0, 0.5)
				g.z_index = -1
				n.add_child(g)
				n.set_meta("glow", g)


static func _rainbow_material() -> ShaderMaterial:
	if _rainbow == null:
		var sh := Shader.new()
		sh.code = RAINBOW_SHADER
		_rainbow = ShaderMaterial.new()
		_rainbow.shader = sh
	return _rainbow


## Сияние: мягкий золотой ореол за героем и искры, которые остаются позади, когда он идёт.
func _set_aura(world: World, on: bool) -> void:
	if _aura != null and is_instance_valid(_aura):
		_aura.queue_free()
	_aura = null
	if not on:
		return
	_aura = Node2D.new()
	_aura.z_index = -1
	world.player.add_child(_aura)
	var halo := Fx.glow(Color(1.0, 0.85, 0.35), 110.0, -26.0, 0.45)
	_aura.add_child(halo)
	var tw := halo.create_tween().set_loops()
	tw.tween_property(halo, "modulate:a", 0.25, 1.1).set_trans(Tween.TRANS_SINE)
	tw.tween_property(halo, "modulate:a", 0.5, 1.1).set_trans(Tween.TRANS_SINE)
	var p := CPUParticles2D.new()
	p.texture = Fx.glow_texture()
	p.amount = 18
	p.lifetime = 1.1
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 14.0
	p.position = Vector2(0, -18)
	p.direction = Vector2(0, -1)
	p.spread = 60.0
	p.gravity = Vector2(0, -18)
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 16.0
	p.scale_amount_min = 0.08
	p.scale_amount_max = 0.16
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.6, 0.9))
	ramp.set_color(1, Color(1.0, 0.6, 0.9, 0.0))
	p.color_ramp = ramp
	p.z_index = 30
	_aura.add_child(p)
