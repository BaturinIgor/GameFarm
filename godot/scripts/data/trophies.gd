class_name Trophies
## Трофеи на стене гостиной: появляются за достижения (порт Trophy из House.swift и trophyProgress из GameState).

const IDS := ["wolf", "bear", "shield", "sword", "star", "cup"]

const SPRITES := {
	"wolf": "hm_wolf", "bear": "hm_bear", "shield": "hm_shield", "sword": "hm_sword", "star": "hm_star", "cup": "hm_cup",
}

## Сколько нужно для трофея.
const TARGETS := {"wolf": 50, "bear": 300, "shield": 15, "sword": 4, "star": 1, "cup": 1}

## Созвездия (ConstellationID) для звёздной таблички.
const CONSTELLATIONS := ["harvest", "forest", "depths", "sea", "beasts", "monsters", "sky", "garden", "dungeon", "birds"]


static func name_of(id: String) -> String:
	return L.t("trophy." + id)


static func sprite(id: String) -> String:
	return SPRITES.get(id, "hm_cup")


static func target(id: String) -> int:
	return int(TARGETS.get(id, 1))


## Текст условия.
static func condition(id: String) -> String:
	return L.t("trophy.%s.how" % id, [target(id)])


static func progress(id: String) -> int:
	var s := Game.save
	match id:
		"wolf", "bear": return int(s.get("kills", 0))
		"shield": return s.get("claimed", []).size()
		"sword": return int(s.get("tools", {}).get("sword", 1))
		"star":
			if not Game.collection.has_method("is_complete"):
				return 0
			var n := 0
			for c in CONSTELLATIONS:
				if bool(Game.collection.call("is_complete", c)):
					n += 1
			return n
		"cup": return int(s.get("rebirths", 0))
	return 0


static func is_earned(id: String) -> bool:
	return progress(id) >= target(id)
