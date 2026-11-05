class_name Store
## Покупки через App Store: плагин InAppStore из godot-ios-plugins (StoreKit), его собирает ios-godot.yml.
## Плагина нет (Android, ПК, тесты, редактор) - LIVE = false: цен в долларах, наборов, пропуска и
## восстановления нет, магазин работает только за кристаллы, заработанные в игре.

## Настоящие покупки доступны: синглтон плагина регистрируется движком до загрузки скриптов.
static var LIVE: bool = Engine.has_singleton("InAppStore")

## Что сейчас покупается ("" - ничего): кнопки показывают часы и не нажимаются.
static var busy := ""

## Цены из App Store в валюте игрока (ключ покупки -> строка вроде "199,00 ₽").
static var _prices := {}
## Магазин ответил списком товаров: без этого StoreKit не даст купить.
static var _loaded := false
static var _requested_at := -100.0
static var _restoring := false
static var _poller: Timer


static func _plugin() -> Object:
	return Engine.get_singleton("InAppStore") if LIVE else null


## Запускается из Game._ready, когда сохранение уже загружено: незавершённые покупки с прошлого
## запуска StoreKit присылает сразу, и их надо выдать.
static func setup(host: Node) -> void:
	if not LIVE or _poller != null:
		return
	# Транзакцию закрываем сами, после выдачи и сохранения: если игра упадёт раньше, покупка придёт снова
	_plugin().set_auto_finish_transaction(false)
	_poller = Timer.new()
	_poller.wait_time = 0.25
	_poller.autostart = true
	_poller.process_mode = Node.PROCESS_MODE_ALWAYS
	_poller.timeout.connect(Store._poll)
	host.add_child(_poller)
	_request_info()


static func _request_info() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _requested_at < 10.0:
		return
	_requested_at = now
	var ids := PackedStringArray()
	for k in Products.KEYS:
		ids.append(Products.id(k))
	_plugin().request_product_info({"product_ids": ids})


static func price(product: String) -> String:
	var k := Products.key(product)
	return str(_prices[k]) if _prices.has(k) else Products.price(product)


static func buy(product: String) -> void:
	var key := Products.key(product)
	if not LIVE or busy != "" or key == "":
		return
	if not _loaded:
		_request_info()
		Game.show_toast("px:potion", L.t("shop.unavailable"))
		return
	var err: int = _plugin().purchase({"product_id": Products.id(key)})
	if err != OK:
		Game.show_toast("px:potion", L.t("shop.unavailable" if err == ERR_UNAVAILABLE else "shop.error"))
		return
	busy = key
	Game.changed.emit()


## Восстановить покупки: App Store присылает все купленные навсегда наборы заново.
static func restore() -> void:
	if not LIVE or _restoring:
		return
	_restoring = true
	_plugin().restore_purchases()


static func _poll() -> void:
	var p := _plugin()
	if p == null:
		return
	while p.get_pending_event_count() > 0:
		var e = p.pop_pending_event()
		if e is Dictionary:
			_handle(e)


static func _handle(e: Dictionary) -> void:
	var type := str(e.get("type", ""))
	var result := str(e.get("result", ""))
	match type:
		"product_info":
			if result != "ok":
				return
			var ids: Array = e.get("ids", [])
			var prices: Array = e.get("localized_prices", [])
			for i in mini(ids.size(), prices.size()):
				var k := Products.key(str(ids[i]))
				if k != "" and str(prices[i]) != "":
					_prices[k] = str(prices[i])
			_loaded = not ids.is_empty()
			if not (e.get("invalid_ids", []) as Array).is_empty():
				push_warning("App Store не знает товары: %s" % str(e["invalid_ids"]))
			Game.changed.emit()
		"purchase":
			var pid := str(e.get("product_id", ""))
			match result:
				"ok":
					Game.premium.grant(pid, str(e.get("transaction_id", "")))
					Game.save_now()
					_plugin().finish_transaction(pid)
					_done(pid)
				"error":
					Game.show_toast("px:potion", L.t("shop.error"))
					_done(pid)
				"progress":
					# 4 - ждёт разрешения родителей (Попросить купить): кнопку освобождаем
					if int(e.get("type_code", 0)) == 4:
						_done(pid)
		"restore":
			match result:
				"ok":
					# Расходуемые не восстанавливаются: их уже выдали при покупке
					var pid := str(e.get("product_id", ""))
					if not Products.consumable(pid):
						Game.premium.grant(pid, str(e.get("transaction_id", "")))
				"completed":
					_restoring = false
					Game.show_toast("px:chest_gold", L.t("shop.restored"))
					Game.changed.emit()
				"error":
					_restoring = false
					Game.show_toast("px:potion", L.t("shop.error"))


static func _done(pid: String) -> void:
	if busy == "" or busy == Products.key(pid):
		busy = ""
	Game.changed.emit()
