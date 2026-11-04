extends "res://tests/test_case.gd"
## Тексты: все ключи из кода есть в переводах, у переводов те же подстановки {0}, {1}.

const SCRIPTS := "res://scripts"


func _lang(code: String) -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(L.DIR + code + ".json"))
	return data if data is Dictionary else {}


## Ключи, которые код передаёт в L.t() строкой целиком (без склейки).
func _code_keys() -> Dictionary:
	var keys := {}
	var re := RegEx.create_from_string("L\\.t\\(\"([^\"]+)\"\\s*[,)]")
	for path in CheckScripts._scripts(SCRIPTS):
		for line in FileAccess.get_file_as_string(path).split("\n"):
			var code := line.strip_edges()
			if code.begins_with("#"):
				continue
			for m in re.search_all(code):
				keys[m.get_string(1)] = path.get_file()
	return keys


func test_strings_present() -> void:
	check(FileAccess.file_exists(L.DIR + "en.json"), "нет строк: запусти tools/godot_sync.sh")
	for code in L.CODES:
		check(not _lang(code).is_empty(), "нет перевода " + code)


func test_code_keys_exist() -> void:
	var en := _lang("en")
	var ru := _lang("ru")
	var keys := _code_keys()
	check(keys.size() > 100, "ключи из кода не нашлись")
	for k in keys:
		check(en.has(k), "нет ключа %s в en.json (%s)" % [k, keys[k]])
		check(ru.has(k), "нет ключа %s в ru.json (%s)" % [k, keys[k]])


func test_all_languages_complete() -> void:
	var en := _lang("en")
	for code in L.CODES:
		var d := _lang(code)
		var missing: Array = []
		for k in en:
			if not d.has(k):
				missing.append(k)
		check(missing.is_empty(), "%s: нет %d строк, например %s" % [code, missing.size(), missing.slice(0, 5)])


func test_placeholders_match() -> void:
	var re := RegEx.create_from_string("\\{\\d+\\}")
	var en := _lang("en")
	for code in L.CODES:
		var d := _lang(code)
		for k in d:
			if not en.has(k):
				continue
			var mine := {}
			for m in re.search_all(str(d[k])):
				mine[m.get_string()] = true
			for m in re.search_all(str(en[k])):
				mine.erase(m.get_string())
			check(mine.is_empty(), "%s: в %s лишние подстановки %s" % [code, k, mine.keys()])


func test_generated_names_exist() -> void:
	var en := _lang("en")
	for kind in Res.KINDS:
		check(en.has("res." + kind), "нет названия ресурса " + kind)
	for id in Locations.IDS:
		check(en.has("loc." + id), "нет названия локации " + id)
	for id in Animals.IDS:
		check(en.has("animal." + id), "нет имени зверя " + id)
	for id in Estate.IDS:
		check(en.has("estate." + id), "нет названия здания " + id)
	for id in Talents.ids():
		check(en.has("talent." + id), "нет названия таланта " + id)
	for b in Talents.BRANCHES:
		check(en.has("branch." + b), "нет названия ветки " + b)
	for tool in Tools.UPGRADABLE:
		for t in range(1, Tools.MAX_TIER + 1):
			check(en.has("tool.%s.%d" % [tool, t]), "нет названия ступени %s %d" % [tool, t])
