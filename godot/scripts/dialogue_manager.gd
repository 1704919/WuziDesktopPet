extends RefCounted

const InputGuard = preload("res://scripts/input_guard.gd")
const ResponseManager = preload("res://scripts/response_manager.gd")
const EasterEggManager = preload("res://scripts/easter_egg_manager.gd")
const CONTEXT_TTL_MS := 120000
const CONTEXT_LIMIT := 3
const NEGATIVE_PREFIXES := ["不", "别", "没", "不要", "不想", "不能", "没有", "不是", "不太", "并不", "别再", "不要再", "不是很", "不怎么", "不够", "不算", "不再"]

var responses := ResponseManager.new()
var easter_eggs := EasterEggManager.new()
var rules: Array[Dictionary] = []
# Only topic + timestamp, never the user's messages; session-local, no disk writes.
var recent_topics: Array[Dictionary] = []
var fallback: Dictionary = {}
var negated: Dictionary = {}
var event_feedback: Dictionary = {}
var mood_state_responses: Dictionary = {}


func load_config(path: String = "res://config/dialogue.json") -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		configure(null)
		return
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		configure(null)
		return
	configure(parser.data)


func configure(raw: Variant) -> void:
	rules.clear()
	recent_topics.clear()
	fallback = {}
	negated = {}
	event_feedback = {}
	mood_state_responses = {}
	if not raw is Dictionary:
		return
	if raw.get("fallback") is Dictionary:
		fallback = raw["fallback"]
	if raw.get("negated") is Dictionary:
		negated = raw["negated"]
	if raw.get("event_feedback") is Dictionary:
		event_feedback = raw["event_feedback"]
	if raw.get("mood_state_responses") is Dictionary:
		mood_state_responses = raw["mood_state_responses"]
	if not raw.get("rules") is Array:
		return
	for spec in raw["rules"]:
		if not spec is Dictionary or not spec.get("id") is String or not spec.get("topic") is String:
			continue
		if spec["id"].is_empty() or spec["topic"].is_empty() or responses.valid_pool(spec.get("responses")).is_empty():
			continue
		var rule: Dictionary = spec.duplicate(true)
		for field in ["exact", "keywords", "exclude", "followups"]:
			rule[field] = _strings(spec.get(field))
		rules.append(rule)


func submit_message(raw: Variant, nickname: Variant = "", now_ms: int = -1) -> Dictionary:
	var checked := InputGuard.check(raw, InputGuard.MESSAGE_LIMIT)
	if not checked.ok:
		return {"accepted": false, "error": checked.error, "text": "说短一点嘛，最多 50 个字符哦。" if checked.error == "too_long" else "", "intent": "", "topic": "", "action_request": "", "mood_event": ""}
	var now := Time.get_ticks_msec() if now_ms < 0 else now_ms
	var clean: String = checked.text
	var match_text := clean.to_lower().strip_edges().trim_suffix("。").trim_suffix("！").trim_suffix("!").trim_suffix("？").trim_suffix("?")
	var name_check := InputGuard.check(nickname, InputGuard.NICKNAME_LIMIT, true)
	var safe_name: String = name_check.text if name_check.ok else ""
	var easter_egg := easter_eggs.match_first(clean)
	if bool(easter_egg.get("matched", false)):
		recent_topics.clear()
		return _easter_egg_result(easter_egg)
	while not recent_topics.is_empty() and now - int(recent_topics[0].at_ms) >= CONTEXT_TTL_MS:
		recent_topics.pop_front()
	var selected: Dictionary = {}
	var is_followup := false
	# Exact rules win, then explicit continuations, then ordered keyword rules.
	for rule in rules:
		if rule.exact.has(match_text):
			selected = rule
			break
	if selected.is_empty() and not recent_topics.is_empty():
		for rule in rules:
			if rule.topic == recent_topics.back().topic and rule.followups.has(match_text):
				selected = rule
				is_followup = true
				break
	var saw_negation := false
	if selected.is_empty():
		for rule in rules:
			if _contains_any(match_text, rule.exclude):
				saw_negation = true
				continue
			for keyword in rule.keywords:
				var offset := match_text.find(keyword)
				while offset >= 0:
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
