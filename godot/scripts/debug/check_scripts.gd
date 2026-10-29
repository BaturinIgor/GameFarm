class_name CheckScripts
extends RefCounted
## Проверка в CI: загружает каждый скрипт проекта, чтобы ошибки разбора и типов роняли сборку.
## Запуск: игра с аргументом "-- --check-scripts" (см. main.gd).


## Пути скриптов, которые не загрузились.
static func run() -> Array[String]:
	var failed: Array[String] = []
	var count := 0
	for path in _scripts("res://scripts"):
		count += 1
		var s := ResourceLoader.load(path) as GDScript
		if s == null or not s.can_instantiate():
			failed.append(path)
	print("check_scripts: ", count, " scripts, failed: ", failed.size())
	for p in failed:
		printerr("check_scripts: FAILED ", p)
	return failed


static func _scripts(dir: String) -> Array[String]:
	var out: Array[String] = []
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(d)))
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	return out
