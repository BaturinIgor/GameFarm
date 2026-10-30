class_name ResidentCard
extends PanelContainer
## Карточка рядом с жителем: портрет, имя, что сейчас, кнопка "Поговорить" или "Сдать".
## Показывается через Hud.current.set_prompt("resident", card).

var id := ""


func _init(resident: String) -> void:
	id = resident
	add_theme_stylebox_override("panel", UiKit.panel_style(18))
	mouse_filter = Control.MOUSE_FILTER_STOP
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	var portrait := TraderPanel.portrait(Residents.sheet(id), 52)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(portrait)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	col.add_child(UiKit.label(Residents.name_of(id), 15))
	var text := UiKit.label(ResidentCard.status_text(id), 13, UiKit.INK_SOFT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(text)
	var s := Game.residents.state(id)
	if s == "new" or s == "ready":
		var b := UiKit.button(L.t("story.talk") if s == "new" else L.t("story.handIn"), "green")
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func() -> void: DialogPopup.talk(id))
		row.add_child(b)


## Что у жителя сейчас: новое задание, прогресс, когда следующая глава.
static func status_text(id: String) -> String:
	var rs := Game.residents
	match rs.state(id):
		"away":
			return L.t("story.away", [Residents.main_level(id)])
		"done":
			return L.t("story.finished")
		"locked":
			return L.t("story.locked", [int(rs.current(id)["level"])])
		"new":
			return L.t("story.new")
		"ready":
			return L.t("story.ready")
	var p := rs.progress(id)
	return "%s · %s / %s" % [Residents.task_text(rs.current(id)["task"]), Fmt.n(int(p[0])), Fmt.n(int(p[1]))]


func _ready() -> void:
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)
