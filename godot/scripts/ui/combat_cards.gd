class_name CombatCards
## Карточки боя для окон: защита героя и особое оружие в мастерской (HeroDefenseCard, WeaponCard),
## заказы стражника во вкладке охот (HuntList), лавка зелий (PotionShopCard), здоровье в шапке (HpStrip).
## Функции возвращают новые Control: окна перестраивают содержимое целиком после Game.changed.

const DIM_FILL := Color(0.906, 0.812, 0.624, 0.7)


# MARK: Мастерская

## Итог защиты героя: здоровье, броня, уклонение, урон (HeroDefenseCard).
static func hero_defense_card() -> Control:
	var p := _card(Color(_tone("blue"), 0.5), 3)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_body(p).add_child(row)
	var c := Game.combat
	row.add_child(_stat("heart", Fmt.n(int(c.max_hp())), L.t("gear.stat.hp")))
	row.add_child(_stat("shield", Fmt.pct(c.defense()), L.t("gear.stat.defense")))
	row.add_child(_stat("eye", Fmt.pct(c.dodge_chance()), L.t("gear.stat.dodge")))
	row.add_child(_stat("sword", Fmt.n(int(round(c.weapon_damage()))), L.t("gear.stat.damage")))
	return p


static func _stat(icon_name: String, value: String, label: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := UiKit.icon(icon_name, 24)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(ic)
	var v := UiKit.label(value, 14)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(v)
	var l := UiKit.label(label, 10, UiKit.INK_SOFT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(l)
	return col


## Раздел "Особое оружие" для вкладки оружия: заголовок и карточки (всё, кроме кованого меча).
static func weapon_cards() -> Array:
	var out: Array = [section_title(L.t("weapon.special"))]
	for id in Weapons.IDS:
		if id != "forged":
			out.append(weapon_card(id))
	return out


## Особое оружие: где взять, свойство, ступень, надеть и улучшить (WeaponCard).
static func weapon_card(id: String) -> Control:
	var c := Game.combat
	var owned := c.owns_weapon(id)
	var tier := c.weapon_tier(id)
	var equipped := c.weapon() == id
	var p := _card(_tone("gold"), 3) if equipped else _card()
	var v := _body(p)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	var ic := UiKit.icon("sword", 34)
	ic.modulate = Weapons.color(id)
	var frame := _frame(ic, Vector2(52, 52), DIM_FILL, Color(0, 0, 0, 0))
	frame.modulate.a = 1.0 if owned else 0.4
	head.add_child(frame)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 3)
	head.add_child(col)
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", 6)
	col.add_child(title)
	title.add_child(UiKit.label(Weapons.name_of(id), 15))
	if owned:
		var lvl := UiKit.label(L.t("common.lvl", [tier]), 11, UiKit.INK_SOFT)
		lvl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		title.add_child(lvl)
	col.add_child(_wrap(Weapons.effect_text(id), 11, UiKit.GOOD))
	var effective := c.effective_weapon_tier(id)
	if owned and effective < tier:
		# Ступень выше доступной по уровню: пока работает слабее
		col.add_child(_wrap(L.t("weapon.capped", [effective]), 11, _tone("orange", 2)))
	if not owned:
		col.add_child(_wrap(Weapons.source(id), 11, UiKit.INK_SOFT))
		return p
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var equip := UiKit.button(L.t("weapon.equipped") if equipped else L.t("weapon.equip"),
		"green" if equipped else "wood", 13, true)
	equip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equip.disabled = equipped
	equip.pressed.connect(func() -> void: Game.combat.equip(id))
	row.add_child(equip)
	var cost := c.weapon_upgrade_cost(id)
	if not cost.is_empty():
		var need := Tools.required_level("sword", tier + 1)
		var up := UiKit.button(L.t("common.upgrade") if Game.level >= need else L.t("common.needLevel", [need]),
			"green", 13, true)
		up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		up.clip_text = true
		up.disabled = not c.can_upgrade_weapon(id)
		up.pressed.connect(func() -> void: Game.combat.upgrade_weapon(id))
		row.add_child(up)
		v.add_child(UiKit.cost_view(cost))
	return p


# MARK: Охота

## Список заказов стражника: время до новых, прогресс, награды и "Забрать" (HuntList).
static func hunts_list() -> Control:
	var c := Game.combat
	c.ensure_hunts()
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	var refresh := HBoxContainer.new()
	refresh.add_theme_constant_override("separation", 4)
	list.add_child(refresh)
	var clock := UiKit.icon("stopwatch", 14)
	clock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	refresh.add_child(clock)
	var countdown := func() -> String:
		return L.t("hunt.refresh", [TraderPanel.countdown(Game.combat.next_hunts_at() - Time.get_unix_time_from_system())])
	refresh.add_child(LiveLabel.new(countdown, 12, UiKit.INK_SOFT))
	var hunts := c.hunts()
	if hunts.is_empty():
		_body(_card_in(list)).add_child(UiKit.label(L.t("hunt.empty"), 14))
	var claimable := c.claimable_hunts()
	if claimable >= 2:
		list.add_child(claim_all_button(claimable, Game.combat.claim_all_hunts))
	for h in hunts:
		list.add_child(_hunt_card(h))
	var tip := _wrap(L.t("hunt.tip"), 11, UiKit.INK_SOFT)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list.add_child(tip)
	return list


static func _hunt_card(h: Dictionary) -> Control:
	var done := CombatSystem.hunt_done(h)
	var kind: String = h["monster"]
	var id: String = h["id"]
	var target := int(h["target"])
	var p := _card(_tone("green"), 3) if done else _card()
	var v := _body(p)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	head.add_child(_frame(monster_icon(kind, 40), Vector2(52, 52), DIM_FILL, Color(UiKit.OUTLINE, 0.6), 2))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 3)
	head.add_child(col)
	col.add_child(_wrap(L.t("hunt.kill", [target, Monsters.name_of(kind)]), 15))
	var homes := PackedStringArray()
	for loc in Monsters.home_of(kind):
		homes.append(Locations.name_of(loc))
	col.add_child(_wrap(", ".join(homes), 11, UiKit.INK_SOFT))
	var tags := HBoxContainer.new()
	tags.add_theme_constant_override("separation", 10)
	col.add_child(tags)
	tags.add_child(reward_tag("coins", Fmt.n(int(h["coins"]))))
	tags.add_child(reward_tag("book", Fmt.n(int(h["xp"]))))
	if bool(h.get("ticket", false)):
		tags.add_child(reward_tag("ticket", "1"))
	var progress := int(h["progress"])
	var bar := UiKit.bar(float(progress) / float(maxi(1, target)), "green" if done else "red", 0.0, 16.0,
		"%d / %d" % [mini(progress, target), target])
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(bar)
	if done:
		var b := UiKit.button(L.t("quests.claim"), "green", 15)
		b.pressed.connect(func() -> void:
			Game.combat.claim_hunt(id)
			Input.vibrate_handheld(20))
		v.add_child(b)
	return p


## Портрет монстра в рамке (MonsterIcon).
static func monster_icon(kind: String, side := 40.0) -> TextureRect:
	var t := TextureRect.new()
	t.custom_minimum_size = Vector2(side, side)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.texture = Monsters.icon(kind)
	return t


# MARK: Зелья

## Лавка зелий у стражника: сколько есть и купить 1 или 5 (PotionShopCard).
static func potion_shop_card() -> Control:
	var c := Game.combat
	var p := _card(Color(_tone("red"), 0.6), 3)
	var v := _body(p)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	var ic := UiKit.icon("heart_plus", 36)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(ic)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	head.add_child(col)
	col.add_child(UiKit.label(L.t("potion.title", [c.potions()]), 15))
	col.add_child(_wrap(L.t("potion.hint", [Fmt.pct(Dungeons.POTION_HEAL)]), 11, UiKit.INK_SOFT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	for n in [1, 5]:
		var price := c.potion_price(n)
		var b := UiKit.button("", "red", 13, true)
		b.custom_minimum_size = Vector2(0, 34)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = int(Game.save["coins"]) < price
		var inner := HBoxContainer.new()
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.add_theme_constant_override("separation", 4)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(inner)
		inner.add_child(UiKit.title("x%d" % n, 13))
		var coin := UiKit.icon("coins", 14)
		coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		inner.add_child(coin)
		inner.add_child(UiKit.title(Fmt.n(price), 13))
		b.pressed.connect(func() -> void: Game.combat.buy_potions(n))
		row.add_child(b)
	return p


# MARK: Общие элементы

## Цвет кнопки из UiKit.TONES: 0 - верх, 1 - основа, 2 - низ.
static func _tone(tone: String, i := 1) -> Color:
	return UiKit.TONES[tone][i]


## Карточка (Card): светлая плашка, рамка цвета border (по умолчанию - тонкая коричневая).
static func _card(border := Color(UiKit.WOOD_DARK, 0.45), width := 2) -> PanelContainer:
	var p := PanelContainer.new()
	var s := UiKit.box(UiKit.PARCHMENT_LIGHT, border, 16, width, false)
	s.set_content_margin_all(14)
	s.shadow_color = Color(UiKit.WOOD_DARK, 0.25)
	s.shadow_offset = Vector2(0, 3)
	s.shadow_size = 1
	p.add_theme_stylebox_override("panel", s)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	return p


static func _card_in(parent: Control, border := Color(UiKit.WOOD_DARK, 0.45), width := 2) -> PanelContainer:
	var p := _card(border, width)
	parent.add_child(p)
	return p


## Столбец содержимого карточки.
static func _body(card: PanelContainer) -> VBoxContainer:
	return card.get_child(0) as VBoxContainer


## Рамка вокруг иконки: скруглённая плашка размера side.
static func _frame(child: Control, side: Vector2, fill: Color, border: Color, width := 0) -> PanelContainer:
	var f := PanelContainer.new()
	var s := UiKit.box(fill, border, 12, width, false)
	s.set_content_margin_all(0)
	f.add_theme_stylebox_override("panel", s)
	f.custom_minimum_size = side
	f.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	child.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	child.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	f.add_child(child)
	return f


## Заголовок раздела с линиями по бокам (SectionTitle).
static func section_title(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 3:
		if i == 1:
			row.add_child(UiKit.label(text.to_upper(), 14, UiKit.INK_SOFT))
			continue
		var line := ColorRect.new()
		line.color = Color(UiKit.WOOD_DARK, 0.35)
		line.custom_minimum_size = Vector2(0, 2)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(line)
	return row


## Награда: иконка и число (RewardTag).
static func reward_tag(icon_name: String, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := UiKit.icon(icon_name, 15)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	row.add_child(UiKit.label(text, 13))
	return row


## Кнопка "Забрать всё", когда наград несколько (ClaimAllButton).
static func claim_all_button(count: int, action: Callable) -> Button:
	var b := UiKit.button(L.t("common.claimAll", [count]), "green", 15)
	b.pressed.connect(func() -> void:
		action.call()
		Input.vibrate_handheld(20))
	return b


static func _wrap(text: String, size: int, color := UiKit.INK) -> Label:
	var l := UiKit.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Подпись, которая сама обновляет текст раз в полсекунды (таймеры внутри окон).
class LiveLabel:
	extends Label

	var _text_of: Callable
	var _tick := 0.0

	func _init(text_of: Callable, font_size: int, color: Color) -> void:
		_text_of = text_of
		var ls := LabelSettings.new()
		ls.font = UiKit.font()
		ls.font_size = font_size
		ls.font_color = color
		label_settings = ls
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		text = _text_of.call()

	func _process(delta: float) -> void:
		_tick -= delta
		if _tick > 0.0:
			return
		_tick = 0.5
		text = _text_of.call()


## Здоровье героя под опытом в шапке: видно в бою или если здоровье не полное.
class HpStrip:
	extends HBoxContainer

	var _bar: ProgressBar
	var _label: Label
	var _shown := -1.0

	func _init() -> void:
		add_theme_constant_override("separation", 3)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic := UiKit.icon("heart", 14)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(ic)
		_bar = UiKit.bar(1.0, "red", 101, 12, " ")
		_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(_bar)
		_label = _bar.get_child(0) as Label
		visible = false

	func _process(delta: float) -> void:
		var c := Game.combat
		var fraction := c.hp_fraction()
		visible = c.in_combat or fraction < 0.999
		if not visible:
			_shown = -1.0
			return
		# Полоска плавно догоняет здоровье
		_shown = fraction if _shown < 0.0 else lerpf(_shown, fraction, minf(1.0, delta * 10.0))
		_bar.value = _shown
		_label.text = str(int(c.hp))
