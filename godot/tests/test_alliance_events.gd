extends "res://tests/test_case.gd"
## События альянса: числа совпадают с сервером (docs/supabase/alliance_events.sql), награды, счётчики заданий.


func test_tasks_match_server() -> void:
	# _al_task_kinds(2966) = treasure, produce, cook (проверено на локальной базе)
	eq(AllianceEvents.task_kinds(2966), ["treasure", "produce", "cook"])
	for wk in range(2900, 2960):
		var k := AllianceEvents.task_kinds(wk)
		check(k[0] != k[1] and k[1] != k[2] and k[0] != k[2], "задания недели %d разные" % wk)
	eq(AllianceEvents.task_target("cook", 2), 62, "как _al_task_target: участников не меньше 5")
	eq(AllianceEvents.task_target("treasure", 2), 37)
	eq(AllianceEvents.task_target("kill", 40), 2400)
	for k in AllianceEvents.KINDS:
		check(AllianceEvents.SHARE.has(k) and AllianceEvents.KIND_ICON.has(k), "у задания %s есть доля и значок" % k)
		check(L.t("alliance.task." + k) != "alliance.task." + k, "есть название задания %s" % k)


func test_boss() -> void:
	eq(AllianceEvents.boss_hp(1, 2), 2000, "как _al_boss_hp")
	var prev := 0
	for t in range(1, 12):
		var hp := AllianceEvents.boss_hp(t, 25)
		check(hp > prev, "страж ступени %d сильнее прошлой" % t)
		prev = hp
		check(Monsters.KINDS.has(AllianceEvents.boss_kind(t)), "страж %d - настоящий монстр" % t)
	eq(AllianceEvents.hit_damage(30, 0, 0), 300)
	eq(AllianceEvents.hit_damage(30, 1200000, 0), 420, "мощь: +1 за каждые 10 000")
	eq(AllianceEvents.hit_damage(30, 0, 10), 360, "талант «Натиск»: +2% за ранг")
	var r := AllianceEvents.with_bounty({"crystals": 10, "coins": 100, "key": "copper"}, 0.3)
	eq(r["crystals"], 13, "«Трофеи» увеличивают награду")
	eq(r["key"], "copper")


func test_rewards() -> void:
	var prev := 1000000
	for p in [1, 2, 3, 4, 10, 11, 50, 51, 200, 201, 5000]:
		var r := AllianceEvents.place_reward(p, 20)
		check(int(r["crystals"]) <= prev, "место %d не лучше места выше" % p)
		prev = int(r["crystals"])
	eq(AllianceEvents.place_reward(1, 20)["key"], "star")
	eq(AllianceEvents.boss_reward(1, 20)["key"], "copper")
	eq(AllianceEvents.boss_reward(20, 20)["crystals"], 30, "кристаллы за стража не больше 30")


func test_claimable_and_counts() -> void:
	var al := Game.alliance
	var save_al: Variant = Game.save.get("alliance", {})
	var save_ev := al.ev
	Game.save["alliance"] = {"id": 7, "name": "T", "tag": "T", "emblem": 0, "talents": {}}
	al.demo = true
	al.ev = {"hits": 1, "extra": 0, "unclaimed": [1, 2], "last_place": 3, "last_claimed": false,
		"tasks": [{"kind": "kill", "target": 10, "progress": 10, "mine": 12, "share": 120, "claimed": false},
			{"kind": "cook", "target": 10, "progress": 10, "mine": 1, "share": 25, "claimed": false},
			{"kind": "order", "target": 10, "progress": 3, "mine": 3, "share": 20, "claimed": false}]}
	eq(al.hits_left(), 2)
	eq(al.claimable().size(), 4, "2 стража, задание с вкладом от 1/10 доли и место")
	eq(al.events_count(), 6)
	# Счётчики копятся в сохранении (в демо не уходят на сервер)
	Game.save["alliancePending"] = {}
	al.on_event("kill", {})
	al.on_event("produce", {"amount": 5})
	al.on_event("plant", {})
	eq(Game.save["alliancePending"], {"kill": 1, "produce": 5})
	al.demo = false
	al.ev = save_ev
	Game.save["alliance"] = save_al
	Game.save["alliancePending"] = {}
