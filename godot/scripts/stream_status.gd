extends RefCounted

# Pure helpers for the Bilibili live-room status check.
#
# Endpoint used by the manager (measured 2026-10-11):
#   GET https://api.live.bilibili.com/room/v1/Room/get_info?room_id=<id>
#   A User-Agent header is mandatory, otherwise the API answers HTTP 412.
#
# Everything here is static and side-effect free so the parsing and the
# notification rules can be covered by an offline test.

const LIVE_STATUS_OFFLINE := 0
const LIVE_STATUS_LIVE := 1
const LIVE_STATUS_ROUND := 2
const MAX_ROOM_ID_DIGITS := 10


# Room ids end up inside a request URL, so only plain digits are accepted.
# Anything else (empty text, separators, letters, over-long input) is rejected
# here instead of being handed to the HTTP layer.
static func normalize_room_id(raw: Variant) -> String:
	var text := _as_text(raw)
	if text.is_empty() or text.length() > MAX_ROOM_ID_DIGITS:
		return ""
	for index in range(text.length()):
		var code := text.unicode_at(index)
		if code < 48 or code > 57:
			return ""
	return text


# Extracts the fields the reminder needs. A response that is rejected by the
# API, malformed, or missing the canonical room id yields an empty dictionary,
# which the manager treats as a failed request.
static func parse_room_info(payload: Dictionary) -> Dictionary:
	if _as_int(payload.get("code"), -1) != 0:
		return {}

	var data_variant: Variant = payload.get("data")
	if typeof(data_variant) != TYPE_DICTIONARY:
		return {}
	var data := data_variant as Dictionary
	if data.is_empty():
		return {}

	# The canonical room id. A user may configure the short id (for example
	# 510); the API always answers with the real one (80397).
	var room_id := _as_text(data.get("room_id"))
	if room_id.is_empty():
		return {}

	return {
		"room_id": room_id,
		"short_id": _as_text(data.get("short_id")),
		"uid": _as_text(data.get("uid")),
		"title": _as_text(data.get("title")),
		"area_name": _as_text(data.get("area_name")),
		"online": _as_int(data.get("online"), 0),
		"live_status": _as_int(
			data.get("live_status"),
			LIVE_STATUS_OFFLINE
		),
		"live_time": _as_text(data.get("live_time"))
	}


# Only status 1 means the streamer is actually broadcasting.
# Status 2 is the looping replay ("轮播") state, which several rooms report
# permanently, so a "!= offline" check would notify forever.
static func is_live(status: Dictionary) -> bool:
	return (
		_as_int(status.get("live_status"), LIVE_STATUS_OFFLINE)
		== LIVE_STATUS_LIVE
	)


# Identifies the current broadcast. The key changes when a new stream starts, so
# a confirmation given for one broadcast never silences the next one.
#
# live_time is used on purpose: live_start_time is null even while a room is
# live (measured on the reference room), so it cannot carry this meaning.
# An offline room, or a live room without live_time, returns an empty key and
# therefore never triggers a reminder.
static func session_key(status: Dictionary) -> String:
	if not is_live(status):
		return ""
	var live_time := _as_text(status.get("live_time"))
	if live_time.is_empty():
		return ""
	return "live|%s|%s" % [_as_text(status.get("room_id")), live_time]


# True while this broadcast is still waiting for the user to confirm the
# reminder.
#
# Deliberately NOT "has this been announced yet": the manager does not mark a
# broadcast as told, so an unanswered reminder comes back on every poll and only
# stops when the user confirms or the broadcast ends (an offline room has no
# session key at all, see session_key).
static func should_remind(status: Dictionary, confirmed_key: String) -> bool:
	var key := session_key(status)
	if key.is_empty():
		return false
	return key != confirmed_key


# JSON numbers arrive as int or float, text fields as String; both are folded
# into a trimmed string here so the callers do not repeat the branching.
static func _as_text(raw: Variant) -> String:
	match typeof(raw):
		TYPE_INT:
			return str(raw as int)
		TYPE_FLOAT:
			return str(int(raw as float))
		TYPE_STRING:
			return (raw as String).strip_edges()
	return ""


static func _as_int(raw: Variant, fallback: int) -> int:
	match typeof(raw):
		TYPE_INT:
			return raw as int
		TYPE_FLOAT:
			return int(raw as float)
		TYPE_STRING:
			var text := (raw as String).strip_edges()
			if text.is_valid_int():
				return text.to_int()
	return fallback
