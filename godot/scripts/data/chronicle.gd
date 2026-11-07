class_name Chronicle
## Летопись и статуи альянса (docs/supabase/alliance_chronicle.sql): страницы по неделям и зал славы.
## Рамка статуи - украшение за кристаллы, силы не даёт. Список рамок совпадает с _al_frames на сервере.

## Рамка: цена в кристаллах, цвет камня и цвет каймы.
const FRAMES := {
	"stone": {"crystals": 0, "fill": Color("b8b0a0"), "edge": Color("6e6658")},
	"bronze": {"crystals": 150, "fill": Color("d8955a"), "edge": Color("8a4e22")},
	"gold": {"crystals": 300, "fill": Color("ffd54a"), "edge": Color("b07a10")},
	"crystal": {"crystals": 500, "fill": Color("9fe4ff"), "edge": Color("3a8ab8")},
	"flame": {"crystals": 800, "fill": Color("ff9a4a"), "edge": Color("c0361a")},
}
const ORDER := ["stone", "bronze", "gold", "crystal", "flame"]
## Сколько недель летописи показывать.
const MAX_WEEKS := 30


static func price(frame: String) -> int:
	return int(FRAMES.get(frame, {}).get("crystals", 0))


static func valid(frame: String) -> bool:
	return FRAMES.has(frame)


## Номер недели альянса: первая неделя после основания - 1.
static func week_number(week_key: int, founded_week: int) -> int:
	return maxi(1, week_key - founded_week + 1)


## Статуй у участника всего.
static func statues(s: Dictionary) -> int:
	return int(s.get("hits", 0)) + int(s.get("gives", 0))
