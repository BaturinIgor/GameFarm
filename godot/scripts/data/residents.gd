class_name Residents
## Жители деревни (документ "Новая экономика", этап 3): переезжают с чётными уровнями главного дома,
## у каждого история из 5 глав - разговор и задание. Реплики - строки story.<житель>.<глава>.a/b/end.

const IDS := ["smith", "miller", "weaver", "scholar", "tracker"]

## main - с какого уровня главного дома переезжает, icon - значок, sheet - лист персонажа из пака.
const SPECS := {
	"smith": {"main": 2, "icon": "hammer", "sheet": "miner"},
	"miller": {"main": 4, "icon": "seed_wheat", "sheet": "harvester"},
	"weaver": {"main": 6, "icon": "wardrobe", "sheet": "cultivator"},
	"scholar": {"main": 8, "icon": "book", "sheet": "stargazer"},
	"tracker": {"main": 10, "icon": "compass", "sheet": "ranger"},
}

## Главы: level - уровень героя, task - что сделать, crystals - награда (монеты и опыт - от уровня главы).
## give - отдать со склада, kill - победить монстров после взятия задания, build - здание усадьбы до уровня.
const CHAPTERS := {
	"smith": [
		{"level": 3, "crystals": 10, "task": {"type": "give", "items": [["wood", 40], ["stone", 30]]}},
		{"level": 5, "crystals": 12, "task": {"type": "give", "items": [["coal", 20], ["stone", 20]]}},
		{"level": 7, "crystals": 15, "task": {"type": "kill", "kind": "orc", "n": 5}},
		{"level": 9, "crystals": 20, "task": {"type": "give", "items": [["planks", 15]]}},
		{"level": 11, "crystals": 30, "task": {"type": "give", "items": [["iron", 25], ["planks", 10]]}},
	],
	"miller": [
		{"level": 9, "crystals": 10, "task": {"type": "give", "items": [["wheat", 30]]}},
		{"level": 10, "crystals": 12, "task": {"type": "build", "id": "mill", "n": 2}},
		{"level": 11, "crystals": 15, "task": {"type": "give", "items": [["flour", 10], ["berries", 30]]}},
		{"level": 12, "crystals": 20, "task": {"type": "kill", "kind": "slimeBlue", "n": 15}},
		{"level": 14, "crystals": 30, "task": {"type": "give", "items": [["flour", 20], ["apples", 40]]}},
	],
	"weaver": [
		{"level": 15, "crystals": 10, "task": {"type": "give", "items": [["bamboo", 40]]}},
		{"level": 16, "crystals": 12, "task": {"type": "give", "items": [["herbs", 25], ["berries", 40]]}},
		{"level": 17, "crystals": 15, "task": {"type": "kill", "kind": "slimePurple", "n": 15}},
		{"level": 18, "crystals": 20, "task": {"type": "give", "items": [["slats", 15]]}},
		{"level": 20, "crystals": 30, "task": {"type": "give", "items": [["clay", 20], ["cactus", 30]]}},
	],
	"scholar": [
		{"level": 21, "crystals": 10, "task": {"type": "give", "items": [["mushrooms", 40]]}},
		{"level": 22, "crystals": 12, "task": {"type": "kill", "kind": "skeleton", "n": 15}},
		{"level": 23, "crystals": 15, "task": {"type": "give", "items": [["brick", 10], ["lime", 10]]}},
		{"level": 24, "crystals": 20, "task": {"type": "give", "items": [["ice", 20]]}},
		{"level": 26, "crystals": 30, "task": {"type": "give", "items": [["gold", 15], ["diamond", 3]]}},
	],
	"tracker": [
		{"level": 27, "crystals": 10, "task": {"type": "kill", "kind": "skelRogue", "n": 10}},
		{"level": 28, "crystals": 12, "task": {"type": "give", "items": [["fish", 40], ["coconut", 15]]}},
		{"level": 29, "crystals": 15, "task": {"type": "kill", "kind": "orcWarrior", "n": 8}},
		{"level": 30, "crystals": 20, "task": {"type": "give", "items": [["iron_bar", 10], ["planks", 20]]}},
		{"level": 32, "crystals": 30, "task": {"type": "kill", "kind": "skeletonDark", "n": 15}},
	],
}


static func name_of(id: String) -> String:
	return L.t("resident." + id)


static func icon(id: String) -> String:
	return str(SPECS.get(id, {}).get("icon", "book"))


## Лист персонажа (pl_<лист>) для фигурки и портрета.
static func sheet(id: String) -> String:
	return str(SPECS.get(id, {}).get("sheet", "merchant"))


static func main_level(id: String) -> int:
	return int(SPECS.get(id, {}).get("main", 99))


static func chapters(id: String) -> Array:
	return CHAPTERS.get(id, [])


## Реплики перед заданием главы (номер главы с нуля).
static func intro(id: String, chapter: int) -> Array:
	var key := "story.%s.%d." % [id, chapter + 1]
	return [L.t(key + "a"), L.t(key + "b")]


## Реплика после сдачи главы.
static func outro(id: String, chapter: int) -> String:
	return L.t("story.%s.%d.end" % [id, chapter + 1])


## Монеты и опыт за главу растут с её уровнем.
static func reward(id: String, chapter: int) -> Dictionary:
	var ch: Dictionary = chapters(id)[chapter]
	var lv := int(ch["level"])
	return {"coins": int(round(Game.level_coin_reward(lv) / 10.0)) * 10, "xp": maxi(10, Game.xp_to_next(lv) / 8),
		"crystals": int(ch["crystals"])}


## Короткая подпись задания.
static func task_text(task: Dictionary) -> String:
	match str(task.get("type", "")):
		"give":
			return L.t("story.task.give")
		"kill":
			return L.t("story.task.kill", [Monsters.name_of(task["kind"])])
		"build":
			return L.t("story.task.build", [Estate.name_of(task["id"]), int(task["n"])])
	return ""
