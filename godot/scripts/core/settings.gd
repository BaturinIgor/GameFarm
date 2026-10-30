class_name Settings
## Игровые настройки в сохранении (settings): набеги на усадьбу и диалоги жителей.
## Звук и экономия батареи - в Sound (user://settings.cfg), язык - в L.


static func _flag(key: String, fallback: bool) -> bool:
	var s: Variant = Game.save.get("settings", {})
	return bool(s.get(key, fallback)) if s is Dictionary else fallback


static func set_value(key: String, on: bool) -> void:
	var s: Variant = Game.save.get("settings", {})
	if not s is Dictionary:
		s = {}
	s[key] = on
	Game.save["settings"] = s
	Game.mark_dirty()


## Набеги монстров на усадьбу (без них нет и наград за набеги).
static func raids() -> bool:
	return _flag("raids", true)


## Окна с диалогами жителей (задания сюжета остаются в списке).
static func dialogs() -> bool:
	return _flag("dialogs", true)


## Примерка украшения из магазина (CosmeticPreview): какое и до какого времени (секунды с запуска).
static var preview_id := ""
static var preview_until := 0.0


## Украшение включено: куплено и не выключено в настройках, или его сейчас примеряют.
static func cosmetic(id: String) -> bool:
	if id == preview_id and Time.get_ticks_msec() / 1000.0 < preview_until:
		return true
	return Game.premium.owns(id) and _flag("cos_" + id, true)
