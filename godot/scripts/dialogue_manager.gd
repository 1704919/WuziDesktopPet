  1 | extends RefCounted
  2 | 
  3 | const InputGuard = preload("res://scripts/input_guard.gd")
  4 | const ResponseManager = preload("res://scripts/response_manager.gd")
  5 | const EasterEggManager = preload("res://scripts/easter_egg_manager.gd")
  6 | const CONTEXT_TTL_MS := 120000
  7 | const CONTEXT_LIMIT := 3
  8 | const NEGATIVE_PREFIXES := ["不", "别", "没", "不要", "不想", "不能", "没有", "不是", "不太", "并不", "别再", "不要再", "不是很", "不怎么", "不够", "不算", "不再"]
  9 | 
 10 | var responses := ResponseManager.new()
 11 | var easter_eggs := EasterEggManager.new()
 12 | var rules: Array[Dictionary] = []
 13 | # Only topic + timestamp, never the user's messages; session-local, no disk writes.
 14 | var recent_topics: Array[Dictionary] = []
 15 | var fallback: Dictionary = {}
 16 | var negated: Dictionary = {}
 17 | var event_feedback: Dictionary = {}
 18 | var mood_state_responses: Dictionary = {}
 19 | 
 20 | 
 21 | func load_config(path: String = "res://config/dialogue.json") -> void:
 22 | 	var file := FileAccess.open(path, FileAccess.READ)
 23 | 	if file == null:
 24 | 		configure(null)
 25 | 		return
 26 | 	var parser := JSON.new()
 27 | 	if parser.parse(file.get_as_text()) != OK:
 28 | 		configure(null)
 29 | 		return
 30 | 	configure(parser.data)
 31 | 
 32 | 
 33 | func configure(raw: Variant) -> void:
 34 | 	rules.clear()
 35 | 	recent_topics.clear()
 36 | 	fallback = {}
 37 | 	negated = {}
 38 | 	event_feedback = {}
 39 | 	mood_state_responses = {}
 40 | 	if not raw is Dictionary:
 41 | 		return
 42 | 	if raw.get("fallback") is Dictionary:
 43 | 		fallback = raw["fallback"]
 44 | 	if raw.get("negated") is Dictionary:
 45 | 		negated = raw["negated"]
 46 | 	if raw.get("event_feedback") is Dictionary:
 47 | 		event_feedback = raw["event_feedback"]
 48 | 	if raw.get("mood_state_responses") is Dictionary:
 49 | 		mood_state_responses = raw["mood_state_responses"]
 50 | 	if not raw.get("rules") is Array:
 51 | 		return
 52 | 	for spec in raw["rules"]:
 53 | 		if not spec is Dictionary or not spec.get("id") is String or not spec.get("topic") is String:
 54 | 			continue
 55 | 		if spec["id"].is_empty() or spec["topic"].is_empty() or responses.valid_pool(spec.get("responses")).is_empty():
 56 | 			continue
 57 | 		var rule: Dictionary = spec.duplicate(true)
 58 | 		for field in ["exact", "keywords", "exclude", "followups"]:
 59 | 			rule[field] = _strings(spec.get(field))
 60 | 		rules.append(rule)
 61 | 
 62 | 
 63 | func submit_message(raw: Variant, nickname: Variant = "", now_ms: int = -1) -> Dictionary:
 64 | 	var checked := InputGuard.check(raw, InputGuard.MESSAGE_LIMIT)
 65 | 	if not checked.ok:
 66 | 		return {"accepted": false, "error": checked.error, "text": "说短一点嘛，最多 50 个字符哦。" if checked.error == "too_long" else "", "intent": "", "topic": "", "action_request": "", "mood_event": ""}
 67 | 	var now := Time.get_ticks_msec() if now_ms < 0 else now_ms
 68 | 	var clean: String = checked.text
 69 | 	var match_text := clean.to_lower().strip_edges().trim_suffix("。").trim_suffix("！").trim_suffix("!").trim_suffix("？").trim_suffix("?")
 70 | 	var name_check := InputGuard.check(nickname, InputGuard.NICKNAME_LIMIT, true)
 71 | 	var safe_name: String = name_check.text if name_check.ok else ""
 72 | 	var easter_egg := easter_eggs.match_first(clean)
 73 | 	if bool(easter_egg.get("matched", false)):
 74 | 		recent_topics.clear()
 75 | 		return _easter_egg_result(easter_egg)
 76 | 	while not recent_topics.is_empty() and now - int(recent_topics[0].at_ms) >= CONTEXT_TTL_MS:
 77 | 		recent_topics.pop_front()
 78 | 	var selected: Dictionary = {}
 79 | 	var is_followup := false
 80 | 	# Exact rules win, then explicit continuations, then ordered keyword rules.
 81 | 	for rule in rules:
 82 | 		if rule.exact.has(match_text):
 83 | 			selected = rule
 84 | 			break
 85 | 	if selected.is_empty() and not recent_topics.is_empty():
 86 | 		for rule in rules:
 87 | 			if rule.topic == recent_topics.back().topic and rule.followups.has(match_text):
 88 | 				selected = rule
 89 | 				is_followup = true
 90 | 				break
 91 | 	var saw_negation := false
 92 | 	if selected.is_empty():
 93 | 		for rule in rules:
 94 | 			if _contains_any(match_text, rule.exclude):
 95 | 				saw_negation = true
 96 | 				continue
 97 | 			for keyword in rule.keywords:
 98 | 				var offset := match_text.find(keyword)
 99 | 				while offset >= 0:
					if not _is_negated(match_text, offset):
						selected = rule
						break
					saw_negation = true
					offset = match_text.find(keyword, offset + keyword.length())
				if not selected.is_empty():
					break
			if not selected.is_empty():
				break
	if selected.is_empty():
		recent_topics.clear()
		return _result(responses.choose(negated if saw_negation else fallback, safe_name), "negated" if saw_negation else "fallback", "", false)
	var topic: String = selected.topic
	recent_topics.append({"topic": topic, "at_ms": now})
	while recent_topics.size() > CONTEXT_LIMIT:
		recent_topics.pop_front()
	var pool := selected
	if is_followup and selected.get("followup_responses") is Array:
		pool = {"responses": selected.followup_responses}
	var action_id := str(selected.get("action_request", ""))
	var variants := _strings(selected.get("action_requests", []))
	if not variants.is_empty():
		action_id = variants[responses.rng.randi_range(0, variants.size() - 1)]
	return _result(
		responses.choose(pool, safe_name),
		selected.id,
		topic,
		is_followup,
		action_id,
		str(selected.get("mood_event", ""))
	)


# Event lines are separate from keywords: files and dragging never execute via chat.
func event_reply(event_id: String) -> String:
	return _choose_configured(event_feedback.get(event_id, []))


func mood_reply(mood: String) -> String:
	var known_mood := mood if mood in ["normal", "happy", "shy", "angry", "sleepy"] else "normal"
	return _choose_configured(mood_state_responses.get(known_mood, []))


func _choose_configured(raw: Variant) -> String:
	var pool := responses.valid_pool(raw)
	if pool.is_empty():
		return ""
	# A one-line event must never turn into a generic fallback merely because
	# the same event happened twice in a row.
	if pool.size() == 1:
		return pool[0]
	return responses.choose({"responses": pool}, "")


func birthday_auto_event(date: Dictionary, last_trigger_year: int) -> Dictionary:
	var easter_egg := easter_eggs.auto_birthday_event(
		date,
		last_trigger_year
	) as Dictionary
	if not bool(easter_egg.get("matched", false)):
		return {}
	recent_topics.clear()
	return _easter_egg_result(easter_egg)


func _easter_egg_result(easter_egg: Dictionary) -> Dictionary:
	var result := _result(
		easter_eggs.format_reply(easter_egg),
		"easter_egg",
		"",
		false,
		str(easter_egg.get("action_request", "")),
		str(easter_egg.get("mood_event", ""))
	)
	result["easter_egg"] = easter_egg
	return result


func _result(
	text: String,
	intent: String,
	topic: String,
	followed: bool,
	action_request: String = "",
	mood_event: String = ""
) -> Dictionary:
	return {
		"accepted": true,
		"error": "",
		"text": text,
		"intent": intent,
		"topic": topic,
		"used_context": followed,
		"action_request": action_request,
		"mood_event": mood_event,
		"easter_egg": {}
	}


func _strings(raw: Variant) -> Array[String]:
	var result: Array[String] = []
	if raw is Array:
		for value in raw:
			if value is String and not value.strip_edges().is_empty():
				result.append(value.to_lower())
	return result


func _contains_any(text: String, words: Array[String]) -> bool:
	for word in words:
		if text.contains(word):
			return true
	return false


func _is_negated(text: String, offset: int) -> bool:
	var before := text.left(offset).strip_edges()
	for prefix in NEGATIVE_PREFIXES:
		if prefix == "别" and before.ends_with("特别"):
			continue
		if before.ends_with(prefix):
			return true
	return false
