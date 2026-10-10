 1 | extends RefCounted
 2 | 
 3 | # String.length() and LineEdit.max_length both count Unicode code points.
 4 | # A joined emoji or a combining mark can therefore occupy multiple characters.
 5 | const MESSAGE_LIMIT := 50
 6 | const NICKNAME_LIMIT := 12
 7 | 
 8 | 
 9 | static func normalize(raw: String) -> String:
	var result := ""
	var space_pending := false
	for index in range(raw.length()):
		var code := raw.unicode_at(index)
		if _is_space(code):
			space_pending = not result.is_empty()
			continue
		if space_pending:
			result += " "
			space_pending = false
		result += raw[index]
	return result


static func check(raw: Variant, limit: int, allow_empty: bool = false) -> Dictionary:
	if not raw is String:
		return {"ok": false, "text": "", "error": "invalid_type"}
	# Bound work before building a normalized copy of an oversized submission.
	if raw.length() > limit:
		for index in range(raw.length()):
			if not _is_space(raw.unicode_at(index)):
				return {"ok": false, "text": "", "error": "too_long"}
		return {"ok": allow_empty, "text": "", "error": "" if allow_empty else "empty"}
	var text := normalize(raw)
	if text.is_empty():
		return {"ok": allow_empty, "text": "", "error": "" if allow_empty else "empty"}
	return {"ok": true, "text": text, "error": ""}


static func _is_space(code: int) -> bool:
	return (
		code <= 32 or code == 127
		or code in [133, 160, 5760, 8232, 8233, 8239, 8287, 12288]
		or (code >= 8192 and code <= 8202)
	)
