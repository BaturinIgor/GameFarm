class_name IncubatorPanel
extends Sheet
## Инкубатор: яйцо в работе (таймер, ускорение, "Вылупить"), запас яиц, Гнездо для пары зверей и рецепты гибридов.
## Вылупление показывает HatchOverlay.

## Выбор родителей для гнезда: первый и второй.
var _pick_a := ""
var _pick_b := ""
var _timer_labels: Array = []
var _was_ready := false
var _was_nest_ready := false


func _init() -> void:
	title_key = "inc.title"


func _process(delta: float) -> void:
	super(delta)
	var sys := Game.incubator
	if sys.ready() != _was_ready or sys.nest_ready() != _was_nest_ready:
		_dirty = true
		return
	for pair in _timer_labels:
		var l: Label = pair[0]
		if is_instance_valid(l):
			l.text = Fmt.seconds(sys.time_left() if pair[1] == "slot" else sys.nest_left())


func build() -> void:
	_timer_labels.clear()
	var sys := Game.incubator
	_was_ready = sys.ready()
	_was_nest_ready = sys.nest_ready()
	var hint := UiKit.label(L.t("inc.hint"), 12, UiKit.INK_SOFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(hint)
	_incubator_card()
	_eggs_card()
	_nest_card()
	_recipes_card()


# MARK: Инкубатор

func _incubator_card() -> void:
	var sys := Game.incubator
	var border := EggView.shell_color(str(sys.slot()["egg"]["r"])) if sys.busy() else Color(UiKit.WOOD_DARK, 0.45)
	var v := TraderPanel.card_box(content, border, 3 if sys.busy() else 2)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(72, 84)
	row.add_child(holder)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	row.add_child(col)
	col.add_child(UiKit.label(L.t("inc.slot"), 16))
	if not sys.busy():
		var empty := EggView.icon("green", 56)
		empty.modulate = Color(0, 0, 0, 0.25)
		holder.add_child(empty)
		var t := UiKit.label(L.t("inc.empty") if not sys.eggs().is_empty() else L.t("inc.noEggs"), 12, UiKit.INK_SOFT)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(t)
		return
	var egg: Dictionary = sys.slot()["egg"]
	var view := EggView.icon(str(egg["r"]), 64)
	view.glow = 1.0 if sys.ready() else 0.0
	holder.add_child(view)
	col.add_child(UiKit.label(_egg_title(egg), 13, UiKit.INK_SOFT))
	if sys.ready():
		var hatch := UiKit.button(L.t("inc.hatch"), "green", 16)
		hatch.pressed.connect(_hatch)
		v.add_child(hatch)
		UiKit.attention(hatch)
		return
	var left := UiKit.label(Fmt.seconds(sys.time_left()), 15)
	_timer_labels.append([left, "slot"])
	col.add_child(left)
	var price := IncubatorSystem.speed_price(sys.time_left())
	var speed := _gem_button(L.t("inc.speed"), price)
	speed.pressed.connect(func() -> void:
		if not Game.incubator.speed_up():
			_no_crystals())
	v.add_child(speed)


func _egg_title(egg: Dictionary) -> String:
	var h := str(egg.get("a", ""))
	if h != "":
		return L.t("inc.hybridEgg", [Animals.name_of(h)])
	return Incubator.name_of(str(egg["r"]))


func _hatch() -> void:
	var out := Game.incubator.hatch()
	if out.is_empty():
		return
	HatchOverlay.show_result(out)


# MARK: Запас яиц

func _eggs_card() -> void:
	var sys := Game.incubator
	var v := TraderPanel.card_box(content)
	section_title(L.t("inc.eggs", [sys.eggs().size(), Incubator.MAX_EGGS]), v)
	if sys.eggs().is_empty():
		var t := UiKit.label(L.t("inc.whereEggs"), 12, UiKit.INK_SOFT)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(t)
	else:
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		v.add_child(flow)
		for i in sys.eggs().size():
			flow.add_child(_egg_button(i, sys.eggs()[i]))
		if not sys.busy():
			var t2 := UiKit.label(L.t("inc.tapEgg"), 11, UiKit.INK_SOFT)
			t2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(t2)
	var buy := _gem_button(L.t("inc.buyEgg", [Incubator.name_of(Incubator.EGG_PRICE_RARITY)]), Incubator.EGG_PRICE)
	buy.pressed.connect(func() -> void:
		if not Game.incubator.buy_egg():
			_no_crystals())
	v.add_child(buy)


func _egg_button(i: int, egg: Dictionary) -> Control:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(56, 64)
	var s := UiKit.box(UiKit.PARCHMENT_LIGHT, EggView.shell_color(str(egg["r"])).darkened(0.2), 12, 2, false)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, s)
	var e := EggView.icon(str(egg["r"]), 46)
	e.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	e.offset_left = 5
	e.offset_right = -5
	e.offset_top = 6
	e.offset_bottom = -6
	b.add_child(e)
	if str(egg.get("a", "")) != "":
		var mark := UiKit.icon("spark", 14)
		mark.position = Vector2(38, 2)
		b.add_child(mark)
	b.tooltip_text = _egg_title(egg)
	b.disabled = Game.incubator.busy()
	b.pressed.connect(func() -> void:
		if Game.incubator.incubate(i):
			scroll_to_top())
	return b


# MARK: Гнездо

func _nest_card() -> void:
	var sys := Game.incubator
	var v := TraderPanel.card_box(content)
	section_title(L.t("inc.nest"), v)
	if sys.nesting():
		var n := sys.nest()
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override("separation", 8)
		pair.alignment = BoxContainer.ALIGNMENT_CENTER
		pair.add_child(AnimalsPanel.animal_icon(str(n["a"]), 40))
		pair.add_child(UiKit.icon("heart", 20))
		pair.add_child(AnimalsPanel.animal_icon(str(n["b"]), 40))
		v.add_child(pair)
		var names := UiKit.label("%s + %s" % [Animals.name_of(str(n["a"])), Animals.name_of(str(n["b"]))], 13)
		names.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(names)
		var hy := Incubator.hybrid_of(str(n["a"]), str(n["b"]))
		var what := UiKit.label(L.t("inc.nestHybrid", [Animals.name_of(hy)]) if hy != "" else L.t("inc.nestPlain"), 12, UiKit.INK_SOFT)
		what.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(what)
		if sys.nest_ready():
			var take := UiKit.button(L.t("inc.nestTake"), "green", 15)
			take.pressed.connect(func() -> void:
				var egg := Game.incubator.collect_nest()
				if not egg.is_empty():
					Game.show_toast("egg:" + str(egg["r"]), L.t("egg.got", [_egg_title(egg)])))
			v.add_child(take)
			UiKit.attention(take)
		else:
			var left := UiKit.label(Fmt.seconds(sys.nest_left()), 15)
			left.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_timer_labels.append([left, "nest"])
			v.add_child(left)
			var speed := _gem_button(L.t("inc.speed"), IncubatorSystem.speed_price(sys.nest_left()))
			speed.pressed.connect(func() -> void:
				if not Game.incubator.nest_speed_up():
					_no_crystals())
			v.add_child(speed)
		return
	var hint := UiKit.label(L.t("inc.nestHint", [Incubator.NEST_STARS]), 12, UiKit.INK_SOFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	var list := sys.parents()
	if list.size() < 2:
		var none := UiKit.label(L.t("inc.nestNone", [Incubator.NEST_STARS]), 12)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(none)
		return
	if not _pick_a in list:
		_pick_a = ""
	if not _pick_b in list:
		_pick_b = ""
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	v.add_child(flow)
	for id in list:
		flow.add_child(_parent_button(id))
	var hybrid := Incubator.hybrid_of(_pick_a, _pick_b)
	var result := ""
	if _pick_a != "" and _pick_b != "":
		result = L.t("inc.nestHybrid", [Animals.name_of(hybrid)]) if hybrid != "" else L.t("inc.nestPlain")
	else:
		result = L.t("inc.nestPick")
	var res_l := UiKit.label(result, 12, UiKit.INK_SOFT)
	res_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(res_l)
	var go := UiKit.button(L.t("inc.nestGo", [int(Incubator.NEST_SECONDS / 3600.0)]), "green" if sys.can_breed(_pick_a, _pick_b) else "gray", 15)
	go.disabled = not sys.can_breed(_pick_a, _pick_b)
	go.pressed.connect(func() -> void:
		if Game.incubator.breed(_pick_a, _pick_b):
			_pick_a = ""
			_pick_b = "")
	v.add_child(go)


func _parent_button(id: String) -> Control:
	var picked := id == _pick_a or id == _pick_b
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(52, 52)
	var s := UiKit.box(UiKit.PARCHMENT_LIGHT if not picked else Color("fff3c4"),
		UiKit.TONES["green"][1] if picked else Color(UiKit.WOOD_DARK, 0.35), 12, 3 if picked else 2, false)
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, s)
	# Значок по центру кнопки при любом её размере (якорь в центре с ручной позицией уезжал вправо вниз)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := AnimalsPanel.animal_icon(id, 36)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(icon)
	b.add_child(center)
	b.tooltip_text = Animals.name_of(id)
	b.pressed.connect(func() -> void:
		Sound.play("tap")
		if id == _pick_a:
			_pick_a = ""
		elif id == _pick_b:
			_pick_b = ""
		elif _pick_a == "":
			_pick_a = id
		else:
			_pick_b = id
		_dirty = true)
	return b


# MARK: Рецепты

func _recipes_card() -> void:
	var v := TraderPanel.card_box(content)
	section_title(L.t("inc.recipes"), v)
	for rec in Incubator.RECIPES:
		var known: bool = str(rec[2]) in Game.incubator.found() or Game.animals.stars(str(rec[2])) > 0
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		v.add_child(row)
		row.add_child(AnimalsPanel.animal_icon(str(rec[0]), 28))
		row.add_child(UiKit.label("+", 14))
		row.add_child(AnimalsPanel.animal_icon(str(rec[1]), 28))
		row.add_child(UiKit.label("=", 14))
		var h := AnimalsPanel.animal_icon(str(rec[2]), 32)
		if not known:
			h.modulate = Color(0, 0, 0, 0.75)
		row.add_child(h)
		var name := UiKit.label(Animals.name_of(str(rec[2])) if known else "???", 13)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)


# MARK: Общее

func _gem_button(text: String, price: int) -> Button:
	var b := UiKit.button("", "blue" if Game.shop.crystals() >= price else "gray", 14, true)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_child(UiKit.title(text, 13))
	row.add_child(UiKit.icon("gem", 14))
	row.add_child(UiKit.title(str(price), 13))
	b.add_child(row)
	return b


func _no_crystals() -> void:
	Sound.play("error")
	Game.show_toast("px:gem", L.t("chest.noCrystals"))
