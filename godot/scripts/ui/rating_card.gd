class_name RatingCard
## Карточка рейтинга ивента во вкладках окна ивентов: лига или мир, место игрока, таблица и награды.
## Данные берёт из Game.rating.cache и просит обновить (Game.rating.fetch); после ответа окно перестраивается.

## Что показано: "league" или "global" (общее для обеих вкладок).
static var view := "league"
## Показать таблицу наград вместо таблицы мест.
static var show_rewards := false

const ROWS_GLOBAL := 30


static func build(key: String) -> Control:
	var c := EventsPanel._card(Color(UiKit.WOOD_DARK, 0.45), 2)
	var v := EventsPanel._body(c)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	head.add_child(UiKit.icon("star", 26))
	var title := UiKit.label(L.t("rating.title"), 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var gift := UiKit.button(L.t("rating.rewards") if not show_rewards else L.t("rating.table"), "wood", 12, true)
	gift.pressed.connect(func() -> void:
		show_rewards = not show_rewards
		Game.changed.emit())
	head.add_child(gift)

	if not OnlineConfig.enabled():
		v.add_child(HousePanel.wrapped(L.t("rating.soon"), 12, UiKit.INK_SOFT))
		if show_rewards:
			_rewards(v)
		return c

	v.add_child(UiKit.tabs([["league", L.t("rating.league")], ["global", L.t("rating.global")]], view,
		func(id: String) -> void:
			view = id
			Game.changed.emit()))
	if show_rewards:
		_rewards(v)
		return c

	Game.rating.fetch(key)
	var data: Dictionary = Game.rating.cache.get(key, {})
	if data.is_empty():
		v.add_child(UiKit.label(L.t("rating.loading"), 12, UiKit.INK_SOFT))
		return c
	if bool(data.get("error", false)):
		v.add_child(HousePanel.wrapped(L.t("rating.offline"), 12, UiKit.INK_SOFT))
		return c
	var rows: Array = data.get(view, [])
	var me: Dictionary = {}
	for r in rows:
		if r is Dictionary and bool(r.get("me", false)):
			me = r
	if me.is_empty():
		v.add_child(HousePanel.wrapped(L.t("rating.join"), 12, UiKit.INK_SOFT))
	else:
		v.add_child(UiKit.label(L.t("rating.you", [int(me.get("place", 0))]), 14, UiKit.TONES["green"][2]))
	if rows.is_empty():
		v.add_child(UiKit.label(L.t("rating.empty"), 12, UiKit.INK_SOFT))
	var shown := 0
	for r in rows:
		if not (r is Dictionary):
			continue
		var mine := bool(r.get("me", false))
		if view == "global" and shown >= ROWS_GLOBAL and not mine:
			continue
		v.add_child(_row(r, mine))
		shown += 1
	v.add_child(_name_row())
	return c


static func _row(r: Dictionary, mine: bool) -> Control:
	var p := PanelContainer.new()
	var s := UiKit.box(Color(UiKit.TONES["green"][1], 0.25) if mine else Color(UiKit.PARCHMENT_DEEP, 0.5),
		Color(UiKit.WOOD_DARK, 0.25), 8, 1, false)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", s)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	p.add_child(row)
	var place := UiKit.label(str(int(r.get("place", 0))), 13, UiKit.INK)
	place.custom_minimum_size = Vector2(34, 0)
	row.add_child(place)
	var name := UiKit.label(str(r.get("name", "")), 13, UiKit.INK)
	name.clip_text = true
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name)
	var lvl := UiKit.label(L.t("rating.level", [int(r.get("level", 1))]), 11, UiKit.INK_SOFT)
	lvl.custom_minimum_size = Vector2(44, 0)
	row.add_child(lvl)
	var score := UiKit.label(Fmt.n(int(r.get("score", 0))), 13, UiKit.INK)
	score.custom_minimum_size = Vector2(64, 0)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(score)
	return p


## Имя в таблицах. Имена только автоматические (Farmer1234): свободный ввод виден другим игрокам,
## а это пользовательский контент, которому App Store требует фильтр и жалобы.
static func _name_row() -> Control:
	var name := UiKit.label(Game.rating.player_name(), 13, UiKit.INK)
	name.clip_text = true
	return name


## Таблица наград: лига и мир.
static func _rewards(v: VBoxContainer) -> void:
	v.add_child(UiKit.label(L.t("rating.league"), 13, UiKit.INK_SOFT))
	var from := 1
	for r in Ratings.LEAGUE:
		v.add_child(_reward_row(Ratings.place_label(from, int(r[0])), int(r[1]), int(r[2])))
		from = int(r[0]) + 1
	v.add_child(UiKit.label(L.t("rating.global"), 13, UiKit.INK_SOFT))
	from = 1
	for r in Ratings.GLOBAL:
		v.add_child(_reward_row(Ratings.place_label(from, int(r[0])), int(r[1]), int(r[2])))
		from = int(r[0]) + 1
	v.add_child(_reward_row(L.t("rating.topPct", [Ratings.GLOBAL_TOP_PCT]), int(Ratings.GLOBAL_PCT_REWARD[0]),
		int(Ratings.GLOBAL_PCT_REWARD[1])))


static func _reward_row(caption: String, crystals: int, planks: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var l := UiKit.label(caption, 12, UiKit.INK)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	row.add_child(UiKit.icon("gem", 16))
	var c := UiKit.label(Fmt.n(crystals), 12, UiKit.INK)
	c.custom_minimum_size = Vector2(36, 0)
	row.add_child(c)
	row.add_child(UiKit.icon("planks", 16))
	var p := UiKit.label(Fmt.n(Ratings.planks_scaled(planks, Game.level)), 12, UiKit.INK)
	p.custom_minimum_size = Vector2(36, 0)
	row.add_child(p)
	return row
