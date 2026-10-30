extends Node
## Корень игры: мир, слой джойстика, интерфейс и затемнение при переходах.

var world: World
var hud: Hud


func _ready() -> void:
	# Проверка в CI: все скрипты загружаются
	if "--check-scripts" in OS.get_cmdline_user_args():
		get_tree().quit(1 if not CheckScripts.run().is_empty() else 0)
		return
	# Снимки в CI - на русском: длинные подписи лучше показывают, что не помещается
	if "--shots" in OS.get_cmdline_user_args():
		L.set_language("ru", false)
	var joy_layer := CanvasLayer.new()
	joy_layer.layer = 5
	var joystick := Joystick.new()
	joy_layer.add_child(joystick)

	world = World.new()
	world.joystick = joystick
	add_child(world)
	add_child(joy_layer)

	hud = Hud.new()
	add_child(hud)
	# Звери-производители работали, пока игры не было
	OfflineOverlay.check()
	CalendarPanel.check()
	OfferPopup.check()

	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 50
	var fader := ColorRect.new()
	fader.color = Color.BLACK
	fader.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fader.modulate.a = 0.0
	fader.visible = false
	fade_layer.add_child(fader)
	add_child(fade_layer)
	world.set_fader(fader)

	# Проверка в CI: снимки экрана по сценарию
	if "--shots" in OS.get_cmdline_user_args():
		var driver: Node = load("res://scripts/debug/shot_driver.gd").new()
		driver.main = self
		add_child(driver)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED:
		OfflineOverlay.check()
		CalendarPanel.check()
		Game.premium.repair_timers()
		OfferPopup.check()
