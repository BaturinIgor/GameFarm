class_name EnergyPopup
extends Control
## Где взять энергию: сколько есть и когда восстановится, ролик, покупка за кристаллы, бесконечная энергия
## на 30 минут, блюдо с кухни и подсказка про другие источники. Открывается кнопкой "+" у полосы энергии
## и когда энергия кончилась.


static func open() -> void:
	if Hud.current == null:
		return
	for n in Hud.current.find_children("*", "", true, false):
		if n is EnergyPopup:
			return
	Hud.current.show_overlay(EnergyPopup.new())


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = UiKit.DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			close())
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	var st := UiKit.panel_style(20)
	st.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", st)
	panel.custom_minimum_size = Vector2(minf(350.0, get_viewport_rect().size.x - 32.0), 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	_fill(v)


func _fill(v: VBoxContainer) -> void:
	var en := Game.energy
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	head.add_child(UiKit.icon("bolt", 36))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(col)
	col.add_child(UiKit.label(L.t("energy.title"), 18))
	var state := func() -> String:
		var e := Game.energy
		if e.infinite():
			return L.t("energy.infiniteLeft", [House.countdown(e.infinite_left())])
		var t := e.until_full()
		return L.t("energy.full") if t <= 0.0 else L.t("energy.fullIn", [House.countdown(t)])
	col.add_child(CombatCards.LiveLabel.new(state, 12, UiKit.INK_SOFT))
	v.add_child(UiKit.bar(minf(1.0, en.value() / en.max_value()), "gold", 0.0, 18.0,
		"%d / %d" % [int(en.value()), int(en.max_value())]))
	# Ролик
	var ad := Ads.reward_button(L.t("energy.ad", [EnergySystem.AD_ENERGY, en.ads_left()]), "blue", 14)
	ad.disabled = en.ads_left() <= 0
	ad.pressed.connect(func() -> void:
		Ads.show_rewarded(func() -> void:
			Game.energy.ad_reward()
			close()))
	v.add_child(ad)
	# За кристаллы
	var buy := MapPanel.icon_button([["t", L.t("energy.buy", [EnergySystem.BUY_ENERGY])], ["i", "gem"], ["t", str(en.buy_price())]],
		"purple", 14)
	buy.pressed.connect(func() -> void:
		if Game.energy.buy():
			close()
		else:
			Game.show_toast("px:gem", L.t("crystals.notEnough", [Fmt.n(Game.energy.buy_price() - Game.shop.crystals())])))
	v.add_child(buy)
	var inf := MapPanel.icon_button([["t", L.t("energy.infinite", [EnergySystem.INFINITE_MINUTES])], ["i", "gem"],
		["t", str(en.infinite_price())]], "orange", 14)
	inf.pressed.connect(func() -> void:
		if Game.energy.buy_infinite():
			close()
		else:
			Game.show_toast("px:gem", L.t("crystals.notEnough", [Fmt.n(Game.energy.infinite_price() - Game.shop.crystals())])))
	v.add_child(inf)
	# Кухня
	var food := UiKit.button(L.t("energy.kitchen"), "green", 14)
	food.pressed.connect(func() -> void:
		close()
		if Hud.current != null:
			Hud.current.open_window(KitchenPanel.new()))
	v.add_child(food)
	var hint := UiKit.label(L.t("energy.hint"), 12, UiKit.INK_SOFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	var close_b := UiKit.button(L.t("common.close"), "wood", 14, true)
	close_b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_b.pressed.connect(close)
	v.add_child(close_b)


func close() -> void:
	queue_free()
