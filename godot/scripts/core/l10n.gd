extends Node
## Строки интерфейса из data/strings/<язык>.json (те же файлы, что у iOS-версии).
## L.t("key", [arg0, arg1]) подставляет {0}, {1}. Нет строки на языке - берётся английская.

signal language_changed

const DIR := "res://data/strings/"
const CODES := ["en", "ru", "de", "fr", "es", "pt-BR", "it", "tr", "pl", "zh-Hans", "zh-Hant", "ja", "ko", "id", "vi", "th", "hi"]
const NAMES := {
	"en": "English", "ru": "Русский", "de": "Deutsch", "fr": "Français", "es": "Español",
	"pt-BR": "Português (Brasil)", "it": "Italiano", "tr": "Türkçe", "pl": "Polski",
	"zh-Hans": "简体中文", "zh-Hant": "繁體中文", "ja": "日本語", "ko": "한국어",
	"id": "Bahasa Indonesia", "vi": "Tiếng Việt", "th": "ไทย", "hi": "हिन्दी",
}
const SETTINGS := "user://language.cfg"

var code := "en"
var _strings: Dictionary = {}
var _fallback: Dictionary = {}


func _ready() -> void:
	_fallback = _load("en")
	var saved := ""
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		saved = str(cfg.get_value("lang", "code", ""))
	set_language(saved if saved in CODES else _system_code(), false)


func _load(c: String) -> Dictionary:
	var path := DIR + c + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}


## Язык телефона, если он есть среди переводов.
func _system_code() -> String:
	var locale := OS.get_locale()
	var lang := OS.get_locale_language()
	if lang == "zh":
		return "zh-Hant" if ("TW" in locale or "HK" in locale or "Hant" in locale) else "zh-Hans"
	if lang == "pt":
		return "pt-BR"
	return lang if lang in CODES else "en"


func set_language(c: String, remember := true) -> void:
	code = c if c in CODES else "en"
	_strings = _fallback if code == "en" else _load(code)
	if remember:
		var cfg := ConfigFile.new()
		cfg.set_value("lang", "code", code)
		cfg.save(SETTINGS)
	language_changed.emit()


func has(key: String) -> bool:
	return _strings.has(key) or _fallback.has(key)


func t(key: String, args: Array = []) -> String:
	var s: String = _strings.get(key, _fallback.get(key, key))
	for i in args.size():
		s = s.replace("{%d}" % i, str(args[i]))
	return s
