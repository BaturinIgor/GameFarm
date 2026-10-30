class_name EnergySystem
extends RefCounted
## Энергия: 1 удар по ресурсу - 1 энергия. Запас 600, восстанавливается сама (1 за 45 секунд, полный запас
## примерно за 8 часов). Ещё: новый уровень (до полного), блюда с кухни, ролик, покупка за кристаллы,
## бесконечная энергия на время (покупка и последняя платная ступень ивента), награды жителей и набегов.
## Бой, грядки, звери и производство энергию не тратят. Экспедиции по билетам - тоже.
## В Game.save: energy = {value, at, inf_until, buy_day, bought, ad_day, ads}.

const BASE_MAX := 600.0
const REGEN_SECONDS := 45.0
## Еда даёт не больше стольких единиц в день и не поднимает выше запаса (иначе кухня - бесконечная энергия).
const FOOD_PER_DAY := 240
const AD_ENERGY := 150
const ADS_PER_DAY := 3
const BUY_ENERGY := 250
const BUY_BASE := 10
const BUY_STEP := 5
const INFINITE_MINUTES := 30
const INFINITE_PRICE := 60
## Сверх запаса можно накопить едой и покупками, но не больше двух запасов.
const OVERFLOW := 3.0

var _hint_at := -100.0


func defaults(save: Dictionary) -> void:
	var raw: Variant = save.get("energy", {})
	var e: Dictionary = raw if raw is Dictionary else {}
	save["energy"] = {"value": float(e.get("value", BASE_MAX)), "at": float(e.get("at", _now())),
		"inf_until": float(e.get("inf_until", 0.0)), "buy_day": int(e.get("buy_day", -1)), "bought": int(e.get("bought", 0)),
		"ad_day": int(e.get("ad_day", -1)), "ads": int(e.get("ads", 0)),
		"food_day": int(e.get("food_day", -1)), "food": int(e.get("food", 0))}


func _e() -> Dictionary:
	return Game.save["energy"]


static func _now() -> float:
	return Time.get_unix_time_from_system()


## Запас: академия (выносливость) и Pro.
func max_value() -> float:
	return roundf(BASE_MAX * Game.academy.mult("stamina") * (1.2 if Game.premium.has_pro() else 1.0))


## Секунд на одну единицу: академия (отдых) и Pro.
func regen_seconds() -> float:
	return REGEN_SECONDS * Game.academy.mult("recovery") * (0.8 if Game.premium.has_pro() else 1.0)


## Текущая энергия с учётом восстановления (ниже запаса копится, выше - нет).
func value() -> float:
	var e := _e()
	var v := float(e["value"])
	var mx := max_value()
	var now := _now()
	if v < mx:
		v = minf(mx, v + (now - float(e["at"])) / regen_seconds())
	e["value"] = v
	e["at"] = now
	return v


func infinite() -> bool:
	return float(_e()["inf_until"]) > _now()


func infinite_left() -> float:
	return maxf(0.0, float(_e()["inf_until"]) - _now())


## Секунд до полного запаса (0 - уже полный).
func until_full() -> float:
	return maxf(0.0, (max_value() - value()) * regen_seconds())


## Потратить на удар. false - энергии нет (подсказка показывается не чаще раза в 3 секунды).
func try_spend(n := 1.0) -> bool:
	if infinite():
		return true
	# Бережливость: шанс не потратить
	if randf() < Game.academy.mult("thrift"):
		return true
	var v := value()
	if v < n:
		return false
	_e()["value"] = v - n
	Game.changed.emit()
	return true


func add(n: float, toast := false) -> void:
	var v := value()
	_e()["value"] = minf(max_value() * OVERFLOW, v + n)
	if toast:
		Game.show_toast("px:bolt", L.t("energy.gained", [int(n)]))
	Game.mark_dirty()


## Сколько энергии ещё может дать еда сегодня.
func food_left() -> int:
	var e := _e()
	if int(e.get("food_day", -1)) != ShopSystem.day_index():
		return FOOD_PER_DAY
	return maxi(0, FOOD_PER_DAY - int(e.get("food", 0)))


## Энергия от блюда: в пределах дневного лимита и не выше запаса. Возвращает, сколько добавилось.
func add_food(n: int) -> int:
	var e := _e()
	var today := ShopSystem.day_index()
	if int(e.get("food_day", -1)) != today:
		e["food_day"] = today
		e["food"] = 0
	var v := value()
	var gain := mini(mini(n, food_left()), int(maxf(0.0, max_value() - v)))
	if gain <= 0:
		return 0
	e["food"] = int(e["food"]) + gain
	e["value"] = v + float(gain)
	Game.show_toast("px:bolt", L.t("energy.gained", [gain]))
	Game.mark_dirty()
	return gain


## Новый уровень: до полного запаса.
func refill() -> void:
	var v := value()
	if v < max_value():
		_e()["value"] = max_value()
		Game.mark_dirty()


func add_infinite(seconds: float) -> void:
	var e := _e()
	e["inf_until"] = maxf(float(e["inf_until"]), _now()) + seconds
	Game.show_toast("px:bolt", L.t("energy.infiniteOn", [int(round(seconds / 60.0))]))
	Game.mark_dirty()
	Game.save_now()


# MARK: Покупка и ролик

## Цена пакета за кристаллы: растёт с каждой покупкой за день, академия (скупщик) дешевле.
func buy_price() -> int:
	var e := _e()
	var bought := int(e["bought"]) if int(e["buy_day"]) == ShopSystem.day_index() else 0
	return maxi(1, int(round(float(BUY_BASE + BUY_STEP * bought) * Game.academy.mult("bargain"))))


func buy() -> bool:
	if not Game.shop.spend_crystals(buy_price()):
		return false
	var e := _e()
	var today := ShopSystem.day_index()
	if int(e["buy_day"]) != today:
		e["buy_day"] = today
		e["bought"] = 0
	e["bought"] = int(e["bought"]) + 1
	add(BUY_ENERGY, true)
	Game.save_now()
	return true


func infinite_price() -> int:
	return maxi(1, int(round(float(INFINITE_PRICE) * Game.academy.mult("bargain"))))


func buy_infinite() -> bool:
	if not Game.shop.spend_crystals(infinite_price()):
		return false
	add_infinite(INFINITE_MINUTES * 60.0)
	return true


func ads_left() -> int:
	var e := _e()
	if int(e["ad_day"]) != ShopSystem.day_index():
		return ADS_PER_DAY
	return maxi(0, ADS_PER_DAY - int(e["ads"]))


func ad_reward() -> void:
	if ads_left() <= 0:
		return
	var e := _e()
	var today := ShopSystem.day_index()
	if int(e["ad_day"]) != today:
		e["ad_day"] = today
		e["ads"] = 0
	e["ads"] = int(e["ads"]) + 1
	add(AD_ENERGY, true)
	Game.save_now()


## Энергия кончилась: надпись над героем и раз в минуту - окно, где её взять.
func out_of_energy(world: Node) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _hint_at < 3.0:
		return
	var first := now - _hint_at > 60.0
	_hint_at = now
	if world is World:
		var w: World = world
		Fx.text(w.fx, L.t("energy.out"), w.player.position - Vector2(0, 70), Color(1, 0.8, 0.3), 15)
	Sound.play("error")
	if first:
		EnergyPopup.open()


func on_event(name: String, data: Dictionary) -> void:
	match name:
		"story":
			add(100)
		"raid":
			if bool(data.get("win", false)):
				add(100)
