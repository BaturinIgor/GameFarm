class_name WandererPanel
extends Sheet
## Бродячий торговец (порт WandererView): три редких товара, пока он не ушёл.

const ICON_FILL := Color("ede2fa")

var _countdown: Label
var _tick := 0.0


func _init() -> void:
	title_key = "wanderer.title"


func build() -> void:
	var g := Game.garden
	var lines: Array = [UiKit.label(L.t("wanderer.hello"), 13)]
	_countdown = null
	if not g.wanderer.is_empty():
		_countdown = UiKit.label(_leaves_text(), 12, UiKit.TONES["purple"][2])
		lines.append(_countdown)
	content.add_child(TraderPanel.hello_row("wanderer", lines))
	if g.wanderer.is_empty():
		var c := TraderPanel.card_box(content)
		c.add_child(UiKit.label(L.t("wanderer.gone"), 14))
		return
	for offer in g.wanderer["offers"]:
		_row(offer)


func _process(delta: float) -> void:
	super(delta)
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 1.0
	if _countdown != null and is_instance_valid(_countdown) and not Game.garden.wanderer.is_empty():
		_countdown.text = _leaves_text()


func _leaves_text() -> String:
	var until := float(Game.garden.wanderer.get("until", 0.0))
	return L.t("wanderer.leaves", [TraderPanel.countdown(until - GardenSystem.now())])


## Товар (WandererRow): иконка, название, цена или галочка, если уже куплен.
func _row(offer: Dictionary) -> void:
	var g := Game.garden
	var bought := g.wanderer_bought(offer)
	var c := TraderPanel.card_box(content, Color(UiKit.WOOD_DARK, 0.45) if bought else Color(UiKit.TONES["purple"][1], 0.6),
		2 if bought else 3)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	c.add_child(row)
	var goods: Dictionary = offer["goods"]
	row.add_child(TraderPanel.icon_frame(_icon(goods), 30, ICON_FILL, Color(UiKit.OUTLINE, 0.6)))
	var title := UiKit.label(_title(goods), 15)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(title)
	if bought:
		row.add_child(TraderPanel.check_mark(22))
		return
	var price := int(offer["price"])
	var b := TraderPanel.coin_button("", price, "purple")
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.disabled = int(Game.save["coins"]) < price
	b.pressed.connect(func() -> void: Game.garden.buy_wanderer(offer))
	row.add_child(b)


func _icon(goods: Dictionary) -> String:
	match str(goods["type"]):
		"ticket": return "ticket"
		"map": return "tmap"
		"seeds": return Farming.seed_icon(str(goods["crop"]))
	return str(goods.get("kind", "bag"))


func _title(goods: Dictionary) -> String:
	match str(goods["type"]):
		"ticket": return L.t("wanderer.ticket")
		"map": return L.t("wanderer.map")
		"seeds": return "%s x%d" % [Farming.name_of(str(goods["crop"])), int(goods["n"])]
	return "%s x%d" % [Res.name_of(str(goods["kind"])), int(goods["n"])]
