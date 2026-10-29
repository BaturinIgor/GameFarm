class_name AnimSprite
extends Sprite2D
## Лента кадров, которая крутится сама (костёр, сундук, рыба под водой).

var fps := 8.0
var count := 1
var playing := true
var _clock := 0.0


func setup(frames: int, frames_per_second: float, random_start := true) -> void:
	count = maxi(1, frames)
	fps = frames_per_second
	if random_start:
		_clock = randf() * count


func _process(delta: float) -> void:
	if not playing or count <= 1:
		return
	_clock += delta * fps
	frame = int(_clock) % count


## Проиграть ленту один раз вперёд (или назад) и остановиться.
func play_once(reverse := false) -> void:
	playing = false
	var tw := create_tween()
	var from := 0 if not reverse else count - 1
	var to := count - 1 if not reverse else 0
	tw.tween_method(func(v: float) -> void: frame = int(round(v)), float(from), float(to), count * 0.05)
