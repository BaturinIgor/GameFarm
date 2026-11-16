class_name ShopPill
extends Button
## Квадратная кнопка магазина в правом столбце под монетами (порт shopPill из HUDView).
## Удача (x2) - отдельный кружок в ряду таймеров, срочный набор - кнопка «Горячее» (HotOfferPill).
## Новое предложение или кристаллы MAX - красная точка. Здесь же раз в полсекунды проверяется,
## не пора ли показать окно нового предложения (OfferPopup.check).

var _text: Label
var _dot: Control
var _tick := 0.0


func _init() -> void:
	_text = HudRound.square(self, UiKit.icon("chest", 30), Color(UiKit.WOOD, 0.95))
	HudRound.caption(_text, L.t("shop.short"))
	pressed.connect(func() -> void:
		if Hud.current != null:
			Hud.current.open_window(ShopPanel.new()))
	_dot = UiKit.count_badge(0)
	(_dot.get_child(0) as Label).text = "!"
	_dot.visible = false
	UiKit.pin_badge(_dot, self)
	L.language_changed.connect(func() -> void: HudRound.caption(_text, L.t("shop.short")))
	_refresh()


func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.5
	_refresh()
	OfferPopup.check()


## Ближайший конец срочного набора (стартовый или по уровню), 0 - таких нет.
static func urgent_until() -> float:
	var best := 0.0
	for o in Game.shop.current_offers():
		if o["product"] == "eventPass":
			continue
		var ends := ShopPanel.offer_ends(o["product"])
		if ends > 0.0 and (best == 0.0 or ends < best):
			best = ends
	return best


func _refresh() -> void:
	_dot.visible = Game.shop.has_news()
