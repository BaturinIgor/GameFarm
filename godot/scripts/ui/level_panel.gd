class_name LevelPanel
extends Sheet
## Профиль: уровень и опыт, характеристики, что откроется дальше, статистика, язык, покупки (порт LevelView).
## Здесь же награды и открытия уровней (GameRules.rewards, GameRules.unlocks) - их берёт и заставка уровня.

# Копии таблиц из Swift, пока их нет в scripts/data: уровни планет, зверей лавки, этажей дома,
# семян, рядов талантов и подземелий.
const PLANET_LEVELS := {"ember": 45, "azure": 54}
const SHOP_ANIMALS := {"chicken": 2, "cow": 5, "horse": 8, "sheep": 11, "bee": 14, "rooster": 18, "pig": 26, "unicorn": 40}
const ANIMAL_IDS := ["chicken", "cow", "horse", "sheep", "bee", "rooster", "pig", "unicorn",
	"mouse", "goose", "duck", "frog", "butterfly", "swan", "goldenGoose", "duckHat"]
const HOUSE_FLOORS := {"greenhouse": 30, "attic": 22, "upper": 8, "ground": 1, "basement": 14}
## Семена: [id, уровень, что растёт].
const CROPS := [
	["wheat", 1, "wheat"], ["carrot", 2, "carrots"], ["tomato", 4, "tomato"], ["potato", 6, "potato"],
	["strawberry", 8, "strawberry"], ["corn", 11, "corn"], ["cabbage", 14, "cabbage"], ["eggplant", 17, "eggplant"],
	["pumpkin", 20, "pumpkin"], ["sunflower", 24, "sunflower"], ["chili", 28, "chili"], ["grapes", 33, "grapes"],
]
const MAX_BEDS := 12
const TALENT_TIER_LEVELS := [1, 3, 6, 10, 15, 21, 28, 35, 42, 48, 55]
const DUNGEONS := {"slimeCaves": 8, "boneCrypt": 15, "orcCamp": 22, "frostHollow": 30, "fireDepths": 40}

static var _portraits: Dictionary = {}

## Раскрытые строки ленты уровней.
var _expanded: Dictionary = {}


func _init() -> void:
	title_key = "profile.title"


func build() -> void:
	_progress_card()
	_bonuses_card()
	_upcoming_card()
	_stats_card()
	content.add_child(LegacyPanel.profile_card())
	_settings_card()


# MARK: Награды и открытия уровней

## Что даёт уровень (награды за все уровни сразу, если игрок прыгнул через несколько).
static func rewards(from: int, to: int) -> Array:
	var points := Game.talent_points_at(to) - Game.talent_points_at(from)
	var coins := 0
	for lv in range(from + 1, to + 1):
		coins += Game.level_coin_reward(lv)
	return [
		_line("px:star", L.t("reward.talentPoints", [points])),
		_line("px:coins", L.t("reward.coins", [Fmt.n(coins)])),
		_line("px:bag", L.t("reward.backpack")),
		_line("px:fist", L.t("reward.power")),
	]


## Что открывается ровно на этом уровне: строки {icon, text}.
static func unlocks(level: int) -> Array:
	var lines: Array = []
	for planet in PLANET_LEVELS:
		if PLANET_LEVELS[planet] == level:
			lines.append(_line("px:telescope", L.t("unlock.planet", [L.t("planet." + planet)])))
	for id in Locations.IDS:
		var spec := Locations.spec(id)
		if spec["kind"] == "world" and int(spec["level"]) == level and level > 1:
			lines.append(_line("px:map", L.t("unlock.location", [Locations.name_of(id)])))
	for tool in Tools.UPGRADABLE:
		for tier in range(2, Tools.MAX_TIER + 1):
			if Tools.required_level(tool, tier) == level:
				lines.append(_line("px:" + Tools.icon_name(tool), L.t("unlock.tool", [Tools.tier_name(tool, tier)])))
	for id in SHOP_ANIMALS:
		if SHOP_ANIMALS[id] == level:
			lines.append(_line("an:" + id, L.t("unlock.animal", [L.t("animal." + id)])))
	for floor in HOUSE_FLOORS:
		if HOUSE_FLOORS[floor] == level and level > 1:
			var floor_name := L.t("house.floor." + floor) + " · " + L.t("house.room." + floor)
			lines.append(_line("px:stairs", L.t("unlock.floor", [floor_name])))
	if level > 1 and _beds(level) > _beds(level - 1):
		lines.append(_line("px:sprout", L.t("unlock.bed")))
	for crop in CROPS:
		if int(crop[1]) == level and level > 1:
			lines.append(_line("px:seed_" + crop[0], L.t("unlock.seed", [Res.name_of(crop[2])])))
	var row := TALENT_TIER_LEVELS.find(level)
	if row > 0:
		lines.append(_line("px:book", L.t("unlock.talentRow", [row + 1])))
	for d in DUNGEONS:
		if DUNGEONS[d] == level:
			lines.append(_line("px:key", L.t("unlock.dungeon", [L.t("dungeon." + d)])))
	return lines


static func _line(icon: String, text: String) -> Dictionary:
	return {"icon": icon, "text": text}


## Грядок на уровне (Garden.beds).
static func _beds(level: int) -> int:
	return mini(MAX_BEDS, 4 + level / 4)


## Лицо героя для профиля (Sprites.portrait): кусок первого кадра без прозрачных краёв.
static func portrait(skin: String) -> Texture2D:
	if _portraits.has(skin):
		return _portraits[skin]
	var out: Texture2D = null
	var tex := Sprites.texture("pl_" + skin)
	if tex != null:
		var img := tex.get_image()
		if img != null:
			if img.is_compressed():
				img.decompress()
			var part := img.get_region(Rect2i(20, 14, 24, 26))
			var used := part.get_used_rect()
			if used.size.x > 0 and used.size.y > 0:
				part = part.get_region(used)
			out = ImageTexture.create_from_image(part)
	_portraits[skin] = out
	return out


# MARK: Уровень

func _progress_card() -> void:
	var c := _card(UiKit.GOLD_DARK)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	c.add_child(row)

	# Лицо героя и номер уровня в углу
	var avatar := Control.new()
	avatar.custom_minimum_size = Vector2(86, 86)
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(avatar)
	var frame := PanelContainer.new()
	var fs := UiKit.box(UiKit.PARCHMENT_DEEP, UiKit.OUTLINE, 16, 3, false)
	fs.set_content_margin_all(7)
	frame.add_theme_stylebox_override("panel", fs)
	frame.position = Vector2.ZERO
	frame.size = Vector2(78, 78)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar.add_child(frame)
	var face := TextureRect.new()
	face.texture = portrait(Skins.current())
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face.custom_minimum_size = Vector2(64, 64)
	frame.add_child(face)
	var badge := _level_badge(Game.level, 34)
	badge.position = Vector2(52, 52)
	avatar.add_child(badge)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	row.add_child(col)
	col.add_child(UiKit.label(L.t("level.n", [Game.level]), 19))
	if Game.level < Game.MAX_LEVEL:
		var text := "%s / %s" % [Fmt.n(int(Game.save["xp"])), Fmt.n(Game.xp_needed)]
		var bar := UiKit.bar(Game.level_progress, "gold", 120, 16, text)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(bar)
		col.add_child(_wrap(L.t("level.xpHint"), 12, UiKit.INK_SOFT))
	else:
		col.add_child(UiKit.label(L.t("level.maxReached"), 14))


# MARK: Характеристики

func _bonuses_card() -> void:
	var s := Game.stats
	var tiles := [
		["fist", L.t("stats.damage"), "x" + _dec(s.damage_mult, 2)],
		["bolt", L.t("stats.hitEvery"), L.t("stats.seconds", [_dec(s.hit_interval, 2)])],
		["heart", L.t("stats.health"), Fmt.n(int(Game.workshop.max_hp()))],
		["shield", L.t("stats.defense"), Fmt.pct(Game.workshop.defense())],
		["wind", L.t("stats.dodge"), Fmt.pct(Game.workshop.dodge_chance())],
		["target", L.t("stats.crit"), Fmt.pct(s.crit_chance)],
		["boots", L.t("stats.speed"), "+" + Fmt.pct(s.speed / Stats.BASE_SPEED - 1.0)],
		["bag", L.t("stats.backpack"), L.t("stats.slots", [s.capacity])],
		["basket", L.t("stats.yield"), "+" + Fmt.pct(s.yield_all)],
		["sprout", L.t("stats.regrow"), "x" + _dec(1.0 / s.respawn_mult, 2)],
		["book", L.t("stats.xp"), "+" + Fmt.pct(s.xp_mult - 1.0)],
		["coins", L.t("stats.sell"), "+" + Fmt.pct(s.sell_mult - 1.0)],
	]
	section_title(L.t("stats.title"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	content.add_child(grid)
	for t in tiles:
		grid.add_child(_stat_tile(t[0], t[1], t[2]))

	var points := PanelContainer.new()
	points.add_theme_stylebox_override("panel", _list_box(12))
	content.add_child(points)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	points.add_child(row)
	row.add_child(UiKit.icon("star", 26))
	var pl := UiKit.label(L.t("stats.talentPoints"), 14)
	pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pl)
	var pv := UiKit.label(L.t("stats.freeOf", [Game.talents.points_free(), Game.talents.points_total()]), 14)
	pv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pv)


## Плитка характеристики (StatTile): иконка, значение, подпись.
func _stat_tile(icon: String, title: String, value: String) -> PanelContainer:
	var p := PanelContainer.new()
	var ps := _list_box(12)
	ps.set_content_margin_all(8)
	p.add_theme_stylebox_override("panel", ps)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	p.add_child(row)
	var frame := PanelContainer.new()
	var fs := UiKit.box(UiKit.PARCHMENT_DEEP, Color(UiKit.WOOD_DARK, 0.4), 9, 2, false)
	fs.set_content_margin_all(4)
	frame.add_theme_stylebox_override("panel", fs)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.add_child(UiKit.icon(icon, 26))
	row.add_child(frame)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	var v := UiKit.label(value, 15)
	v.clip_text = true
	v.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(v)
	var t := UiKit.label(title, 11, UiKit.INK_SOFT)
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(t)
	return p


# MARK: Скоро откроется

## Ближайшие уровни с наградами: до 14 уровней вперёд (UpcomingCard).
func _upcoming_items() -> Array:
	var out: Array = []
	var start := Game.level + 1
	var end := mini(Game.MAX_LEVEL, start + 14)
	for lv in range(start, end + 1):
		var lines := unlocks(lv)
		if not lines.is_empty():
			out.append({"level": lv, "lines": lines})
	return out


func _upcoming_card() -> void:
	var list := _upcoming_items()
	section_title(L.t("upcoming.title"))
	_every_level()
	if list.is_empty():
		content.add_child(UiKit.label(L.t("upcoming.none"), 14))
		return
	_next_card(list[0])
	var rest := list.slice(1, 7)
	if rest.is_empty():
		return
	var box := PanelContainer.new()
	var bs := _list_box(14)
	bs.set_content_margin_all(0)
	box.add_theme_stylebox_override("panel", bs)
	content.add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	box.add_child(col)
	for i in rest.size():
		col.add_child(_level_row(rest[i]))
		if i < rest.size() - 1:
			var m := MarginContainer.new()
			m.add_theme_constant_override("margin_left", 52)
			m.mouse_filter = Control.MOUSE_FILTER_IGNORE
			m.add_child(_divider())
			col.add_child(m)


## Что даёт каждый уровень: четыре короткие плашки.
func _every_level() -> void:
	content.add_child(UiKit.label(L.t("upcoming.eachTitle"), 11, UiKit.INK_SOFT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	content.add_child(row)
	for chip in [["star", "upcoming.chip.talent"], ["bag", "upcoming.chip.bag"], ["fist", "upcoming.chip.power"],
			["coins", "upcoming.chip.sell"]]:
		var p := PanelContainer.new()
		var ps := UiKit.box(UiKit.PARCHMENT_DEEP, Color(UiKit.WOOD_DARK, 0.35), 12, 1, false)
		ps.content_margin_left = 6
		ps.content_margin_right = 6
		ps.content_margin_top = 4
		ps.content_margin_bottom = 4
		p.add_theme_stylebox_override("panel", ps)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 3)
		p.add_child(h)
		var ic := UiKit.icon(chip[0], 15)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
		# Узкая плашка: текст переносится на вторую строку, а не вылезает за край
		var l := UiKit.label(L.t(chip[1]), 11)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		row.add_child(p)


## Ближайший уровень с наградами: все строки и сколько осталось.
func _next_card(item: Dictionary) -> void:
	var lv := int(item["level"])
	var left := lv - Game.level
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.box(Color("fff3d0"), UiKit.GOLD_DARK, 14, 3, false))
	content.add_child(p)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	p.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	col.add_child(head)
	head.add_child(_level_badge(lv, 40))
	var hc := VBoxContainer.new()
	hc.alignment = BoxContainer.ALIGNMENT_CENTER
	hc.add_theme_constant_override("separation", 1)
	head.add_child(hc)
	hc.add_child(UiKit.label(L.t("upcoming.next"), 15))
	hc.add_child(UiKit.label(L.t("upcoming.nextLevel") if left == 1 else L.t("upcoming.inLevels", [left]), 11,
		UiKit.INK_SOFT))
	for line in item["lines"]:
		col.add_child(_line_row(line, 22, 13))


## Строка уровня: иконки наград, по нажатию раскрывается текст.
func _level_row(item: Dictionary) -> Control:
	var lv := int(item["level"])
	var lines: Array = item["lines"]
	var open := _expanded.has(lv)
	var p := PanelContainer.new()
	var ps := StyleBoxEmpty.new()
	ps.content_margin_left = 10
	ps.content_margin_right = 10
	ps.content_margin_top = 8
	ps.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", ps)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	# Нажатие раскрывает строку; если палец сдвинулся (прокрутка), не раскрываем
	p.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				p.set_meta("down", e.global_position)
			elif p.has_meta("down") and e.global_position.distance_to(p.get_meta("down")) < 12.0:
				_toggle(lv))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	head.add_child(_level_badge(lv, 30))
	var icons := HBoxContainer.new()
	icons.add_theme_constant_override("separation", 4)
	icons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(icons)
	for i in mini(5, lines.size()):
		icons.add_child(_icon(lines[i]["icon"], 22))
	if lines.size() > 5:
		var more := UiKit.label("+%d" % (lines.size() - 5), 12, UiKit.INK_SOFT)
		more.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icons.add_child(more)
	var arrow := UiKit.label("›", 16, UiKit.INK_SOFT)
	arrow.custom_minimum_size = Vector2(16, 16)
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	arrow.pivot_offset = Vector2(8, 8)
	arrow.rotation_degrees = -90.0 if open else 90.0
	head.add_child(arrow)
	if open:
		for line in lines:
			var m := MarginContainer.new()
			m.add_theme_constant_override("margin_left", 40)
			m.mouse_filter = Control.MOUSE_FILTER_IGNORE
			m.add_child(_line_row(line, 18, 12))
			col.add_child(m)
	return p


func _toggle(level: int) -> void:
	if _expanded.has(level):
		_expanded.erase(level)
	else:
		_expanded[level] = true
	_dirty = true


# MARK: Статистика

func _stats_card() -> void:
	var c := card()
	c.add_child(UiKit.label(L.t("stats.statistics"), 16))
	var tamed := 0
	for id in ANIMAL_IDS:
		if Game.animals.stars(id) > 0:
			tamed += 1
	_stat_row(c, "tool_pickaxe", L.t("stats.harvests"), Fmt.n(int(Game.save.get("harvests", 0))))
	_stat_row(c, "coins", L.t("stats.coinsEarned"), Fmt.n(int(Game.save.get("coinsEarned", 0))))
	_stat_row(c, "wheat", L.t("stats.crops"), Fmt.n(int(Game.save.get("cropsHarvested", 0))))
	_stat_row(c, "skull", L.t("stats.kills"), Fmt.n(int(Game.save.get("kills", 0))))
	_stat_row(c, "paw", L.t("stats.animals"), L.t("common.ofN", [tamed, ANIMAL_IDS.size()]))
	_stat_row(c, "map", L.t("stats.locations"), L.t("common.ofN", [Game.save["unlocked"].size(), Locations.world().size()]))
	var gathered: Dictionary = Game.save.get("gathered", {})
	var kinds := Res.KINDS.filter(func(k: String) -> bool: return int(gathered.get(k, 0)) > 0)
	if kinds.is_empty():
		return
	c.add_child(UiKit.label(L.t("stats.gathered"), 12, UiKit.INK_SOFT))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	c.add_child(flow)
	for kind in kinds:
		var p := PanelContainer.new()
		var ps := UiKit.box(UiKit.PARCHMENT_DEEP, Color(UiKit.WOOD_DARK, 0.35), 12, 1, false)
		ps.content_margin_left = 8
		ps.content_margin_right = 8
		ps.content_margin_top = 4
		ps.content_margin_bottom = 4
		p.add_theme_stylebox_override("panel", ps)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 4)
		p.add_child(h)
		h.add_child(UiKit.icon(kind, 18))
		h.add_child(UiKit.label(Fmt.n(int(gathered[kind])), 13))
		flow.add_child(p)


func _stat_row(parent: Control, icon: String, title: String, value: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	row.add_child(UiKit.icon(icon, 22))
	var t := UiKit.label(title, 14)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	row.add_child(UiKit.label(value, 14))


# MARK: Настройки

func _settings_card() -> void:
	var c := card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	c.add_child(row)
	var l := UiKit.label(L.t("settings.language"), 14)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	var pick := OptionButton.new()
	pick.focus_mode = Control.FOCUS_NONE
	pick.fit_to_longest_item = false
	var style := UiKit.pill_style()
	style.set_corner_radius_all(10)
	for state in ["normal", "hover", "pressed", "disabled"]:
		pick.add_theme_stylebox_override(state, style)
	pick.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	pick.add_theme_font_override("font", UiKit.font())
	pick.add_theme_font_size_override("font_size", 13)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		pick.add_theme_color_override(k, Color.WHITE)
	pick.add_theme_color_override("font_outline_color", UiKit.WOOD_DARK)
	pick.add_theme_constant_override("outline_size", 3)
	for i in L.CODES.size():
		var code: String = L.CODES[i]
		pick.add_item(L.NAMES.get(code, code), i)
		if code == L.code:
			pick.select(i)
	pick.get_popup().add_theme_font_size_override("font_size", 16)
	pick.item_selected.connect(func(index: int) -> void:
		var code: String = L.CODES[index]
		if code != L.code:
			L.set_language(code))
	row.add_child(pick)
	c.add_child(_divider())
	c.add_child(WardrobePanel.profile_row())
	c.add_child(_divider())
	_purchases_rows(c)


## Pro (если куплен), восстановление покупок и сброс тестовых покупок (сборка без магазина, как SIDELOAD).
func _purchases_rows(c: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	c.add_child(row)
	if Game.premium.has_pro():
		var crown := UiKit.icon("crown", 18)
		crown.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(crown)
		var pro := UiKit.label(Products.title("pro"), 14, UiKit.TONES["purple"][2])
		pro.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(pro)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	var restore := UiKit.button(L.t("shop.restore"), "wood", 13, true)
	restore.pressed.connect(Store.restore)
	row.add_child(restore)
	var reset := UiKit.button(L.t("settings.resetTest"), "gray", 13, true)
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	reset.pressed.connect(func() -> void: Game.premium.reset_test_purchases())
	c.add_child(reset)


# MARK: Элементы

## Карточка с рамкой цвета (Card(tint:)).
func _card(border: Color) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.box(UiKit.PARCHMENT_LIGHT, border, 14, 3, false))
	content.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	return v


## Светлая подложка для групп строк (listBox).
func _list_box(radius: int) -> StyleBoxFlat:
	return UiKit.box(UiKit.PARCHMENT_LIGHT, Color(UiKit.WOOD_DARK, 0.45), radius, 2, false)


## Оранжевый кружок с номером уровня.
func _level_badge(level: int, size: float) -> PanelContainer:
	var p := PanelContainer.new()
	var s := UiKit.box(UiKit.TONES["orange"][1], UiKit.OUTLINE, int(size / 2.0), 2, false)
	s.set_content_margin_all(0)
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size = Vector2(size, size)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UiKit.title(str(level), int(size * 0.42))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


## Строка награды или открытия: иконка и текст.
func _line_row(line: Dictionary, icon_size: float, font_size: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_icon(line["icon"], icon_size))
	var t := _wrap(line["text"], font_size)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(t)
	return row


func _icon(code: String, size: float) -> Control:
	var ic := UiKit.icon_any(code, size)
	ic.custom_minimum_size = Vector2(size + 4.0, size)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return ic


func _divider() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(UiKit.WOOD_DARK, 0.18)
	r.custom_minimum_size = Vector2(0, 2)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _wrap(text: String, size: int, color := UiKit.INK) -> Label:
	var l := UiKit.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Дробное число с заданным числом знаков (Fmt.decimal).
static func _dec(v: float, digits: int) -> String:
	return ("%." + str(digits) + "f") % v
