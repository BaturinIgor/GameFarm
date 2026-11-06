extends RefCounted
## Бот-игрок: играет сессиями по правилам игры (системы Game) в ускоренном времени (Clock.offset).
## Мир заменён моделью: точки добычи из раскладок карт, удары по прочности и энергии, восстановление точек.
## Бои, подземелья, ивенты и огород бот не трогает: их доход в расчёт не входит.
## Шахту он проходит без поля (победа с шансом mine_win), открывает сундуки и пользуется инкубатором и гнездом.

const WALK := 2.5          # секунд дойти до следующей точки
const DEPOSIT_WALK := 10.0 # секунд сходить к складу
const DAY := 86400.0

var profile: Dictionary
var t0 := 0.0
var played := 0.0          # секунд в игре всего
var log_days: Array = []   # снимок в конце каждого дня
var milestones := {}       # уровень -> [день, часы игры]
var energy_outs := 0       # сессий, кончившихся из-за энергии
var waiting_goods := {}    # товар -> сколько раз стройка ждала его
var built := {}            # здание -> сколько уровней построено
var spent_goods := {}      # товар -> сколько ушло на стройку и инструменты
var sold_coins := 0
var sold_by := {}          # ресурс -> монет за продажу
var coins_by := {}         # источник -> монет
var crystals_spent := 0
var events_hit := {}
var games := {"mine_runs": 0, "mine_wins": 0, "mine_coins": 0, "chests": 0, "hatched": 0, "hybrids": 0, "shiny": 0, "eggs_crystals": 0, "hearts": 0, "altar": 0}
var _spots := {}           # "loc|type" -> [время готовности точек]
var _layouts := {}


func _init(p: Dictionary) -> void:
	profile = p


func now() -> float:
	return Clock.now()


func advance(sec: float) -> void:
	Clock.offset += sec


func day() -> int:
	return int((now() - t0) / DAY)


# MARK: Прогон

func run() -> Dictionary:
	Clock.offset = 0.0
	Game.save = Game.default_save()
	for sys in Game.systems:
		sys.defaults(Game.save)
	Game.world_map.refresh_reachable()
	Game.recalc()
	t0 = now()
	for key in profile.get("buy_at_start", []):
		Game.premium.grant(key)
	var days := int(profile["days"])
	var sessions := int(profile["sessions"])
	var minutes := float(profile["minutes"])
	for d in days:
		var day_start := t0 + d * DAY
		# Сессии равномерно в окне 08:00-23:00
		for s in sessions:
			var at := day_start + 8.0 * 3600.0 + (15.0 * 3600.0) * float(s) / float(maxi(1, sessions))
			if now() < at:
				_away(at - now())
			_session(minutes * 60.0)
		for key in profile.get("buy_daily", []):
			Game.premium.grant(key)
		_snapshot(d + 1)
		if Game.level >= Game.MAX_LEVEL and not milestones.has("done"):
			milestones["done"] = [d + 1, played / 3600.0]
	return report()


func _away(sec: float) -> void:
	Game.save["lastSeen"] = now()
	advance(sec)
	Game.animals.apply_offline()
	Game.estate.tick()


func _session(budget: float) -> void:
	var end := now() + budget
	_daily_chores()
	_spend()
	var idle_checks := 0
	while now() < end:
		var did := _gather_step()
		if did < 0.0:
			# Энергия кончилась
			if not _refill_energy():
				energy_outs += 1
				break
			continue
		if did == 0.0:
			idle_checks += 1
			advance(30.0)
			played += 30.0
			if idle_checks > 6:
				break
			continue
		played += did
		if Game.backpack_free <= 0:
			_deposit()
	_deposit()
	_spend()


# MARK: Добыча

func _layout(loc: String) -> Dictionary:
	if not _layouts.has(loc):
		var path := "res://data/layouts/layout_%s.json" % loc
		var data = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		var counts := {}
		if data is Dictionary:
			for s in data.get("spots", []):
				counts[str(s[0])] = int(counts.get(str(s[0]), 0)) + 1
		_layouts[loc] = counts
	return _layouts[loc]


## Точки, которые бот может бить: [локация, тип, количество].
func _options() -> Array:
	var out: Array = []
	for loc in Locations.world():
		if not Game.world_map.is_unlocked(loc):
			continue
		var counts: Dictionary = _layout(loc)
		for type in counts:
			var spec := Nodes.spec(type)
			if spec.is_empty() or not Game.can_harvest(spec):
				continue
			out.append([loc, type, int(counts[type])])
	return out


func _hits_for(spec: Dictionary) -> int:
	var s := Game.stats
	var dmg := Game.damage_against(spec) * (1.0 + s.crit_chance * (s.crit_mult - 1.0)) * (1.0 + s.double_strike_chance)
	return maxi(1, int(ceil(float(spec["hp"]) / maxf(0.01, dmg))))


## Что сейчас нужно: ресурс -> недостача для ближайших целей.
func _needs() -> Dictionary:
	var need := {}
	var add := func(cost: Dictionary) -> void:
		for it in cost.get("items", []):
			var k := str(it[0])
			var miss := int(it[1]) - Game.amount(k)
			if miss > 0 and not Estate.is_good(k):
				need[k] = maxi(int(need.get(k, 0)), miss)
	for tool in Tools.GATHERING:
		if Game.workshop.upgrade_block(tool) in ["", "cost"]:
			add.call(Game.workshop.next_cost(tool))
	for g in WorldGraph.GATES:
		if (g["a"] in Game.world_map.reachable or g["b"] in Game.world_map.reachable) and not g["royal"] \
				and not Game.world_map.is_gate_open(g["id"]) and Game.level >= WorldGraph.level(g):
			add.call(Game.world_map.gate_cost(g))
	for id in Estate.IDS:
		var b: Array = Game.estate.upgrade_block(id)
		if b.is_empty() or str(b[0]) == "estate.block.builders":
			add.call(Estate.build_cost(id, Game.estate.level(id) + 1))
	# Дар Сердцу текущей главы
	if profile.get("story_needs", true) and Game.story.chapter_open() and not Game.story.gift_given():
		add.call(Story.gift(Game.story.chapter()))
	for good in _active_recipes():
		for it in Estate.RECIPES[good]:
			var want := int(it[1]) * 40
			if Game.amount(it[0]) < want and not Estate.is_good(it[0]):
				need[it[0]] = maxi(int(need.get(it[0], 0)), want - Game.amount(it[0]))
	return need


func _active_recipes() -> Array:
	var out: Array = []
	for id in Estate.IDS:
		if Estate.produces(id) and Game.estate.level(id) > 0:
			out.append(Game.estate.recipe(id))
	return out


## Одна точка: секунды игры, 0 - нечего делать, -1 - нет энергии.
func _gather_step() -> float:
	var need := _needs()
	var best: Array = []
	var best_score := -1.0
	for o in _options():
		var spec := Nodes.spec(o[1])
		var hits := _hits_for(spec)
		var key := "%s|%s" % [o[0], o[1]]
		var ready := _ready_at(key, int(o[2]))
		var wait := maxf(0.0, ready - now())
		var sec := hits * Game.stats.hit_interval + WALK + wait
		var value := 0.0
		for y in spec["yields"]:
			var n := (float(y[1]) + float(y[2])) * 0.5 * float(y[3]) * Game.stats.yield_multiplier(y[0])
			if need.has(y[0]):
				# Нужное на цели важнее опыта: вес растёт с уровнем, как растёт опыт с точки
				value += minf(n, float(need[y[0]])) * (6.0 + 2.0 * float(Game.level))
			value += n * Game.sell_price(y[0]) * 0.05
		value += float(spec["xp"]) * 1.0
		# Энергия дороже времени: очки за единицу энергии и за секунду
		var score := value / (float(hits) * 4.0 + sec)
		# Страницы дневника падают только в локации главы: туда и тянет, пока их не хватает
		if Game.story.chapter_open() and o[0] == Story.loc(Game.story.chapter()) and Game.story.pages() < Story.PAGES:
			score *= 3.0
		if score > best_score:
			best_score = score
			best = [o, spec, hits, key, sec]
	if best.is_empty():
		return 0.0
	var spec: Dictionary = best[1]
	var hits: int = best[2]
	for i in hits:
		if not Game.energy.try_spend():
			return -1.0
	advance(best[4])
	Game.save["current"] = str(best[0][0])
	_take_spot(best[3], int(best[0][2]), float(spec["respawn"]) * Game.stats.respawn_mult)
	var stats := Game.stats
	var roll := randf()
	var mult := 3 if roll < stats.triple_chance else (2 if roll < stats.triple_chance + stats.double_chance else 1)
	for y in spec["yields"]:
		if randf() >= float(y[3]):
			continue
		var raw := float(randi_range(int(y[1]), int(y[2]))) * stats.yield_multiplier(y[0])
		var n := int(raw)
		if randf() < raw - n:
			n += 1
		n *= mult
		if n > 0:
			if Game.add_to_backpack(y[0], n) < n:
				_deposit()
				Game.add_to_backpack(y[0], n)
	Game.register_harvest(int(spec["xp"]))
	return best[4]


func _ready_at(key: String, count: int) -> float:
	var list: Array = _spots.get(key, [])
	if list.size() < count:
		return now()
	return list.min()


func _take_spot(key: String, count: int, respawn: float) -> void:
	var list: Array = _spots.get(key, [])
	if list.size() < count:
		list.append(now() + respawn)
	else:
		var i := list.find(list.min())
		list[i] = maxf(now(), float(list[i])) + respawn
	_spots[key] = list


func _deposit() -> void:
	if Game.backpack_count <= 0:
		return
	advance(DEPOSIT_WALK)
	played += DEPOSIT_WALK
	Game.deposit_backpack()
	_sell_surplus()
	# Что не влезло на склад - продаём из рюкзака не получится: продаём со склада и сдаём ещё раз
	if Game.backpack_count > 0:
		_sell_surplus(true)
		Game.deposit_backpack()
		if Game.backpack_count > 0:
			Game.save["backpack"] = {}


## Продать лишнее: всё сверх нужного на цели, когда хранилище заполнено больше чем на 70%.
func _sell_surplus(force := false) -> void:
	var need := {}
	for k in _reserve():
		need[k] = _reserve()[k]
	for store in ["storage", "barn"]:
		var cap := Game.estate.capacity(store)
		if not force and Game.estate.stored(store) < cap * 0.7:
			continue
		var kinds: Array = Game.save["storage"].keys()
		for kind in kinds:
			if Estate.store_of(kind) != store:
				continue
			var keep := int(need.get(kind, 0)) + 30
			var extra := Game.storage_of(kind) - keep
			if extra > 0:
				var c := Game.sell(kind, extra)
				sold_coins += c
				sold_by[kind] = int(sold_by.get(kind, 0)) + c


## Сколько держать на складе: полные цены ближайших целей и сырьё цехов.
func _reserve() -> Dictionary:
	var r := {}
	var add := func(cost: Dictionary) -> void:
		for it in cost.get("items", []):
			r[it[0]] = maxi(int(r.get(it[0], 0)), int(it[1]))
	for tool in Tools.GATHERING:
		add.call(Game.workshop.next_cost(tool))
	for id in Estate.IDS:
		if Game.estate.level(id) < Estate.max_level(id):
			add.call(Estate.build_cost(id, Game.estate.level(id) + 1))
	for good in _active_recipes():
		for it in Estate.RECIPES[good]:
			r[it[0]] = maxi(int(r.get(it[0], 0)), int(it[1]) * 60)
	return r


func _refill_energy() -> bool:
	if Game.energy.ads_left() > 0 and profile.get("ads", true):
		Game.energy.ad_reward()
		return true
	if profile.get("spend_crystals", false) and Game.shop.crystals() >= Game.energy.buy_price() + 20 \
			and int(Game.save["energy"]["bought"]) < int(profile.get("energy_buys", 2)):
		crystals_spent += Game.energy.buy_price()
		return Game.energy.buy()
	return false


# MARK: Траты

func _daily_chores() -> void:
	Game.estate.tick()
	Game.estate.collect_all()
	if Game.shop.gift_ready():
		Game.shop.claim_gift()
	Game.quests.ensure_quests()
	Game.quests.claim_all_quests()
	for a in Quests.achievements():
		if Game.quests.can_claim(a):
			Game.quests.claim(a)
	for i in Game.daily.goals().size():
		Game.daily.claim(i)
	for i in Game.daily.week_goals().size():
		Game.daily.claim(i, true)
	if Game.daily.bonus_ready():
		Game.daily.take_bonus()
	if Game.daily.bonus_ready(true):
		Game.daily.take_bonus(true)


func _spend() -> void:
	Game.estate.tick()
	Game.estate.collect_all()
	for i in 200:
		if Game.talents.points_free() <= 0:
			break
		var learned := false
		for id in _talent_order():
			if Game.talents.learn(id):
				learned = true
				break
		if not learned:
			break
	for tool in Tools.UPGRADABLE:
		var cost := Game.workshop.next_cost(tool)
		if Game.workshop.upgrade(tool):
			_count_goods(cost)
	for g in WorldGraph.GATES:
		Game.world_map.open_gate(g["id"])
	# Сюжет раньше стройки: дар просит монеты, а стройка тратит их все
	_story()
	_build()
	_orders()
	_animals()
	if profile.get("minigames", true):
		_minigames()
	if profile.get("spend_crystals", false):
		_crystals()


## Сердца земли: пара боёв за сессию в локации главы (живой игрок бьёт монстров по пути), дар, пробуждение,
## алтарь. Мифическое пробуждение - в _animals через обычный awaken.
func _story() -> void:
	var st := Game.story
	if st.chapter_open():
		var loc := Story.loc(st.chapter())
		var keep := Game.current
		Game.save["current"] = loc
		for i in int(profile.get("story_kills", 3)):
			Game.emit_event("kill", {"monster": "slime", "level": Game.level, "boss": false})
		Game.save["current"] = keep
		st.give_gift()
		if not st.awaken_heart().is_empty():
			games["hearts"] += 1
	while st.raise_altar():
		games["altar"] += 1


func _talent_order() -> Array:
	var ids := Talents.ids()
	var pref: Array = profile.get("branches", ["gathering", "mining", "beasts", "travel", "farming", "combat"])
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ta := Talents.tier(a)
		var tb := Talents.tier(b)
		if ta != tb:
			return ta < tb
		return _branch_rank(pref, Talents.branch(a)) < _branch_rank(pref, Talents.branch(b)))
	return ids


## Место ветки в предпочтениях профиля; ветки вне списка (усадьба) - в конце.
static func _branch_rank(pref: Array, b: String) -> int:
	var i := pref.find(b)
	return i if i >= 0 else pref.size()


func _build() -> void:
	# Редкие материалы диких земель бот не добывает (там бои): считаем, что игрок ходит туда,
	# когда открыто кольцо, и приносит столько, сколько нужно на стройку
	for i in Wild.RINGS.size():
		var ring: Dictionary = Wild.RINGS[i]
		if Game.level < int(ring["level"]):
			continue
		var need := 0
		for id in Estate.IDS:
			for it in Estate.build_cost(id, Game.estate.level(id) + 1).get("items", []):
				if it[0] == ring["rare"]:
					need = maxi(need, int(it[1]))
		if Game.storage_of(ring["rare"]) < need:
			Game.save["storage"][ring["rare"]] = need
	# Главный дом, склад, амбар, лесопилка - в первую очередь, потом остальные по возрастанию уровня
	var order: Array = Estate.IDS.duplicate()
	order.sort_custom(func(a: String, b: String) -> bool:
		var pa := 0 if a in ["main", "storage", "barn", "sawmill"] else 1
		var pb := 0 if b in ["main", "storage", "barn", "sawmill"] else 1
		if pa != pb:
			return pa < pb
		return Game.estate.level(a) < Game.estate.level(b))
	for id in order:
		var block: Array = Game.estate.upgrade_block(id)
		if not block.is_empty():
			continue
		var cost := Estate.build_cost(id, Game.estate.level(id) + 1)
		if not Game.can_afford(cost) and profile.get("buy_goods", true) and Game.estate.can_buy_missing(id) \
				and int(Game.save["coins"]) > Game.estate.missing_goods_coins(id) * 2:
			var c := int(Game.save["coins"])
			_count_goods(cost)
			if Game.estate.buy_missing_and_upgrade(id):
				built[id] = int(built.get(id, 0)) + 1
				coins_by["goods"] = int(coins_by.get("goods", 0)) + c - int(Game.save["coins"])
				continue
		if not Game.can_afford(cost):
			for it in cost.get("items", []):
				if Estate.is_good(it[0]) and Game.amount(it[0]) < int(it[1]):
					waiting_goods[it[0]] = int(waiting_goods.get(it[0], 0)) + 1
			continue
		if Game.estate.start_upgrade(id):
			built[id] = int(built.get(id, 0)) + 1
			_count_goods(cost)
	# Цеха: делают тот товар из своих рецептов, которого меньше всего относительно нужного на стройку
	var want := _reserve()
	for id in Estate.IDS:
		if not Estate.produces(id) or Game.estate.level(id) <= 0:
			continue
		var best := Game.estate.recipe(id)
		var best_ratio := INF
		for good in Estate.recipes(id):
			var need := float(want.get(good, 0))
			if need <= 0.0:
				continue
			var ratio := float(Game.amount(good)) / need
			if ratio < best_ratio:
				best_ratio = ratio
				best = good
		Game.estate.set_recipe(id, best)


func _count_goods(cost: Dictionary) -> void:
	for it in cost.get("items", []):
		if Estate.is_good(it[0]):
			spent_goods[it[0]] = int(spent_goods.get(it[0], 0)) + int(it[1])


func _orders() -> void:
	if not Game.estate.orders_open():
		return
	for o in Game.estate.orders().duplicate():
		if o is Dictionary and o.has("id") and Game.estate.can_complete(o):
			Game.estate.complete_order(str(o["id"]))


func _animals() -> void:
	for id in Animals.IDS:
		var price := Game.animals.shop_price(id)
		if price > 0 and int(Game.save["coins"]) > price * int(profile.get("animal_margin", 3)):
			Game.animals.buy(id)


func _crystals() -> void:
	# Доски из лавки и ускорение стройки
	while Game.shop.planks_left() > 0 and Game.shop.crystals() > 200:
		var c := Game.shop.crystals()
		if not Game.shop.buy_market("planks"):
			break
		crystals_spent += c - Game.shop.crystals()
	# Цеха за кристаллы: окно производства заполняется сразу (сырьё всё равно нужно)
	for id in Estate.IDS:
		if Game.estate.can_boost(id) and Game.estate.boost_cost(id) <= int(profile.get("boost_max", 0)) \
				and Game.estate.affordable(id) > Game.estate.capacity_of(id):
			var c := Game.shop.crystals()
			Game.estate.collect(id)
			if Game.estate.boost(id):
				crystals_spent += c - Game.shop.crystals()
				Game.estate.collect(id)
	for id in Estate.IDS:
		if Game.estate.building(id) and Game.estate.speedup_cost(id) <= int(profile.get("speedup_max", 0)):
			var c := Game.shop.crystals()
			if Game.estate.speed_up(id):
				crystals_spent += c - Game.shop.crystals()


# MARK: Шахта, сундуки, инкубатор

func _minigames() -> void:
	var win_chance := float(profile.get("mine_win", 0.75))
	# Шахта - пара заходов за сессию (профиль mine_runs), а не все фонари подряд
	var runs := int(profile.get("mine_runs", 2))
	while runs > 0 and Game.mine.open() and Game.mine.start():
		runs -= 1
		games["mine_runs"] += 1
		var f := Game.mine.floor_n()
		if randf() < win_chance:
			var c0 := int(Game.save["coins"])
			var blocks := {}
			for c in Mine.colors(f):
				blocks[c] = randi_range(10, 25)
			Game.mine.take_ore(f, blocks)
			Game.mine.win(f)
			games["mine_wins"] += 1
			games["mine_coins"] += int(Game.save["coins"]) - c0
		advance(150.0)
		played += 150.0
	for chest in Chests.IDS:
		games["chests"] += Game.chests.open(chest, 50).size()
	var inc := Game.incubator
	if not inc.open():
		return
	if inc.ready():
		var out := inc.hatch()
		games["hatched"] += 1
		if Animals.is_hybrid(str(out["animal"])):
			games["hybrids"] += 1
		if bool(out["shiny"]):
			games["shiny"] += 1
		games["eggs_crystals"] += int(out["crystals"])
	if not inc.busy() and not inc.eggs().is_empty():
		# Самое редкое яйцо первым
		var best := 0
		for i in inc.eggs().size():
			if Incubator.RARITIES.find(str(inc.eggs()[i]["r"])) > Incubator.RARITIES.find(str(inc.eggs()[best]["r"])):
				best = i
		inc.incubate(best)
	if inc.nest_ready():
		inc.collect_nest()
	if not inc.nesting():
		var ps := inc.parents()
		var pair: Array = []
		for rec in Incubator.RECIPES:
			if rec[0] in ps and rec[1] in ps and not rec[2] in inc.found():
				pair = [rec[0], rec[1]]
				break
		if pair.is_empty() and ps.size() >= 2:
			pair = [ps[0], ps[1]]
		if not pair.is_empty():
			inc.breed(pair[0], pair[1])


# MARK: Отчёт

func _snapshot(d: int) -> void:
	for lvl in [5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60]:
		if Game.level >= lvl and not milestones.has(lvl):
			milestones[lvl] = [d, snappedf(played / 3600.0, 0.1)]
	var levels := {}
	for id in Estate.IDS:
		levels[id] = Game.estate.level(id)
	var tools := {}
	for tool in Tools.GATHERING:
		tools[tool] = Game.tier(tool)
	log_days.append({"day": d, "level": Game.level, "hours": snappedf(played / 3600.0, 0.1), "coins": int(Game.save["coins"]),
		"crystals": Game.shop.crystals(), "estate": levels, "tools": tools, "planks": Game.storage_of("planks"),
		"talents_spent": Game.talents.points_spent(), "talents_total": Game.talents.points_total(),
		"locations": Game.world_map.reachable.size(), "animals": Game.animals.owned().size(),
		"chapter": Game.story.chapter(), "shards": Game.story.shards(), "altar": Game.story.altar()})


func report() -> Dictionary:
	return {"profile": profile["name"], "milestones": milestones, "days": log_days, "energy_outs": energy_outs,
		"waiting_goods": waiting_goods, "built": built, "spent_goods": spent_goods, "sold_coins": sold_coins, "sold_by": sold_by, "coins_by": coins_by,
		"crystals_spent": crystals_spent, "minigames": games, "shards": Game.story.shards(), "chapter": Game.story.chapter(), "mine_floor": Game.mine.best(),
		"eggs": Game.incubator.eggs().size(), "found_hybrids": Game.incubator.found(), "gathered": Game.save["gathered"], "storage": Game.save["storage"], "played_hours": snappedf(played / 3600.0, 0.1)}
