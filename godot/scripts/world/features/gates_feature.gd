class_name GatesFeature
extends WorldFeature
## Проходы и экспедиции в сцене (порт checkGates/setGatePrompt и checkExpedition из GameScene):
## карточка у закрытых ворот, конец экспедиции по времени и окно с её итогом.
## Открытие ворот на карте и переход через открытые ворота делает World (_check_gates).
## Через current мини-карта в шапке видит сцену: карту локации и где стоит герой.

## С какого расстояния (в клетках) от закрытых ворот видна карточка.
const NEAR_CELLS := 3.2

static var current: GatesFeature

var world: World
var _near := ""
var _timer := 0.0
var _card: GateCard
var _card_lang := ""
var _finishing := false


func build(w: World) -> void:
	current = self
	world = w
	_timer = 0.0
	_near = ""
	_set_card("")


func clear(w: World) -> void:
	world = w
	_near = ""
	_set_card("")


func process(w: World, dt: float) -> void:
	current = self
	world = w
	ExpeditionReport.present_pending()
	_check_expedition(w)
	# Ближайшие закрытые ворота: раз в 0.2 секунды
	_timer -= dt
	if _timer <= 0.0:
		_timer = 0.2
		var near := ""
		for g in w.gates:
			if not g.is_open and g.position.distance_to(w.player.position) < w.layout.cell * NEAR_CELLS:
				near = g.gate_id
		_near = near
	_set_card(_near)


## Время экспедиции вышло: итог и возвращение домой.
func _check_expedition(w: World) -> void:
	var run = Game.premium.expedition()
	if run == null or str(run["location"]) != w.loaded:
		_finishing = false
		return
	if Time.get_unix_time_from_system() >= float(run["endsAt"]) and not _finishing:
		_finishing = true
		Game.premium.finish_expedition()


## Карточка над кнопками: "" убирает. Перестраивается при смене ворот или языка.
func _set_card(id: String) -> void:
	if Hud.current == null:
		return
	if id == "":
		if _card != null:
			_card = null
			Hud.current.set_prompt("gate", null)
		return
	if _card != null and is_instance_valid(_card) and _card.gate_id == id and _card_lang == L.code:
		return
	_card_lang = L.code
	_card = GateCard.new(id)
	Hud.current.set_prompt("gate", _card)
