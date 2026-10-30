class_name DialogPopup
extends Control
## Разговор с жителем: панель внизу экрана, портрет и имя, реплики по одной (касание - дальше,
## текст печатается). После последней реплики - задание с кнопками или награда.
## Если диалоги выключены в настройках, окна нет: задание берётся и сдаётся сразу, с подсказкой.

## Секунд на букву при печати.
const TYPE_SPEED := 0.018

var npc := ""
var lines: Array = []
## Что показать после последней реплики: func(box: VBoxContainer, popup: DialogPopup).
var footer := Callable()
var _i := 0
var _text: Label
var _footer_box: VBoxContainer
var _next: Button
var _tw: Tween


## Поговорить с жителем: взять новое задание или сдать готовое.
static func talk(id: String) -> void:
	var rs := Game.residents
	match rs.state(id):
		"new":
			if not Settings.dialogs():
				rs.take(id)
				Game.show_toast("px:" + Residents.icon(id), L.t("story.taken", [Residents.name_of(id)]))
				return
			var ch := rs.chapter(id)
			_open(id, Residents.intro(id, ch), func(box: VBoxContainer, popup: DialogPopup) -> void:
				box.add_child(DialogPopup.task_view(Residents.chapters(id)[ch]["task"], 13))
				box.add_child(DialogPopup.reward_row(Residents.reward(id, ch)))
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 8)
				box.add_child(row)
				var later := UiKit.button(L.t("story.later"), "wood", 14)
				later.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				later.pressed.connect(popup.close)
				row.add_child(later)
				var ok := UiKit.button(L.t("story.take"), "green", 14)
				ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				ok.pressed.connect(func() -> void:
					rs.take(id)
					popup.close())
				row.add_child(ok))
		"ready":
			var done_ch := rs.chapter(id)
			var reward := rs.hand_in(id)
			if reward.is_empty():
				return
			if not Settings.dialogs():
				Game.show_toast("px:gem", L.t("story.done", [Residents.name_of(id)]))
				return
			_open(id, [Residents.outro(id, done_ch)], func(box: VBoxContainer, popup: DialogPopup) -> void:
				box.add_child(DialogPopup.reward_row(reward))
				var ok := UiKit.button(L.t("story.thanks"), "green", 14)
				ok.pressed.connect(popup.close)
				box.add_child(ok))


static func _open(id: String, text_lines: Array, end: Callable) -> void:
	if Hud.current == null:
		return
	var p := DialogPopup.new()
	p.npc = id
	p.lines = text_lines
	p.footer = end
	Hud.current.show_overlay(p)


## Что нужно сделать: ресурсы значками или полоска прогресса.
static func task_view(task: Dictionary, size := 13) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var t := UiKit.label(Residents.task_text(task), size, UiKit.INK_SOFT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	if task["type"] == "give":
		v.add_child(UiKit.cost_view({"items": task["items"]}, size))
	return v


## Награда главы: кристаллы, монеты, опыт.
static func reward_row(reward: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(UiKit.label(L.t("story.reward"), 13, UiKit.INK_SOFT))
	for part in [["gem", int(reward["crystals"])], ["coins", int(reward["coins"])], ["book", int(reward["xp"])]]:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 3)
		h.add_child(UiKit.icon(part[0], 16))
		h.add_child(UiKit.label(Fmt.n(part[1]), 13))
		row.add_child(h)
	return row


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	gui_input.connect(_on_input)
	var panel := PanelContainer.new()
	var st := UiKit.panel_style(20)
	st.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", st)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	var bottom := float(UiKit.safe_insets(get_viewport()).get("bottom", 0.0))
	panel.offset_left = 12
	panel.offset_right = -12
	panel.offset_bottom = -20 - bottom
	panel.offset_top = -20 - bottom
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	var portrait := TraderPanel.portrait(Residents.sheet(npc), 72)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(portrait)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	head.add_child(col)
	col.add_child(UiKit.label(Residents.name_of(npc), 18, UiKit.WOOD_DARK))
	_text = UiKit.label("", 15)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(0, 44)
	col.add_child(_text)
	_footer_box = VBoxContainer.new()
	_footer_box.add_theme_constant_override("separation", 8)
	v.add_child(_footer_box)
	_next = UiKit.button(L.t("story.next"), "wood", 13, true)
	_next.size_flags_horizontal = Control.SIZE_SHRINK_END
	_next.pressed.connect(_advance)
	v.add_child(_next)
	panel.modulate.a = 0.0
	create_tween().tween_property(panel, "modulate:a", 1.0, 0.18)
	_show(0)


func _show(i: int) -> void:
	_i = i
	_text.text = str(lines[i]) if i < lines.size() else ""
	_text.visible_ratio = 0.0
	if _tw != null:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(_text, "visible_ratio", 1.0, maxf(0.15, TYPE_SPEED * float(_text.text.length())))
	var last := i >= lines.size() - 1
	_next.visible = not last
	if last and footer.is_valid() and _footer_box.get_child_count() == 0:
		footer.call(_footer_box, self)


## Касание: допечатать строку или перейти к следующей.
func _advance() -> void:
	if _text.visible_ratio < 1.0:
		if _tw != null:
			_tw.kill()
		_text.visible_ratio = 1.0
		return
	if _i < lines.size() - 1:
		_show(_i + 1)


func _on_input(e: InputEvent) -> void:
	var mb := e as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_advance()


func close() -> void:
	queue_free()
