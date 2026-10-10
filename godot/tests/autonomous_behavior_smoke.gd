extends SceneTree

# End-to-end autonomous action policy. The baseline runner uses an isolated
# Godot copy and a separate user data folder; no production setting is changed.
var failures: Array[String] = []


func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var cfg := scene.config.get("idle_actions", {}) as Dictionary
	var items := cfg.get("actions", []) as Array
	check(bool(cfg.get("enabled", false)), "random_actions_should_be_enabled")
	var interval := cfg.get("interval_sec", []) as Array
	check(interval.size() == 2 and int(interval[0]) == 10 and int(interval[1]) == 20,
		"ten_to_twenty_second_interval")
	check(items.size() == 26, "exactly_26_random_actions")
	var expected := {
		"march_in_place_video": [2, "A"], "yawn_small_video": [4, "A"],
		"yawn_video": [4, "A"],
		"read_book": [2, "B"], "work_computer": [2, "B"],
		"lie_phone": [4, "B"], "watch_kline": [4, "B"],
		"sing": [4, "C"], "game_controller": [4, "C"],
		"pc_game_focused": [4, "C"], "game_rage_video": [4, "C"],
		"pc_game_rage": [4, "C"],
		"drink_milk_tea": [4, "D"], "eat_breakfast": [3, "D"],
		"eat_noodles": [3, "D"], "eat_fried_chicken": [3, "D"],
		"eat_sushi": [3, "D"], "eat_bullfrog": [3, "D"],
		"eat_fries": [3, "D"], "birthday_cake": [1, "D"],
		"mic_test": [4, "E"], "hop_bounce": [4, "E"],
		"unbox_cards": [4, "E"], "sunglasses_proud": [4, "E"],
		"cat_accident": [4, "E"], "startle_video": [3, "E"],
	}
	var total := 0
	var found: Dictionary = {}
	for item in items:
		var spec := item as Dictionary
		var action_id := str(spec.get("id", ""))
		check(not found.has(action_id), "unique_" + action_id)
		found[action_id] = true
		check(expected.has(action_id), "unexpected_" + action_id)
		var resolved_id: String = scene.action_registry.resolve_action_id(action_id)
		check(scene.action_registry.is_action_ready(action_id)
			and not resolved_id.is_empty() and scene.clips.has(resolved_id),
			"missing_clip_" + action_id)
		if expected.has(action_id):
			var expected_spec: Array = expected[action_id]
			check(int(spec.get("weight", -1)) == int(expected_spec[0]), "weight_" + action_id)
			check(str(spec.get("category", "")) == str(expected_spec[1]), "category_" + action_id)
		total += int(spec.get("weight", 0))
	check(total == 88, "weight_sum_88")
	check(not found.has("sleepy_video"), "sleepy_only_from_sleep_system")
	check(not found.has("sleep_down"), "sleep_chain_outside_random_pool")

	# The menu only pauses autonomous behavior. Other reminders remain enabled.
	var reminder_enabled: bool = bool(scene.reminder_manager.enabled)
	var roaming_enabled: bool = bool(scene.roaming_controller.is_enabled())
	scene.call("_set_autonomous_paused", true)
	check(scene.random_actions_paused, "pause_flag_set")
	check(scene.reminder_manager.chatter_paused, "random_chatter_paused")
	check(scene.reminder_manager.enabled == reminder_enabled, "reminder_setting_unchanged")
	check(scene.roaming_controller.is_enabled() == roaming_enabled, "roaming_setting_preserved")

	# No countdown or wandering while paused, even with an overdue attempt.
	scene.idle_action_countdown_sec = 0.1
	scene.call("_update_roaming", 60.0)
	check(not scene.roaming_controller.is_active(), "roaming_does_not_start_while_paused")
	scene.call("_process", 1.0)
	check(is_equal_approx(scene.idle_action_countdown_sec, 0.1), "random_timer_frozen")
	check(not scene.sequence_running, "no_random_clip_while_paused")
	scene.call("_start_random_idle_action")
	check(not scene.sequence_running, "direct_random_call_guarded")

	var reminder_events: Array[String] = []
	scene.reminder_manager.reminder_due.connect(
		func(text: String) -> void:
			reminder_events.append(text)
	)
	scene.reminder_manager.random_chatter_enabled = true
	scene.reminder_manager.random_messages = ["autonomous chatter probe"]
	scene.reminder_manager.chatter_countdown_sec = 0.1
	scene.reminder_manager.water_countdown_sec = 0.1
	scene.reminder_manager._process(1.0)
	check(reminder_events.has("喝点水吧，别一直盯着屏幕。"), "water_reminder_kept_while_paused")
	check(not reminder_events.has("autonomous chatter probe"), "chatter_is_suspended")

	# Sleep initiation is suspended, not the user's ability to play sleep clips.
	var now_ms := Time.get_ticks_msec()
	scene.inactivity_manager.configure(
		{"enabled": true, "long_idle_minutes": 0.02,
		 "rest_check_interval_sec": [1, 1], "sleep_trigger_probability": 1.0},
		now_ms - 3000
	)
	scene.call("_update_inactivity_rest")
	check(scene.sleep_phase == "none", "automatic_sleep_blocked_while_paused")
	scene.inactivity_manager.reset()

	scene.call("_set_autonomous_paused", false)
	check(not scene.random_actions_paused, "pause_flag_cleared")
	check(not scene.reminder_manager.chatter_paused, "chatter_resumes")
	check(scene.roaming_controller.is_enabled() == roaming_enabled, "roaming_preference_after_resume")
	check(scene.idle_action_countdown_sec >= 10.0 and scene.idle_action_countdown_sec <= 20.0,
		"fresh_random_timer_on_resume")

	# If wandering is already underway, pausing should stop it immediately,
	# without changing the user's separate roaming-enabled preference.
	var started_roaming := bool(scene.call(
		"_request_coordinated_clip",
		"walk_left",
		"roaming",
		scene.ACTION_PRIORITY_ROAMING,
		true,
		scene.PetState.ROAMING
	))
	check(started_roaming, "roaming_test_clip_starts")
	if started_roaming:
		check(scene.roaming_controller.mark_started("walk_left"), "roaming_controller_starts")
		scene.call("_set_autonomous_paused", true)
		check(not scene.roaming_controller.is_active(), "active_roaming_stopped_by_pause")
		check(scene.state == scene.PetState.IDLE, "roaming_returns_idle_when_paused")
		check(scene.roaming_controller.is_enabled() == roaming_enabled,
			"pause_does_not_disable_roaming_preference")
		scene.call("_set_autonomous_paused", false)

	# An open chat/menu is a temporary interactive guard: an overdue draw
	# must not close or interrupt a user's controls.
	scene.overlay_interactive = true
	scene.idle_action_countdown_sec = 0.1
	scene.call("_process", 1.0)
	check(is_equal_approx(scene.idle_action_countdown_sec, 0.1),
		"interactive_overlay_freezes_random_timer")
	check(not scene.sequence_running, "interactive_overlay_not_preempted")
	scene.overlay_interactive = false

	# Simulate two completed selections from food and demand another category.
	scene.last_idle_action_id = "eat_fries"
	scene.last_idle_action_category = "D"
	scene.idle_category_streak = 2
	scene.call("_start_random_idle_action")
	check(not scene.last_idle_action_id.is_empty(), "draw_selected")
	check(scene.last_idle_action_category != "D", "third_draw_category_changes")
	check(scene.idle_category_streak == 1, "new_category_count_starts_at_one")
	check(scene.sequence_running, "draw_starts_a_clip")
	scene.call("_cancel_active_action")
	scene.call("_return_to_idle", false)
	check(scene.idle_action_countdown_sec >= 10.0 and scene.idle_action_countdown_sec <= 20.0,
		"timer_restarts_when_clip_finishes")

	if failures.is_empty():
		print("AUTONOMOUS_BEHAVIOR_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error("autonomous_behavior: " + failure)
		quit(2)
