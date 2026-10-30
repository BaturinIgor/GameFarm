class_name CalendarPanel
extends Sheet
## Календарь наград за вход: неделя наград и кнопка "Забрать" (порт CalendarView).
## При запуске, если сегодняшняя награда не забрана, - заставка CalendarPanel.check() (CalendarPopup).

static var _popup: Control

var _next_label: Label
var _tick := 0.0


func _init() -> void:
	title_key = "house.calendar"


## Показать календарь при запуске, если сегодня награду ещё не забирали и обучение пройдено.
## Заставка ждёт, пока закроются другие заставки (новый уровень, доход за время без игры).
static func check() -> void:
	if Hud.current == null or not Game.house.can_claim_login() or not bool(Game.save.get("tutorialDone", false)):
		return
	if _popup != null and is_instance_valid(_popup):
		return
	_popup = LoginPopup.new()
	Hud.current.show_overlay(_popup)


func _process(delta: float) -> void:
	super._process(delta)
	_tick -= delta
	if _tick <= 0.0:
		_tick = 1.0
		if _next_label != null and is_instance_valid(_next_label):
			_next_label.text = CalendarPanel.next_text()
		if Game.house.can_claim_login() != (_next_label == null):
			_dirty = true


func build() -> void:
	_next_label = null
	var hint := HousePanel.wrapped(L.t("calendar.hint"), 13, UiKit.INK_SOFT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(hint)
	content.add_child(CalendarPanel.grid())
	if Game.house.can_claim_login():
		content.add_child(CalendarPanel.claim_button(Callable()))
	else:
		_next_label = CalendarPanel.next_label()
		content.add_child(_next_label)


# MARK: Общие части окна и заставки

## "Следующая награда через ч:мм:сс".
static func next_text() -> String:
	return L.t("calendar.next", [House.countdown(Game.house.next_login_at() - Time.get_unix_time_from_system())])


static func next_label() -> Label:
	var l := UiKit.label(next_text(), 13, UiKit.INK_SOFT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func claim_button(on_claim: Callable) -> Button:
	var b := UiKit.button(L.t("calendar.claim"), "orange", 16)
	b.icon = Sprites.icon("chest_gold")
	b.add_theme_constant_override("icon_max_width", 22)
	b.add_theme_constant_override("h_separation", 8)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.pressed.connect(func() -> void:
		Game.house.claim_login()
		if on_claim.is_valid():
			on_claim.call())
	return b


## Неделя наград: забранные, сегодняшняя и будущие (CalendarGrid).
static func grid() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	var claims := Game.house.login_claims()
	var start := claims - claims % House.LOGIN_DAYS
	var can := Game.house.can_claim_login()
	for i in House.LOGIN_DAYS:
		var claim := start + i
		g.add_child(_day_cell(i, Game.house.login_reward(claim), claim < claims, claim == claims and can))
	return g


static func _day_cell(i: int, reward: Dictionary, claimed: bool, today: bool) -> Control:
	var p := PanelContainer.new()
	var fill: Color = UiKit.TONES["orange"][1] if today else (Color("fbe3c2") if i == House.LOGIN_DAYS - 1 else UiKit.PARCHMENT_LIGHT)
	var s := UiKit.box(fill, UiKit.OUTLINE if today else Color(UiKit.WOOD_DARK, 0.4), 12, 3 if today else 2, false)
	s.content_margin_left = 2
	s.content_margin_right = 2
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", s)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(col)
	var day := UiKit.label(L.t("calendar.day", [i + 1]), 11, Color.WHITE if today else UiKit.INK_SOFT, 3 if today else 0)
	if today:
		day.label_settings.outline_color = UiKit.TONES["orange"][2]
	day.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(day)
	# Забранная награда бледнее, поверх - галочка
	var holder := PanelContainer.new()
	holder.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(holder)
	var pic := reward_icon(reward)
	holder.add_child(pic)
	if claimed:
		pic.modulate.a = 0.45
		var center := CenterContainer.new()
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(HousePanel.check_mark(24))
		holder.add_child(center)
	return p


## Значок награды и подпись (LoginRewardIcon).
static func reward_icon(r: Dictionary) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pic := HBoxContainer.new()
	pic.alignment = BoxContainer.ALIGNMENT_CENTER
	pic.add_theme_constant_override("separation", 0)
	col.add_child(pic)
	var text := ""
	var font_size := 11
	match str(r.get("type", "")):
		"coins":
			pic.add_child(UiKit.icon("coins", 26))
			text = Fmt.n(int(r["coins"]))
		"seeds":
			pic.add_child(UiKit.icon("seed_" + str(r["crop"]), 26))
			text = "x%d" % int(r["n"])
		"tickets":
			pic.add_child(UiKit.icon("ticket", 26))
			text = "x%d" % int(r["n"])
		"coinsAndWood":
			pic.add_child(UiKit.icon("coins", 20))
			pic.add_child(UiKit.icon("wood", 20))
			text = Fmt.n(int(r["coins"]))
		"dish":
			pic.add_child(UiKit.icon(House.dish_icon(str(r["dish"])), 26))
			text = "x1"
		"resource":
			pic.add_child(UiKit.icon(str(r["kind"]), 26))
			text = "x%d" % int(r["n"])
		"chest":
			pic.add_child(UiKit.icon("chest_gold", 28))
			if int(r.get("crystals", 0)) > 0:
				pic.add_child(UiKit.icon("gem", 18))
			text = "%s +%d" % [Fmt.n(int(r["coins"])), int(r["tickets"])]
			font_size = 10
	var l := UiKit.label(text, font_size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	col.add_child(l)
	return col


## Календарь при запуске игры (CalendarPopup): неделя, "Забрать" и "Позже".
class LoginPopup extends Control:
	var _panel := PanelContainer.new()
	var _closing := false
	var _shown := false

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
		var stack := VBoxContainer.new()
		# Лента заголовка заходит на верх плашки
		stack.add_theme_constant_override("separation", -18)
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(stack)
		var ribbon := PanelContainer.new()
		var rs := UiKit.box(UiKit.TONES["orange"][1], UiKit.OUTLINE, 12, 3)
		rs.content_margin_left = 20
		rs.content_margin_right = 20
		rs.content_margin_top = 5
		rs.content_margin_bottom = 5
		ribbon.add_theme_stylebox_override("panel", rs)
		ribbon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ribbon.z_index = 1
		ribbon.add_child(UiKit.title(L.t("house.calendar"), 19))
		stack.add_child(ribbon)
		var style := UiKit.panel_style(22)
		style.set_content_margin_all(16)
		style.content_margin_top = 30
		_panel.add_theme_stylebox_override("panel", style)
		_panel.custom_minimum_size = Vector2(minf(380.0, get_viewport_rect().size.x - 40.0), 0)
		stack.add_child(_panel)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 12)
		_panel.add_child(col)
		col.add_child(CalendarPanel.grid())
		if Game.house.can_claim_login():
			col.add_child(CalendarPanel.claim_button(close))
		else:
			col.add_child(CalendarPanel.next_label())
		var later := UiKit.button(L.t("offer.later"), "wood", 14, true)
		later.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		later.pressed.connect(close)
		col.add_child(later)
		stack.resized.connect(func() -> void: stack.pivot_offset = stack.size / 2.0)
		stack.scale = Vector2.ONE * 0.85
		modulate.a = 0.0
		visible = false

	## Ждём, пока закроются заставки, показанные раньше (новый уровень, доход без игры).
	func _process(_delta: float) -> void:
		if _shown or _closing:
			return
		for c in get_parent().get_children():
			if c == self:
				break
			if c is Control and (c as Control).visible:
				return
		_shown = true
		visible = true
		var stack: Control = _panel.get_parent()
		var tw := create_tween().set_parallel()
		tw.tween_property(self, "modulate:a", 1.0, 0.18)
		tw.tween_property(stack, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	func close() -> void:
		if _closing:
			return
		_closing = true
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.15)
		tw.tween_callback(queue_free)
