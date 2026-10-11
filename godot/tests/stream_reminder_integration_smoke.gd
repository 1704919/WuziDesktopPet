extends SceneTree

# Main-scene integration check for the stream reminder.
#
# It drives the REAL main.tscn and the REAL manager, and replaces only the HTTP
# hop: a synthetic response is handed to the manager's completion handler, so
# parsing, the reminder signal, the bubble, the confirm button and the settings
# file are all the production ones and no network is involved.
#
# Covered: what switching rooms, switching the reminder off, an unanswered
# reminder, the confirm button and a restart do to the state.
#
#   godot --headless --path godot --script res://tests/stream_reminder_integration_smoke.gd

const StreamStatus = preload("res://scripts/stream_status.gd")
const StreamReplyFormatter = preload("res://scripts/stream_reply_formatter.gd")
const SETTINGS_PATH := "user://wuzi_pet_settings.json"

# The room the test starts on, and the one it switches to.
const ROOM_A := "510"
const ROOM_B := "80397"
const FIRST_BROADCAST := "2099-01-01 12:00:00"

var main
var manager
var failures: Array[String] = []
var reminders: Array = []
var updates := 0


func check(value: bool, label: String) -> void:
	if not value:
		failures.append(label)


func _init() -> void:
	call_deferred("_run")


# --- fixtures -------------------------------------------------------------

func room_info(
	live_status: int, live_time: String, room_id: String = ROOM_B
) -> Dictionary:
	return {
		"code": 0,
		"data": {
			"room_id": int(room_id),
			"short_id": int(ROOM_A),
			"uid": 7706705,
			"title": "示例标题",
			"area_name": "示例分区",
			"online": 1,
			"live_status": live_status,
			"live_time": live_time
		}
	}


func status_of(
	live_status: int,
	live_time: String,
	room_id: String = ROOM_B
) -> Dictionary:
	return StreamStatus.parse_room_info(
		room_info(live_status, live_time, room_id)
	)


# Answers whatever request is currently on its way. A response for a room the
# user has already left is exactly what note_request_started() plus a room
# switch is here to produce.
func answer(
	live_status: int, live_time: String, room_id: String = ROOM_B
) -> void:
	manager._on_status_completed(
		HTTPRequest.RESULT_SUCCESS,
		200,
		PackedStringArray(),
		JSON.stringify(
			room_info(live_status, live_time, room_id)
		).to_utf8_buffer()
	)


# A poll that left and came straight back.
func poll(
	live_status: int, live_time: String, room_id: String = ROOM_B
) -> void:
	manager.note_request_started()
	answer(live_status, live_time, room_id)


# Switches the reminder on without letting the automatic poll run: this test
# answers every request itself, so the real network stays out of it.
func watch(room: String, label: String = "") -> void:
	manager.set_room(room, label, true)
	manager.check_countdown_sec = 9999.0


func last_reminder() -> Dictionary:
	var entry: Dictionary = reminders[reminders.size() - 1]
	return entry


func bubble_action_labels() -> Array:
	var labels := []
	var row: Node = main.get_node_or_null("Bubble/Card/Margin/Content/Actions")
	if row == null:
		return labels
	for child in row.get_children():
		labels.append(str(child.text))
	return labels


func read_settings() -> Dictionary:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return {}
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if typeof(parsed) == TYPE_DICTIONARY else {}


func stream_settings() -> Dictionary:
	return read_settings().get("stream_reminder", {}) as Dictionary


func _on_reminder(text: String, repeated: bool) -> void:
	reminders.append({"text": text, "repeated": repeated})


func _on_updated(_status: Dictionary, _manual: bool) -> void:
	updates += 1


# --- cases ----------------------------------------------------------------

func _check_starting_state() -> void:
	# The settings file decides what the manager starts with. The baseline runner
	# isolates it, but a manual run can sit on top of a real one, so the test
	# takes ownership of the configuration before asserting anything.
	manager.set_room("", "", false)
	manager.confirmed_key = ""
	var updates_before := updates
	for _index in range(5):
		await process_frame

	check(manager.enabled == false, "starts_disabled")
	check(manager.room_query.is_empty(), "starts_without_a_room")
	check(updates == updates_before, "no_status_while_disabled")
	check(
		manager.status_request.get_http_client_status()
		== HTTPClient.STATUS_DISCONNECTED,
		"no_request_while_disabled"
	)


func _check_stale_answer_after_room_switch() -> void:
	watch(ROOM_A, "小舞")
	check(manager.room_query == ROOM_A, "watching_the_first_room")

	# A poll for the first room is on its way when the user switches away.
	manager.note_request_started()
	watch(ROOM_B, "小舞")

	# The late answer describes the room that was left behind, so it must change
	# nothing at all: not the cached canonical id, not the published status, and
	# certainly not a reminder for a room nobody is watching any more.
	answer(1, FIRST_BROADCAST, ROOM_A)
	await process_frame
	check(
		manager.resolved_room_id.is_empty(),
		"stale_answer_does_not_cache_the_old_room"
	)
	check(updates == 0, "stale_answer_is_not_published")
	check(reminders.is_empty(), "stale_answer_raises_no_reminder")
	check(manager.reminder_key.is_empty(), "stale_answer_leaves_no_question")

	# The room that is actually configured is still answered normally.
	poll(1, FIRST_BROADCAST, ROOM_B)
	await process_frame
	check(manager.resolved_room_id == ROOM_B, "current_answer_is_applied")
	check(updates == 1, "current_answer_is_published")
	check(reminders.size() == 1, "current_answer_asks")


func _check_stale_answer_after_switching_off() -> void:
	var reminders_before := reminders.size()
	var updates_before := updates

	# The same race, with the reminder switched off instead of moved.
	manager.note_request_started()
	manager.set_room(ROOM_B, "小舞", false)
	answer(1, FIRST_BROADCAST, ROOM_B)
	await process_frame

	check(manager.reminder_key.is_empty(), "no_question_after_switching_off")
	check(reminders.size() == reminders_before, "no_reminder_after_switching_off")
	check(updates == updates_before, "no_status_after_switching_off")
	# Nothing is left to answer, so a click that is still on screen cannot
	# silence the next broadcast either.
	check(not manager.confirm(), "nothing_left_to_confirm")


func _check_confirm_is_bound_to_the_broadcast() -> void:
	watch(ROOM_B, "小舞")
	var broadcast := "live|%s|%s" % [ROOM_B, FIRST_BROADCAST]
	var reminders_before := reminders.size()

	poll(1, FIRST_BROADCAST, ROOM_B)
	await process_frame
	check(reminders.size() == reminders_before + 1, "unanswered_broadcast_asks")
	check(last_reminder()["repeated"] == false, "first_ask_is_not_a_repeat")
	check(bubble_action_labels().has("知道啦"), "ask_offers_the_confirm_button")
	check(manager.reminder_key == broadcast, "question_tracks_the_broadcast")
	check(manager.confirmed_key.is_empty(), "nothing_is_confirmed_yet")

	# Unanswered, so the next poll asks again -- and marks it as a repeat, which
	# is what keeps the pet from animating on every single one.
	poll(1, FIRST_BROADCAST, ROOM_B)
	await process_frame
	check(reminders.size() == reminders_before + 2, "reminder_repeats_until_answered")
	check(last_reminder()["repeated"], "repeat_is_flagged_for_the_caller")
	check(
		absf(manager._effective_interval() - 30.0) < 0.01,
		"unanswered_reminder_asks_again_in_30s"
	)
	check(
		str(stream_settings().get("confirmed_key", "")).is_empty(),
		"an_unanswered_reminder_is_not_marked_as_told"
	)

	# Answering through the bubble signal, exactly like pressing the button.
	main.get_node("Bubble").action_selected.emit("stream_confirm")
	await process_frame
	check(manager.confirmed_key == broadcast, "confirm_binds_to_the_broadcast")
	check(manager.reminder_key.is_empty(), "confirm_retires_the_question")
	check(
		str(stream_settings().get("confirmed_key", "")) == broadcast,
		"confirm_is_written_to_settings"
	)

	# The broadcast that was answered stays quiet, and the cadence goes back to
	# normal because nothing is waiting for an answer any more.
	poll(1, FIRST_BROADCAST, ROOM_B)
	await process_frame
	check(reminders.size() == reminders_before + 2, "confirmed_broadcast_is_quiet")
	check(
		absf(manager._effective_interval() - manager.check_interval_sec) < 0.01,
		"cadence_back_to_normal_after_answering"
	)

	# One answer settles one broadcast, and only that one.
	poll(1, "2099-01-01 13:00:00", ROOM_B)
	await process_frame
	check(reminders.size() == reminders_before + 3, "the_next_broadcast_asks_again")

	# A click that arrives once the stream has ended must not silence anything.
	poll(0, "0000-00-00 00:00:00", ROOM_B)
	await process_frame
	check(manager.reminder_key.is_empty(), "question_is_dropped_when_offline")
	check(not manager.confirm(), "late_confirm_is_refused")
	check(manager.confirmed_key == broadcast, "late_confirm_changes_nothing")


func _check_room_switch_through_the_card() -> void:
	# The path a user actually takes. Saving with the reminder switched off makes
	# no request at all, which is what keeps this case offline and deterministic.
	main.call("_open_stream_window")
	await process_frame
	var card: Control = main.get_node("StreamBubble")
	var room_field: LineEdit = main.get_node("StreamBubble/Card/Margin/Content/Room")
	var toggle: CheckButton = main.get_node("StreamBubble/Card/Margin/Content/Enabled")
	check(card.visible, "settings_card_opens")
	check(room_field.text == manager.room_query, "card_shows_the_watched_room")
	check(toggle.button_pressed == manager.enabled, "card_shows_the_toggle")

	# A question is pending, and a canonical id is cached, for the old room.
	poll(1, "2099-01-01 14:00:00", ROOM_B)
	await process_frame
	check(not manager.reminder_key.is_empty(), "a_question_is_pending")
	check(manager.resolved_room_id == ROOM_B, "the_canonical_id_is_cached")

	room_field.text = ROOM_A
	toggle.button_pressed = false
	main.call("_on_stream_save_pressed")
	await create_timer(0.4).timeout

	check(not card.visible, "save_closes_the_card")
	check(manager.room_query == ROOM_A, "card_switch_changes_the_room")
	check(manager.enabled == false, "card_switch_switches_the_reminder_off")
	# Both belong to the room and the reminder that were left behind.
	check(manager.resolved_room_id.is_empty(), "card_switch_drops_the_cached_id")
	check(manager.reminder_key.is_empty(), "card_switch_drops_the_question")
	check(
		manager.status_request.get_http_client_status()
		== HTTPClient.STATUS_DISCONNECTED,
		"switching_off_makes_no_request"
	)
	check(str(stream_settings().get("room_query", "")) == ROOM_A, "switch_is_persisted")
	check(
		bool(stream_settings().get("enabled", true)) == false,
		"the_off_state_is_persisted"
	)


func _check_restart_restores_the_confirmation() -> void:
	# Restarting is main.tscn configuring a manager from the settings file, which
	# is what the second half of this case does without a second process.
	var broadcast := "live|%s|2099-01-01 15:00:00" % ROOM_B
	watch(ROOM_B, "小舞")
	manager.confirmed_key = ""
	poll(1, "2099-01-01 15:00:00", ROOM_B)
	await process_frame
	check(not manager.reminder_key.is_empty(), "restart_fixture_is_pending")
	main.get_node("Bubble").action_selected.emit("stream_confirm")
	await process_frame

	main.get_node("SettingsStore").set_value(
		"stream_reminder", manager.export_settings()
	)
	check(
		str(stream_settings().get("confirmed_key", "")) == broadcast,
		"the_answer_reaches_the_settings_file"
	)

	var script = load("res://scripts/stream_reminder_manager.gd")
	var restored = script.new()
	root.add_child(restored)
	# The restore path is what is under test, not the poll it would start.
	restored.set_process(false)
	restored.configure({}, stream_settings())

	check(restored.confirmed_key == broadcast, "restart_restores_the_answer")
	check(restored.enabled, "restart_restores_the_toggle")
	check(restored.room_query == ROOM_B, "restart_restores_the_room")
	check(restored.resolved_room_id == ROOM_B, "restart_restores_the_canonical_id")
	check(
		not StreamStatus.should_remind(
			status_of(1, "2099-01-01 15:00:00"), restored.confirmed_key
		),
		"restart_stays_quiet_for_the_broadcast_that_was_answered"
	)
	check(
		StreamStatus.should_remind(
			status_of(1, "2099-01-01 16:00:00"), restored.confirmed_key
		),
		"restart_asks_again_for_the_next_broadcast"
	)
	restored.queue_free()


func _check_settings_text() -> void:
	main.call("_open_stream_window")
	await process_frame
	await process_frame
	# The card animates open; measure once it has settled.
	await create_timer(0.4).timeout
	var hint: Label = main.get_node("StreamBubble/Card/Margin/Content/Hint")
	var cadence := StreamReplyFormatter.build_settings_hint(
		manager.check_interval_sec, manager.retry_interval_sec
	)
	check(hint.text == cadence, "hint_is_built_from_the_live_cadence")

	# The text has to describe what the code does: the reminder keeps coming back
	# until the button is pressed or the broadcast ends.
	check(hint.text.contains("知道啦"), "hint_names_the_confirm_button")
	check(hint.text.contains("没确认就每"), "hint_says_the_reminder_repeats")
	check(hint.text.contains("直到这场直播结束"), "hint_says_when_the_asking_stops")
	check(not hint.text.contains("不会重复提醒"), "hint_drops_the_once_only_claim")
	check(not hint.text.contains("提醒一次"), "hint_drops_the_single_ask_claim")

	# The card is a fixed size and its content box grows to fit the text, so a
	# wording that is one line too long would push the buttons past the panel.
	var card: Control = main.get_node("StreamBubble")
	var content: Control = main.get_node("StreamBubble/Card/Margin/Content")
	print(
		"STREAM_HINT_CARD card=%s lines=%s content=%s"
		% [card.size.y, hint.get_line_count(), content.size.y]
	)
	check(content.size.y <= card.size.y, "hint_still_fits_the_card")


func _finish() -> void:
	if failures.is_empty():
		print("STREAM_REMINDER_INTEGRATION_SMOKE_OK")
		quit(0)
	else:
		for label in failures:
			push_error("stream_reminder_integration: " + label)
		quit(2)


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	main = packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	manager = main.get_node_or_null("StreamReminderManager")
	check(manager != null, "manager_node_present")
	if manager == null:
		_finish()
		return

	manager.reminder_due.connect(_on_reminder)
	manager.stream_updated.connect(_on_updated)
	# The reminder is only ever built from the response path, so nothing here
	# waits on a real poll.

	await _check_starting_state()
	await _check_stale_answer_after_room_switch()
	await _check_stale_answer_after_switching_off()
	await _check_confirm_is_bound_to_the_broadcast()
	await _check_room_switch_through_the_card()
	await _check_restart_restores_the_confirmation()
	await _check_settings_text()

	_finish()
