extends Node
## Раннер автотестов: запускает все функции test_* из tests/test_*.gd и выходит с кодом 1, если что-то упало.
## Запуск: godot --headless --path godot -- --run-tests [фильтр]
## Фильтр - часть имени файла или теста (например "energy"). Ошибки скриптов во время теста тоже его роняют.

const DIR := "res://tests"
const SAVE := "user://test_save.json"


class ErrorCatcher extends Logger:
	var errors: Array[String] = []
	var _mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
			error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		# Предупреждения движка (например, утечки при выходе) тест не роняют
		if error_type == ERROR_TYPE_WARNING:
			return
		_mutex.lock()
		errors.append("%s: %s (%s:%d %s)" % ["SCRIPT ERROR" if error_type == ERROR_TYPE_SCRIPT else "ERROR",
			rationale if rationale != "" else code, file.get_file(), line, function])
		_mutex.unlock()

	func take() -> Array[String]:
		_mutex.lock()
		var out := errors.duplicate()
		errors.clear()
		_mutex.unlock()
		return out


func _ready() -> void:
	# Сохранение тестов - в свой файл: настоящий прогресс не трогаем
	Game.save_path = SAVE
	var args := OS.get_cmdline_user_args()
	var i := args.find("--run-tests")
	var filter := args[i + 1] if i >= 0 and i + 1 < args.size() and not args[i + 1].begins_with("--") else ""
	var code := run(filter)
	for f in DirAccess.get_files_at("user://"):
		if f.begins_with(SAVE.get_file().get_basename()):
			DirAccess.remove_absolute("user://".path_join(f))
	get_tree().quit(code)


func run(filter: String) -> int:
	var catcher := ErrorCatcher.new()
	OS.add_logger(catcher)
	var passed := 0
	var failed: Array[String] = []
	var started := Time.get_ticks_msec()
	for file in _files():
		var script := load(DIR.path_join(file)) as GDScript
		if script == null or not script.can_instantiate():
			failed.append(file + ": не загрузился")
			print("FAIL ", file, ": не загрузился")
			continue
		for m in script.get_script_method_list():
			var name := str(m["name"])
			if not name.begins_with("test_") or (filter != "" and not filter in file and not filter in name):
				continue
			seed(hash(file + name))
			var t: RefCounted = script.new()
			catcher.take()
			t.call("fresh")
			t.call(name)
			var problems: Array[String] = []
			problems.append_array(t.get("failures"))
			for e in catcher.take():
				if not (t.get("engine_errors_ok") and not e.begins_with("SCRIPT ERROR")):
					problems.append(e)
			var title := "%s.%s" % [file.get_basename(), name]
			if problems.is_empty():
				passed += 1
				print("ok   ", title)
			else:
				failed.append(title)
				print("FAIL ", title)
				for p in problems:
					print("       ", p)
	OS.remove_logger(catcher)
	print("")
	print("tests: %d passed, %d failed, %.1f s" % [passed, failed.size(), (Time.get_ticks_msec() - started) / 1000.0])
	for f in failed:
		print("  failed: ", f)
	if passed + failed.size() == 0:
		print("tests: ничего не найдено")
		return 1
	return 1 if not failed.is_empty() else 0


static func _files() -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(DIR):
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_case.gd":
			out.append(f)
	out.sort()
	return out
