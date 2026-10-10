  1 | extends SceneTree
  2 | 
  3 | # End-to-end autonomous action policy. The baseline runner uses an isolated
  4 | # Godot copy and a separate user data folder; no production setting is changed.
  5 | var failures: Array[String] = []
  6 | 
  7 | 
  8 | func check(ok: bool, label: String) -> void:
  9 | 	if not ok:
 10 | 		failures.append(label)
 11 | 
 12 | 
 13 | func _init() -> void:
 14 | 	call_deferred("_run")
 15 | 
 16 | 
 17 | func _run() -> void:
 18 | 	var scene = load("res://scenes/main.tscn").instantiate()
 19 | 	root.add_child(scene)
 20 | 	await process_frame
 21 | 	await process_frame
 22 | 
 23 | 	var cfg := scene.config.get("idle_actions", {}) as Dictionary
 24 | 	var items := cfg.get("actions", []) as Array
 25 | 	check(bool(cfg.get("enabled", false)), "random_actions_should_be_enabled")
 26 | 	var interval := cfg.get("interval_sec", []) as Array
 27 | 	check(interval.size() == 2 and int(interval[0]) == 10 and int(interval[1]) == 20,
 28 | 		"ten_to_twenty_second_interval")
 29 | 	check(items.size() == 26, "exactly_26_random_actions")
 30 | 	var expected := {
 31 | 		"march_in_place_video": [2, "A"], "yawn_small_video": [4, "A"],
 32 | 		"yawn_video": [4, "A"],
 33 | 		"read_book": [2, "B"], "work_computer": [2, "B"],
 34 | 		"lie_phone": [4, "B"], "watch_kline": [4, "B"],
 35 | 		"sing": [4, "C"], "game_controller": [4, "C"],
 36 | 		"pc_game_focused": [4, "C"], "game_rage_video": [4, "C"],
 37 | 		"pc_game_rage": [4, "C"],
 38 | 		"drink_milk_tea": [4, "D"], "eat_breakfast": [3, "D"],
 39 | 		"eat_noodles": [3, "D"], "eat_fried_chicken": [3, "D"],
 40 | 		"eat_sushi": [3, "D"], "eat_bullfrog": [3, "D"],
 41 | 		"eat_fries": [3, "D"], "birthday_cake": [1, "D"],
 42 | 		"mic_test": [4, "E"], "hop_bounce": [4, "E"],
 43 | 		"unbox_cards": [4, "E"], "sunglasses_proud": [4, "E"],
 44 | 		"cat_accident": [4, "E"], "startle_video": [3, "E"],
 45 | 	}
 46 | 	var total := 0
 47 | 	var found: Dictionary = {}
 48 | 	for item in items:
 49 | 		var spec := item as Dictionary
 50 | 		var action_id := str(spec.get("id", ""))
 51 | 		check(not found.has(action_id), "unique_" + action_id)
 52 | 		found[action_id] = true
 53 | 		check(expected.has(action_id), "unexpected_" + action_id)
 54 | 		var resolved_id: String = scene.action_registry.resolve_action_id(action_id)
 55 | 		check(scene.action_registry.is_action_ready(action_id)
 56 | 			and not resolved_id.is_empty() and scene.clips.has(resolved_id),
 57 | 			"missing_clip_" + action_id)
 58 | 		if expected.has(action_id):
 59 | 			var expected_spec: Array = expected[action_id]
 60 | 			check(int(spec.get("weight", -1)) == int(expected_spec[0]), "weight_" + action_id)
 61 | 			check(str(spec.get("category", "")) == str(expected_spec[1]), "category_" + action_id)
 62 | 		total += int(spec.get("weight", 0))
 63 | 	check(total == 88, "weight_sum_88")
 64 | 	check(not found.has("sleepy_video"), "sleepy_only_from_sleep_system")
 65 | 	check(not found.has("sleep_down"), "sleep_chain_outside_random_pool")
 66 | 
 67 | 	# The menu only pauses autonomous behavior. Other reminders remain enabled.
 68 | 	var reminder_enabled: bool = bool(scene.reminder_manager.enabled)
 69 | 	var roaming_enabled: bool = bool(scene.roaming_controller.is_enabled())
 70 | 	scene.call("_set_autonomous_paused", true)
 71 | 	check(scene.random_actions_paused, "pause_flag_set")
 72 | 	check(scene.reminder_manager.chatter_paused, "random_chatter_paused")
 73 | 	check(scene.reminder_manager.enabled == reminder_enabled, "reminder_setting_unchanged")
 74 | 	check(scene.roaming_controller.is_enabled() == roaming_enabled, "roaming_setting_preserved")
 75 | 
 76 | 	# No countdown or wandering while paused, even with an overdue attempt.
 77 | 	scene.idle_action_countdown_sec = 0.1
 78 | 	scene.call("_update_roaming", 60.0)
 79 | 	check(not scene.roaming_controller.is_active(), "roaming_does_not_start_while_paused")
 80 | 	scene.call("_process", 1.0)
 81 | 	check(is_equal_approx(scene.idle_action_countdown_sec, 0.1), "random_timer_frozen")
 82 | 	check(not scene.sequence_running, "no_random_clip_while_paused")
 83 | 	scene.call("_start_random_idle_action")
 84 | 	check(not scene.sequence_running, "direct_random_call_guarded")
 85 | 
 86 | 	var reminder_events: Array[String] = []
 87 | 	scene.reminder_manager.reminder_due.connect(
 88 | 		func(text: String) -> void:
 89 | 			reminder_events.append(text)
 90 | 	)
 91 | 	scene.reminder_manager.random_chatter_enabled = true
 92 | 	scene.reminder_manager.random_messages = ["autonomous chatter probe"]
 93 | 	scene.reminder_manager.chatter_countdown_sec = 0.1
 94 | 	scene.reminder_manager.water_countdown_sec = 0.1
 95 | 	scene.reminder_manager._process(1.0)
 96 | 	check(reminder_events.has("喝点水吧，别一直盯着屏幕。"), "water_reminder_kept_while_paused")
 97 | 	check(not reminder_events.has("autonomous chatter probe"), "chatter_is_suspended")
 98 | 
 99 | 	# Sleep initiation is suspended, not the user's ability to play sleep clips.
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
