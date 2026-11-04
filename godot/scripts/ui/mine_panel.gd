class_name MinePanel
extends Sheet
## Шахта Глубин: этаж, порода, фонари и награды впереди. Кнопка "Спуститься" открывает поле (MineGame).

var _lamp_label: Label
var _shown_lamps := -1


func _init() -> void:
	title_key = "mine.title"


func _process(delta: float) -> void:
	super(delta)
	if _lamp_label == null or not is_instance_valid(_lamp_label):
		return
	var n := Game.mine.lamps()
	if n != _shown_lamps:
		_dirty = true
		return
	_lamp_label.text = _lamp_text()


func _lamp_text() -> String:
	var left := Game.mine.lamp_left()
	if left <= 0.0:
		return L.t("mine.lampsFull")
	return L.t("mine.lampNext", [Fmt.seconds(left)])


func build() -> void:
	var sys := Game.mine
	var floor_n := sys.floor_n()
	var lay := Mine.layer(floor_n)

	var hint := UiKit.label(L.t("mine.hint"), 12, UiKit.INK_SOFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(hint)

	# Этаж и порода
	var v := TraderPanel.card_box(content, Color(lay["tint"]), 3)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var swatch := MinePreview.new(floor_n)
	row.add_child(swatch)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 3)
	row.add_child(col)
	col.add_child(UiKit.label(L.t("mine.floor", [floor_n]), 18))
	col.add_child(UiKit.label(Mine.layer_name(floor_n), 13, UiKit.INK_SOFT))
	if sys.best() > 0:
		col.add_child(UiKit.label(L.t("mine.best", [sys.best()]), 11, UiKit.INK_SOFT))
	var ores := HBoxContainer.new()
	ores.add_theme_constant_override("separation", 4)
	for c in Mine.colors(floor_n):
		ores.add_child(UiKit.icon(Mine.ore_of(floor_n, c), 18))
	col.add_child(ores)

	# Фонари
	_shown_lamps = sys.lamps()
	var lamps := HBoxContainer.new()
	lamps.add_theme_constant_override("separation", 3)
	for i in Mine.LAMPS_MAX:
		var l := UiKit.icon("flame", 22)
		if i >= _shown_lamps:
			l.modulate = Color(0.3, 0.3, 0.3, 0.6)
		lamps.add_child(l)
	var lamp_col := HBoxContainer.new()
	lamp_col.add_theme_constant_override("separation", 8)
	lamp_col.add_child(lamps)
	_lamp_label = UiKit.label(_lamp_text(), 12, UiKit.INK_SOFT)
	_lamp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lamp_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lamp_col.add_child(_lamp_label)
	v.add_child(lamp_col)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	v.add_child(buttons)
	var go := UiKit.button(L.t("mine.go"), "green" if _shown_lamps > 0 else "gray", 16)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.disabled = _shown_lamps <= 0
	go.pressed.connect(_go)
	buttons.add_child(go)
	if _shown_lamps < Mine.LAMPS_MAX:
		var buy := UiKit.button("", "blue" if Game.shop.crystals() >= Mine.LAMPS_PRICE else "gray", 14, true)
		buy.custom_minimum_size.x = 110
		var br := HBoxContainer.new()
		br.add_theme_constant_override("separation", 3)
		br.alignment = BoxContainer.ALIGNMENT_CENTER
		br.mouse_filter = Control.MOUSE_FILTER_IGNORE
		br.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		br.add_child(UiKit.icon("flame", 14))
		br.add_child(UiKit.title(str(Mine.LAMPS_MAX), 13))
		br.add_child(UiKit.icon("gem", 14))
		br.add_child(UiKit.title(str(Mine.LAMPS_PRICE), 13))
		buy.add_child(br)
		buy.pressed.connect(func() -> void:
			if not Game.mine.buy_lamps():
				Sound.play("error")
				Game.show_toast("px:gem", L.t("chest.noCrystals")))
		buttons.add_child(buy)

	# Награды впереди
	var r := TraderPanel.card_box(content)
	section_title(L.t("mine.rewards"), r)
	var line := UiKit.label(L.t("mine.rewardFloor", [Fmt.n(Mine.coins(floor_n, Game.level))]), 12)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_child(line)
	for step in [5, 10, 25]:
		var next := (floor_n + step - 1) / step * step
		var key := Mine.key_for(next)
		var kr := HBoxContainer.new()
		kr.add_theme_constant_override("separation", 6)
		kr.add_child(ChestsPanel.key_icon(key, 16))
		var t := UiKit.label(L.t("mine.rewardKey", [Chests.key_name(key), next]), 12)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		kr.add_child(t)
		r.add_child(kr)
	var ore := UiKit.label(L.t("mine.oreToday", [Game.mine.ore_room(), Mine.daily_ore(Game.level)]), 11, UiKit.INK_SOFT)
	ore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_child(ore)

	# Как играть
	var how := TraderPanel.card_box(content)
	section_title(L.t("mine.how"), how)
	for k in ["mine.how1", "mine.how2", "mine.how3"]:
		var l := UiKit.label(L.t(k), 12)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		how.add_child(l)


func _go() -> void:
	if not Game.mine.start():
		Sound.play("error")
		return
	Sound.play("open")
	MineGame.launch(Game.mine.floor_n())


## Квадратик породы: фон шахты и пара блоков руды.
class MinePreview:
	extends Control

	var floor_n := 1

	func _init(f: int) -> void:
		floor_n = f
		custom_minimum_size = Vector2(64, 64)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var lay := Mine.layer(floor_n)
		draw_rect(Rect2(Vector2.ZERO, size), UiKit.OUTLINE)
		draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color(lay["bg"]))
		var cs := (size.x - 8.0) / 2.0
		for i in 4:
			var p := Vector2(4 + (i % 2) * cs, 4 + (i / 2) * cs)
			if i == 3:
				MineGame.draw_rock(self, Rect2(p, Vector2(cs, cs)).grow(-1), 2, Color(lay["rock"]))
			else:
				MineGame.draw_ore(self, Rect2(p, Vector2(cs, cs)).grow(-1), floor_n, i)
