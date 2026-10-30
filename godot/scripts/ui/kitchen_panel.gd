class_name KitchenPanel
extends Sheet
## Кухня: плита и что на ней готовится, уровень кухни, действующие блюда, запасы и рецепты (порт KitchenView).

var _tick := 0.0
# Таймеры на плите и у блюд: обновляются каждую секунду (пересоздаются в build)
var _jobs: Array = []    ## {bar, label, ready_at, total}
var _meals: Array = []   ## {label, until}


func _init() -> void:
	title_key = "house.kitchen"


func _process(delta: float) -> void:
	super._process(delta)
	_tick -= delta
	if _tick <= 0.0:
		_tick = 1.0
		Game.house.collect_dishes()
		_update_timers()


func build() -> void:
	_jobs = []
	_meals = []
	_stove_card()
	_level_card()
	var active := Game.house.active_meal_list()
	if not active.is_empty():
		section_title(L.t("kitchen.active", [active.size(), Game.house.meal_slots()]))
		for m in active:
			_meal_card(m["dish"], float(m["until"]))
	if Game.house.total_dishes() > 0:
		section_title(L.t("kitchen.pantry"))
		for dish in House.DISHES:
			if Game.house.dishes(dish) > 0:
				_pantry_row(dish)
	section_title(L.t("kitchen.recipes"))
	for dish in House.DISHES:
		_recipe_row(dish)
	_update_timers()


func _update_timers() -> void:
	var now := Time.get_unix_time_from_system()
	for j in _jobs:
		if not is_instance_valid(j["bar"]):
			continue
		var left := maxf(0.0, float(j["ready_at"]) - now)
		var bar: ProgressBar = j["bar"]
		bar.value = clampf(1.0 - left / maxf(1.0, float(j["total"])), 0.0, 1.0)
		(j["label"] as Label).text = House.countdown(left)
	for m in _meals:
		if is_instance_valid(m["label"]):
			(m["label"] as Label).text = House.countdown(float(m["until"]) - now)


func _dish_icon(dish: String, side: float) -> TextureRect:
	var ic := UiKit.icon(House.dish_icon(dish), side)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return ic


func _stove_card() -> void:
	var c := HousePanel.tinted_card(content, UiKit.TONES["orange"][1])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	c.add_child(row)
	var stove := HousePanel.sprite_rect("stove", 2.0)
	stove.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(stove)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	row.add_child(col)
	var cooking := Game.house.cooking()
	col.add_child(UiKit.label(L.t("kitchen.stove", [cooking.size(), Game.house.cook_slots()]), 15))
	for job in cooking:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		col.add_child(line)
		var dish: String = job["dish"]
		line.add_child(_dish_icon(dish, 20))
		var bar := UiKit.bar(0.0, "orange", 120, 14, " ")
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(bar)
		_jobs.append({"bar": bar, "label": bar.get_child(0), "ready_at": float(job["readyAt"]),
			"total": Game.house.cook_time(dish)})
	if cooking.is_empty():
		col.add_child(HousePanel.wrapped(L.t("kitchen.idle"), 12, UiKit.INK_SOFT))


## Уровень кухни: плиты, скорость готовки и сколько блюд сразу.
func _level_card() -> void:
	var level := Game.house.kitchen_level()
	var c := card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	c.add_child(row)
	var ic := UiKit.icon("hammer", 30)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	col.add_child(UiKit.label(L.t("kitchen.level", [level, House.KITCHEN_MAX]), 14))
	col.add_child(HousePanel.wrapped(L.t("kitchen.level.now", [House.kitchen_slots(level),
		Fmt.pct(1.0 - House.kitchen_speed(level)), House.kitchen_meal_slots(level)]), 11, UiKit.INK_SOFT))
	var cost := Game.house.next_kitchen_cost()
	if cost.is_empty():
		return
	var need := House.kitchen_required_level(level + 1)
	c.add_child(HousePanel.wrapped(L.t("kitchen.level.next", [House.kitchen_slots(level + 1),
		Fmt.pct(1.0 - House.kitchen_speed(level + 1)), House.kitchen_meal_slots(level + 1)]), 11, UiKit.INK_SOFT))
	c.add_child(UiKit.cost_view(cost))
	var b := UiKit.button(L.t("common.upgrade") if Game.level >= need else L.t("common.needLevel", [need]), "orange", 14, true)
	b.disabled = not Game.house.can_upgrade_kitchen()
	b.pressed.connect(Game.house.upgrade_kitchen)
	c.add_child(b)


func _meal_card(dish: String, until: float) -> void:
	var c := HousePanel.tinted_card(content, UiKit.TONES["green"][1])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	c.add_child(row)
	row.add_child(_dish_icon(dish, 34))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	col.add_child(UiKit.label(L.t("kitchen.eaten", [House.dish_name(dish)]), 14))
	col.add_child(HousePanel.wrapped(House.effect_text(dish), 12, UiKit.GOOD))
	var time := HBoxContainer.new()
	time.add_theme_constant_override("separation", 4)
	col.add_child(time)
	time.add_child(UiKit.icon("stopwatch", 14))
	var l := UiKit.label("", 12, UiKit.INK_SOFT)
	time.add_child(l)
	_meals.append({"label": l, "until": until})


func _pantry_row(dish: String) -> void:
	var c := card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	c.add_child(row)
	row.add_child(_dish_icon(dish, 30))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	col.add_child(UiKit.label("%s x%d" % [House.dish_name(dish), Game.house.dishes(dish)], 14))
	col.add_child(HousePanel.wrapped(House.effect_text(dish) + " · " + L.t("energy.plus", [House.dish_energy(dish)]), 11,
		UiKit.INK_SOFT))
	var b := UiKit.button(L.t("kitchen.eat"), "green", 14, true)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.disabled = not Game.house.can_eat(dish)
	b.pressed.connect(func() -> void: Game.house.eat(dish))
	row.add_child(b)


func _recipe_row(dish: String) -> void:
	var c := card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	c.add_child(row)
	var frame := PanelContainer.new()
	var fs := UiKit.box(Color(UiKit.PARCHMENT_DEEP, 0.7), Color(UiKit.WOOD_DARK, 0.4), 12, 2, false)
	fs.set_content_margin_all(6)
	frame.add_theme_stylebox_override("panel", fs)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.add_child(UiKit.icon(House.dish_icon(dish), 34))
	row.add_child(frame)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 3)
	row.add_child(col)
	col.add_child(UiKit.label(House.dish_name(dish), 15))
	col.add_child(HousePanel.wrapped(House.effect_text(dish) + " · " + Fmt.seconds(House.dish_duration(dish)) + " · "
		+ L.t("energy.plus", [House.dish_energy(dish)]), 11, UiKit.GOOD))
	c.add_child(UiKit.cost_view(House.dish_cost(dish)))
	var b := UiKit.button(L.t("kitchen.cook", [Fmt.seconds(Game.house.cook_time(dish))]), "orange", 14, true)
	b.icon = Sprites.icon("flame")
	b.add_theme_constant_override("icon_max_width", 18)
	b.add_theme_constant_override("h_separation", 6)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.disabled = not Game.house.can_cook(dish)
	b.pressed.connect(func() -> void: Game.house.cook(dish))
	c.add_child(b)
