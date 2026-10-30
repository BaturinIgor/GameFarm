class_name Skins
## Образы героя (порт Skin и SkinUnlock из Premium.swift). Только внешний вид, на силу не влияют.
## Лист героя - спрайт pl_<образ>. Выбранный образ - save["skin"].

const IDS := [
	"farmer", "farmerWoman", "farmerMan", "builder", "cowboy", "detective", "elf", "rockstar",
	"robot", "genie",
	"wizard", "ninja", "vampire", "astronaut", "princess", "prince", "superhero", "merperson", "fairy", "zombie",
	"knight",
	"harvester", "ranger", "miner", "sailor", "shepherd", "hunter", "stargazer",
	"cultivator", "duelist", "falconer",
	"autumn", "slimeKing", "frost", "surfer",
]

## Как открывается образ: [вид, значение]. Вид: free, level, product, constellation, event.
## Остальные образы - из покупки "Коллекция образов" (product skins).
const UNLOCK := {
	"farmer": ["free"], "farmerWoman": ["free"], "farmerMan": ["free"],
	"builder": ["level", 10], "cowboy": ["level", 20], "detective": ["level", 30], "elf": ["level", 40],
	"rockstar": ["level", 50],
	"robot": ["product", "starter"], "genie": ["product", "pro"], "knight": ["product", "garden"],
	"harvester": ["constellation", "harvest"], "ranger": ["constellation", "forest"],
	"miner": ["constellation", "depths"], "sailor": ["constellation", "sea"],
	"shepherd": ["constellation", "beasts"], "hunter": ["constellation", "monsters"],
	"stargazer": ["constellation", "sky"], "cultivator": ["constellation", "garden"],
	"duelist": ["constellation", "dungeon"], "falconer": ["constellation", "birds"],
	"autumn": ["event", "harvestFest"], "slimeKing": ["event", "slimeNight"], "frost": ["event", "winterTale"],
	"surfer": ["event", "beachParty"],
}


static func is_valid(skin: String) -> bool:
	return skin in IDS


static func name_of(skin: String) -> String:
	return L.t("skin." + skin)


static func unlock(skin: String) -> Array:
	return UNLOCK.get(skin, ["product", "skins"])


## Образы из покупки "Коллекция образов".
static func collection() -> Array:
	return IDS.filter(func(s: String) -> bool:
		var u := unlock(s)
		return u[0] == "product" and u[1] == "skins")


## Выбранный образ (неизвестный - фермер).
static func current() -> String:
	var skin := str(Game.save.get("skin", "farmer"))
	return skin if is_valid(skin) else "farmer"


static func is_unlocked(skin: String) -> bool:
	if not is_valid(skin):
		return false
	var u := unlock(skin)
	match str(u[0]):
		"free": return true
		"level": return maxi(Game.level, int(Game.save.get("bestLevel", 1))) >= int(u[1])
		"product":
			# Образ из коллекции можно получить и по одному: за кристаллы, в наборе или от MAX
			return Game.premium.owns(str(u[1])) or (str(u[1]) == "skins" and Game.shop.owns_skin(skin))
		"constellation": return Game.collection.is_complete(str(u[1]))
		"event": return skin in Game.save.get("eventSkins", [])
	return false


static func select(skin: String) -> void:
	if not is_unlocked(skin):
		return
	Game.save["skin"] = skin
	Game.mark_dirty()


## Как открыть закрытый образ: уровень, покупка, созвездие или ивент.
static func lock_text(skin: String) -> String:
	var u := unlock(skin)
	match str(u[0]):
		"level": return L.t("common.lvl", [int(u[1])])
		"product": return L.t("product." + str(u[1]))
		"constellation": return Cards.constellation_name(str(u[1]))
		"event": return L.t("skin.event", [L.t("event." + str(u[1]))])
	return ""
