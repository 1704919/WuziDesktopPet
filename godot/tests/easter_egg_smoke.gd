extends SceneTree

const EasterEgg = preload("res://scripts/easter_egg_manager.gd")
const Dialogue = preload("res://scripts/dialogue_manager.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func check_map(parser: RefCounted, input: String, expected_original: String, expected_mapped: String, label: String) -> void:
	var result: Dictionary = parser.match_first(input)
	check(bool(result.get("matched", false)), label + " matched")
	check(str(result.get("original", "")) == expected_original, label + " original")
	check(str(result.get("mapped", "")) == expected_mapped, label + " mapped")


func check_miss(parser: RefCounted, input: String, label: String) -> void:
	var result: Dictionary = parser.match_first(input)
	check(not bool(result.get("matched", false)), label)


func _init() -> void:
	var parser := EasterEgg.new()

	var named_cases := [
		[
			"生日",
			"birthday",
			"今天是我生日！礼物呢？",
			"birthday_cake",
			"happy"
		],
		[
			"庄园",
			"manor",
			"梓友庄园施工中，给你留了门口的位置。",
			"",
			""
		],
		[
			"阿梓",
			"azi",
			"生疏了，你竟然不愿叫我一声梓神。",
			"click_angry_video",
			"angry"
		],
		[
			"梓神",
			"zishen",
			"喊这么大声干嘛，梓神也会害羞的。",
			"click_shy_video",
			"praise"
		],
		[
			"五杀",
			"penta_kill",
			"你赖姐牛不牛",
			"",
			"happy"
		]
	]
	for named_case in named_cases:
		var named := parser.match_first(named_case[0])
		check(bool(named.get("matched", false)), "named matched " + named_case[0])
		check(str(named.get("id", "")) == named_case[1], "named id " + named_case[0])
		check(parser.format_reply(named) == named_case[2], "named reply " + named_case[0])
		check(str(named.get("action_request", "")) == named_case[3], "named action " + named_case[0])
		check(str(named.get("mood_event", "")) == named_case[4], "named mood " + named_case[0])
	check_miss(parser, "今天生日快乐", "named eggs require exact input")

	var birthday_auto := parser.auto_birthday_event(
		{"year": 2026, "month": 12, "day": 20},
		2025
	)
	check(bool(birthday_auto.get("matched", false)), "birthday auto on date")
	check(
		not bool(parser.auto_birthday_event(
			{"year": 2026, "month": 12, "day": 20},
			2026
		).get("matched", false)),
		"birthday auto once per year"
	)
	check(
		not bool(parser.auto_birthday_event(
			{"year": 2026, "month": 12, "day": 19},
			2025
		).get("matched", false)),
		"birthday auto only on december 20"
	)

	for pair in [
		["29", "29", "92"],
		["92", "92", "29"],
		["290", "290", "920"],
		["920", "920", "290"],
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
