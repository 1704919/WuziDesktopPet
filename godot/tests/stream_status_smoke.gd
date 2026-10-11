extends SceneTree

# Offline coverage for the stream reminder's pure logic. The fixture mirrors the
# field layout the room API returns, including live_start_time being null while
# a room is live, and the looping "轮播" status. No request is made here.

const StreamStatus = preload("res://scripts/stream_status.gd")
const StreamReplyFormatter = preload("res://scripts/stream_reply_formatter.gd")

const SAMPLE_LIVE_TIME := "2026-01-02 03:04:05"
var failures: Array[String] = []


func check(value: bool, label: String) -> void:
	if not value:
		failures.append(label)


func _init() -> void:
	call_deferred("_run")


# Response body shape as observed from
# /room/v1/Room/get_info?room_id=<id>; values are placeholders.
func sample_data() -> Dictionary:
	return {
		"uid": 10001,
		"room_id": 12345,
		"short_id": 678,
		"live_status": 1,
		"live_time": SAMPLE_LIVE_TIME,
		"live_start_time": null,
		"title": "示例标题",
		"area_name": "示例分区",
		"online": 1234,
		"attention": 5678
	}


func envelope(data: Variant) -> Dictionary:
	return {"code": 0, "message": "ok", "data": data}


func live_status(overrides: Dictionary = {}) -> Dictionary:
	var data := sample_data()
	for key in overrides.keys():
		data[key] = overrides[key]
	return StreamStatus.parse_room_info(envelope(data))


func _check_room_id_normalization() -> void:
	check(StreamStatus.normalize_room_id("510") == "510", "room_id_plain")
	check(StreamStatus.normalize_room_id(" 80397 ") == "80397", "room_id_trimmed")
	check(StreamStatus.normalize_room_id("0") == "0", "room_id_zero")
	check(
		StreamStatus.normalize_room_id("1234567890") == "1234567890",
		"room_id_max_digits"
	)
	check(StreamStatus.normalize_room_id(510) == "510", "room_id_from_int")
	check(StreamStatus.normalize_room_id(510.0) == "510", "room_id_from_float")
	check(StreamStatus.normalize_room_id(null) == "", "room_id_null")
	check(StreamStatus.normalize_room_id("") == "", "room_id_empty")
	check(StreamStatus.normalize_room_id("   ") == "", "room_id_blank")
	check(StreamStatus.normalize_room_id("abc") == "", "room_id_letters")
	check(StreamStatus.normalize_room_id("-510") == "", "room_id_negative")
	check(StreamStatus.normalize_room_id("510.0") == "", "room_id_decimal")
	check(StreamStatus.normalize_room_id("510; DROP") == "", "room_id_injection")
	check(StreamStatus.normalize_room_id("12345678901") == "", "room_id_too_long")
	check(StreamStatus.normalize_room_id("510\n") == "510", "room_id_newline")
	# Full-width digits are rejected on purpose: the value is placed into a URL,
	# and a friendly message is cheaper than guessing at lookalike characters.
	check(StreamStatus.normalize_room_id("５１０") == "", "room_id_full_width")


func _check_parsing() -> void:
	var status := StreamStatus.parse_room_info(envelope(sample_data()))
	check(status.get("room_id", "") == "12345", "parse_room_id")
	check(status.get("short_id", "") == "678", "parse_short_id")
	check(status.get("uid", "") == "10001", "parse_uid")
	check(status.get("title", "") == "示例标题", "parse_title")
	check(status.get("area_name", "") == "示例分区", "parse_area")
	check(int(status.get("online", -1)) == 1234, "parse_online")
	check(int(status.get("live_status", -1)) == 1, "parse_live_status")
	check(status.get("live_time", "") == SAMPLE_LIVE_TIME, "parse_live_time")
	# The manager must be able to tell "not live" from "field missing".
	check(status.has("live_status"), "parse_keeps_offline_status")

	check(
		StreamStatus.parse_room_info({"code": -352, "data": {}}).is_empty(),
		"parse_rejects_risk_control_code"
	)
	# A body without a code field is not a successful response; the default
	# must stay non-zero so an unexpected payload is never read as data.
	check(
		StreamStatus.parse_room_info({"data": sample_data()}).is_empty(),
		"parse_rejects_missing_code"
	)
	check(
		StreamStatus.parse_room_info({"code": 0}).is_empty(),
		"parse_rejects_missing_data"
	)
	check(
		StreamStatus.parse_room_info(envelope([])).is_empty(),
		"parse_rejects_non_dict_data"
	)
	check(
		StreamStatus.parse_room_info(envelope({})).is_empty(),
		"parse_rejects_empty_data"
	)

	var no_room := sample_data()
	no_room.erase("room_id")
	check(
		StreamStatus.parse_room_info(envelope(no_room)).is_empty(),
		"parse_rejects_missing_room_id"
	)

	var blank_room := sample_data()
	blank_room["room_id"] = ""
	check(
		StreamStatus.parse_room_info(envelope(blank_room)).is_empty(),
		"parse_rejects_blank_room_id"
	)

	# A room id that arrives as text is still usable.
	check(
		live_status({"room_id": "99999"}).get("room_id", "") == "99999",
		"parse_room_id_from_string"
	)


func _check_live_detection() -> void:
	check(StreamStatus.is_live(live_status()), "live_when_status_one")
	check(
		not StreamStatus.is_live(live_status({"live_status": 0})),
		"offline_when_status_zero"
	)
	# Regression: status 2 is the looping replay state. A naive "!= 0" check
	# would report those rooms as live forever.
	check(
		not StreamStatus.is_live(live_status({"live_status": 2})),
		"loop_status_is_not_live"
	)
	check(not StreamStatus.is_live({}), "missing_status_is_not_live")
	check(
		StreamStatus.is_live({"live_status": "1"}),
		"string_status_one_is_live"
	)


func _check_session_key() -> void:
	var status := live_status()
	var key := StreamStatus.session_key(status)
	check(
		key == "live|12345|%s" % SAMPLE_LIVE_TIME,
		"session_key_shape"
	)
	check(key.contains(SAMPLE_LIVE_TIME), "session_key_uses_live_time")
	# live_start_time is null even while live, so it must not be part of the key.
	check(
		not key.contains("live_start_time"),
		"session_key_ignores_live_start_time"
	)
	check(
		StreamStatus.session_key(live_status()) == key,
		"session_key_is_stable"
	)
	check(
		StreamStatus.session_key(
			live_status({"live_time": "2026-02-03 04:05:06"})
		) != key,
		"session_key_changes_per_broadcast"
	)
	check(
		StreamStatus.session_key(
			live_status({"room_id": 54321, "short_id": 678})
		) != key,
		"session_key_includes_room_id"
	)
	check(
		StreamStatus.session_key(live_status({"live_status": 0})).is_empty(),
		"session_key_empty_offline"
	)
	check(
		StreamStatus.session_key(live_status({"live_status": 2})).is_empty(),
		"session_key_empty_for_loop"
	)
	check(
		StreamStatus.session_key(live_status({"live_time": ""})).is_empty(),
		"session_key_empty_without_live_time"
	)


func _check_reminder_rules() -> void:
	var status := live_status()
	var key := StreamStatus.session_key(status)

	check(
		StreamStatus.should_remind(status, ""),
		"remind_when_never_confirmed"
	)
	# The core of the confirmation model: an unanswered reminder has to come
	# back, so the rule cannot depend on having announced it once.
	check(
		StreamStatus.should_remind(status, ""),
		"remind_repeats_until_confirmed"
	)
	check(
		not StreamStatus.should_remind(status, key),
		"silent_after_user_confirms"
	)
	check(
		StreamStatus.should_remind(
			live_status({"live_time": "2026-02-03 04:05:06"}),
			key
		),
		"new_broadcast_asks_again"
	)
	# A confirmation belongs to one broadcast: it must never silence a later one.
	check(
		StreamStatus.should_remind(status, "live|999999|2020-01-01 00:00:00"),
		"foreign_confirmation_does_not_silence"
	)
	# The reminder stops asking on its own once the stream ends, so no timer or
	# extra state is needed for "until the live ends".
	check(
		not StreamStatus.should_remind(live_status({"live_status": 0}), ""),
		"silent_when_offline"
	)
	check(
		not StreamStatus.should_remind(live_status({"live_status": 2}), ""),
		"silent_when_looping"
	)
	check(
		not StreamStatus.should_remind(live_status({"live_time": ""}), ""),
		"silent_without_live_time"
	)
	check(not StreamStatus.should_remind({}, ""), "silent_without_status")

	# Regression: the reference response carries live_start_time as null. That
	# must not stop the reminder from firing.
	var with_null_start := live_status()
	check(
		with_null_start.get("live_status", 0) == 1
		and with_null_start.has("live_time"),
		"fixture_keeps_live_fields"
	)
	check(
		StreamStatus.should_remind(with_null_start, ""),
		"null_live_start_time_still_reminds"
	)


func _check_formatter() -> void:
	var status := live_status()

	check(
		StreamReplyFormatter.build(status, "")
		== "你关注的主播开播啦！正在播《示例标题》（示例分区），要不要去看看？",
		"format_default_label"
	)
	check(
		StreamReplyFormatter.build(status, "   ")
		== "你关注的主播开播啦！正在播《示例标题》（示例分区），要不要去看看？",
		"format_blank_label"
	)
	check(
		StreamReplyFormatter.build(status, " 示例昵称 ")
		== "示例昵称开播啦！正在播《示例标题》（示例分区），要不要去看看？",
		"format_trims_label"
	)
	check(
		StreamReplyFormatter.build(live_status({"area_name": ""}), "示例昵称")
		== "示例昵称开播啦！正在播《示例标题》，要不要去看看？",
		"format_without_area"
	)
	check(
		StreamReplyFormatter.build(live_status({"title": ""}), "示例昵称")
		== "示例昵称开播啦，一起去看看吧～",
		"format_without_title"
	)
	check(
		StreamReplyFormatter.build(
			live_status({"title": "  ", "area_name": "  "}),
			"示例昵称"
		) == "示例昵称开播啦，一起去看看吧～",
		"format_blank_title_and_area"
	)
	check(
		StreamReplyFormatter.build({}, "")
		== "你关注的主播开播啦，一起去看看吧～",
		"format_empty_status"
	)

	# The answer to a check the user asked for has to read sensibly in every
	# state, not only while live.
	check(
		StreamReplyFormatter.build_check(live_status(), "示例昵称")
		== "示例昵称正在直播《示例标题》，快去看看～",
		"check_live_with_title"
	)
	check(
		StreamReplyFormatter.build_check(live_status({"title": ""}), "示例昵称")
		== "示例昵称正在直播，快去看看～",
		"check_live_without_title"
	)
	check(
		StreamReplyFormatter.build_check(
			live_status({"live_status": 2}), ""
		) == "你关注的主播现在在轮播，还不算开播，真的开播了我再叫你。",
		"check_looping"
	)
	check(
		StreamReplyFormatter.build_check(live_status({"live_status": 0}), "")
		== "你关注的主播现在没有开播，等开播了我会告诉你的～",
		"check_offline"
	)
	check(
		StreamReplyFormatter.display_name("  ")
		== StreamReplyFormatter.DEFAULT_LABEL,
		"display_name_blank"
	)
	check(
		StreamReplyFormatter.display_name(" 示例昵称 ")
		== "示例昵称",
		"display_name_trimmed"
	)


func _run() -> void:
	_check_room_id_normalization()
	_check_parsing()
	_check_live_detection()
	_check_session_key()
	_check_reminder_rules()
	_check_formatter()

	if failures.is_empty():
		print("STREAM_STATUS_SMOKE_OK")
		quit(0)
	else:
		for label in failures:
			push_error("stream_status: " + label)
		quit(2)
