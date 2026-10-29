class_name EncounterCard
extends PanelContainer
## Карточка над кнопками, когда рядом дикий зверь: кто это, что даёт, цена и кнопка "Приручить".
## Показывается через Hud.current.set_prompt("encounter", card).

var animal := ""
var shiny := false
var on_tame: Callable

var _row := HBoxContainer.new()
var _dirty := true


func _init(id: String, rare: bool, tame_action: Callable) -> void:
	animal = id
	shiny = rare
	on_tame = tame_action
	add_theme_stylebox_override("panel", UiKit.panel_style(18))
	mouse_filter = Control.MOUSE_FILTER_STOP
	_row.add_theme_constant_override("separation", 12)
	add_child(_row)


func _ready() -> void:
	Game.changed.connect(_on_changed)
	L.language_changed.connect(_on_changed)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)


func _on_changed() -> void:
	_dirty = true


func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		for c in _row.get_children():
			c.queue_free()
		_build()


func _build() -> void:
	var a := Game.animals
	var stars := a.stars(animal)
	var cost := a.tame_cost(animal)
	_row.add_child(AnimalsPanel.animal_icon(animal, 52))

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 5)
	_row.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	col.add_child(head)
	head.add_child(UiKit.label(Animals.name_of(animal), 16))
	if stars > 0:
		var st := UiKit.stars(stars, Animals.MAX_STARS, 12)
		st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(st)
	if shiny:
		head.add_child(AnimalsPanel.pill(L.t("shiny.tag"), UiKit.TONES["purple"][1], Color.WHITE, 10))
	var effects := Animals.effects(animal)
	if not effects.is_empty():
		var line := AnimalsPanel.effect_line(effects[0], a.multiplier(animal, 1))
		col.add_child(line)
	if not cost.is_empty() and stars < Animals.MAX_STARS:
		col.add_child(UiKit.cost_view(cost))

	if stars >= Animals.MAX_STARS:
		var mx := UiKit.label(L.t("common.max"), 13, UiKit.INK_SOFT)
		mx.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_row.add_child(mx)
	else:
		var b := UiKit.button(L.t("tame.more").replace("★", "").strip_edges() if stars > 0 else L.t("tame.action"), "green")
		if stars > 0:
			b.icon = Sprites.icon("star")
			b.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			b.add_theme_constant_override("h_separation", 2)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.disabled = cost.is_empty() or not Game.can_afford(cost)
		b.pressed.connect(func() -> void:
			if on_tame.is_valid():
				on_tame.call())
		_row.add_child(b)
