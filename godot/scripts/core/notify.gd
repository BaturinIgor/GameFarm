class_name Notify
## Локальные уведомления: когда игра уходит в фон, ставим напоминания (энергия полная, урожай созрел,
## яйцо готово, цех усадьбы заполнен, ивент скоро закончится, давно не заходил), при возврате убираем.
## Плагин LocalNotify (tools/ios_plugins/localnotify) собирает ios-godot.yml. Без него LIVE = false.

static var LIVE: bool = Engine.has_singleton("LocalNotify")

## Не будим ночью: напоминание на 22:00-9:00 по местному времени переносится на 9:00.
const NIGHT_FROM := 22
const NIGHT_TO := 9
## Меньше этого не напоминаем: игрок ещё рядом.
const MIN_DELAY := 10.0 * 60.0
## Сколько до конца ивента напоминать.
const EVENT_WARN := 3.0 * 3600.0
const COMEBACK := [24.0 * 3600.0, 72.0 * 3600.0]


static func _plugin() -> Object:
	return Engine.get_singleton("LocalNotify") if LIVE else null


static func enabled() -> bool:
	return Settings._flag("notify", true)


static func setup(_host: Node) -> void:
	if LIVE:
		_plugin().refresh_status()
		clear()


## 0 - ещё не спрашивали, 1 - разрешено, 2 - запрещено, -1 - неизвестно (нет плагина).
static func status() -> int:
	return int(_plugin().get_status()) if LIVE else -1


## Окно-вопрос перед системным: спрашиваем один раз, после обучения, когда уведомления уже полезны.
static func maybe_ask() -> void:
	if not LIVE or status() != 0 or not bool(Game.save.get("tutorialDone", false)) or Settings._flag("notifyAsked", false):
		return
	Settings.set_value("notifyAsked", true)
	ConfirmPopup.ask("px:hourglass", L.t("notify.ask.title"), L.t("notify.ask.text"), L.t("notify.ask.ok"), "green",
		func() -> void: _plugin().request_permission(), L.t("notify.ask.later"))


static func clear() -> void:
	if LIVE:
		_plugin().cancel_all()


static func schedule_all() -> void:
	if not LIVE or status() != 1:
		return
	_plugin().cancel_all()
	if not enabled():
		return
	var now := Clock.now()
	for n in plan(now):
		var at := quiet(float(n["at"]))
		_plugin().schedule(str(n["id"]), L.t("notify.title"), str(n["text"]), int(at - now))


## Что и когда напомнить: [{id, at, text}] (at - unix-секунды).
static func plan(now: float) -> Array:
	var out: Array = []
	var add := func(id: String, at: float, text: String) -> void:
		if at - now >= MIN_DELAY:
			out.append({"id": id, "at": at, "text": text})
	# Энергия
	var full := Game.energy.until_full()
	if full > 0.0:
		add.call("energy", now + full, L.t("notify.energy"))
	# Грядки: когда созреет последняя посаженная (чтобы собрать всё за раз)
	var ripe := -1.0
	for i in Game.garden.bed_count():
		ripe = maxf(ripe, Farming.ready_at(Game.garden.bed(i)))
	if ripe > 0.0:
		add.call("garden", ripe, L.t("notify.garden"))
	# Инкубатор и гнездо
	if Game.incubator.busy():
		add.call("egg", now + Game.incubator.time_left(), L.t("notify.egg"))
	if Game.incubator.nesting():
		add.call("nest", now + Game.incubator.nest_left(), L.t("notify.nest"))
	# Усадьба: первый цех, который заполнится
	var first := 0.0
	for id in Estate.IDS:
		var left := Game.estate.until_full(id)
		if left > 0.0 and (first == 0.0 or left < first):
			first = left
	if first > 0.0:
		add.call("estate", now + first, L.t("notify.estate"))
	# Ивент скоро закончится
	if Game.events.events_open():
		var run := Events.current()
		add.call("event", float(run["end"]) - EVENT_WARN, L.t("notify.event", [Events.name_of(str(run["event"]))]))
	# Погода альянса начнётся
	var wx: Dictionary = Game.save.get("allianceWeather", {})
	if Game.alliance.in_alliance() and AllianceWeather.pending(wx, now):
		add.call("weather", float(wx["starts"]), L.t("notify.weather." + str(wx["kind"])))
	# Давно не заходил
	for i in COMEBACK.size():
		add.call("comeback%d" % i, now + float(COMEBACK[i]), L.t("notify.comeback%d" % i))
	return out


## Перенос ночного времени на утро (местное время).
static func quiet(at: float) -> float:
	var bias := float(Time.get_time_zone_from_system().get("bias", 0)) * 60.0
	return quiet_with_bias(at, bias)


static func quiet_with_bias(at: float, bias: float) -> float:
	var local := at + bias
	var day := floorf(local / 86400.0) * 86400.0
	var hour := (local - day) / 3600.0
	if hour >= NIGHT_FROM:
		return day + 86400.0 + NIGHT_TO * 3600.0 - bias
	if hour < NIGHT_TO:
		return day + NIGHT_TO * 3600.0 - bias
	return at
