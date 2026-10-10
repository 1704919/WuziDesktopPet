  1 | extends RefCounted
  2 | 
  3 | const DEFAULT_CHAT := [
  4 | 	"唔，我听见了。",
  5 | 	"再让我睡一会儿。",
  6 | 	"嗯，我还在听。",
  7 | 	"刚才梦到什么来着。",
  8 | ]
  9 | const DEFAULT_REMINDER_PREFIX := ["唔，好像有什么事。"]
 10 | const DEFAULT_WEATHER_PREFIX := ["外面，是天气的事吗。"]
 11 | 
 12 | var rng := RandomNumberGenerator.new()
 13 | var chat_responses: Array[String] = []
 14 | var chat_nickname_responses: Array[String] = []
 15 | var reminder_prefixes: Array[String] = []
 16 | var weather_prefixes: Array[String] = []
 17 | var fallback_prefixes: Array[String] = []
 18 | 
 19 | 
 20 | func _init() -> void:
 21 | 	rng.randomize()
 22 | 
 23 | 
 24 | func load_config(path: String = "res://config/dialogue.json") -> void:
 25 | 	var file := FileAccess.open(path, FileAccess.READ)
 26 | 	if file == null:
 27 | 		configure({})
 28 | 		return
 29 | 	var parsed: Variant = JSON.parse_string(file.get_as_text())
 30 | 	if not parsed is Dictionary:
 31 | 		configure({})
 32 | 		return
 33 | 	configure((parsed as Dictionary).get("dream_talk", {}) as Dictionary)
 34 | 
 35 | 
 36 | func configure(raw: Dictionary) -> void:
 37 | 	chat_responses = _strings((raw.get("chat", {}) as Dictionary).get("responses", []))
 38 | 	chat_nickname_responses = _strings((raw.get("chat", {}) as Dictionary).get("nickname_responses", []))
 39 | 	reminder_prefixes = _strings((raw.get("reminder", {}) as Dictionary).get("prefixes", []))
 40 | 	weather_prefixes = _strings((raw.get("weather", {}) as Dictionary).get("prefixes", []))
 41 | 	fallback_prefixes = _strings((raw.get("fallback", {}) as Dictionary).get("prefixes", []))
 42 | 	if chat_responses.is_empty():
 43 | 		chat_responses = _strings(DEFAULT_CHAT)
 44 | 	if reminder_prefixes.is_empty():
 45 | 		reminder_prefixes = _strings(DEFAULT_REMINDER_PREFIX)
 46 | 	if weather_prefixes.is_empty():
 47 | 		weather_prefixes = _strings(DEFAULT_WEATHER_PREFIX)
 48 | 	if fallback_prefixes.is_empty():
 49 | 		fallback_prefixes = _strings(reminder_prefixes)
 50 | 
 51 | 
 52 | func set_seed(seed: int) -> void:
 53 | 	rng.seed = seed
 54 | 
 55 | 
 56 | func chat_reply(nickname: String = "") -> String:
 57 | 	var pool := chat_responses
 58 | 	if not nickname.is_empty() and not chat_nickname_responses.is_empty() and rng.randf() < 0.25:
 59 | 		pool = chat_nickname_responses
 60 | 	var text := _choose(pool)
 61 | 	if not nickname.is_empty():
 62 | 		text = text.replace("{nickname}", nickname)
 63 | 	return decorate(text)
 64 | 
 65 | 
 66 | func format_notice(kind: String, original: String) -> String:
 67 | 	var prefixes := fallback_prefixes
 68 | 	if kind == "weather":
 69 | 		prefixes = weather_prefixes
 70 | 	elif kind == "reminder":
 71 | 		prefixes = reminder_prefixes
 72 | 	var prefix := _choose(prefixes)
 73 | 	var combined := prefix
 74 | 	if not original.strip_edges().is_empty():
 75 | 		combined = "%s %s" % [prefix, original.strip_edges()]
 76 | 	return decorate(combined)
 77 | 
 78 | 
 79 | func decorate(text: String) -> String:
 80 | 	var clean := text.strip_edges()
 81 | 	if clean.length() <= 1:
 82 | 		return clean
 83 | 
 84 | 	var target_count := _ellipsis_count(clean.length())
 85 | 	var candidates := _candidate_boundaries(clean)
 86 | 	if candidates.is_empty():
 87 | 		return clean
 88 | 	target_count = mini(target_count, candidates.size())
 89 | 
 90 | 	var chosen: Dictionary = {}
 91 | 	for _index in range(target_count):
 92 | 		var pick := rng.randi_range(0, candidates.size() - 1)
 93 | 		var boundary: int = int(candidates[pick])
 94 | 		chosen[boundary] = true
 95 | 		candidates.remove_at(pick)
 96 | 
 97 | 	var result := ""
 98 | 	for i in range(clean.length()):
 99 | 		if chosen.has(i):
			result += "..."
		result += clean.substr(i, 1)
	return result


func _ellipsis_count(length: int) -> int:
	if length <= 10:
		return 1
	if length <= 24:
		return rng.randi_range(1, 2)
	if length <= 48:
		return rng.randi_range(2, 3)
	return rng.randi_range(3, 4)


func _candidate_boundaries(text: String) -> Array[int]:
	var preferred: Array[int] = []
	var fallback: Array[int] = []
	for i in range(1, text.length()):
		var left := text.substr(i - 1, 1)
		var right := text.substr(i, 1)
		if _protected_boundary(left, right):
			continue
		if left in ["，", ",", "。", "！", "!", "？", "?", "；", ";", "、", "：", ":"]:
			preferred.append(i)
		elif i >= 2 and i <= text.length() - 2:
			fallback.append(i)
	for boundary in fallback:
		if not preferred.has(boundary):
			preferred.append(boundary)
	return preferred


func _protected_boundary(left: String, right: String) -> bool:
	if left in [".", "…"] or right in [".", "…"]:
		return true
	if left.strip_edges().is_empty() or right.strip_edges().is_empty():
		return false
	return _ascii_token_char(left) or _ascii_token_char(right)


func _ascii_token_char(ch: String) -> bool:
	if ch.length() != 1:
		return false
	var code := ch.unicode_at(0)
	if (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122):
		return true
	return ch in [".", ":", "/", "%", "°", "+", "-", "_", "@", "#", "?", "=", "&"]


func _choose(pool: Array[String]) -> String:
	if pool.is_empty():
		return ""
	return pool[rng.randi_range(0, pool.size() - 1)]


func _strings(raw: Variant) -> Array[String]:
	var result: Array[String] = []
	if raw is Array:
		for item in raw:
			if item is String and not item.strip_edges().is_empty():
				result.append(item.strip_edges())
	return result
