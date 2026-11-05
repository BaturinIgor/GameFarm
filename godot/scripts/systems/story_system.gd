class_name StorySystem
extends RefCounted
## Сюжет «Сердца земли», Осколки Древних и Алтарь (данные - data/story.gd).
## В Game.save: heart = {ch: текущая глава (= разбуженных Сердец), pages, pity, gift, kills}, shards, altar.


func defaults(save: Dictionary) -> void:
	var raw: Dictionary = save.get("heart", {}) if save.get("heart") is Dictionary else {}
	save["heart"] = {
		"ch": clampi(int(raw.get("ch", 0)), 0, Story.count()),
		"pages": clampi(int(raw.get("pages", 0)), 0, Story.PAGES),
		"pity": maxi(0, int(raw.get("pity", 0))),
		"gift": bool(raw.get("gift", false)),
		"kills": maxi(0, int(raw.get("kills", 0))),
	}
	save["shards"] = maxi(0, int(save.get("shards", 0)))
	save["altar"] = clampi(int(save.get("altar", 0)), 0, Story.ALTAR.size())


func _h() -> Dictionary:
	return Game.save["heart"]


# MARK: Главы

func chapter() -> int:
	return int(_h()["ch"])


func hearts() -> int:
	return chapter()


func finished() -> bool:
	return chapter() >= Story.count()


## Глава доступна: раздел открыт по уровню и её локация открыта.
func chapter_open() -> bool:
	return not finished() and Game.level >= Story.MIN_LEVEL and Game.world_map.is_unlocked(Story.loc(chapter()))


func pages() -> int:
	return int(_h()["pages"])


## Все прочитанные страницы: полные главы и текущая.
func pages_total() -> int:
	return chapter() * Story.PAGES + (0 if finished() else pages())


func gift_given() -> bool:
	return bool(_h()["gift"])


func kills() -> int:
	return int(_h()["kills"])


func can_give_gift() -> bool:
	return chapter_open() and not gift_given() and Game.can_afford(Story.gift(chapter()))


func give_gift() -> bool:
	if not can_give_gift():
		return false
	Game.pay(Story.gift(chapter()))
	_h()["gift"] = true
	Sound.play("success")
	_changed()
	return true


func can_awaken() -> bool:
	return chapter_open() and pages() >= Story.PAGES and gift_given() and kills() >= Story.kills(chapter())


## Разбудить Сердце: осколки, ключ, следующая глава. Возвращает {shards, key} или {}.
func awaken_heart() -> Dictionary:
	if not can_awaken():
		return {}
	var ch := chapter()
	var out := {"shards": Story.shards_for(ch), "key": Story.key_for(ch), "ch": ch}
	add_shards(int(out["shards"]), false)
	Game.chests.add_keys(str(out["key"]), 1, false)
	Game.save["heart"] = {"ch": ch + 1, "pages": 0, "pity": 0, "gift": false, "kills": 0}
	Sound.play("levelUp")
	Game.emit_event("heart", {"ch": ch})
	Game.recalc()
	_changed()
	return out


## Отметка: можно отдать дар или разбудить Сердце.
func ready_count() -> int:
	return 1 if can_awaken() or can_give_gift() else 0


# MARK: Осколки

func shards() -> int:
	return int(Game.save.get("shards", 0))


func add_shards(n: int, toast := true) -> void:
	if n <= 0:
		return
	Game.save["shards"] = shards() + n
	if toast:
		Game.show_toast("shard", L.t("shard.got", [n]))
		Sound.play("treasure")
	Game.mark_dirty()


func spend_shards(n: int) -> bool:
	if shards() < n:
		return false
	Game.save["shards"] = shards() - n
	Game.mark_dirty()
	return true


# MARK: Алтарь Древних

func altar() -> int:
	return int(Game.save.get("altar", 0))


func altar_price() -> int:
	return int(Story.ALTAR_COST[altar()]) if altar() < Story.ALTAR.size() else 0


func can_raise_altar() -> bool:
	return altar() < Story.ALTAR.size() and shards() >= altar_price()


func raise_altar() -> bool:
	if not can_raise_altar():
		return false
	spend_shards(altar_price())
	Game.save["altar"] = altar() + 1
	Sound.play("levelUp")
	Game.recalc()
	_changed()
	return true


func _changed() -> void:
	Game.save_now()
	Game.changed.emit()


# MARK: События

func on_event(name: String, data: Dictionary) -> void:
	match name:
		"gather":
			if randf() < Story.SHARD_CHANCE:
				add_shards(1)
			if chapter_open() and Game.current == Story.loc(chapter()) and pages() < Story.PAGES:
				_h()["pity"] = int(_h()["pity"]) + 1
				if randf() < Story.PAGE_CHANCE or int(_h()["pity"]) >= Story.PAGE_PITY:
					_h()["pity"] = 0
					_h()["pages"] = pages() + 1
					Game.show_toast("px:book", L.t("heart.pageFound", [pages(), Story.PAGES]))
					Sound.play("pickup")
					Game.mark_dirty()
					Game.changed.emit()
		"kill":
			if chapter_open() and Game.current == Story.loc(chapter()) and kills() < Story.kills(chapter()):
				_h()["kills"] = kills() + 1
				Game.mark_dirty()
		"mine":
			var f := int(data.get("floor", 0))
			if f > 0 and f % Story.MINE_SHARD_EVERY == 0:
				add_shards(1)
