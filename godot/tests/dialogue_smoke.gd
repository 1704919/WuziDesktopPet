  1 | extends SceneTree
  2 | 
  3 | const Guard = preload("res://scripts/input_guard.gd")
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
 14 | func _init() -> void:
 15 | 	var chat := Dialogue.new()
 16 | 	chat.load_config()
 17 | 	check(Guard.check("🙂".repeat(50), 50).ok, "50 emoji accepted")
 18 | 	check(not Guard.check("🙂".repeat(51), 50).ok, "51 emoji rejected")
 19 | 	check(Guard.check("你".repeat(50), 50).ok, "50 Chinese accepted")
 20 | 	check(not Guard.check("a".repeat(51), 50).ok, "51 ASCII rejected")
 21 | 	check(not Guard.check("a".repeat(100000), 50).ok, "oversized backend input bounded")
 22 | 	check(Guard.check("　".repeat(10000), 50).error == "empty", "oversized whitespace remains empty")
 23 | 	check(Guard.check("e\u0301", 50).text.length() == 2, "combining mark code points")
 24 | 	check(Guard.check("👩‍💻", 50).text.length() == 3, "joined emoji code points")
 25 | 	check(not Guard.check("\t\r\n　\u00a0", 50).ok, "unicode whitespace empty")
 26 | 	check(Guard.check(" 你好\r\n\t世界　", 50).text == "你好 世界", "whitespace normalized")
 27 | 	check(not Guard.check(" " + "a".repeat(50), 50).ok, "raw limit cannot bypass with spaces")
 28 | 	var cases := {"你好": "greeting", "你好可爱": "praise", "你好漂亮": "praise", "我喜欢你": "praise", "晚安": "sleep", "不要睡觉": "negated", "我不喜欢你": "negated", "不太可爱": "negated", "我累了": "tired", "无聊": "bored", "摸摸": "touch", "唱歌": "sing", "摸鱼": "slack", "帮我改名，你好可爱": "file_help"}
 29 | 	var stage4_fields := {
 30 | 		"praise": ["click_shy_video", "praise"],
 31 | 		"touch": ["click_happy_video", "touch"],
 32 | 		"sleep": ["sleep_down", "sleepy"],
 33 | 		"tired": ["yawn_video", "sleepy"],
 34 | 		"sing": ["sing", ""]
 35 | 	}
 36 | 	for message in cases:
 37 | 		var result := chat.submit_message(message, "", 0)
 38 | 		var intent := str(cases[message])
 39 | 		check(result.intent == intent, "intent: " + message)
 40 | 		if stage4_fields.has(intent):
 41 | 			var expected := stage4_fields[intent] as Array
 42 | 			check(result.action_request == expected[0], "stage four action: " + message)
 43 | 			check(result.mood_event == expected[1], "stage four mood: " + message)
 44 | 		elif intent in ["slack", "bored"]:
 45 | 			var possible := ["lie_phone", "read_book"] if intent == "slack" else ["game_controller", "read_book"]
 46 | 			check(possible.has(str(result.action_request)), "lifestyle action link: " + message)
 47 | 			check(str(result.mood_event).is_empty(), "lifestyle no mood change: " + message)
 48 | 		else:
 49 | 			check(result.action_request.is_empty() and result.mood_event.is_empty(), "no stage four side effect: " + message)
 50 | 	var eat_link := chat.submit_message("我饿了")
 51 | 	check(str(eat_link.action_request) in ["eat_noodles", "eat_fries", "eat_sushi", "eat_fried_chicken"],
 52 | 		"eating action link")
 53 | 	var mood_query := chat.submit_message("心情怎么样")
 54 | 	check(mood_query.intent == "mood_query" and mood_query.action_request.is_empty(), "mood intent safe")
 55 | 	for mood_key in ["normal", "happy", "shy", "angry", "sleepy"]:
 56 | 		check(not chat.mood_reply(mood_key).is_empty(), "mood response: " + mood_key)
 57 | 	for event_key in ["file_success", "file_failure", "file_preview", "file_duplicate", "drag_start", "drag_end", "click_spam"]:
 58 | 		check(not chat.event_reply(event_key).is_empty(), "event response: " + event_key)
 59 | 	check(chat.event_reply("file_preview") == "先看看预览，确认没问题再动手。", "preview exact text")
 60 | 	check(chat.event_reply("file_preview") == "先看看预览，确认没问题再动手。", "single line stays stable")
 61 | 	check(chat.event_reply("drag_start") == "哇，要带我去哪里？", "drag start exact text")
 62 | 	var egg_29 := chat.submit_message("29")
 63 | 	check(egg_29.text == "29？我还以为92呢" and egg_29.intent == "easter_egg", "29 easter egg")
 64 | 	var egg_92 := chat.submit_message("92")
 65 | 	check(egg_92.text == "92？我还以为29呢" and egg_92.intent == "easter_egg", "92 reverse easter egg")
 66 | 	check(chat.submit_message("你特别可爱").intent == "praise", "special is not a negation")
 67 | 	check(chat.submit_message("你不是很可爱").intent == "negated", "simple negative qualifier")
 68 | 	check(chat.submit_message("🙂 [img] {nickname} 👩‍💻").accepted, "special characters safe")
 69 | 	chat.submit_message("你吃饭了吗？", "", 1000)
 70 | 	var before := chat.recent_topics.duplicate(true)
 71 | 	check(not chat.submit_message("x".repeat(51), "", 2000).accepted, "backend overlong rejected")
 72 | 	check(not chat.submit_message("  ", "", 2000).accepted, "backend empty rejected")
 73 | 	check(chat.recent_topics == before, "invalid input preserves context")
 74 | 	var follow := chat.submit_message("那去吃吧", "", 3000)
 75 | 	check(follow.intent == "eat" and follow.used_context, "eating continuation")
 76 | 	chat.submit_message("你吃饭了吗", "", 4000)
 77 | 	check(chat.submit_message("那去吧", "", 124000).intent == "fallback", "context expires at 120 seconds")
 78 | 	chat.submit_message("吃饭了吗", "", 200000)
 79 | 	chat.submit_message("晚安", "", 201000)
 80 | 	check(chat.submit_message("那去吧", "", 202000).topic == "sleep", "latest topic wins")
 81 | 	chat.submit_message("你吃饭了吗", "", 203000)
 82 | 	chat.submit_message("宇宙飞船", "", 204000)
 83 | 	check(chat.submit_message("那去吧", "", 205000).intent == "fallback", "unknown topic clears context")
 84 | 	for index in range(10):
 85 | 		chat.submit_message("早安", "", 300000 + index)
 86 | 	check(chat.recent_topics.size() == 3, "only three rounds retained")
 87 | 	check(Dialogue.new().recent_topics.is_empty(), "no cross-session context")
 88 | 	chat.responses.rng.seed = 29
 89 | 	var last := ""
 90 | 	for index in range(200):
 91 | 		var text: String = chat.submit_message("你好可爱").text
 92 | 		check(text != last, "no adjacent repeated response")
 93 | 		check(not text.contains("{nickname}"), "no nickname placeholder")
 94 | 		last = text
 95 | 	chat.responses.rng.seed = 92
 96 | 	var named_count := 0
 97 | 	for index in range(2000):
 98 | 		var text: String = chat.submit_message("你好", "小水").text
 99 | 		if text.contains("小水"):
			named_count += 1
		check(text != last, "no named response repeat")
		last = text
	check(named_count >= 300 and named_count <= 500, "nickname near 20 percent: %d" % named_count)
	for bad_name in [null, 29, [], {}, "长".repeat(13)]:
		check(not chat.submit_message("你好", bad_name).text.contains("{nickname}"), "bad nickname falls back")
	for raw in [null, [], 42, {"rules": "bad"}, {"rules": [null, {}, {"id": 12, "topic": []}]}]:
		chat.configure(raw)
		check(chat.submit_message("你好").intent == "fallback", "bad config falls back")
	chat.configure({"rules": [{"id": "test", "topic": "test", "exact": [null, "测试"], "keywords": 29, "responses": [null, "{unknown}", "正常。"], "nickname_responses": [12, "{other}"]}]})
	check(chat.submit_message("测试").text == "正常。", "malformed fields safely filtered")
	chat.load_config("res://missing-dialogue.json")
	check(not chat.submit_message("你好").text.is_empty(), "missing config fallback")
	var broken := FileAccess.open("user://stage2_broken_dialogue.json", FileAccess.WRITE)
	broken.store_string("{ not json")
	broken.close()
	chat.load_config("user://stage2_broken_dialogue.json")
	check(chat.submit_message("你好").intent == "fallback", "invalid JSON fallback")
	if failures.is_empty():
		print("DIALOGUE_SMOKE_OK nickname_count=", named_count, "/2000")
		quit(0)
	else:
		push_error("DIALOGUE_SMOKE_FAILED: " + ", ".join(failures))
		quit(2)
