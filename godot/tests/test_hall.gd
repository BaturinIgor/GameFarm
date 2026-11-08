extends "res://tests/test_case.gd"
## Ратуша и живой чат: правила, подарки, помощь со стройкой (демо без сервера).


func test_rules() -> void:
	eq(Hall.goal(1), 10, "цель не меньше 10")
	eq(Hall.goal(20), 60)
	eq(Hall.goal(100), 150, "цель не больше 150")
	eq(Hall.gift_tier("step1"), 1)
	eq(Hall.gift_tier("crystals2"), 2)
	eq(Hall.gift_tier("crystals4"), 3)
	check(Hall.is_sticker("::heart"))
	check(not Hall.is_sticker("::bogus"), "только стикеры из списка")
	check(not Hall.is_sticker("heart"))


func test_demo_help_and_gifts() -> void:
	fresh({"level": 20})
	var al := Game.alliance
	al.demo = true
	# Запрос из прошлого теста мог не вернуться (нет сети) - начинаем с чистого листа
	al.busy = false
	al.hall = {"help": [{"id": 1, "name": "Masha", "target": "barn", "got": 2, "need": 10, "me": false, "helped": false}],
		"helps_today": 0, "gifts": [{"id": 5, "name": "Masha", "product": "starter"}],
		"goal": {"done": 12, "need": 12, "mine": 1, "claimed": false}, "praise": {"given": null, "week": {}}}
	eq(al.help_open_count(), 1)
	var coins := int(Game.save["coins"])
	await al.give_help(1)
	eq(al.help_open_count(), 0, "дважды не помочь")
	eq(int(Game.save["coins"]) - coins, Hall.help_coins(Game.level), "монеты помощнику")
	check(al.can_claim_goal())
	await al.claim_goal()
	check(not al.can_claim_goal(), "награда цели один раз")
	await al.claim_gift(5)
	eq(al.gifts().size(), 0)
	await al.praise("b")
	eq(al.praised_today(), "b")
	eq(al.praise_count("b"), 1)
	al.reacts = {}
	al.my_reacts = {}
	await al.react(7, "heart")
	eq(al.reacts[7]["heart"], 1)
	await al.react(7, "heart")
	eq(al.reacts[7]["heart"], 0, "та же реакция снимает")
	al.demo = false
	al.hall = {}
