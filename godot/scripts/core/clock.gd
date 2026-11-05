class_name Clock
extends RefCounted
## Время правил игры в unix-секундах. Боты-симуляции (tests/sim) сдвигают offset, чтобы прожить дни за секунды.
## В игре offset всегда 0.

static var offset := 0.0


static func now() -> float:
	return Time.get_unix_time_from_system() + offset
