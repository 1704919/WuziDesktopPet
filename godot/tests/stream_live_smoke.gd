extends SceneTree

# Live check that the real request path still works: endpoint reachable, the
# mandatory User-Agent accepted, and the response parseable.
#
# The default room is Bilibili's own room (short id 1), not a streamer: it is
# permanently reachable and sits in the looping state, so this test never
# depends on whether a person happens to be broadcasting. Pass another room id
# after "--" to probe a specific room:
#   godot --headless --path godot --script res://tests/stream_live_smoke.gd -- 510
#
# It deliberately does not assert live_status, because the value depends on the
# real world; that is what the offline test covers.

const StreamStatus = preload("res://scripts/stream_status.gd")
const DEFAULT_ROOM := "1"

var manager
var finished := false
var room := DEFAULT_ROOM


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var extra := OS.get_cmdline_user_args()
	if not extra.is_empty() and not extra[0].strip_edges().is_empty():
		room = extra[0].strip_edges()

	var script = load("res://scripts/stream_reminder_manager.gd")
	manager = script.new()
	root.add_child(manager)
	await process_frame

	manager.stream_updated.connect(_on_stream_updated)
	manager.request_failed.connect(_on_failed)
	manager.configure({
		"enabled": true,
		"room_id": room,
		"label": "",
		"check_interval_seconds": 600
	})
	if manager.room_query != StreamStatus.normalize_room_id(room):
		push_error("STREAM_LIVE_SMOKE_BAD_ROOM: " + room)
		quit(4)
		return

	manager.refresh()
	await create_timer(20.0).timeout
	if not finished:
		push_error("STREAM_LIVE_SMOKE_TIMEOUT")
		quit(3)


func _on_stream_updated(status: Dictionary, _manual: bool) -> void:
	finished = true

	var room_id := str(status.get("room_id", ""))
	if room_id.is_empty() or StreamStatus.normalize_room_id(room_id) != room_id:
		push_error("STREAM_LIVE_SMOKE_BAD_ROOM_ID: " + room_id)
		quit(2)
		return

	var live_status := int(status.get("live_status", -1))
	if live_status < 0 or live_status > 2:
		push_error("STREAM_LIVE_SMOKE_BAD_STATUS: %d" % live_status)
		quit(2)
		return

	# Cross-check the reminder rule against real data: a reminder is due exactly
	# when the room is live and carries a usable live_time (nothing confirmed).
	var expected := (
		live_status == StreamStatus.LIVE_STATUS_LIVE
		and not str(status.get("live_time", "")).is_empty()
	)
	if StreamStatus.should_remind(status, "") != expected:
		push_error(
			"STREAM_LIVE_SMOKE_REMIND_MISMATCH: status=%d live_time=%s"
			% [live_status, str(status.get("live_time", ""))]
		)
		quit(2)
		return

	print("STREAM_LIVE_SMOKE_OK")
	print(JSON.stringify(status))
	quit(0)


func _on_failed(message: String) -> void:
	finished = true
	push_error("STREAM_LIVE_SMOKE_FAILED: " + message)
	quit(2)
