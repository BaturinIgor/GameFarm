class_name Consumables
## Расходники для боя (кроме зелья лечения): эликсиры силы, защиты и скорости, бомба и свиток второго шанса.
## Открываются по уровню, продаются у алхимика (центр сражений) за монеты, иногда выпадают из сундука подземелья.
## Эликсиры и бомба - кнопками в бою рядом с зельем, свиток срабатывает сам, когда здоровье кончается.

const IDS := ["strength", "guard", "swift", "bomb", "revive"]

## level - с какого уровня продаётся, price - во сколько раз дороже зелья лечения, duration - секунд действия,
## power - сила: доля для эликсиров, множитель удара для бомбы, доля здоровья для свитка.
## hue - сдвиг цвета красной колбы зелья, mark - значок на колбе.
const SPECS := {
	"strength": {"level": 8, "price": 3.0, "duration": 60.0, "power": 0.3, "hue": 0.08, "mark": "fist", "tone": "orange"},
	"guard": {"level": 10, "price": 3.0, "duration": 60.0, "power": 0.4, "hue": 0.6, "mark": "shield", "tone": "blue"},
	"swift": {"level": 12, "price": 2.0, "duration": 45.0, "power": 0.3, "hue": 0.36, "mark": "wind", "tone": "green"},
	"bomb": {"level": 15, "price": 4.0, "radius": 150.0, "power": 4.0, "tone": "gray"},
	"revive": {"level": 18, "price": 8.0, "power": 0.5, "tone": "gold"},
}

## Бестиарий: сколько побед над видом монстра нужно для ступени и сколько кристаллов за неё.
## Каждая ступень ещё и +5% урона по этому виду.
const BESTIARY_TIERS := [25, 100, 500]
const BESTIARY_CRYSTALS := [5, 15, 40]
const BESTIARY_DAMAGE := 0.05

static var _hue_shader: Shader


static func spec(id: String) -> Dictionary:
	return SPECS.get(id, {})


static func is_elixir(id: String) -> bool:
	return spec(id).has("duration")


## Нажимается в бою (свиток - нет, он срабатывает сам).
static func usable(id: String) -> bool:
	return id != "revive"


static func level(id: String) -> int:
	return int(spec(id).get("level", 1))


static func price(id: String, hero_level: int) -> int:
	return int(round(float(Dungeons.potion_price(hero_level)) * float(spec(id).get("price", 1.0))))


static func name_of(id: String) -> String:
	return L.t("item." + id)


## Что делает: с числами из таблицы.
static func info(id: String) -> String:
	var s := spec(id)
	match id:
		"strength", "guard", "swift":
			return L.t("item." + id + ".info", [Fmt.pct(float(s["power"])), int(s["duration"])])
		"bomb":
			return L.t("item.bomb.info", [int(float(s["power"]) * 100.0)])
		"revive":
			return L.t("item.revive.info", [Fmt.pct(float(s["power"]))])
	return ""


# MARK: Значки

## Значок расходника: цветная колба со значком (эликсиры), бомба, свиток с сердцем.
static func icon(id: String, side: float) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(side, side)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := spec(id)
	if is_elixir(id):
		var flask := UiKit.icon("potion", side)
		flask.material = hue_material(float(s["hue"]))
		flask.size = Vector2(side, side)
		holder.add_child(flask)
		_badge(holder, str(s["mark"]), side)
	elif id == "bomb":
		var bomb := BombIcon.new()
		bomb.size = Vector2(side, side)
		bomb.custom_minimum_size = Vector2(side, side)
		holder.add_child(bomb)
	elif id == "revive":
		var scroll := UiKit.icon("scroll2", side)
		scroll.size = Vector2(side, side)
		holder.add_child(scroll)
		_badge(holder, "heart_plus", side)
	else:
		holder.add_child(UiKit.icon("potion", side))
	return holder


static func _badge(holder: Control, icon_name: String, side: float) -> void:
	var k := side * 0.48
	var b := UiKit.icon(icon_name, k)
	b.position = Vector2(side - k * 0.9, side - k * 0.95)
	b.size = Vector2(k, k)
	holder.add_child(b)


## Сдвиг цвета: красная колба зелья становится оранжевой, синей или зелёной. Контур и блики не трогаем.
static func hue_material(shift: float) -> ShaderMaterial:
	if _hue_shader == null:
		_hue_shader = Shader.new()
		_hue_shader.code = """
shader_type canvas_item;
uniform float shift = 0.0;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	vec3 hsv = rgb2hsv(t.rgb);
	if (hsv.y > 0.25) {
		hsv.x = fract(hsv.x + shift);
	}
	COLOR = vec4(hsv2rgb(hsv), t.a) * COLOR;
}
"""
	var m := ShaderMaterial.new()
	m.shader = _hue_shader
	m.set_shader_parameter("shift", shift)
	return m


## Бомба: тёмный шар с бликом, фитиль и искра (в наборе спрайтов бомбы нет).
class BombIcon extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var side := minf(size.x, size.y)
		var c := Vector2(side * 0.46, side * 0.58)
		var r := side * 0.34
		draw_circle(c, r + 1.5, UiKit.OUTLINE)
		draw_circle(c, r, Color("3a3f4b"))
		draw_circle(c + Vector2(-r * 0.35, -r * 0.35), r * 0.28, Color(1, 1, 1, 0.35))
		# Горлышко и фитиль
		var neck := Rect2(c + Vector2(r * 0.35, -r * 1.05), Vector2(r * 0.5, r * 0.4))
		draw_rect(neck.grow(1.2), UiKit.OUTLINE)
		draw_rect(neck, Color("6b7080"))
		var a := neck.position + Vector2(neck.size.x * 0.5, 0)
		var b := a + Vector2(side * 0.12, -side * 0.12)
		draw_line(a, b, Color("c98a1b"), maxf(1.5, side * 0.05), true)
		draw_circle(b, side * 0.08, Color("ffb04a"))
		draw_circle(b, side * 0.04, Color("fff3c4"))
