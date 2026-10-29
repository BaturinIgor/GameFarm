class_name TraderFeature
extends WorldFeature
## Лавка у дома и бродячий торговец (порт updateTraderPrompt и updateWanderer из GameScene):
## карточка рядом с торговцем, приход торговца раз в несколько минут, уход и стрелка к нему.

## С какого расстояния показывается карточка торговца.
const NEAR_DISTANCE := 96.0
## Торговец появляется не ближе к герою.
const MIN_FROM_PLAYER := 220.0
const ARROW_COLOR := Color(0.65, 0.4, 0.95)

var _stall: TraderNode
var _stall_obstacle = null
var _wanderer_node: TraderNode
## Таймер прихода живёт вместе со сценой, а не с локацией (как в Swift).
var _wanderer_timer := 300.0
var _arrow: PointerArrow
var _card: Control
var _card_kind := ""
var _card_lang := ""


func build(world: World) -> void:
	_stall = null
	_stall_obstacle = null
	_wanderer_node = null
	_arrow = PointerArrow.new(ARROW_COLOR, "basket")
	world.fx.add_child(_arrow)
	var kind: String = world.spec["kind"]
	if kind == "home" or kind == "dungeon":
		return
	if world.layout.stall is Vector2:
		var point: Vector2 = world.layout.stall
		_stall = TraderNode.new("stall", L.t("trader.title"), "basket")
		_stall.position = point
		world.entities.add_child(_stall)
		_stall_obstacle = point - Vector2(0, 10)


func clear(_world: World) -> void:
	_stall = null
	_stall_obstacle = null
	_wanderer_node = null
	_arrow = null
	Game.garden.trader_prompt = ""
	_set_card("")


## Сквозь прилавок не пройти.
func resolve(_world: World, p: Vector2, radius: float) -> Vector2:
	if not (_stall_obstacle is Vector2):
		return p
	var c: Vector2 = _stall_obstacle
	var min_d := 34.0 + radius
	var d := p.distance_to(c)
	if d >= min_d:
		return p
	if d < 0.01:
		return c + Vector2(0, min_d)
	return c + (p - c) * (min_d / d)


func process(world: World, dt: float) -> void:
	if _stall != null and is_instance_valid(_stall):
		_update_prompt(world, _stall)
	_update_wanderer(world, dt)
	if _arrow != null and is_instance_valid(_arrow):
		var target = null
		if _wanderer_node != null and is_instance_valid(_wanderer_node):
			target = _wanderer_node.position
		_arrow.track(world, target)
	_set_card(Game.garden.trader_prompt)


## Подсказка "торговать", когда персонаж рядом с торговцем.
func _update_prompt(world: World, node: TraderNode) -> void:
	var g := Game.garden
	if node.position.distance_to(world.player.position) < NEAR_DISTANCE:
		g.trader_prompt = node.kind
	elif g.trader_prompt == node.kind:
		g.trader_prompt = ""


## Бродячий торговец приходит раз в несколько минут в обычную локацию и уходит через три минуты.
func _update_wanderer(world: World, dt: float) -> void:
	var g := Game.garden
	if not g.wanderer.is_empty() and float(g.wanderer["until"]) < GardenSystem.now():
		g.dismiss_wanderer()
		Game.show_toast("px:bag", L.t("toast.wandererLeft"))
	if not g.wanderer.is_empty() and str(g.wanderer["location"]) == world.loaded:
		if _wanderer_node == null:
			var point = _random_open_point(world, MIN_FROM_PLAYER)
			if point is Vector2:
				_wanderer_node = TraderNode.new("wanderer", L.t("wanderer.title"), "bag")
				_wanderer_node.position = point
				world.entities.add_child(_wanderer_node)
				_wanderer_node.pop_in()
	elif _wanderer_node != null:
		if is_instance_valid(_wanderer_node):
			_wanderer_node.vanish()
		_wanderer_node = null
		if g.trader_prompt == "wanderer":
			g.trader_prompt = ""
	if _wanderer_node != null and is_instance_valid(_wanderer_node):
		_update_prompt(world, _wanderer_node)
	if not g.wanderer.is_empty() or world.spec["kind"] != "world":
		return
	_wanderer_timer -= dt
	if _wanderer_timer <= 0.0:
		_wanderer_timer = randf_range(360.0, 600.0)
		g.spawn_wanderer(world.loaded)
		Game.show_toast("px:bag", L.t("toast.wanderer"))


## Карточка над кнопками: "" убирает. Перестраивается при смене торговца или языка.
func _set_card(kind: String) -> void:
	if Hud.current == null:
		return
	if kind == "":
		if _card != null:
			_card = null
			_card_kind = ""
			Hud.current.set_prompt("trader", null)
		return
	if _card != null and is_instance_valid(_card) and _card_kind == kind and _card_lang == L.code:
		return
	_card_kind = kind
	_card_lang = L.code
	_card = TraderCard.new(kind)
	Hud.current.set_prompt("trader", _card)


## Случайная проходимая точка вдали от героя, точек добычи, проходов, грядок и лавки (randomOpenPoint).
func _random_open_point(world: World, min_from_player: float):
	var layout := world.layout
	var farm := Rect2()
	for i in layout.farm.size():
		var pt: Vector2 = layout.farm[i]
		var cell_rect := Rect2(pt - Vector2.ONE * layout.cell / 2.0, Vector2.ONE * layout.cell)
		farm = cell_rect if i == 0 else farm.merge(cell_rect)
	for _i in 60:
		var c := randi_range(2, maxi(3, layout.cols - 2) - 1)
		var r := randi_range(2, maxi(3, layout.rows - 2) - 1)
		var cell := layout.at(c, r)
		if cell != MapLayout.Cell.LAND and cell != MapLayout.Cell.PATH:
			continue
		# Не у самого края: все соседи тоже проходимы
		if not (layout.walkable_cell(c - 1, r) and layout.walkable_cell(c + 1, r)
				and layout.walkable_cell(c, r - 1) and layout.walkable_cell(c, r + 1)):
			continue
		var p := layout.center(c, r)
		if p.distance_to(world.player.position) < min_from_player:
			continue
		if world.spots.any(func(s: ResourceSpot) -> bool: return p.distance_to(s.position) < 44.0):
			continue
		if world.gates.any(func(g: GateNode) -> bool: return p.distance_to(g.position) < 120.0):
			continue
		if farm.has_area() and farm.grow(48.0).has_point(p):
			continue
		if layout.stall is Vector2 and p.distance_to(layout.stall) < 120.0:
			continue
		return p
	return null
