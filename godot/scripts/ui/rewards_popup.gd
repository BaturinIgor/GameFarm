class_name RewardsPopup
extends Control
## "Ты получил": все награды разом сеткой по 4 в ряд (значок и сколько), прокрутка, если их много,
## и кнопка "Забрать", которая закрывает окно. Список считается разницей состояния до и после выдачи
## (RewardsPopup.track), поэтому подходит к любой выдаче: ивент, сундуки целей, задания, достижения.

const COLUMNS := 4
const CELL := Vector2(70, 76)
## Выше этой высоты сетка прокручивается.
const MAX_GRID_HEIGHT := 330.0

## [[код значка для UiKit.icon_any, подпись], ...]
var items: Array = []
var title_key := "rewards.title"


## Выполнить выдачу и показать, что пришло. Ничего не пришло - окна нет.
static func track(action: Callable, title := "rewards.title") -> void:
	var before := snapshot()
	action.call()
	show_items(diff(before, snapshot()), title)


static func show_items(list: Array, title := "rewards.title") -> void:
	if list.is_empty() or Hud.current == null:
		return
	var p := RewardsPopup.new()
	p.items = list
	p.title_key = title
	Hud.current.show_overlay(p)


## Всё, что может прийти наградой: валюты, склад, семена, блюда, карты, украшения, образы.
static func snapshot() -> Dictionary:
	var s := Game.save
	return {
		"coins": int(s.get("coins", 0)),
		"crystals": Game.shop.crystals(),
		"level": Game.level,
		"xp": int(s.get("xp", 0)),
		"points": int(s.get("bonusTalentPoints", 0)),
		"tickets": int(s.get("tickets", 0)),
		"sparks": int(s.get("sparks", 0)),
		"maps": int(s.get("maps", 0)),
		"storage": (s.get("storage", {}) as Dictionary).duplicate(),
		"seeds": (s.get("seeds", {}) as Dictionary).duplicate(),
		"dishes": (s.get("dishes", {}) as Dictionary).duplicate(),
		"cards": (s.get("cards", {}) as Dictionary).duplicate(),
		"decor": (s.get("eventDecor", []) as Array).duplicate(),
		"skins": (s.get("eventSkins", []) as Array).duplicate(),
	}


## Что прибавилось между двумя снимками: [[значок, подпись], ...]. Траты (минус) не показываем.
static func diff(a: Dictionary, b: Dictionary) -> Array:
	var out: Array = []
	var add := func(icon_code: String, n: int) -> void:
		if n > 0:
			out.append([icon_code, Fmt.compact(n) if n >= 10000 else Fmt.n(n)])
	add.call("px:coin", int(b["coins"]) - int(a["coins"]))
	add.call("px:gem", int(b["crystals"]) - int(a["crystals"]))
	# Опыт считаем, только если уровень не сменился: новый уровень покажет своё окно
	if int(b["level"]) == int(a["level"]):
		add.call("px:book", int(b["xp"]) - int(a["xp"]))
	add.call("px:star", int(b["points"]) - int(a["points"]))
	add.call("px:ticket", int(b["tickets"]) - int(a["tickets"]))
	add.call("px:spark", int(b["sparks"]) - int(a["sparks"]))
	add.call("px:tmap", int(b["maps"]) - int(a["maps"]))
	for k in b["storage"]:
		add.call("res:" + str(k), int(b["storage"][k]) - int(a["storage"].get(k, 0)))
	for crop in b["seeds"]:
		add.call("px:" + Farming.seed_icon(str(crop)), int(b["seeds"][crop]) - int(a["seeds"].get(crop, 0)))
	for dish in b["dishes"]:
		add.call("px:" + House.dish_icon(str(dish)), int(b["dishes"][dish]) - int(a["dishes"].get(dish, 0)))
	var cards := 0
	for c in b["cards"]:
		cards += maxi(0, int(b["cards"][c]) - int(a["cards"].get(c, 0)))
	add.call("px:cards", cards)
	for d in b["decor"]:
		if not d in a["decor"]:
			out.append(["decor:" + str(d), House.decor_name(str(d))])
	for sk in b["skins"]:
		if not sk in a["skins"]:
			out.append(["skin:" + str(sk), L.t("skin." + str(sk))])
	return out


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = UiKit.DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	var st := UiKit.panel_style(20)
	st.content_margin_left = 16
	st.content_margin_right = 16
	st.content_margin_top = 16
	st.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", st)
	var width := minf(340.0, get_viewport_rect().size.x - 40.0)
	panel.custom_minimum_size = Vector2(width, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var t := UiKit.label(L.t(title_key), 20)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)

	var grid := GridContainer.new()
	var cols := mini(COLUMNS, items.size())
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for it in items:
		grid.add_child(_cell(it))
	var rows := ceili(float(items.size()) / float(COLUMNS))
	var grid_h := rows * CELL.y + (rows - 1) * 6.0
	if grid_h > MAX_GRID_HEIGHT:
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.custom_minimum_size = Vector2(0, MAX_GRID_HEIGHT)
		var c := CenterContainer.new()
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.add_child(grid)
		scroll.add_child(c)
		v.add_child(scroll)
		Sheet.touch_scroll(scroll)
	else:
		v.add_child(grid)

	var ok := UiKit.button(L.t("rewards.take"), "green", 16)
	ok.pressed.connect(close)
	v.add_child(ok)
	# Появление: панель чуть увеличивается, клетки по очереди
	panel.pivot_offset = Vector2(width / 2.0, 120.0)
	panel.scale = Vector2.ONE * 0.85
	panel.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.15)
	var i := 0
	for cell in grid.get_children():
		(cell as Control).modulate.a = 0.0
		tw.tween_property(cell, "modulate:a", 1.0, 0.15).set_delay(0.12 + 0.04 * i)
		i += 1
	Sound.play("treasure")


## Клетка: значок в светлой плашке и число под ним (длинное название украшения или образа - мельче).
func _cell(it: Array) -> Control:
	var p := PanelContainer.new()
	var st := UiKit.box(UiKit.PARCHMENT_LIGHT, Color(UiKit.WOOD_DARK, 0.45), 12, 2, false)
	st.set_content_margin_all(4)
	p.add_theme_stylebox_override("panel", st)
	p.custom_minimum_size = CELL
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(col)
	var code: String = it[0]
	var art: Control
	if code.begins_with("decor:"):
		art = HousePanel.sprite_rect(House.decor_sprite(code.substr(6)), 1.0, Vector2(40, 40))
	elif code.begins_with("skin:"):
		art = EventsPanel.skin_icon(code.substr(5), 40)
	else:
		art = UiKit.icon_any(code, 36)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(art)
	var text: String = it[1]
	var l := UiKit.label(text, 13 if text.length() <= 7 else 10, UiKit.INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size = Vector2(CELL.x - 8.0, 0)
	col.add_child(l)
	return p


func close() -> void:
	queue_free()
