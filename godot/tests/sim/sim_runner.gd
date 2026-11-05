extends Node
## Прогон ботов: godot --headless --path godot -- --simulate [профиль] [дней]
## Пишет отчёт в user://sim/<профиль>.json и коротко в консоль.

const PROFILES := {
	# Бесплатно, 3 захода по 15 минут в день, смотрит ролики за энергию
	"casual": {"name": "casual", "days": 60, "sessions": 3, "minutes": 15.0, "ads": true},
	# Бесплатно, 6 заходов по 20 минут
	"active": {"name": "active", "days": 60, "sessions": 6, "minutes": 20.0, "ads": true},
	# Бесплатно, без роликов: проверка, что игра идёт без рекламы
	"noads": {"name": "noads", "days": 60, "sessions": 6, "minutes": 20.0, "ads": false},
	# Донат: стартовый набор, Pro, строитель, MAX и пачка кристаллов в неделю; кристаллы на доски, энергию, ускорение
	"payer": {"name": "payer", "days": 60, "sessions": 6, "minutes": 20.0, "ads": true,
		"buy_at_start": ["starter", "pro", "builder", "max", "crystals3"], "spend_crystals": true,
		"energy_buys": 2, "speedup_max": 40, "boost_max": 15},
	# Кит: всё сразу и кристаллы каждый день
	"whale": {"name": "whale", "days": 60, "sessions": 6, "minutes": 20.0, "ads": true,
		"buy_at_start": ["starter", "pro", "builder", "max", "garden", "crystals5"], "buy_daily": ["crystals3"],
		"spend_crystals": true, "energy_buys": 6, "speedup_max": 400, "boost_max": 100},
}


func _ready() -> void:
	Game.save_path = "user://sim_save.json"
	var args := OS.get_cmdline_user_args()
	var i := args.find("--simulate")
	var names: Array = PROFILES.keys()
	var no_mini := args.has("--no-minigames")
	if i >= 0 and i + 1 < args.size() and PROFILES.has(args[i + 1]):
		names = [args[i + 1]]
	var days := int(args[i + 2]) if i >= 0 and i + 2 < args.size() and args[i + 2].is_valid_int() else -1
	DirAccess.make_dir_recursive_absolute("user://sim")
	var bot_script := load("res://tests/sim/bot.gd")
	for n in names:
		var p: Dictionary = PROFILES[n].duplicate(true)
		if days > 0:
			p["days"] = days
		if no_mini:
			p["minigames"] = false
		seed(12345)
		var started := Time.get_ticks_msec()
		var bot: RefCounted = bot_script.new(p)
		var rep: Dictionary = bot.run()
		var f := FileAccess.open("user://sim/%s.json" % n, FileAccess.WRITE)
		f.store_string(JSON.stringify(rep, " "))
		f.close()
		print("== %s (%.1f s): %s" % [n, (Time.get_ticks_msec() - started) / 1000.0, ProjectSettings.globalize_path("user://sim/%s.json" % n)])
		print("   milestones: ", rep["milestones"])
		var last: Dictionary = rep["days"][-1]
		print("   day %d: level %d, %s h played, coins %d, crystals %d, estate %s, tools %s" % [last["day"], last["level"],
			last["hours"], last["coins"], last["crystals"], last["estate"], last["tools"]])
		print("   energy outs %d, waiting goods %s, spent goods %s, crystals spent %d" % [rep["energy_outs"],
			rep["waiting_goods"], rep["spent_goods"], rep["crystals_spent"]])
		print("   minigames %s, mine best %d, eggs %d, hybrids %s, animals %d" % [rep["minigames"], rep["mine_floor"], rep["eggs"],
			rep["found_hybrids"], last["animals"]])
	Clock.offset = 0.0
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.save_path))
	get_tree().quit(0)
