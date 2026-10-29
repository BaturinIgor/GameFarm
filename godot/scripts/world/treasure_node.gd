class_name TreasureNode
extends Node2D
## Клад: появляется время от времени, открывается, если подойти (порт TreasureNode).

## Сколько секунд ещё лежит на карте.
var life: float


func _init(point: Vector2, life_seconds: float) -> void:
	position = point
	life = life_seconds


func _ready() -> void:
	var glow := Fx.glow(Color(1, 0.8, 0.2), 110.0, 16.0, 0.6)
	add_child(glow)
	_pulse(glow, 0.6)

	# Сундук покачивается вверх-вниз и время от времени дёргается
	var holder := Node2D.new()
	add_child(holder)
	var box: Node2D = Sprites.make("chest_gold_anim")
	if box == null:
		var tex := Sprites.icon("chest_gold")
		var s := Sprite2D.new()
		s.texture = tex
		if tex != null:
			s.scale = Vector2.ONE * 40.0 / float(tex.get_width())
		s.position = Vector2(0, -20)
		box = s
	holder.add_child(box)
	var wobble := box.create_tween().set_loops()
	wobble.tween_property(box, "rotation", 0.12, 0.12)
	wobble.tween_property(box, "rotation", -0.12, 0.12)
	wobble.tween_property(box, "rotation", 0.0, 0.1)
	wobble.tween_interval(1.4)
	var start := holder.create_tween()
	start.tween_interval(randf() * 0.7)
	start.tween_callback(func() -> void:
		var bob := holder.create_tween().set_loops()
		bob.tween_property(holder, "position:y", -3.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bob.tween_property(holder, "position:y", 0.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT))

	# Три искорки над сундуком
	var spark := Sprites.icon("spark")
	for i in 3:
		var s := Sprite2D.new()
		s.texture = spark if spark != null else Fx.glow_texture()
		var k := 12.0 / float(maxi(1, s.texture.get_width()))
		s.scale = Vector2.ONE * k
		s.position = Vector2((i - 1) * 18.0, -(42.0 + (i % 2) * 8.0))
		s.modulate.a = 0.0
		add_child(s)
		var delay := s.create_tween()
		delay.tween_interval(i * 0.4)
		delay.tween_callback(_twinkle.bind(s, k))

	# Появляется из точки
	scale = Vector2.ONE * 0.1
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _pulse(node: CanvasItem, alpha: float) -> void:
	var tw := node.create_tween().set_loops()
	tw.tween_property(node, "modulate:a", alpha * 0.5, randf_range(1.1, 1.6)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, "modulate:a", alpha, randf_range(1.1, 1.6)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _twinkle(s: Sprite2D, k: float) -> void:
	var tw := s.create_tween().set_loops()
	tw.tween_property(s, "modulate:a", 1.0, 0.3)
	tw.parallel().tween_property(s, "scale", Vector2.ONE * k * 1.2, 0.3)
	tw.tween_property(s, "modulate:a", 0.0, 0.5)
	tw.parallel().tween_property(s, "scale", Vector2.ONE * k * 0.6, 0.5)
	tw.tween_interval(0.4)


## Время вышло: тает и пропадает.
func vanish() -> void:
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_property(self, "scale", Vector2.ONE * 0.3, 0.4)
	tw.chain().tween_callback(queue_free)


## Открыт: подпрыгивает и исчезает.
func burst() -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE * 1.4, 0.12)
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.parallel().tween_property(self, "scale", Vector2.ONE * 0.2, 0.2)
	tw.tween_callback(queue_free)
