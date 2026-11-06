class_name Ads
## Реклама только по желанию игрока и только за награду: Google AdMob через плагин Poing Studios
## (godot-admob-ios), его ставит tools/fetch_admob.sh в ios-godot.yml. Владельцы Pro получают награду
## сразу, без рекламы. Без плагина (Android, ПК, тесты) LIVE = false: кнопки - бесплатные бонусы
## с теми же дневными лимитами, подписи "...Free" (без слова "ролик").

## Настоящая реклама доступна: синглтоны плагина регистрируются движком до загрузки скриптов.
static var LIVE: bool = Engine.has_singleton("PoingGodotAdMobRewardedAd")

## Блок "Rewarded" из AdMob (приложение Harvest Hollow, блок rewarded).
## App ID приложения - в tools/fetch_admob.sh (ADMOB_APP_ID).
const REWARDED_ID := "ca-app-pub-9867750696429328/9239036001"

## Ролик загружен (uid в плагине) или -1.
static var _ad := -1
static var _loading := false
static var _started := false
## Ролик на экране: награда выдаётся, когда его закроют, если досмотрели.
static var _showing := false
static var _earned := false
static var _on_reward := Callable()
static var _retry_at := 0.0
static var _host: Node
## Звук игры был выключен до ролика (на время ролика глушим общий канал).
static var _muted_before := false


static func _s(name: String) -> Object:
	return Engine.get_singleton(name) if Engine.has_singleton(name) else null


## Запускается из Game._ready. Сначала согласие (GDPR и окно ATT, их показывает Google UMP по
## настройкам в AdMob), потом запуск SDK и загрузка первого ролика.
static func setup(host: Node) -> void:
	if not LIVE or _host != null:
		return
	_host = host
	var rew := _s("PoingGodotAdMobRewardedAd")
	rew.connect("on_rewarded_ad_loaded", Ads._on_loaded)
	rew.connect("on_rewarded_ad_failed_to_load", Ads._on_load_failed)
	rew.connect("on_rewarded_ad_user_earned_reward", Ads._on_earned)
	rew.connect("on_rewarded_ad_dismissed_full_screen_content", Ads._on_closed)
	rew.connect("on_rewarded_ad_failed_to_show_full_screen_content", Ads._on_show_failed)
	var consent := _s("PoingGodotAdMobConsentInformation")
	if consent == null:
		_start_sdk()
		return
	consent.connect("on_consent_info_updated_success", Ads._on_consent_info)
	consent.connect("on_consent_info_updated_failure", func(_e: Dictionary) -> void: Ads._start_sdk())
	consent.update({"tag_for_under_age_of_consent": false, "consent_debug_settings": {}})
	# Если Google не ответит, всё равно запускаем рекламу через 10 секунд
	host.get_tree().create_timer(10.0).timeout.connect(Ads._start_sdk)


static func _on_consent_info() -> void:
	var consent := _s("PoingGodotAdMobConsentInformation")
	var ump := _s("PoingGodotAdMobUserMessagingPlatform")
	# 2 - согласие нужно (ЕС, Великобритания или окно ATT ещё не показывали)
	if ump == null or not consent.get_is_consent_form_available() or consent.get_consent_status() != 2:
		_start_sdk()
		return
	ump.connect("on_consent_form_load_success_listener", func(uid: int) -> void: ump.show(uid))
	ump.connect("on_consent_form_dismissed", func(_uid: int, _e: Dictionary) -> void: Ads._start_sdk())
	ump.connect("on_consent_form_load_failure_listener", func(_e: Dictionary) -> void: Ads._start_sdk())
	ump.load_consent_form()


static func _start_sdk() -> void:
	if _started:
		return
	_started = true
	var sdk := _s("PoingGodotAdMob")
	if sdk != null:
		sdk.initialize()
	var tick := Timer.new()
	tick.wait_time = 5.0
	tick.autostart = true
	tick.process_mode = Node.PROCESS_MODE_ALWAYS
	tick.timeout.connect(Ads._load)
	_host.add_child(tick)
	_load()


static func _load() -> void:
	if not _started or _ad >= 0 or _loading or _showing or Time.get_ticks_msec() / 1000.0 < _retry_at:
		return
	_loading = true
	var rew := _s("PoingGodotAdMobRewardedAd")
	var uid: int = rew.create()
	rew.load(REWARDED_ID, {"google_request_agent": "", "mediation_extras": {}, "extras": {}}, PackedStringArray(), uid)


static func _on_loaded(uid: int) -> void:
	_loading = false
	_ad = uid
	Game.changed.emit()


static func _on_load_failed(_uid: int, _err: Dictionary) -> void:
	_loading = false
	# Нет ролика (нет сети или показов): пробуем снова через минуту
	_retry_at = Time.get_ticks_msec() / 1000.0 + 60.0


static func _on_earned(_uid: int, _item: Dictionary) -> void:
	_earned = true


static func _on_closed(_uid: int) -> void:
	_finish()


static func _on_show_failed(_uid: int, _err: Dictionary) -> void:
	_earned = false
	Game.show_toast("px:potion", L.t("ads.notReady"))
	_finish()


static func _finish() -> void:
	if not _showing:
		return
	_showing = false
	AudioServer.set_bus_mute(0, _muted_before)
	var cb := _on_reward
	_on_reward = Callable()
	if _earned and cb.is_valid():
		cb.call()
	_earned = false
	Game.changed.emit()
	_load()


## Показать ролик и вызвать on_reward, если его досмотрели.
static func show_rewarded(on_reward: Callable) -> void:
	# Без рекламы (нет плагина) или с Pro - награда сразу
	if Game.premium.has_pro() or not LIVE:
		on_reward.call()
		return
	if _showing:
		return
	if _ad < 0:
		Game.show_toast("px:potion", L.t("ads.notReady"))
		_retry_at = 0.0
		_load()
		return
	var uid := _ad
	_ad = -1
	_showing = true
	_earned = false
	_on_reward = on_reward
	_muted_before = AudioServer.is_bus_mute(0)
	AudioServer.set_bus_mute(0, true)
	_s("PoingGodotAdMobRewardedAd").show(uid)


## Ключ подписи: без рекламы - вариант "...Free" (без слова "ролик").
static func k(key: String) -> String:
	return key if LIVE else key + "Free"


## Ролик загружен и его можно показать (или он не нужен).
static func ready() -> bool:
	return not LIVE or _ad >= 0 or Game.premium.has_pro()


## Кнопка награды за рекламу: значок ролика (с Pro - корона) и подпись.
static func reward_button(text: String, tone := "green", font_size := 15, small := false) -> Button:
	var b := UiKit.button("", tone, font_size, small)
	var inner := HBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 6)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(inner)
	if not LIVE:
		pass
	elif Game.premium.has_pro():
		var crown := UiKit.icon("crown", font_size + 3.0)
		crown.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		inner.add_child(crown)
	else:
		inner.add_child(mark(font_size - 2.0))
	var l := UiKit.title(text, font_size)
	l.label_settings.outline_size = 5
	inner.add_child(l)
	b.custom_minimum_size = Vector2(inner.get_combined_minimum_size().x + 24.0, font_size + (16.0 if small else 22.0))
	return b


## Значок ролика (play.rectangle.fill): белый прямоугольник с треугольником.
static func mark(side := 14.0, color := Color.WHITE) -> Control:
	var m := PlayMark.new()
	m.tint = color
	m.custom_minimum_size = Vector2(side * 1.25, side)
	m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return m


class PlayMark extends Control:
	var tint := Color.WHITE

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var box := StyleBoxFlat.new()
		box.bg_color = tint
		box.border_color = UiKit.OUTLINE
		box.set_border_width_all(1)
		box.set_corner_radius_all(int(size.y * 0.25))
		box.anti_aliasing = true
		draw_style_box(box, r)
		var c := r.get_center()
		var h := size.y * 0.42
		var tri := PackedVector2Array([c + Vector2(-h * 0.45, -h / 2.0), c + Vector2(h * 0.6, 0), c + Vector2(-h * 0.45, h / 2.0)])
		draw_colored_polygon(tri, UiKit.OUTLINE)
