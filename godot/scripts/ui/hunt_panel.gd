class_name HuntPanel
extends Sheet
## Стражник у доски: заказы на охоту и подземелья (порт HuntView).


var tab := "hunts"


func _init() -> void:
	title_key = "hunt.title"


func build() -> void:
	Game.combat.ensure_hunts()
	var hello := UiKit.label(L.t("hunt.hello" if tab == "hunts" else "dungeon.hello"), 13)
	content.add_child(TraderPanel.hello_row("guard", [hello]))
	_tabs()
	if tab == "hunts":
		content.add_child(CombatCards.hunts_list())
		return
	content.add_child(CombatCards.potion_shop_card())
	DungeonPanel.build_list(content, close)


## Вкладки (GameTabs): охота со счётчиком готовых заказов и подземелья.
func _tabs() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	content.add_child(row)
	for it in [["hunts", "hunt.tab", Game.combat.claimable_hunts()], ["dungeons", "dungeon.tab", 0]]:
		var id: String = it[0]
		var b := UiKit.button("", "orange" if id == tab else "wood", 13, true)
		b.custom_minimum_size = Vector2(0, 36)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var inner := HBoxContainer.new()
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.add_theme_constant_override("separation", 4)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(inner)
		inner.add_child(UiKit.title(L.t(it[1]), 13))
		var n := int(it[2])
		if n > 0:
			var badge := UiKit.count_badge(mini(n, 99))
			badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			inner.add_child(badge)
		b.pressed.connect(func() -> void:
			tab = id
			_dirty = true)
		row.add_child(b)
