class_name ChestsPanel
extends Sheet
## Сундуки: три сундука за свои ключи, гарантия, покупка ключа за кристаллы и таблица шансов.
## Открытие показывает ChestOverlay.

## Раскрыта ли таблица шансов.
var _odds := false


func _init() -> void:
	title_key = "chest.title"


func build() -> void:
	var hint := UiKit.label(L.t("chest.hint"), 12, UiKit.INK_SOFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(hint)
	for chest in Chests.IDS:
		_chest_card(chest)
	_odds_card()


## Значок сундука: крупный, в цвет сундука.
static func chest_icon(chest: String, size := 52.0) -> Control:
	var c := UiKit.crisp("px:" + str(Chests.spec(chest)["icon"]), size, size)
	c.modulate = Chests.TINT.get(chest, Color.WHITE)
	return c


static func key_icon(key: String, size := 16.0) -> TextureRect:
	var k := UiKit.icon("key", size)
	k.modulate = Chests.KEY_TINT.get(key, Color.WHITE)
	return k


func _chest_card(chest: String) -> void:
	var sys := Game.chests
	var key := Chests.key_of(chest)
	var have := sys.keys(key)
	var v := TraderPanel.card_box(content, Chests.color(str(Chests.spec(chest)["pity_rarity"])) if have > 0 \
		else Color(UiKit.WOOD_DARK, 0.45), 3 if have > 0 else 2)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var icon_box := CenterContainer.new()
	icon_box.custom_minimum_size = Vector2(60, 60)
	icon_box.add_child(chest_icon(chest))
	row.add_child(icon_box)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 3)
	row.add_child(col)
	col.add_child(UiKit.label(Chests.name_of(chest), 16))
	var keys_row := HBoxContainer.new()
	keys_row.add_theme_constant_override("separation", 4)
	keys_row.add_child(key_icon(key))
	keys_row.add_child(UiKit.label(L.t("chest.keys", [Chests.key_name(key), have]), 13))
	col.add_child(keys_row)
	# Гарантия: через сколько сундуков редкость не ниже
	var guard := str(Chests.spec(chest)["pity_rarity"])
	var pity := UiKit.label(L.t("chest.pity", [Chests.rarity_name(guard), sys.pity_left(chest)]), 11,
		Chests.color(guard).darkened(0.35))
	pity.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(pity)

	# Кнопки одинаковой ширины: открыть, открыть сразу несколько, купить ключ
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	v.add_child(buttons)
	var open_b := UiKit.button(L.t("chest.open"), "green" if have > 0 else "gray", 14, true)
	open_b.disabled = have <= 0
	open_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open_b.pressed.connect(func() -> void: _open(chest, 1))
	buttons.add_child(open_b)
	var many := mini(ChestSystem.MULTI, have)
	var multi_b := UiKit.button(L.t("chest.openN", [maxi(2, many)]), "orange" if many >= 2 else "gray", 14, true)
	multi_b.disabled = many < 2
	multi_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	multi_b.pressed.connect(func() -> void: _open(chest, ChestSystem.MULTI))
	buttons.add_child(multi_b)
	var price := sys.key_price(chest)
	var buy := UiKit.button("", "blue" if Game.shop.crystals() >= price else "gray", 14, true)
	buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var buy_row := HBoxContainer.new()
	buy_row.add_theme_constant_override("separation", 3)
	buy_row.alignment = BoxContainer.ALIGNMENT_CENTER
	buy_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buy_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	buy_row.add_child(key_icon(key, 14))
	buy_row.add_child(UiKit.title("+1", 13))
	buy_row.add_child(UiKit.icon("gem", 14))
	buy_row.add_child(UiKit.title(str(price), 13))
	buy.add_child(buy_row)
	buy.pressed.connect(func() -> void:
		if not Game.chests.buy_key(chest):
			Sound.play("error")
			Game.show_toast("px:gem", L.t("chest.noCrystals")))
	buttons.add_child(buy)


func _open(chest: String, count: int) -> void:
	var rewards := Game.chests.open(chest, count)
	if rewards.is_empty():
		return
	ChestOverlay.show_rewards(chest, rewards)


# MARK: Шансы

func _odds_card() -> void:
	var v := TraderPanel.card_box(content)
	var head := UiKit.button(L.t("chest.odds") + ("  -" if _odds else "  +"), "wood", 13, true)
	head.pressed.connect(func() -> void:
		_odds = not _odds
		_dirty = true)
	v.add_child(head)
	if not _odds:
		return
	var grid := GridContainer.new()
	grid.columns = 1 + Chests.IDS.size()
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	v.add_child(grid)
	grid.add_child(UiKit.label("", 11))
	for chest in Chests.IDS:
		var h := UiKit.label(Chests.name_of(chest), 11, UiKit.INK_SOFT)
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		grid.add_child(h)
	for r in Chests.RARITIES:
		var name_row := HBoxContainer.new()
		name_row.add_theme_constant_override("separation", 5)
		name_row.add_child(RarityDot.new(r))
		name_row.add_child(UiKit.label(Chests.rarity_name(r), 12))
		grid.add_child(name_row)
		for chest in Chests.IDS:
			var p := float(Chests.spec(chest)["odds"].get(r, 0.0))
			var l := UiKit.label(_pct(p), 12)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			grid.add_child(l)
	var stars := UiKit.label(L.t("chest.oddsStars", [Chests.STAR_WEIGHTS[0], Chests.STAR_WEIGHTS[1], Chests.STAR_WEIGHTS[2]]),
		11, UiKit.INK_SOFT)
	stars.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(stars)
	for chest in Chests.IDS:
		var sp := Chests.spec(chest)
		var g := UiKit.label(L.t("chest.oddsPity", [Chests.name_of(chest), sp["pity"], Chests.rarity_name(str(sp["pity_rarity"]))]),
			11, UiKit.INK_SOFT)
		g.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(g)


static func _pct(p: float) -> String:
	if p <= 0.0:
		return "-"
	if p < 0.1:
		return "%.2f%%" % p
	if p < 1.0:
		return "%.1f%%" % p
	return "%d%%" % int(round(p)) if is_equal_approx(p, round(p)) else "%.1f%%" % p


## Кружок цвета редкости (у радуги переливается).
class RarityDot:
	extends Control

	var rarity := ""
	var _t := 0.0

	func _init(r: String) -> void:
		rarity = r
		custom_minimum_size = Vector2(12, 12)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if rarity == "rainbow":
			_t += delta
			queue_redraw()

	func _draw() -> void:
		draw_circle(size / 2.0, 6.0, UiKit.OUTLINE)
		draw_circle(size / 2.0, 4.5, Chests.color(rarity, _t))
