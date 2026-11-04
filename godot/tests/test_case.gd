extends RefCounted
## Основа автотестов: проверки и чистое состояние игры. Файл теста - tests/test_*.gd,
## `extends "res://tests/test_case.gd"`, каждая функция test_* - отдельный тест.
## Перед каждым тестом раннер вызывает fresh(): новое сохранение, как у нового игрока.

## Ошибки текущего теста (заполняют проверки и раннер).
var failures: Array[String] = []
## Ошибки движка (не скриптов) в этом тесте ожидаемы: например, разбор испорченного JSON.
var engine_errors_ok := false


## Новое сохранение с нужными полями поверх (например {"level": 20, "coins": 5000}).
func fresh(overrides := {}) -> void:
	var save := Game.default_save()
	for k in overrides:
		save[k] = overrides[k]
	Game.save = save
	for sys in Game.systems:
		sys.defaults(Game.save)
	Game.recalc()


## Уровень героя без начисления опыта и наград.
func set_level(n: int) -> void:
	Game.save["level"] = n
	Game.recalc()


## Тест специально проверяет плохие данные: ошибки движка в лог не роняют его, ошибки скриптов - роняют.
func expect_engine_errors() -> void:
	engine_errors_ok = true


func fail(msg: String) -> void:
	failures.append(msg + _where())


func check(cond: bool, msg := "условие не выполнено") -> bool:
	if not cond:
		fail(msg)
	return cond


func eq(actual: Variant, expected: Variant, msg := "") -> bool:
	if typeof(actual) in [TYPE_INT, TYPE_FLOAT] and typeof(expected) in [TYPE_INT, TYPE_FLOAT]:
		if float(actual) == float(expected):
			return true
	elif actual == expected:
		return true
	fail("%sожидалось %s, получено %s" % [msg + ": " if msg != "" else "", var_to_str(expected), var_to_str(actual)])
	return false


func near(actual: float, expected: float, eps := 0.0001, msg := "") -> bool:
	if absf(actual - expected) <= eps:
		return true
	fail("%sожидалось %s ± %s, получено %s" % [msg + ": " if msg != "" else "", expected, eps, actual])
	return false


func between(actual: float, lo: float, hi: float, msg := "") -> bool:
	if actual >= lo and actual <= hi:
		return true
	fail("%sожидалось от %s до %s, получено %s" % [msg + ": " if msg != "" else "", lo, hi, actual])
	return false


## Строка, где упала проверка: первый кадр стека из файла теста.
func _where() -> String:
	for frame in get_stack():
		var src := str(frame.get("source", ""))
		if src.begins_with("res://tests/test_") and not src.ends_with("test_case.gd"):
			return " (%s:%d)" % [src.get_file(), int(frame.get("line", 0))]
	return ""
