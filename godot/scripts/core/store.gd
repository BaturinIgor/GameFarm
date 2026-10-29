class_name Store
## Покупки (порт Store.swift, ветка SIDELOAD). Сборка Android ставится не из магазина, поэтому покупки
## тестовые: выдаются сразу и бесплатно, тост говорит, что это тест.

## Что сейчас покупается ("" - ничего): кнопки показывают часы и не нажимаются.
static var busy := ""


static func price(product: String) -> String:
	return Products.price(product)


static func buy(product: String) -> void:
	if busy != "" or Products.key(product) == "":
		return
	busy = Products.key(product)
	Game.changed.emit()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_finish(product)
		return
	tree.create_timer(0.5).timeout.connect(func() -> void: Store._finish(product))


static func _finish(product: String) -> void:
	busy = ""
	Game.premium.grant(product)
	Game.show_toast("px:potion", L.t("shop.testPurchase"))
	Game.changed.emit()


## Восстановить покупки: в тестовой сборке восстанавливать нечего.
static func restore() -> void:
	Game.show_toast("px:potion", L.t("shop.testRestore"))
