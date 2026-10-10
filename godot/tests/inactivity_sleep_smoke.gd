  1 | extends SceneTree
  2 | 
  3 | const InactivityManager = preload("res://scripts/inactivity_manager.gd")
  4 | const DreamTalkManager = preload("res://scripts/dream_talk_manager.gd")
  5 | 
  6 | var failures: Array[String] = []
  7 | 
  8 | 
  9 | func check(condition: bool, label: String) -> void:
 10 | 	if not condition:
 11 | 		failures.append(label)
 12 | 
 13 | 
 14 | func _init() -> void:
 15 | 	call_deferred("_run")
 16 | 
 17 | 
 18 | func _run() -> void:
 19 | 	var inactivity := InactivityManager.new()
 20 | 	inactivity.configure({
 21 | 		"long_idle_minutes": 0.02,
 22 | 		"rest_check_interval_sec": [1.0, 1.0],
 23 | 		"sleepy_weight_multiplier": 4.0,
 24 | 		"rest_baseline_weight": 3.0,
 25 | 		"sleep_trigger_probability": 0.18,
 26 | 		"sleep_loop_cycles": 5,
 27 | 	}, 1000)
 28 | 	check(not inactivity.is_long_idle(2199), "long idle threshold not early")
 29 | 	check(inactivity.is_long_idle(2200), "long idle threshold exact")
 30 | 	check(inactivity.adjusted_idle_weight("sleepy_video", 2.0, 2200) == 8.0, "sleepy weight boosted")
 31 | 	check(inactivity.choose_long_idle_action(0.0, 0.99) == "sleep", "sleep probability branch")
 32 | 	check(inactivity.choose_long_idle_action(1.0, 0.0) == "sleepy", "sleepy weighted branch")
 33 | 	check(inactivity.choose_long_idle_action(1.0, 0.99) == "", "rest no-op branch")
 34 | 	check(inactivity.sleep_loop_cycles == 5, "sleep loop target five")
 35 | 
 36 | 	inactivity.note_user_activity(2000)
 37 | 	check(not inactivity.is_long_idle(3199), "activity resets long idle")
 38 | 	check(inactivity.is_long_idle(3200), "activity reset threshold")
 39 | 	var frozen_activity := inactivity.last_activity_ms
 40 | 	inactivity.set_sleep_frozen(true)
 41 | 	inactivity.note_user_activity(9999)
 42 | 	check(inactivity.last_activity_ms == frozen_activity, "sleep freezes user activity timer")
 43 | 	check(not inactivity.is_long_idle(9999), "frozen sleep never becomes long idle")
 44 | 	inactivity.finish_sleep(10000)
 45 | 	check(not inactivity.frozen and inactivity.last_activity_ms == 10000, "wake restarts timer")
 46 | 	check(not inactivity.is_long_idle(11199) and inactivity.is_long_idle(11200), "wake threshold restarts from zero")
 47 | 
 48 | 	var dream := DreamTalkManager.new()
 49 | 	dream.configure({
 50 | 		"chat": {"responses": ["我听见你说话了"]},
 51 | 		"reminder": {"prefixes": ["好像有人提醒我"]},
 52 | 		"weather": {"prefixes": ["外面的天气在说话"]},
 53 | 		"fallback": {"prefixes": ["我听到了"]},
 54 | 	})
 55 | 	dream.set_seed(7)
 56 | 	var chat := dream.chat_reply("")
 57 | 	check(chat.contains("..."), "dream chat receives ellipsis")
 58 | 	var weather := dream.format_notice("weather", "降雨概率 80%，气温 23°C。")
 59 | 	check(weather.contains("..."), "dream weather receives ellipsis")
 60 | 	check(weather.contains("80%") and weather.contains("23°C"), "dream ellipsis preserves weather tokens")
 61 | 
 62 | 	var scene = load("res://scenes/main.tscn").instantiate()
 63 | 	root.add_child(scene)
 64 | 	await process_frame
 65 | 	await process_frame
 66 | 
 67 | 	check(scene.inactivity_manager.sleep_loop_cycles == 5, "scene config loop target")
 68 | 	check(scene.inactivity_manager.long_idle_ms == 20 * 60 * 1000, "scene config twenty minutes")
 69 | 
 70 | 	scene.sleep_phase = "waiting_loop"
 71 | 	scene.state = scene.PetState.SLEEPING
 72 | 	scene.inactivity_manager.set_sleep_frozen(true)
 73 | 	scene.action_coordinator.cancel("test")
 74 | 	scene.call("_handle_command_text", "晚安")
 75 | 	await process_frame
 76 | 	check(scene.sleep_phase == "waiting_loop", "chat does not wake sleeping pet")
 77 | 	check(not scene.action_coordinator.is_busy(), "dream chat does not request normal dialogue action")
 78 | 	check(scene.bubble.current_text.contains("..."), "sleep chat displays dream text")
 79 | 
 80 | 	scene.call("_on_reminder_due", "喝点水吧，温度 23°C。")
 81 | 	await process_frame
 82 | 	check(scene.sleep_phase == "waiting_loop", "reminder does not wake sleeping pet")
 83 | 	var reminder_pages := "".join(scene.bubble.pages).replace("\n", "")
 84 | 	check(reminder_pages.contains("23°C"), "sleep reminder keeps core content across pages")
 85 | 
 86 | 	var right_click := InputEventMouseButton.new()
 87 | 	right_click.button_index = MOUSE_BUTTON_RIGHT
 88 | 	right_click.pressed = true
 89 | 	scene.call("_input", right_click)
 90 | 	await process_frame
 91 | 	check(scene.sleep_phase == "waiting_loop", "right click menu does not wake sleeping pet")
 92 | 
 93 | 	scene.call("_on_files_dropped", PackedStringArray())
 94 | 	await process_frame
 95 | 	check(scene.sleep_phase == "none", "file drop wakes waiting sleep")
 96 | 	check(int(scene.state) == int(scene.PetState.IDLE), "file drop returns fallback sleep to idle")
 97 | 
 98 | 	# Inject tiny in-memory clips only in this test process. Formal catalog/config
 99 | 	# stays waiting_video; this verifies the already-prepared future path.
	var actions := scene.action_registry.catalog.get("actions", {}) as Dictionary
	actions["sleep_loop"] = {"ready": true, "status": "test"}
	actions["wake_up"] = {"ready": true, "status": "test"}
	var frame_path := "res://assets_display/wuzi_chibi/video_idle/frames/000.png"
	var frame_texture := load(frame_path) as Texture2D
	scene.clips["sleep_loop"] = {
		"frame_paths": [frame_path],
		"timing_ms": [8],
		"source_type": "green_screen_video",
		"render_mode": "direct",
		"frames_dir": "res://assets_display/wuzi_chibi/video_idle/frames",
		"start_texture": frame_texture,
		"loop": true,
	}
	scene.clips["wake_up"] = {
		"frame_paths": [frame_path],
		"timing_ms": [8],
		"source_type": "green_screen_video",
		"render_mode": "direct",
		"frames_dir": "res://assets_display/wuzi_chibi/video_idle/frames",
		"start_texture": frame_texture,
		"loop": false,
	}
	scene.action_coordinator.cancel("test_setup")
	scene.sleep_phase = "looping"
	scene.state = scene.PetState.SLEEPING
	scene.inactivity_manager.set_sleep_frozen(true)
	var before_auto_wake := Time.get_ticks_msec()
	var loop_started := bool(scene.call(
		"_request_coordinated_clip",
		"sleep_loop",
		"test_sleep_loop",
		scene.ACTION_PRIORITY_SLEEP,
		false,
		scene.PetState.SLEEPING
	))
	check(loop_started, "synthetic sleep loop starts")
	await create_timer(0.35).timeout
	check(scene.sleep_phase == "none", "five sleep loops auto wake")
	check(int(scene.state) == int(scene.PetState.IDLE), "auto wake returns idle")
	check(not scene.inactivity_manager.frozen, "auto wake unfreezes inactivity")
	check(scene.inactivity_manager.last_activity_ms >= before_auto_wake, "auto wake restarts inactivity clock")

	if failures.is_empty():
		print("INACTIVITY_SLEEP_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(2)
