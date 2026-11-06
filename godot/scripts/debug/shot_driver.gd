extends Node
## Снимки экрана для проверки в CI: запуск с "-- --shots <папка>".
## Сценарий по времени: старт, герой идёт касаниями к ближайшей точке и добывает,
## несёт добычу на склад, открывается окно склада. На каждом шаге - снимок.

const ORIGIN := Vector2(195, 620)
const WINDOWS := ["workshop", "talents", "animals", "quests", "level", "house", "kitchen", "garden", "trader", "hunt", "level:settings",
	"dungeon", "trophies", "collection", "collection:zoo", "collection:trophies", "legacy", "wardrobe", "map", "events", "shop",
	"shop:vip", "shop:crystals", "shop:market", "shop:free", "hunt:alchemy", "hunt:bestiary", "estate", "estate:orders", "quests:story", "wild", "talents:estate",
	"story", "story:altar", "collection:diary"]

var dir := "/tmp/shots"
var main: Node
var _time := 0.0
var _step := 0
var _trace := 0.0
var _opened := ""
var _shot_done := ""
var _sub := 0
var _mine: MineGame
var _lang := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--shots")
	if i >= 0 and i + 1 < args.size():
		dir = args[i + 1]
	DirAccess.make_dir_recursive_absolute(dir)
	# Снимки для App Store на нужном языке: "-- --shots <папка> --lang en"
	var li := args.find("--lang")
	if li >= 0 and li + 1 < args.size():
		L.set_language(args[li + 1], false)


func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	_time += dt
	var world: World = main.world
	_trace -= dt
	if _trace <= 0.0:
		_trace = 1.0
		print("t=%.1f pos=%s pack=%d coins=%d storage=%s" % [_time, world.player.position, Game.backpack_count,
			int(Game.save["coins"]), Game.save["storage"]])
		# Нагрузка: время скриптов и кадра, вызовы отрисовки, узлы и сироты (рост - утечка)
		print("PERF t=%.1f step=%d fps=%d process_ms=%.2f draws=%d nodes=%d orphans=%d objects=%d mem_mb=%.1f" % [_time, _step,
			Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_COUNT),
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
	match _step:
		0:
			if _time > 1.5:
				_shot("1_start")
				# Заставки при входе (календарь, доход без игры) ставят мир на паузу: закрываем, чтобы герой пошёл
				for _i in 6:
					if not main.hud.is_blocking() or not main.hud.back():
						break
				_touch(ORIGIN, true)
				_step = 1
		1:
			var target := _nearest(world)
			if target != null:
				var d := target.position - world.player.position
				_drag(ORIGIN + (d.normalized() * 50.0 if d.length() > 40.0 else Vector2.ZERO))
			if _time > 4.0 and _time - dt <= 4.0:
				_shot("2_walk")
			if Game.backpack_count >= 6 or _time > 14.0:
				_shot("3_gathered")
				_step = 2
		2:
			var d := world.layout.base - world.player.position
			_drag(ORIGIN + (d.normalized() * 50.0 if d.length() > 30.0 else Vector2.ZERO))
			if Game.backpack_count == 0 or _time > 24.0:
				_touch(ORIGIN, false)
				_shot("4_deposited")
				main.hud.open_window(StoragePanel.new())
				_step = 3
				_time = 100.0
		3:
			if _time > 101.0:
				_shot("5_storage_window")
				# Прокачанный герой: окна с содержимым
				Game.save["level"] = 18
				# Окно стартового набора закрывало бы снимки окон
				Game.save["starterOffers"] = 2
				Game.save["crystals"] = 98765
				Game.save["consumables"] = {"strength": 2, "guard": 1, "swift": 3}
				Game.save["killsBy"] = {"slimeGreen": 31, "orc": 12, "slimeBlue": 4}
				# Усадьба: несколько зданий, одно строится, лесопилка накопила доски
				var now := Time.get_unix_time_from_system()
				var est: Dictionary = Game.save["estate"]
				for b in [["main", 5], ["storage", 3], ["barn", 4], ["board", 2], ["sawmill", 3], ["mill", 1], ["kiln", 1],
						["tower", 5], ["wall", 3], ["camp", 6], ["loom", 2]]:
					est[b[0]]["level"] = b[1]
				est["sawmill"]["since"] = now - 3.0 * 3600.0
				est["mill"]["until"] = now + 25.0 * 60.0
				Game.save["storage"]["wheat"] = 120
				# Жители: кузнец ждёт сдачи главы 2, мельник с новым заданием
				var res: Dictionary = Game.save["residents"]
				res["smith"]["arrived"] = true
				res["smith"]["chapter"] = 1
				res["smith"]["taken"] = true
				res["miller"]["arrived"] = true
				# Куплены сияние и светлячки питомцев; переливы и ночную поляну можно примерить (кнопка в магазине)
				var bought: Array = Game.save.get("purchases", [])
				for cid in ["aura", "petGlow"]:
					bought.append(Products.id(cid))
				Game.save["purchases"] = bought
				res["smith"]["friend"] = 150
				res["elder"]["friend"] = 50
				# Ветка талантов "Усадьба": стройка и склад изучены
				Game.save["talents"]["estBuild"] = 3
				Game.save["talents"]["estStorage"] = 2
				Game.save["talents"]["estStamina"] = 1
				# Дикие земли: три зверя, один отряд уже в походе
				Game.save["animals"]["chicken"] = 3
				Game.save["animals"]["cow"] = 2
				Game.save["animals"]["sheep"] = 1
				# Пробуждённая курица (рамка цвета ступени) и корова с героем (синяя рамка в диких землях)
				Game.save["awaken"] = {"chicken": 2}
				Game.save["active"] = ["cow"]
				# Добыча с монстров в профиле: клык и эссенция со своими иконками
				var gathered: Dictionary = Game.save.get("gathered", {})
				for k in ["wood", "stone", "slime", "bone", "tusk", "essence"]:
					gathered[k] = int(gathered.get(k, 0)) + 40
				Game.save["gathered"] = gathered
				var dep: Array = Wild.sectors(0).filter(func(sc: Dictionary) -> bool: return sc["kind"] == "deposit")
				print("wild sent: ", Game.wild.send(dep[0]["id"], ["sheep"]), " sectors: ", Wild.sectors(0))
				Game.estate.tick()
				Game.save["offerPopupDay"] = ShopSystem.day_index()
				Game.save["coins"] = 25000
				for k in ["wood", "stone", "clay", "coal", "iron", "berries", "fish", "apples"]:
					Game.save["storage"][k] = 300
				# Сердца земли: две страницы первой главы, часть слуг Мглы, осколки и две ступени алтаря
				Game.save["heart"] = {"ch": 0, "pages": 2, "pity": 0, "gift": false, "kills": 4}
				Game.save["shards"] = 3
				Game.save["altar"] = 2
				Game.recalc()
				Game.mark_dirty()
				_step = 4
				_time = 200.0
		4:
			var t := int(_time - 200.0)
			if t < WINDOWS.size() * 2:
				var w: String = WINDOWS[t / 2]
				if t % 2 == 0 and _opened != w:
					_opened = w
					# Окна с покупками за деньги (наборы, пропуск, кристаллы) тоже должны пройти проверку
					Store.LIVE = true
					if ":" in w:
						var parts := w.split(":")
						main.hud.open_window(load("res://scripts/ui/%s_panel.gd" % parts[0]).new(parts[1]))
					else:
						var path := "res://scripts/ui/%s_panel.gd" % w
						if ResourceLoader.exists(path):
							main.hud.open_window(load(path).new())
				elif t % 2 == 1 and _shot_done != w:
					_shot_done = w
					_shot("6_" + w.replace(":", "_"))
					_check_layout(w)
			else:
				main.hud.close_window()
				Store.LIVE = Engine.has_singleton("InAppStore")
				_step = 41
				_time = 260.0
				_sub = 0
		41:
			# Ещё снимки: магазин после покупок, выбор языка, окна на японском, хинди и тайском, экспедиции
			var k := int((_time - 260.0) / 1.2)
			if k != _sub:
				_sub = k
				_extra(k)
		5:
			# По порядку: "Где взять" для глины, разговор с мельником, жители у дома
			if _sub == 0 and _time > 300.5:
				_sub = 1
				WherePopup.open("clay")
			elif _sub == 1 and _time > 301.5:
				_sub = 2
				_shot("6_where_clay")
				_free_overlays()
				DialogPopup.talk("miller")
			elif _sub == 2 and _time > 302.5:
				_sub = 3
				for n in main.hud.find_children("*", "", true, false):
					if n is DialogPopup:
						n.call("_advance")
						n.call("_advance")
			elif _sub == 3 and _time > 304.0:
				_sub = 4
				_shot("6_dialog")
				_free_overlays()
				world_at_home()
				# Энергия на исходе: окно "Где взять энергию"
				Game.save["energy"]["value"] = 37.0
				EnergyPopup.open()
			elif _sub == 4 and _time > 305.0 and _shot_done != "energy":
				_shot_done = "energy"
				_shot("6_energy")
				_free_overlays()
				# Примерка переливов: плашка внизу и наряд героя на следующем снимке
				CosmeticPreview.start("rainbow")
			elif _sub == 4 and _time > 306.8:
				_sub = 5
				_shot("7_world_level18")
				# Набег: волна выходит с краёв карты, башни стреляют. Герой у левой башни
				Game.save["raid"]["next"] = Time.get_unix_time_from_system() - 1.0
				var towers: Array = []
				var walls := 0
				for n in main.world.entities.get_children():
					if n is TowerNode:
						towers.append(n.position)
					elif n is Sprite2D and n.texture != null and n.texture.resource_path.ends_with("palisade.png"):
						walls += 1
				print("towers: ", towers, " palisade: ", walls, " base: ", main.world.layout.base)
				if not towers.is_empty():
					main.world.player.position = towers[0] + Vector2(90, 40)
			elif _sub == 5 and _time > 311.0:
				_sub = 6
				_shot("7_raid")
				print("raid live: ", Game.raids.live)
				if MonstersFeature.current != null:
					for sl in MonstersFeature.current.slots:
						if sl.get("raid", false) and sl["node"] != null:
							MonstersFeature.current.remove_raider(sl["node"])
				Game.raids.live = {}
				Game.save["raid"]["next"] = Time.get_unix_time_from_system() + 8.0 * 3600.0
				LevelUpOverlay.present(17, 18)
				_step = 6
				_time = 400.0
		6:
			if _time > 401.5:
				_shot("8_level_up")
				if LevelUpOverlay.current != null and is_instance_valid(LevelUpOverlay.current):
					LevelUpOverlay.current.queue_free()
				# Дом: построены подвал и спальня, чердак и оранжерея ещё закрыты
				for f in ["upper", "basement"]:
					if not f in Game.save["houseFloors"]:
						Game.save["houseFloors"].append(f)
				if Game.house.has_method("enter_house"):
					Game.house.call("enter_house")
				_step = 7
				_time = 500.0
				_sub = 0
		7:
			var w: World = main.world
			if _sub == 0 and _time > 503.0:
				_sub = 1
				_shot("9_home")
				# Герой на лестнице из гостиной в спальню
				var cols: Array = House.STAIRS["ground"]
				var top: float = w.layout.floor_rects["ground"].position.y
				w.player.position = Vector2((float(cols[0]) + 1.0) * w.layout.cell, top - 10.0)
			elif _sub == 1 and _time > 505.0:
				_sub = 2
				print("home floor at stairs: ", Game.current, " walkable: ", w.layout.walkable(w.player.position + Vector2(0, -80)))
				_shot("9_home_stairs")
				w.set_overview(true)
			elif _sub == 2 and _time > 507.5:
				_sub = 3
				_shot("9_home_overview")
				w.set_overview(false)
				if Game.house.has_method("leave_house"):
					Game.house.call("leave_house")
				_step = 8
				_time = 600.0
		8:
			if _time > 603.0:
				_shot("10_meadow_door")
				Game.dungeons.start_dungeon("slimeCaves", 1)
				_step = 9
				_time = 700.0
		9:
			if _time > 704.0 and _shot_done != "dungeon_run":
				_shot_done = "dungeon_run"
				_shot("11_dungeon")
			if _time > 712.0:
				_shot("12_dungeon_later")
				get_tree().quit()

## Проверка вёрстки окна: панель не шире экрана, иначе ищем самые глубокие узлы,
## которые не помещаются в родителя, и печатаем их (LAYOUT OVERFLOW в журнале CI).
func _check_layout(w: String) -> void:
	var sheet: Sheet = null
	for n in main.hud.find_children("*", "", true, false):
		if n is Sheet:
			sheet = n
	if sheet == null:
		return
	var limit := get_viewport().get_visible_rect().size.x
	var panel: Control = sheet._panel
	var right := panel.get_global_rect().end.x
	var inner_w := sheet.content.get_combined_minimum_size().x
	_check_overlap_later(w, sheet)
	if right <= limit + 0.5 and inner_w <= sheet.content_width() + 0.5:
		print("LAYOUT OK %s width=%.0f" % [w, panel.size.x])
		return
	print("LAYOUT OVERFLOW %s panel_right=%.0f screen=%.0f content=%.0f/%.0f" % [w, right, limit, inner_w, sheet.content_width()])
	var avail := sheet.content_width()
	_report_overflow(sheet.content, avail, w, 0)


## Наложения: видимые картинки, надписи и кнопки окна не должны залезать друг на друга,
## если одна не лежит внутри другой (значки-счётчики помечены meta "overlay_ok").
func _check_overlap_later(w: String, sheet: Sheet) -> void:
	if _check_overlap(w, sheet, false) == 0:
		print("OVERLAP OK %s" % w)
		return
	# Окно могло перестроиться в этом кадре: ждём, пока контейнеры расставят новые элементы
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(sheet) and sheet.is_inside_tree():
		_check_overlap(w, sheet, true)
	else:
		print("OVERLAP %s (окно закрылось до перепроверки)" % w)


## Сколько пар элементов окна залезают друг на друга; loud - напечатать их.
func _check_overlap(w: String, sheet: Sheet, loud: bool) -> int:
	var leaves: Array = []
	_collect_leaves(sheet._panel, leaves)
	var bad := 0
	for i in leaves.size():
		for j in range(i + 1, leaves.size()):
			var a: Control = leaves[i][0]
			var b: Control = leaves[j][0]
			if leaves[i][2] != leaves[j][2] or a.is_ancestor_of(b) or b.is_ancestor_of(a):
				continue
			# Рисунок, собранный вручную в простом Control (значок на углу, горка кристаллов),
			# накладывается намеренно; ошибка - когда элементы раскладывает контейнер
			var common := _common_parent(a, b)
			if common is Control and not common is Container:
				continue
			var x: Rect2 = (leaves[i][1] as Rect2).intersection(leaves[j][1])
			var tight := a is LevelUpOverlay.Ribbon or b is LevelUpOverlay.Ribbon
			if x.size.x > (0.5 if tight else 2.0) and x.size.y > (0.5 if tight else 2.0):
				bad += 1
				if loud and bad <= 8:
					print("  %s overlap %.0fx%.0f in %s: %s <-> %s" % [w, x.size.x, x.size.y, common.get_class(), _describe(a), _describe(b)])
	if loud:
		print(("OVERLAP %s count=%d" % [w, bad]) if bad > 0 else ("OVERLAP OK %s" % w))
	return bad


func _collect_leaves(node: Node, out: Array, clip := Rect2(-1e6, -1e6, 2e6, 2e6), group: Object = null) -> void:
	for c in node.get_children():
		if not c is Control:
			continue
		var ctl := c as Control
		if not ctl.is_visible_in_tree() or ctl.has_meta("overlay_ok") or ctl.is_queued_for_deletion():
			continue
		var r := ctl.get_global_rect().intersection(clip)
		# Пустой держатель нулевой высоты не пропускаем: в нём висит лента, которая и наезжает
		var empty := r.size.x <= 0.5 or r.size.y <= 0.5
		if empty and (ctl.clip_contents or ctl is ScrollContainer):
			continue
		# Прокрутка не режет: проверяем всё содержимое, но сравниваем только внутри одной прокрутки
		var inner_clip := clip
		var inner_group := group
		if ctl is ScrollContainer:
			inner_clip = Rect2(-1e6, -1e6, 2e6, 2e6)
			inner_group = ctl
		elif ctl.clip_contents:
			inner_clip = r
		var leaf := false
		if ctl is Label:
			leaf = (ctl as Label).text.strip_edges() != ""
			if leaf:
				# Рамка надписи шире текста: берём только сам текст
				var lb := ctl as Label
				var ts := lb.get_minimum_size()
				if lb.autowrap_mode == TextServer.AUTOWRAP_OFF:
					var gx := ctl.get_global_rect().position.x
					if lb.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
						gx += (ctl.size.x - ts.x) / 2.0
					elif lb.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
						gx += ctl.size.x - ts.x
					var gy := ctl.get_global_rect().position.y
					var lh := ts.y
					if lb.vertical_alignment == VERTICAL_ALIGNMENT_CENTER:
						gy += (ctl.size.y - lh) / 2.0
					elif lb.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM:
						gy += ctl.size.y - lh
					r = Rect2(gx, gy, minf(ts.x, ctl.size.x), minf(lh, ctl.size.y)).intersection(clip)
		elif ctl is TextureRect:
			leaf = (ctl as TextureRect).texture != null
		elif ctl is LevelUpOverlay.Ribbon:
			# Под лентой рисуется тень на 3 точки, и ей нужен хотя бы 1 точка воздуха
			leaf = true
			r = r.grow_side(SIDE_BOTTOM, 4.0)
		elif ctl is BaseButton:
			leaf = true
		if leaf and r.size.x > 0.5 and r.size.y > 0.5:
			out.append([ctl, r, group])
		_collect_leaves(ctl, out, inner_clip, inner_group)


func _common_parent(a: Node, b: Node) -> Node:
	var p := a.get_parent()
	while p != null and not p.is_ancestor_of(b):
		p = p.get_parent()
	return p


func _describe(c: Control) -> String:
	var t := ""
	if c is Label:
		t = " '" + (c as Label).text.left(24) + "'"
	elif c is Button:
		t = " '" + (c as Button).text.left(24) + "'"
	elif c is LevelUpOverlay.Ribbon:
		t = " ribbon '" + (c as LevelUpOverlay.Ribbon).label.text.left(24) + "'"
	return "%s%s @%s" % [c.get_class(), t, c.get_global_rect().position.round()]


func _report_overflow(node: Control, avail: float, w: String, depth: int) -> void:
	var found := false
	for c in node.get_children():
		if not c is Control or not (c as Control).visible:
			continue
		var cm := (c as Control).get_combined_minimum_size().x
		if cm > avail + 0.5:
			found = true
			var inner := avail
			if c is PanelContainer:
				var st := (c as Control).get_theme_stylebox("panel")
				if st != null:
					inner -= st.get_margin(SIDE_LEFT) + st.get_margin(SIDE_RIGHT)
			elif c is MarginContainer:
				inner -= (c as Control).get_theme_constant("margin_left") + (c as Control).get_theme_constant("margin_right")
			if c is HBoxContainer or c is HFlowContainer:
				var parts: Array = []
				for k in c.get_children():
					if k is Control and (k as Control).visible:
						var txt := ""
						if k is Label:
							txt = (k as Label).text
						elif k is Button:
							txt = (k as Button).text
						parts.append("%s(%.0f)%s" % [k.get_class(), (k as Control).get_combined_minimum_size().x, " '" + txt + "'" if txt != "" else ""])
				print("  %s row min=%.0f avail=%.0f: %s" % [w, cm, avail, ", ".join(parts)])
			if depth < 12:
				_report_overflow(c, inner, w, depth + 1)
	if not found and depth == 0:
		print("  %s: no single child overflows" % w)


func _touch(p: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = p
	e.global_position = p
	Input.parse_input_event(e)


func _drag(p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = p
	e.global_position = p
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(e)


func _nearest(world: World) -> ResourceSpot:
	var best: ResourceSpot = null
	var bd := INF
	for s in world.spots:
		if s.alive and Game.can_harvest(s.spec) and s.spec["tool"] != "rod":
			var d := s.position.distance_to(world.player.position)
			if d < bd:
				bd = d
				best = s
	return best


## Шаги дополнительных снимков (по одному раз в 1,2 секунды).
func _extra(k: int) -> void:
	match k:
		1:
			for p in ["flash", "step1", "crystals1"]:
				Game.premium.grant(p)
			main.hud.open_window(ShopPanel.new("offers"))
		2:
			_scroll_window(560)
		3:
			_shot("6_shop_bought")
			_check_layout("shop_bought")
			_scroll_window(100000)
		4:
			_shot("6_shop_extras")
			main.hud.open_window(ShopPanel.new("crystals"))
		5:
			_shot("6_shop_crystals_bought")
			main.hud.open_window(MapPanel.new("garden"))
		6:
			_scroll_window(0)
		7:
			_shot("6_map_garden")
			main.hud.close_window()
			LanguagePopup.open()
		8:
			_shot("6_language")
			for n in main.hud.find_children("*", "", true, false):
				if n is LanguagePopup:
					n.queue_free()
			_lang = L.code
			L.set_language("ja")
			main.hud.open_window(QuestsPanel.new())
		9:
			_shot("6_quests_ja")
			_check_layout("quests_ja")
			L.set_language("hi")
			main.hud.open_window(load("res://scripts/ui/level_panel.gd").new("settings"))
		10:
			_shot("6_settings_hi")
			L.set_language("th")
			main.hud.open_window(QuestsPanel.new())
		11:
			_shot("6_quests_th")
			L.set_language(_lang)
			# Все множители продажи на виду: x1000 и x100 должны читаться целиком
			StoragePanel._mult = {"wood": 1000, "stone": 100, "clay": 10, "coal": StoragePanel.MAX}
			main.hud.open_window(StoragePanel.new())
		12:
			_shot("6_storage_full")
			_check_layout("storage_full")
			main.hud.open_window(QuestsPanel.new())
		13:
			_scroll_window(100000)
		14:
			_shot("6_quests_board")
			main.hud.close_window()
			# Окно наград: как после "Забрать всё" в ивенте
			RewardsPopup.track(func() -> void:
				Game.add_coins(1500)
				Game.shop.add_crystals(12)
				Game.save["tickets"] = int(Game.save.get("tickets", 0)) + 2
				for res in ["wood", "stone", "berries", "fish", "apples"]:
					Game.save["storage"][res] = int(Game.save["storage"].get(res, 0)) + 25)
		15:
			_shot("6_rewards")
			for n in main.hud.find_children("*", "", true, false):
				if n is RewardsPopup:
					n.queue_free()
			# Дикие звери дальних биомов внизу списка (перекрашенные листы)
			main.hud.open_window(load("res://scripts/ui/animals_panel.gd").new("wild"))
		16:
			_scroll_window(900)
		17:
			_shot("6_animals_wild_mid")
			_scroll_window(100000)
		18:
			_shot("6_animals_wild_end")
			# Сундуки: ключи, окно, открытие десяти сундуков с наградами всех цветов
			Game.chests.add_keys("copper", 12, false)
			Game.chests.add_keys("silver", 1, false)
			main.hud.open_window(ChestsPanel.new())
		19:
			_shot("6_chests")
			_check_layout("chests")
			var list: Array = []
			for r in Chests.RARITIES:
				list.append(ChestSystem.make_reward(r, 1 + list.size() % 3, Game.level))
			list.append(ChestSystem.make_reward("gold", 3, Game.level))
			list.append(ChestSystem.make_reward("blue", 2, Game.level))
			list.append(ChestSystem.make_reward("green", 1, Game.level))
			for r in list:
				Game.chests.give(r)
			ChestOverlay.show_rewards("wood", list)
		20:
			_shot("6_chest_shake")

		26:
			_shot("6_chest_open10")
			for n in main.hud.find_children("*", "", true, false):
				if n is ChestOverlay:
					n.queue_free()
			var top := ChestSystem.make_reward("rainbow", 3, Game.level)
			Game.chests.give(top)
			ChestOverlay.show_rewards("ancient", [top])
		32:
			_shot("6_chest_open1")
			for n in main.hud.find_children("*", "", true, false):
				if n is ChestOverlay:
					n.queue_free()
			main.hud.close_window()
			# Шахта Глубин: окно, поле, ход, победа, окно наград, глубокий этаж
			if Game.level < Mine.MIN_LEVEL:
				Game.save["level"] = Mine.MIN_LEVEL
				Game.recalc()
			main.hud.open_window(MinePanel.new())
		33:
			_shot("7_mine_panel")
			_check_layout("mine")
			Game.mine.start()
			_mine = MineGame.launch(Game.mine.floor_n(), 3)
		36:
			_shot("7_mine_board")
			for i in _mine.board.cells.size():
				if _mine.board.group(i).size() >= 3:
					_mine.tap_cell(i)
					break
		37:
			_shot("7_mine_after_tap")
			_mine._show_end("moves")
		38:
			_shot("7_mine_no_moves")
			_mine._clear_end()
			_mine._show_end("win")
		39:
			_shot("7_mine_win")
			_mine._finish(true)
		40:
			_shot("7_mine_rewards")
			for n in main.hud.find_children("*", "", true, false):
				if n is RewardsPopup:
					n.queue_free()
			_mine = MineGame.launch(35, 5)
		42:
			_shot("7_mine_crystal")
			_mine.queue_free()
			main.hud.close_window()
			# Инкубатор: яйца всех цветов, яйцо в работе, гнездо с парой по рецепту
			if Game.level < 20:
				Game.save["level"] = 20
				Game.recalc()
			Game.save["animals"]["horse"] = 3
			Game.save["animals"]["swan"] = 3
			Game.save["incubator"]["eggs"] = []
			for r in Incubator.RARITIES:
				Game.incubator.add_egg(r, "", 0.0, false)
			Game.incubator.add_egg("gold", "pegasus", 0.25, false)
			Game.incubator.incubate(1)
			Game.incubator.breed("horse", "swan")
			main.hud.open_window(IncubatorPanel.new())
		44:
			_shot("8_incubator")
			_check_layout("incubator")
			_scroll_window(100000)
		45:
			_shot("8_incubator_nest")
			Game.save["incubator"]["slot"]["egg"] = {"r": "gold", "a": "pegasus", "s": 1.0}
			Game.save["incubator"]["slot"]["until"] = Clock.now() - 1.0
			Game.save["incubator"]["nest"]["until"] = Clock.now() - 1.0
			Game.changed.emit()
			for n in main.hud.find_children("*", "", true, false):
				if n is Sheet:
					(n as Sheet).scroll_to_top()
		46:
			_shot("8_incubator_ready")
			HatchOverlay.show_result(Game.incubator.hatch())
		47:
			_shot("8_hatch_shake")
		50:
			_shot("8_hatch_reveal")
			for n in main.hud.find_children("*", "", true, false):
				if n is HatchOverlay:
					n.queue_free()
			Game.incubator.add_egg("green", "", 0.0, false)
			Game.save["incubator"]["slot"] = {"egg": {"r": "green", "a": "", "s": 0.0}, "until": Clock.now() - 1.0}
			HatchOverlay.show_result(Game.incubator.hatch())
		53:
			_shot("8_hatch_plain")
			for n in main.hud.find_children("*", "", true, false):
				if n is HatchOverlay:
					n.queue_free()
			main.hud.close_window()
		_ when k >= 54 and k < 54 + 2 * Story.count():
			# Каждая глава "Сердец земли" на узком экране: страницы прочитаны, дар принесён наполовину,
			# пройденные главы списком. Окно не должно вылезать за экран.
			var ch := (k - 54) / 2
			if (k - 54) % 2 == 0:
				if ch == 5:
					_shot("6_story_reward")
				Game.save["level"] = maxi(Game.level, int(Locations.SPECS[Story.loc(ch)]["level"]))
				Game.recalc()
				Game.save["current"] = Story.loc(ch)
				if not Story.loc(ch) in Game.world_map.reachable:
					Game.world_map.reachable.append(Story.loc(ch))
				var given := {"coins": int(Story.gift(ch)["coins"]) / 2}
				Game.save["heart"] = {"ch": ch, "pages": Story.PAGES, "pity": 0, "gift": false, "given": given, "kills": 1}
				main.hud.open_window(StoryPanel.new())
			else:
				_check_layout("story_ch%d" % (ch + 1))
				if ch == 4:
					_scroll_window(520)
				if ch == Story.count() - 1:
					_scroll_window(100000)
		_ when k == 54 + 2 * Story.count():
			_shot("6_story_last")
			# Наборы ключей за деньги (в сборке без покупок их не видно - показываем принудительно)
			ChestsPanel.debug_packs = true
			main.hud.open_window(ChestsPanel.new())
		_ when k == 55 + 2 * Story.count():
			_scroll_window(100000)
		_ when k == 56 + 2 * Story.count():
			_shot("6_chests_packs")
			_check_layout("chests_packs")
			ChestsPanel.debug_packs = false
			# Гнездо без пары: выбор родителей, первые два выбраны
			Game.save["incubator"]["nest"] = {}
			for id in Game.incubator.parents().slice(0, 2):
				if IncubatorPanel._pick_a == "":
					IncubatorPanel._pick_a = id
				else:
					IncubatorPanel._pick_b = id
			main.hud.open_window(IncubatorPanel.new())
		_ when k == 57 + 2 * Story.count():
			_scroll_window(560)
		_ when k == 58 + 2 * Story.count():
			_shot("8_incubator_pick")
			main.hud.close_window()
			_step = 5
			_time = 300.0
			_sub = 0


func _scroll_window(y: int) -> void:
	for n in main.hud.find_children("*", "", true, false):
		if n is Sheet:
			(n as Sheet)._scroll.scroll_vertical = y


func _shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(dir.path_join(name + ".png"))
	print("shot saved: ", name)


## Поставить героя у дома на поляне, чтобы жители попали в кадр.
func world_at_home() -> void:
	var world: World = main.world
	if world == null or world.loaded != "meadow":
		return
	world.player.position = world.layout.base + Vector2(0, 170)


func _free_overlays() -> void:
	for n in main.hud.find_children("*", "", true, false):
		if n is WherePopup or n is DialogPopup or n is EnergyPopup:
			n.queue_free()
