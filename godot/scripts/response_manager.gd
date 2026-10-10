 1 | extends RefCounted
 2 | 
 3 | const FALLBACKS := ["嗯嗯，听到啦～你继续说。", "我在听呢，慢慢说。", "嗯，陪你聊一会儿。"]
 4 | 
 5 | var rng := RandomNumberGenerator.new()
 6 | var last_text := ""
 7 | 
 8 | 
 9 | func _init() -> void:
	rng.randomize()


func valid_pool(raw: Variant, with_nickname: bool = false) -> Array[String]:
	var result: Array[String] = []
	if not raw is Array:
		return result
	for value in raw:
		if not value is String or value.strip_edges().is_empty() or value.length() > 200:
			continue
		if with_nickname != value.contains("{nickname}"):
			continue
		var plain: String = value.replace("{nickname}", "")
		if plain.contains("{") or plain.contains("}"):
			continue
		if not result.has(value):
			result.append(value)
	return result


func choose(spec: Dictionary, nickname: String) -> String:
	var ordinary := valid_pool(spec.get("responses", []))
	if ordinary.is_empty():
		ordinary.assign(FALLBACKS)
	var named := valid_pool(spec.get("nickname_responses", []), true)
	var use_name := not nickname.is_empty() and not named.is_empty() and rng.randf() < 0.2
	var candidates: Array[String] = []
	var selected := named if use_name else ordinary
	for template in selected:
		var text: String = template.replace("{nickname}", nickname)
		if text != last_text:
			candidates.append(text)
	if candidates.is_empty():
		for text in ordinary:
			if text != last_text:
				candidates.append(text)
	if candidates.is_empty():
		for text in FALLBACKS:
			if text != last_text:
				candidates.append(text)
	last_text = candidates[rng.randi_range(0, candidates.size() - 1)]
	return last_text
