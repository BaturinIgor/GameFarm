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

## Середина фигуры героя над точкой ног (в точках мира).
const HERO_MID := 18.0

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
				var g := Fx.glow(Color(0.55, 1.0, 0.75), 70.0, 12.0, 0.5)
				g.z_index = -1
				n.add_child(g)
				n.set_meta("glow", g)


## Кольцо: прозрачная середина, яркая полоса ближе к краю, мягкий спад наружу.
static var _ring: Texture2D


static func _ring_texture() -> Texture2D:
	if _ring == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.5, 0.8, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.1), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_ring = t
	return _ring


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
	# Ореол - светлое кольцо вокруг героя (в середине почти прозрачное, чтобы не было яркого пятна),
	# центр - середина фигуры (рисунок от 40 точек над ногами до ног), а не точка у ног
	var halo := Sprite2D.new()
	halo.texture = _ring_texture()
	halo.scale = Vector2.ONE * 92.0 / 128.0
	halo.position = Vector2(0, -HERO_MID)
	halo.modulate = Color(1.0, 0.85, 0.4, 0.5)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	halo.material = mat
	_aura.add_child(halo)
	var tw := halo.create_tween().set_loops()
	tw.tween_property(halo, "modulate:a", 0.3, 1.3).set_trans(Tween.TRANS_SINE)
	tw.tween_property(halo, "modulate:a", 0.55, 1.3).set_trans(Tween.TRANS_SINE)
	var p := CPUParticles2D.new()
	p.texture = Fx.glow_texture()
	p.amount = 12
	p.lifetime = 1.1
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 14.0
	p.position = Vector2(0, -HERO_MID)
	p.direction = Vector2(0, -1)
	p.spread = 60.0
	p.gravity = Vector2(0, -18)
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 16.0
	p.scale_amount_min = 0.08
	p.scale_amount_max = 0.16
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.6, 0.7))
	ramp.set_color(1, Color(1.0, 0.6, 0.9, 0.0))
	p.color_ramp = ramp
	p.z_index = 30
	_aura.add_child(p)
