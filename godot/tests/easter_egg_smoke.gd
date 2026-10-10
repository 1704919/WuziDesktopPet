  1 | extends SceneTree
  2 | 
  3 | const EasterEgg = preload("res://scripts/easter_egg_manager.gd")
  4 | const Dialogue = preload("res://scripts/dialogue_manager.gd")
  5 | 
  6 | var failures: Array[String] = []
  7 | 
  8 | 
  9 | func check(condition: bool, label: String) -> void:
 10 | 	if not condition:
 11 | 		failures.append(label)
 12 | 
 13 | 
 14 | func check_map(parser: RefCounted, input: String, expected_original: String, expected_mapped: String, label: String) -> void:
 15 | 	var result: Dictionary = parser.match_first(input)
 16 | 	check(bool(result.get("matched", false)), label + " matched")
 17 | 	check(str(result.get("original", "")) == expected_original, label + " original")
 18 | 	check(str(result.get("mapped", "")) == expected_mapped, label + " mapped")
 19 | 
 20 | 
 21 | func check_miss(parser: RefCounted, input: String, label: String) -> void:
 22 | 	var result: Dictionary = parser.match_first(input)
 23 | 	check(not bool(result.get("matched", false)), label)
 24 | 
 25 | 
 26 | func _init() -> void:
 27 | 	var parser := EasterEgg.new()
 28 | 
 29 | 	var named_cases := [
 30 | 		[
 31 | 			"生日",
 32 | 			"birthday",
 33 | 			"今天是我生日！礼物呢？",
 34 | 			"birthday_cake",
 35 | 			"happy"
 36 | 		],
 37 | 		[
 38 | 			"庄园",
 39 | 			"manor",
 40 | 			"梓友庄园施工中，给你留了门口的位置。",
 41 | 			"",
 42 | 			""
 43 | 		],
 44 | 		[
 45 | 			"阿梓",
 46 | 			"azi",
 47 | 			"生疏了，你竟然不愿叫我一声梓神。",
 48 | 			"click_angry_video",
 49 | 			"angry"
 50 | 		],
 51 | 		[
 52 | 			"梓神",
 53 | 			"zishen",
 54 | 			"喊这么大声干嘛，梓神也会害羞的。",
 55 | 			"click_shy_video",
 56 | 			"praise"
 57 | 		],
 58 | 		[
 59 | 			"五杀",
 60 | 			"penta_kill",
 61 | 			"你赖姐牛不牛",
 62 | 			"",
 63 | 			"happy"
 64 | 		]
 65 | 	]
 66 | 	for named_case in named_cases:
 67 | 		var named := parser.match_first(named_case[0])
 68 | 		check(bool(named.get("matched", false)), "named matched " + named_case[0])
 69 | 		check(str(named.get("id", "")) == named_case[1], "named id " + named_case[0])
 70 | 		check(parser.format_reply(named) == named_case[2], "named reply " + named_case[0])
 71 | 		check(str(named.get("action_request", "")) == named_case[3], "named action " + named_case[0])
 72 | 		check(str(named.get("mood_event", "")) == named_case[4], "named mood " + named_case[0])
 73 | 	check_miss(parser, "今天生日快乐", "named eggs require exact input")
 74 | 
 75 | 	var birthday_auto := parser.auto_birthday_event(
 76 | 		{"year": 2026, "month": 12, "day": 20},
 77 | 		2025
 78 | 	)
 79 | 	check(bool(birthday_auto.get("matched", false)), "birthday auto on date")
 80 | 	check(
 81 | 		not bool(parser.auto_birthday_event(
 82 | 			{"year": 2026, "month": 12, "day": 20},
 83 | 			2026
 84 | 		).get("matched", false)),
 85 | 		"birthday auto once per year"
 86 | 	)
 87 | 	check(
 88 | 		not bool(parser.auto_birthday_event(
 89 | 			{"year": 2026, "month": 12, "day": 19},
 90 | 			2025
 91 | 		).get("matched", false)),
 92 | 		"birthday auto only on december 20"
 93 | 	)
 94 | 
 95 | 	for pair in [
 96 | 		["29", "29", "92"],
 97 | 		["92", "92", "29"],
 98 | 		["290", "290", "920"],
 99 | 		["920", "920", "290"],
		["29000", "29000", "92000"],
		["92000", "92000", "29000"],
		["编号29000结束", "29000", "92000"],
	]:
		check_map(parser, pair[0], pair[1], pair[2], "arabic " + pair[0])

	for pair in [
		["二十九", "二十九", "九十二"],
		["九十二", "九十二", "二十九"],
		["二百九", "二百九", "九百二"],
		["九百二", "九百二", "二百九"],
		["二千九", "二千九", "九千二"],
		["九千二", "九千二", "二千九"],
		["二万九", "二万九", "九万二"],
		["九万二", "九万二", "二万九"],
		["二十九万", "二十九万", "九十二万"],
		["九十二万", "九十二万", "二十九万"],
		["二百九十", "二百九十", "九百二十"],
		["九百二十", "九百二十", "二百九十"],
		["大概二十九兆吧", "二十九兆", "九十二兆"],
	]:
		check_map(parser, pair[0], pair[1], pair[2], "chinese " + pair[0])

	check_map(parser, "先92再29", "92", "29", "first valid arabic")
	check_map(parser, "先一百二十九，再二十九", "二十九", "九十二", "skip invalid then match")
	check_map(parser, "129和29", "29", "92", "complete numeric token")
	check_map(parser, "一百二十九和九十二", "九十二", "二十九", "complete Chinese token")

	for pair in [
		["129", "embedded arabic rejected"],
		["292", "non-tail-zero arabic rejected"],
		["029", "leading zero arabic rejected"],
		["一百二十九", "129 Chinese rejected"],
		["二百零九", "209 Chinese rejected"],
		["九百零二", "902 Chinese rejected"],
		["二九", "unitless consecutive Chinese rejected"],
		["十百二十九", "malformed Chinese rejected"],
		["29000000000000000000000000000000000000000", "41 digit token rejected"],
		["二百九".repeat(7), "overlong Chinese token rejected"],
	]:
		check_miss(parser, pair[0], pair[1])

	var chat := Dialogue.new()
	chat.load_config()
	chat.submit_message("你吃饭了吗", "", 1000)
	var before := chat.recent_topics.duplicate(true)
	var egg := chat.submit_message("我说二万九", "", 2000)
	check(egg.intent == "easter_egg", "dialogue integration intent")
	check(egg.text == "二万九？我还以为九万二呢", "dialogue integration reply")
	check(egg.easter_egg.original == "二万九" and egg.easter_egg.mapped == "九万二", "dialogue metadata")
	check(chat.recent_topics.is_empty(), "easter egg clears dialogue context")
	check(before.size() == 1, "context existed before easter egg")
	check(egg.action_request.is_empty() and egg.mood_event.is_empty(), "stage four fields remain inert")

	var birthday := chat.submit_message("生日", "", 2100)
	check(birthday.text == "今天是我生日！礼物呢？", "birthday dialogue reply")
	check(birthday.action_request == "birthday_cake", "birthday dialogue action")
	check(birthday.mood_event == "happy", "birthday dialogue mood")

	var manor := chat.submit_message("庄园", "", 2200)
	check(manor.text == "梓友庄园施工中，给你留了门口的位置。", "manor dialogue reply")

	var azi := chat.submit_message("阿梓", "", 2300)
	check(azi.text == "生疏了，你竟然不愿叫我一声梓神。", "azi dialogue reply")
	check(azi.action_request == "click_angry_video", "azi dialogue action")
	check(azi.mood_event == "angry", "azi dialogue mood")

	var zishen := chat.submit_message("梓神", "", 2400)
	check(zishen.text == "喊这么大声干嘛，梓神也会害羞的。", "zishen dialogue reply")
	check(zishen.action_request == "click_shy_video", "zishen dialogue action")
	check(zishen.mood_event == "praise", "zishen dialogue mood")

	var penta := chat.submit_message("五杀", "", 2500)
	check(penta.text == "你赖姐牛不牛", "penta dialogue reply")
	check(penta.mood_event == "happy", "penta dialogue mood")

	var auto_dialogue := chat.birthday_auto_event(
		{"year": 2026, "month": 12, "day": 20},
		2025
	)
	check(auto_dialogue.text == "今天是我生日！礼物呢？", "birthday auto dialogue reply")
	check(
		chat.birthday_auto_event(
			{"year": 2026, "month": 12, "day": 20},
			2026
		).is_empty(),
		"birthday auto dialogue once per year"
	)

	if failures.is_empty():
		print("EASTER_EGG_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
