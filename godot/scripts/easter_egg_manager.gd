extends RefCounted

const ARABIC_DIGITS := "0123456789"
const CHINESE_NUMERALS := "零〇一二两三四五六七八九十百千万亿兆"
const ARABIC_LIMIT := 40
const CHINESE_LIMIT := 20
const MAX_TARGET_POWER := 16
const BIRTHDAY_MONTH := 12
const BIRTHDAY_DAY := 20

const NAMED_EASTER_EGGS := {
	"生日": {
		"id": "birthday",
		"reply": "今天是我生日！礼物呢？",
		"mood_event": "happy",
		"action_request": "birthday_cake"
	},
	"庄园": {
		"id": "manor",
		"reply": "梓友庄园施工中，给你留了门口的位置。",
		"mood_event": "",
		"action_request": ""
	},
	"阿梓": {
		"id": "azi",
		"reply": "生疏了，你竟然不愿叫我一声梓神。",
		"mood_event": "angry",
		"action_request": "click_angry_video"
	},
	"梓神": {
		"id": "zishen",
		"reply": "喊这么大声干嘛，梓神也会害羞的。",
		"mood_event": "praise",
		"action_request": "click_shy_video"
	},
	"五杀": {
		"id": "penta_kill",
		"reply": "你赖姐牛不牛",
		"mood_event": "happy",
		"action_request": ""
	}
}

const DIGIT_VALUES := {
	"零": 0,
	"〇": 0,
	"一": 1,
	"二": 2,
	"两": 2,
	"三": 3,
	"四": 4,
	"五": 5,
	"六": 6,
	"七": 7,
	"八": 8,
	"九": 9,
}
const SMALL_UNITS := {
	"十": 10,
	"百": 100,
	"千": 1000,
}
const BIG_UNITS := {
	"万": 10000,
	"亿": 100000000,
	"兆": 1000000000000,
}


func match_first(raw: Variant) -> Dictionary:
	if not raw is String:
		return _miss()

	var text: String = raw
	var named := _match_named(text.strip_edges())
	if bool(named.get("matched", false)):
		return named

	var index := 0
	while index < text.length():
		var current := text.substr(index, 1)
		if ARABIC_DIGITS.contains(current):
			var end := index + 1
			while end < text.length() and ARABIC_DIGITS.contains(text.substr(end, 1)):
				end += 1
			var token := text.substr(index, end - index)
			if token.length() <= ARABIC_LIMIT:
				var mapped := _map_arabic(token)
				if not mapped.is_empty():
					return _hit(token, mapped, "arabic", index)
			index = end
			continue

		if CHINESE_NUMERALS.contains(current):
			var end := index + 1
			while end < text.length() and CHINESE_NUMERALS.contains(text.substr(end, 1)):
				end += 1
			var token := text.substr(index, end - index)
			if token.length() <= CHINESE_LIMIT:
				var mapped := _map_chinese(token)
				if not mapped.is_empty():
					return _hit(token, mapped, "chinese", index)
			index = end
			continue

		index += 1

	return _miss()


func format_reply(match: Dictionary) -> String:
	if not bool(match.get("matched", false)):
		return ""
	var direct_reply := str(match.get("reply", ""))
	if not direct_reply.is_empty():
		return direct_reply
	return "%s？我还以为%s呢" % [
		str(match.get("original", "")),
		str(match.get("mapped", "")),
	]


func auto_birthday_event(date: Dictionary, last_trigger_year: int) -> Dictionary:
	var year := int(date.get("year", -1))
	var month := int(date.get("month", -1))
	var day := int(date.get("day", -1))
	if (
		year <= 0
		or month != BIRTHDAY_MONTH
		or day != BIRTHDAY_DAY
		or year == last_trigger_year
	):
		return _miss()
	return _named_hit("生日", NAMED_EASTER_EGGS["生日"], 0)


func _match_named(text: String) -> Dictionary:
	if not NAMED_EASTER_EGGS.has(text):
		return _miss()
	return _named_hit(text, NAMED_EASTER_EGGS[text], 0)


func _named_hit(
	original: String,
	rule: Dictionary,
	start: int
) -> Dictionary:
	return {
		"matched": true,
		"id": str(rule.get("id", "")),
		"original": original,
		"mapped": "",
		"kind": "named",
		"start": start,
		"reply": str(rule.get("reply", "")),
		"mood_event": str(rule.get("mood_event", "")),
		"action_request": str(rule.get("action_request", ""))
	}


func _map_arabic(token: String) -> String:
	if token.length() < 2:
		return ""

	var prefix := token.left(2)
	if prefix != "29" and prefix != "92":
		return ""

	for index in range(2, token.length()):
		if token.substr(index, 1) != "0":
			return ""

	var mapped_prefix := "92" if prefix == "29" else "29"
	return mapped_prefix + token.substr(2)


func _map_chinese(token: String) -> String:
	var values := _values_for_chinese(token)
	if values.is_empty():
		return ""

	var preferred_two := "两" if token.contains("两") and not token.contains("二") else "二"
	var swapped := ""
	for index in range(token.length()):
		var current := token.substr(index, 1)
		if current == "二" or current == "两":
			swapped += "九"
		elif current == "九":
			swapped += preferred_two
		else:
			swapped += current

	if swapped == token:
		return ""

	var swapped_values := _values_for_chinese(swapped)
	if swapped_values.is_empty():
		return ""

	for value in values:
		var target := _target_info(value)
		if target.is_empty():
			continue
		var mapped_value := int(target.get("mapped_value", -1))
		if swapped_values.has(mapped_value):
			return swapped

	return ""


func _values_for_chinese(token: String) -> Array[int]:
	var result: Array[int] = []
	var parsed := _parse_chinese_standard(token)
	if not bool(parsed.get("ok", false)):
		return result

	var standard := int(parsed.get("value", -1))
	if standard >= 0:
		result.append(standard)

	var trailing_digit := int(parsed.get("trailing_digit", -1))
	var last_unit := int(parsed.get("last_explicit_unit", 0))
	var has_zero_gap := bool(parsed.get("has_zero_gap", false))
	if (
		trailing_digit > 0
		and last_unit >= 100
		and not has_zero_gap
		and token.length() >= 3
	):
		var colloquial := standard - trailing_digit + trailing_digit * int(last_unit / 10)
		if colloquial >= 0 and not result.has(colloquial):
			result.append(colloquial)

	return result


func _parse_chinese_standard(token: String) -> Dictionary:
	if token.is_empty() or token.length() > CHINESE_LIMIT:
		return {"ok": false}

	var total: int = 0
	var section: int = 0
	var current_digit: int = -1
	var last_small_unit: int = 10000
	var last_big_unit: int = 10000000000000000
	var last_explicit_unit: int = 0
	var trailing_digit: int = -1
	var has_zero_gap := false
	var saw_value := false
	var zero_pending := false

	for index in range(token.length()):
		var current := token.substr(index, 1)
		if DIGIT_VALUES.has(current):
			var digit := int(DIGIT_VALUES[current])
			if digit == 0:
				if current_digit >= 0 or zero_pending:
					return {"ok": false}
				zero_pending = true
				has_zero_gap = true
				trailing_digit = -1
				continue

			if current_digit >= 0:
				return {"ok": false}
			current_digit = digit
			zero_pending = false
			trailing_digit = digit
			saw_value = true
			continue

		if SMALL_UNITS.has(current):
			var unit := int(SMALL_UNITS[current])
			if unit >= last_small_unit:
				return {"ok": false}
			if zero_pending:
				return {"ok": false}
			if current_digit < 0:
				if unit != 10 or section != 0:
					return {"ok": false}
				current_digit = 1
			section += current_digit * unit
			current_digit = -1
			last_small_unit = unit
			last_explicit_unit = unit
			trailing_digit = -1
			saw_value = true
			continue

		if BIG_UNITS.has(current):
			var unit := int(BIG_UNITS[current])
			if unit >= last_big_unit or zero_pending:
				return {"ok": false}
			if current_digit >= 0:
				section += current_digit
				current_digit = -1
			if section <= 0:
				return {"ok": false}
			total += section * unit
			section = 0
			last_small_unit = 10000
			last_big_unit = unit
			last_explicit_unit = unit
			trailing_digit = -1
			saw_value = true
			continue

		return {"ok": false}

	if zero_pending or not saw_value:
		return {"ok": false}
	if current_digit >= 0:
		section += current_digit
	total += section
	return {
		"ok": true,
		"value": total,
		"trailing_digit": trailing_digit,
		"last_explicit_unit": last_explicit_unit,
		"has_zero_gap": has_zero_gap,
	}


func _target_info(value: int) -> Dictionary:
	if value <= 0:
		return {}

	var value_29: int = 29
	var value_92: int = 92
	for power in range(MAX_TARGET_POWER + 1):
		if value == value_29:
			return {
				"base": 29,
				"power": power,
				"mapped_value": value_92,
			}
		if value == value_92:
			return {
				"base": 92,
				"power": power,
				"mapped_value": value_29,
			}
		value_29 *= 10
		value_92 *= 10

	return {}


func _hit(original: String, mapped: String, kind: String, start: int) -> Dictionary:
	return {
		"matched": true,
		"id": "29_92",
		"original": original,
		"mapped": mapped,
		"kind": kind,
		"start": start,
		"reply": "",
		"mood_event": "",
		"action_request": ""
	}


func _miss() -> Dictionary:
	return {
		"matched": false,
		"id": "",
		"original": "",
		"mapped": "",
		"kind": "",
		"start": -1,
		"reply": "",
		"mood_event": "",
		"action_request": ""
	}
