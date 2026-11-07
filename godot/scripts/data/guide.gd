class_name Guide
## Обучение: первые шаги новичка (по событиям игры) и знакомство с разделами при первом открытии.

## Шаги новичка по порядку: событие игры, сколько нужно, значок, раздел, где это делается (для отметки
## на нижней панели, "" - в мире), и награда в монетах. За последний шаг ещё кристаллы.
const STEPS := [
	{"id": "wood", "event": "gather", "kind": "wood", "target": 5, "icon": "wood", "sub": "", "coins": 50},
	{"id": "deposit", "event": "deposit", "target": 1, "icon": "chest", "sub": "", "coins": 50},
	{"id": "plant", "event": "plant", "target": 1, "icon": "sprout", "sub": "", "coins": 60},
	{"id": "crop", "event": "crop", "target": 1, "icon": "wheat", "sub": "", "coins": 60},
	{"id": "sell", "event": "sell", "target": 1, "icon": "coins", "sub": "storage", "coins": 80},
	{"id": "quest", "event": "quest", "target": 1, "icon": "scroll", "sub": "quests", "coins": 100},
	{"id": "upgrade", "event": "upgrade", "target": 1, "icon": "hammer", "sub": "workshop", "coins": 120},
	{"id": "tame", "event": "tame", "target": 1, "icon": "paw", "sub": "animals", "coins": 150},
]
const FINAL_CRYSTALS := 20
## Старые сохранения с таким уровнем обучение пропускают.
const SKIP_LEVEL := 4

## Знакомство с разделом при первом открытии: значок и сколько слайдов (тексты intro.<раздел>.title и .1, .2...).
const INTROS := {
	"alliance": {"icon": "crown", "slides": 3},
	"mine": {"icon": "stairs", "slides": 2},
	"events": {"icon": "flame", "slides": 2},
	"incubator": {"icon": "egg", "slides": 2},
	"heart": {"icon": "heart", "slides": 2},
	"wild": {"icon": "paw", "slides": 2},
	"estate": {"icon": "hammer", "slides": 2},
	"hunt": {"icon": "sword", "slides": 2},
	"talents": {"icon": "star", "slides": 2},
}
## Значки слайдов (второй и дальше), чтобы слайды не были одинаковыми.
const SLIDE_ICONS := {
	"alliance": ["crown", "swords", "phoenixChick"],
	"mine": ["stairs", "gem"],
	"events": ["flame", "trophy"],
	"incubator": ["egg", "paw"],
	"heart": ["heart", "star"],
	"wild": ["paw", "compass"],
	"estate": ["hammer", "coins"],
	"hunt": ["sword", "scroll"],
	"talents": ["star", "book"],
}


static func step(i: int) -> Dictionary:
	return STEPS[i] if i >= 0 and i < STEPS.size() else {}


static func step_text(i: int) -> String:
	var s := step(i)
	return L.t("guide." + str(s.get("id", "")), [int(s.get("target", 1))]) if not s.is_empty() else ""


static func step_hint(i: int) -> String:
	var s := step(i)
	return L.t("guide." + str(s.get("id", "")) + ".hint") if not s.is_empty() else ""
