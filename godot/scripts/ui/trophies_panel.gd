class_name TrophiesPanel
extends Sheet
## Стена трофеев: какие уже висят и как получить остальные (порт TrophyView).


func _init() -> void:
	title_key = "trophy.title"


func build() -> void:
	content.add_theme_constant_override("separation", 10)
	for id in Trophies.IDS:
		var earned := Trophies.is_earned(id)
		var target := Trophies.target(id)
		var progress := mini(Trophies.progress(id), target)
		var v := TraderPanel.card_box(content, UiKit.GOLD_DARK if earned else Color(UiKit.WOOD_DARK, 0.45), 3 if earned else 2)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		v.add_child(row)

		var frame := PanelContainer.new()
		var fs := UiKit.box(Color(UiKit.PARCHMENT_DEEP, 0.7), Color(0, 0, 0, 0), 12, 0, false)
		fs.set_content_margin_all(0)
		frame.add_theme_stylebox_override("panel", fs)
		frame.custom_minimum_size = Vector2(52, 48)
		frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(HousePanel.sprite_rect(Trophies.sprite(id), 2.0, Vector2(52, 48)))
		if not earned:
			frame.modulate.a = 0.35
		row.add_child(frame)

		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 4)
		row.add_child(col)
		col.add_child(UiKit.label(Trophies.name_of(id), 15))
		var how := UiKit.label(Trophies.condition(id), 11, UiKit.INK_SOFT)
		how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(how)
		if earned:
			row.add_child(HousePanel.check_mark(22))
		else:
			var bar := UiKit.bar(float(progress) / float(target), "orange", 0.0, 12.0, "%d / %d" % [progress, target])
			bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_child(bar)
