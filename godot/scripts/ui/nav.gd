class_name Nav
## Навигация: 5 вкладок нижней панели, у каждой - разделы (окна). Окно раздела получает полосу разделов под
## шапкой (Sheet.nav_group), так что из любого окна видно соседние разделы и где что горит.
## Счётчик вкладки - сумма счётчиков её разделов, счётчик раздела - сумма счётчиков вкладок внутри окна,
## а внутри окна горит сама кнопка (UiKit.attention). Так у любой отметки есть путь до кнопки.
## Закрытые по уровню разделы видны с уровнем и при нажатии говорят, когда откроются.

## Вкладки нижней панели: id, иконка, ключ подписи, разделы.
const GROUPS := [
	["farm", "chest", "nav.farm", ["storage", "estate", "workshop"]],
	["animals", "paw", "hud.animals", ["animals", "wild", "incubator"]],
	["quests", "scroll", "hud.quests", ["quests", "heart"]],
	["hero", "star", "nav.hero", ["talents", "hunt", "collection", "wardrobe"]],
	["world", "map", "nav.world", ["map", "mine", "events"]],
]
## Вкладка в центре: крупнее остальных.
const CENTER := "quests"

## Разделы: ключ подписи и окно.
const SUBS := {
	"storage": ["hud.storage", "res://scripts/ui/storage_panel.gd"],
	"estate": ["estate.title", "res://scripts/ui/estate_panel.gd"],
	"workshop": ["hud.workshop", "res://scripts/ui/workshop_panel.gd"],
	"animals": ["hud.animals", "res://scripts/ui/animals_panel.gd"],
	"wild": ["wild.title", "res://scripts/ui/wild_panel.gd"],
	"incubator": ["inc.title", "res://scripts/ui/incubator_panel.gd"],
	"quests": ["hud.quests", "res://scripts/ui/quests_panel.gd"],
	"heart": ["heart.title", "res://scripts/ui/story_panel.gd"],
	"talents": ["hud.talents", "res://scripts/ui/talents_panel.gd"],
	"hunt": ["hunt.title", "res://scripts/ui/hunt_panel.gd"],
	"collection": ["nav.collection", "res://scripts/ui/collection_panel.gd"],
	"wardrobe": ["wardrobe.title", "res://scripts/ui/wardrobe_panel.gd"],
	"map": ["hud.map", "res://scripts/ui/map_panel.gd"],
	"mine": ["mine.title", "res://scripts/ui/mine_panel.gd"],
	"events": ["event.title", "res://scripts/ui/events_panel.gd"],
}

## Последний открытый раздел вкладки: туда и возвращаемся, если ничего не горит.
static var _last: Dictionary = {}


static func group_spec(group: String) -> Array:
	for g in GROUPS:
		if g[0] == group:
			return g
	return []


## С какого уровня открывается раздел (0 - сразу).
static func level_of(sub: String) -> int:
	match sub:
		"wild": return int(Wild.RINGS[0]["level"])
		"events": return Events.MIN_LEVEL
		"mine": return Mine.MIN_LEVEL
		"incubator": return Incubator.MIN_LEVEL
		"heart": return Story.MIN_LEVEL
	return 0


static func locked(sub: String) -> bool:
	return Game.level < level_of(sub)


## Сколько в разделе можно забрать или сделать прямо сейчас.
static func count(sub: String) -> int:
	if locked(sub):
		return 0
	match sub:
		"estate":
			var e := Game.estate
			return e.ready_count() + e.upgradable_count() + (e.ready_orders() + Game.fair.ready_count() if e.orders_open() else 0)
		"workshop":
			return Game.workshop.upgradable_count()
		"animals":
			return Game.animals.upgradable_count()
		"wild":
			return Game.wild.ready_count() if Game.wild.open() else 0
		"quests":
			return Game.quests.claimable_count() + Game.residents.attention_count()
		"talents":
			return Game.talents.points_free()
		"hunt":
			return Game.combat.bestiary_ready_count()
		"collection":
			return Game.collection.collector_ready()
		"map":
			return Game.world_map.openable_gates() + (1 if Game.premium.free_ticket_ready() else 0) \
				+ (1 if MapPanel.garden_chest_ready() else 0)
		"mine":
			return Game.mine.ready_count()
		"incubator":
			return Game.incubator.ready_count()
		"heart":
			return Game.story.ready_count() + (1 if Game.story.can_raise_altar() else 0)
		"events":
			return Game.events.event_claimable()
	return 0


static func group_count(group: String) -> int:
	var n := 0
	for sub in group_spec(group)[3]:
		n += count(sub)
	return n


## Вкладка и раздел, к которым относится окно ([] - окно вне вкладок).
static func locate(w: Node) -> Array:
	var script: Script = w.get_script()
	if script == null:
		return []
	for g in GROUPS:
		for sub in g[3]:
			if SUBS[sub][1] == script.resource_path:
				return [g[0], sub]
	return []


## Нажали вкладку: раздел, где что-то горит, иначе последний открытый, иначе первый.
static func open_group(group: String) -> void:
	var subs: Array = group_spec(group)[3]
	for sub in subs:
		if count(sub) > 0:
			open_sub(sub)
			return
	var last := str(_last.get(group, ""))
	open_sub(last if last != "" and not locked(last) else subs[0])


static func open_sub(sub: String) -> void:
	if Hud.current == null or not SUBS.has(sub):
		return
	if locked(sub):
		Sound.play("error")
		Game.show_toast("px:key", L.t("nav.locked", [L.t(SUBS[sub][0]), level_of(sub)]))
		return
	var path: String = SUBS[sub][1]
	if not ResourceLoader.exists(path):
		return
	var w: Node = load(path).new()
	# Окно само выбирает вкладку, где горит отметка
	if w.has_method("focus_attention"):
		w.call("focus_attention")
	Hud.current.open_window(w)


## Запомнить раздел, который сейчас открыт (Sheet при показе).
static func remember(group: String, sub: String) -> void:
	_last[group] = sub


## Слепок полосы разделов: если он не изменился, полосу можно не пересобирать.
static func signature(group: String, current: String) -> String:
	var parts: Array = [current, L.code]
	var spec := group_spec(group)
	if not spec.is_empty():
		for sub in spec[3]:
			parts.append("%s:%d:%s" % [sub, count(sub), locked(sub)])
	return "|".join(parts)


## Полоса разделов под шапкой окна. Одна вкладка без соседей - полосы нет (null).
static func bar(group: String, current: String) -> Control:
	var subs: Array = group_spec(group)[3] if not group_spec(group).is_empty() else []
	if subs.size() < 2:
		return null
	var items: Array = []
	for sub in subs:
		var text := L.t(SUBS[sub][0])
		if locked(sub):
			text = L.t("nav.lockedShort", [text, level_of(sub)])
		items.append([sub, text, count(sub)])
	return UiKit.tabs(items, current, func(id: String) -> void: Nav.open_sub(id), true)
