class_name ScreenFade
extends CanvasLayer
## Затемнение экрана внутри сцены (как fader в GameScene): обморок героя, спуск на следующий этаж.
## ScreenFade.run(world, середина, затемнение, пауза, проявление, конец) - слой сам удаляется.

var _rect := ColorRect.new()


static func run(parent: Node, middle: Callable, fade_in := 0.3, hold := 0.1, fade_out := 0.45,
		done := Callable()) -> void:
	var f := ScreenFade.new()
	parent.add_child(f)
	var tw := f.create_tween()
	tw.tween_property(f._rect, "modulate:a", 1.0, fade_in).set_ease(Tween.EASE_IN)
	tw.tween_callback(middle)
	tw.tween_interval(hold)
	tw.tween_property(f._rect, "modulate:a", 0.0, fade_out).set_ease(Tween.EASE_OUT)
	if done.is_valid():
		tw.tween_callback(done)
	tw.tween_callback(f.queue_free)


func _init() -> void:
	layer = 50
	_rect.color = Color.BLACK
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.modulate.a = 0.0
	add_child(_rect)
