class_name GuideSystem
extends RefCounted
## Обучение: шаги новичка (Guide.STEPS) идут по событиям игры, за каждый - монеты, за все - кристаллы.
## Знакомство с разделом показывается один раз при первом открытии (Nav.open_sub).


func defaults(save: Dictionary) -> void:
	# Старые сохранения (уже прокачанные) обучение не проходят
	if not save.has("guideStep"):
		var veteran := int(save.get("level", 1)) >= Guide.SKIP_LEVEL or int(save.get("bestLevel", 1)) >= Guide.SKIP_LEVEL
		save["guideStep"] = Guide.STEPS.size() if veteran else 0
		save["guideCount"] = 0
	save["guideStep"] = clampi(int(save["guideStep"]), 0, Guide.STEPS.size())
	save["guideCount"] = maxi(0, int(save.get("guideCount", 0)))
	var seen: Variant = save.get("introSeen", [])
	save["introSeen"] = (seen as Array).filter(func(x: Variant) -> bool: return x is String) if seen is Array else []


func active() -> bool:
	return index() < Guide.STEPS.size()


func index() -> int:
	return int(Game.save.get("guideStep", Guide.STEPS.size()))


func progress() -> int:
	return int(Game.save.get("guideCount", 0))


func current() -> Dictionary:
	return Guide.step(index())


func on_event(name: String, data: Dictionary) -> void:
	if not active():
		return
	var s := current()
	if name != str(s["event"]):
		return
	if s.has("kind") and str(data.get("kind", "")) != str(s["kind"]):
		return
	var add := maxi(1, int(data.get("amount", 1))) if name == "gather" else 1
	Game.save["guideCount"] = progress() + add
	if progress() >= int(s["target"]):
		_complete(s)
	Game.mark_dirty()
	Game.changed.emit()


func _complete(s: Dictionary) -> void:
	Game.add_coins(int(s.get("coins", 0)))
	Game.save["guideStep"] = index() + 1
	Game.save["guideCount"] = 0
	Sound.play("levelUp")
	if active():
		Game.show_toast("px:star", L.t("guide.done", [Fmt.n(int(s.get("coins", 0)))]))
	else:
		Game.shop.add_crystals(Guide.FINAL_CRYSTALS)
		Game.show_toast("px:gem", L.t("guide.finished", [Guide.FINAL_CRYSTALS]))


## Отметка на разделе, куда идти за текущим шагом.
func badge(sub: String) -> int:
	return 1 if active() and str(current().get("sub", "")) == sub and sub != "" else 0


func skip() -> void:
	Game.save["guideStep"] = Guide.STEPS.size()
	Game.mark_dirty()
	Game.changed.emit()


# MARK: Знакомство с разделами

func should_intro(sub: String) -> bool:
	return Guide.INTROS.has(sub) and not sub in Game.save.get("introSeen", [])


func mark_intro(sub: String) -> void:
	if not sub in Game.save["introSeen"]:
		Game.save["introSeen"].append(sub)
		Game.mark_dirty()
