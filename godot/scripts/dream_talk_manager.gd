extends RefCounted

const DEFAULT_CHAT := [
	"唔，我听见了。",
	"再让我睡一会儿。",
	"嗯，我还在听。",
	"刚才梦到什么来着。",
]
const DEFAULT_REMINDER_PREFIX := ["唔，好像有什么事。"]
const DEFAULT_WEATHER_PREFIX := ["外面，是天气的事吗。"]

var rng := RandomNumberGenerator.new()
var chat_responses: Array[String] = []
var chat_nickname_responses: Array[String] = []
var reminder_prefixes: Array[String] = []
var weather_prefixes: Array[String] = []
var fallback_prefixes: Array[String] = []


func _init() -> void:
	rng.randomize()


func load_config(path: String = "res://config/dialogue.json") -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		configure({})
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		configure({})
		return
	configure((parsed as Dictionary).get("dream_talk", {}) as Dictionary)


func configure(raw: Dictionary) -> void:
	chat_responses = _strings((raw.get("chat", {}) as Dictionary).get("responses", []))
	chat_nickname_responses = _strings((raw.get("chat", {}) as Dictionary).get("nickname_responses", []))
	reminder_prefixes = _strings((raw.get("reminder", {}) as Dictionary).get("prefixes", []))
	weather_prefixes = _strings((raw.get("weather", {}) as Dictionary).get("prefixes", []))
	fallback_prefixes = _strings((raw.get("fallback", {}) as Dictionary).get("prefixes", []))
	if chat_responses.is_empty():
		chat_responses = _strings(DEFAULT_CHAT)
	if reminder_prefixes.is_empty():
		reminder_prefixes = _strings(DEFAULT_REMINDER_PREFIX)
	if weather_prefixes.is_empty():
		weather_prefixes = _strings(DEFAULT_WEATHER_PREFIX)
	if fallback_prefixes.is_empty():
		fallback_prefixes = _strings(reminder_prefixes)


func set_seed(seed: int) -> void:
	rng.seed = seed


func chat_reply(nickname: String = "") -> String:
	var pool := chat_responses
	if not nickname.is_empty() and not chat_nickname_responses.is_empty() and rng.randf() < 0.25:
		pool = chat_nickname_responses
	var text := _choose(pool)
	if not nickname.is_empty():
		text = text.replace("{nickname}", nickname)
	return decorate(text)


func format_notice(kind: String, original: String) -> String:
	var prefixes := fallback_prefixes
	if kind == "weather":
		prefixes = weather_prefixes
	elif kind == "reminder":
		prefixes = reminder_prefixes
	var prefix := _choose(prefixes)
	var combined := prefix
	if not original.strip_edges().is_empty():
		combined = "%s %s" % [prefix, original.strip_edges()]
	return decorate(combined)


func decorate(text: String) -> String:
	var clean := text.strip_edges()
	if clean.length() <= 1:
		return clean

	var target_count := _ellipsis_count(clean.length())
	var candidates := _candidate_boundaries(clean)
	if candidates.is_empty():
		return clean
	target_count = mini(target_count, candidates.size())

	var chosen: Dictionary = {}
	for _index in range(target_count):
		var pick := rng.randi_range(0, candidates.size() - 1)
		var boundary: int = int(candidates[pick])
		chosen[boundary] = true
		candidates.remove_at(pick)

	var result := ""
	for i in range(clean.length()):
		if chosen.has(i):
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
