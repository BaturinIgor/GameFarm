class_name Cloud
## Сохранение в iCloud: копия сохранения в хранилище ключей iCloud (NSUbiquitousKeyValueStore) через
## плагин iCloud из godot-ios-plugins (его собирает ios-godot.yml). Без плагина (Android, ПК, тесты) LIVE = false.
##
## Ключи: "save" - JSON сохранения в gzip, "meta" - уровень, опыт, время и устройство для окна выбора.
## Копия пишется не чаще раза в минуту и при сворачивании игры. Если в iCloud лежит игра с другого
## устройства, новее или с большим уровнем, игра спрашивает, какую оставить. Пока игрок не ответил
## (или iCloud ещё не прислал данные при первом запуске), копия не пишется, чтобы не затереть ту игру.

static var LIVE: bool = Engine.has_singleton("ICloud")

const KEY_SAVE := "save"
const KEY_META := "meta"
## Хранилище ключей iCloud - до 1 МБ на приложение
const MAX_BYTES := 900_000
const UPLOAD_EVERY := 60.0
## Сколько ждать первых данных iCloud на новом устройстве, прежде чем писать свою копию
const FIRST_SYNC_WAIT := 20.0

static var _poller: Timer
static var _started_at := 0.0
static var _last_upload := -1000.0
## Можно писать копию: облако проверено (или пусто), окно выбора не висит.
static var _ready := false
static var _asking := false


static func _plugin() -> Object:
	return Engine.get_singleton("ICloud") if LIVE else null


static func enabled() -> bool:
	return LIVE and Settings._flag("cloud", true)


static func setup(host: Node) -> void:
	if not LIVE or _poller != null:
		return
	_started_at = Time.get_ticks_msec() / 1000.0
	_plugin().synchronize_key_values()
	_poller = Timer.new()
	_poller.wait_time = 1.0
	_poller.autostart = true
	_poller.process_mode = Node.PROCESS_MODE_ALWAYS
	_poller.timeout.connect(Cloud._poll)
	host.add_child(_poller)


static func _poll() -> void:
	var p := _plugin()
	while p.get_pending_event_count() > 0:
		var e: Variant = p.pop_pending_event()
		if e is Dictionary and e.get("type") == "key_value_changed":
			# Пришли данные с другого устройства (или первая загрузка на этом): проверяем, не спросить ли
			check()
	if not _ready and not _asking and Time.get_ticks_msec() / 1000.0 - _started_at > FIRST_SYNC_WAIT:
		_ready = true


## Устройство: у каждой установки на iOS свой id (identifierForVendor).
static func device() -> String:
	return OS.get_unique_id()


## Что лежит в iCloud ({} - ничего).
static func meta() -> Dictionary:
	if not LIVE:
		return {}
	var m: Variant = _plugin().get_key_value(KEY_META)
	return m if m is Dictionary else {}


## Записать копию. force - сразу (сворачивание игры), иначе не чаще раза в минуту.
static func upload(force := false) -> void:
	if not enabled() or not _ready:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if not force and now - _last_upload < UPLOAD_EVERY:
		return
	_last_upload = now
	var bytes := pack(Game.save)
	if bytes.size() > MAX_BYTES:
		return
	_plugin().set_key_values({KEY_SAVE: bytes, KEY_META: make_meta(Game.save, device())})
	_plugin().synchronize_key_values()


static func pack(s: Dictionary) -> PackedByteArray:
	return JSON.stringify(s).to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)


static func unpack(bytes: PackedByteArray) -> Variant:
	if bytes.is_empty():
		return null
	var raw := bytes.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
	return JSON.parse_string(raw.get_string_from_utf8())


static func make_meta(s: Dictionary, dev: String) -> Dictionary:
	return {"level": int(s.get("level", 1)), "xp": int(s.get("xp", 0)), "at": int(Clock.now()), "device": dev}


## Стоит ли предлагать игру из iCloud вместо этой: она с другого устройства и новее или дальше по уровню,
## и игрок ещё не отказался именно от этой копии.
static func should_offer(cloud: Dictionary, local: Dictionary, dev: String) -> bool:
	if cloud.is_empty() or str(cloud.get("device", "")) == dev:
		return false
	var settings: Variant = local.get("settings", {})
	if settings is Dictionary and int(settings.get("cloudDeclined", 0)) == int(cloud.get("at", 0)):
		return false
	var c_level := int(cloud.get("level", 1))
	var l_level := int(local.get("level", 1))
	if c_level != l_level:
		return c_level > l_level or int(cloud.get("at", 0)) > int(local.get("lastSeen", 0))
	return int(cloud.get("at", 0)) > int(local.get("lastSeen", 0)) and int(cloud.get("xp", 0)) != int(local.get("xp", 0))


## Проверить iCloud и при необходимости спросить игрока. Вызывается при запуске и когда iCloud прислал данные.
static func check() -> void:
	if not enabled() or _asking:
		return
	var m := meta()
	if not should_offer(m, Game.save, device()):
		if not m.is_empty():
			_ready = true
		return
	if Hud.current == null:
		return
	_asking = true
	var when := Time.get_datetime_string_from_unix_time(int(m.get("at", 0)), true).substr(0, 16)
	ConfirmPopup.ask("px:cloud", L.t("cloud.title"),
		L.t("cloud.found", [int(m.get("level", 1)), when, int(Game.save.get("level", 1))]),
		L.t("cloud.load"), "green", func() -> void:
			_asking = false
			restore(),
		L.t("cloud.keep"), func() -> void:
			_asking = false
			_ready = true
			var s: Variant = Game.save.get("settings", {})
			if s is Dictionary:
				s["cloudDeclined"] = int(m.get("at", 0))
				Game.save["settings"] = s
			Game.mark_dirty()
			upload(true))


## Загрузить игру из iCloud: файл сохранения заменяется, игра перезапускается со своей сцены.
static func restore() -> void:
	if not LIVE:
		return
	var raw: Variant = _plugin().get_key_value(KEY_SAVE)
	var data: Variant = unpack(raw) if raw is PackedByteArray else null
	if not data is Dictionary:
		Game.show_toast("px:cloud", L.t("cloud.error"))
		_ready = true
		return
	_ready = true
	Game.replace_save(data)
	Game.show_toast("px:cloud", L.t("cloud.loaded"))
