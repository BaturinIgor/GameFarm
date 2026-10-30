class_name WherePopup
extends Control
## "Где взять": все источники ресурса с кнопками. Локация - "Перейти" (герой переносится туда, стрелка
## у края экрана ведёт к ближайшей точке), здание усадьбы, звери, грядки, монстры, подземелья - "Открыть".
## Открывается нажатием на значок ресурса в цене, заказе, рецепте, задании (WherePopup.tap_to_open).

var kind := ""


static func open(res_kind: String) -> void:
	if Hud.current == null or res_kind == "":
		return
	var p := WherePopup.new()
	p.kind = res_kind
	Hud.current.show_overlay(p)


## Сделать значок ресурса нажимаемым: короткое касание (не прокрутка) открывает "Где взять".
static func tap_to_open(c: Control, res_kind: String) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	var press := [Vector2.ZERO]
	c.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			press[0] = mb.global_position
		elif mb.global_position.distance_to(press[0]) < 10.0:
			WherePopup.open(res_kind))


## Источники ресурса: [{kind: location|building|animal|crop|monster|dungeon, id, open, level}].
static func sources(res_kind: String) -> Array:
	var out: Array = []
	for id in Estate.IDS:
		if res_kind in Estate.recipes(id):
			out.append({"kind": "building", "id": id, "open": Game.estate.is_open(id), "level": Estate.hero_level(id)})
	for id in Locations.IDS:
		if Locations.kind(id) != "world":
			continue
		if res_kind in MapPanel.location_resources(id):
			out.append({"kind": "location", "id": id, "open": Game.world_map.is_unlocked(id),
				"level": int(Locations.spec(id)["level"])})
	for crop in Farming.CROP_IDS:
		var cs := Farming.spec(crop)
		if str(cs.get("produce", "")) == res_kind:
			out.append({"kind": "crop", "id": crop, "open": Game.level >= int(cs["level"]), "level": int(cs["level"])})
	for a in Animals.SPECS:
		for e in Animals.SPECS[a].get("effects", []):
			if e.get("type") == "produce" and str(e.get("kind", "")) == res_kind:
				out.append({"kind": "animal", "id": a, "open": Game.animals.stars(a) > 0, "level": 0})
	for m in Monsters.KINDS:
		if Monsters.loot(m) == res_kind:
			out.append({"kind": "monster", "id": m, "open": true, "level": 0})
			break
	if res_kind == "essence":
		out.append({"kind": "dungeon", "id": "", "open": Game.level >= 10, "level": 10})
	return out


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
	var panel := PanelContainer.new()
	var st := UiKit.panel_style(20)
	st.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", st)
	panel.custom_minimum_size = Vector2(minf(350.0, get_viewport_rect().size.x - 32.0), 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	head.add_child(UiKit.icon(kind, 40))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	head.add_child(col)
	col.add_child(UiKit.label(Res.name_of(kind), 18))
	col.add_child(UiKit.label(L.t("where.have", [Fmt.n(Game.amount(kind)), Fmt.n(Game.estate.storage_limit_of(kind))]),
		12, UiKit.INK_SOFT))
	v.add_child(UiKit.label(L.t("where.title"), 14, UiKit.INK_SOFT))
	var list := sources(kind)
	if list.is_empty():
		var none := UiKit.label(L.t("where.none"), 13, UiKit.INK_SOFT)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(none)
	# Открытые - сверху, закрытые - только первые два
	var open_rows: Array = list.filter(func(s: Dictionary) -> bool: return s["open"])
	var closed: Array = list.filter(func(s: Dictionary) -> bool: return not s["open"])
	closed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["level"]) < int(b["level"]))
	for s in open_rows + closed.slice(0, 2):
		v.add_child(_row(s))
	var close_b := UiKit.button(L.t("common.close"), "wood", 14, true)
	close_b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_b.pressed.connect(close)
	v.add_child(close_b)
	panel.resized.connect(func() -> void: panel.pivot_offset = panel.size / 2.0)
	panel.scale = Vector2.ONE * 0.9
	var tw := create_tween()
	tw.tween_property(panel, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _row(s: Dictionary) -> PanelContainer:
	var p := PanelContainer.new()
	var st := UiKit.box(Color(UiKit.PARCHMENT_LIGHT, 1.0) if s["open"] else Color(UiKit.PARCHMENT_DEEP, 0.6),
		Color(UiKit.WOOD_DARK, 0.4), 12, 2, false)
	st.set_content_margin_all(8)
	p.add_theme_stylebox_override("panel", st)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	p.add_child(row)
	var icon_code := "px:map"
	var title := ""
	match str(s["kind"]):
		"location":
			icon_code = "px:" + Locations.icon(s["id"])
			title = Locations.name_of(s["id"])
		"building":
			icon_code = "px:hammer"
			title = L.t("where.building", [Estate.name_of(s["id"])])
		"crop":
			icon_code = "px:" + Farming.seed_icon(s["id"])
			title = L.t("where.crop")
		"animal":
			icon_code = "an:" + str(s["id"])
			title = L.t("animal." + str(s["id"]))
		"monster":
			icon_code = "px:sword"
			title = L.t("where.monster", [Monsters.name_of(s["id"])])
		"dungeon":
			icon_code = "px:skull"
			title = L.t("dungeon.tab")
	var ic := UiKit.icon_any(icon_code, 28)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not s["open"]:
		ic.modulate = Color(1, 1, 1, 0.5)
	row.add_child(ic)
	var t := UiKit.label(title, 14, UiKit.INK if s["open"] else UiKit.INK_SOFT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(t)
	if not s["open"]:
		if int(s["level"]) > 0:
			row.add_child(HousePanel.level_tag(int(s["level"]), Game.level >= int(s["level"])))
		return p
	var action := _action(s)
	if action.is_empty():
		return p
	var b := UiKit.button(action[0], "green", 13, true)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var go: Callable = action[1]
	b.pressed.connect(func() -> void:
		close()
		go.call())
	row.add_child(b)
	return p


## Подпись кнопки и что делать: [текст, Callable] или [] (ты уже здесь).
func _action(s: Dictionary) -> Array:
	var res := kind
	match str(s["kind"]):
		"location":
			var id: String = s["id"]
			if Game.current == id:
				return [L.t("where.show"), func() -> void:
					Game.nav_target = res
					WherePopup._close_windows()]
			return [L.t("where.go"), func() -> void:
				if Game.world_map.travel(id):
					Game.nav_target = res
					WherePopup._close_windows()]
		"building":
			return [L.t("where.open"), func() -> void: EstatePanel.open()]
		"crop":
			if Game.current == "meadow":
				return []
			return [L.t("where.go"), func() -> void:
				if Game.world_map.travel("meadow"):
					WherePopup._close_windows()]
		"animal":
			return [L.t("where.open"), func() -> void:
				if Hud.current != null:
					Hud.current.open_named("animals")]
		"monster":
			return [L.t("where.open"), func() -> void: MonstersFeature.open_hunt()]
		"dungeon":
			return [L.t("where.open"), func() -> void:
				if Hud.current != null:
					Hud.current.open_window(HuntPanel.new("dungeons"))]
	return []


static func _close_windows() -> void:
	if Hud.current != null:
		Hud.current.close_window()


func close() -> void:
	queue_free()
