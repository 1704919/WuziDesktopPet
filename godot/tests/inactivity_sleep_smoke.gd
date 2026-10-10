extends SceneTree

const InactivityManager = preload("res://scripts/inactivity_manager.gd")
const DreamTalkManager = preload("res://scripts/dream_talk_manager.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var inactivity := InactivityManager.new()
	inactivity.configure({
		"long_idle_minutes": 0.02,
		"rest_check_interval_sec": [1.0, 1.0],
		"sleepy_weight_multiplier": 4.0,
		"rest_baseline_weight": 3.0,
		"sleep_trigger_probability": 0.18,
		"sleep_loop_cycles": 5,
	}, 1000)
	check(not inactivity.is_long_idle(2199), "long idle threshold not early")
	check(inactivity.is_long_idle(2200), "long idle threshold exact")
	check(inactivity.adjusted_idle_weight("sleepy_video", 2.0, 2200) == 8.0, "sleepy weight boosted")
	check(inactivity.choose_long_idle_action(0.0, 0.99) == "sleep", "sleep probability branch")
	check(inactivity.choose_long_idle_action(1.0, 0.0) == "sleepy", "sleepy weighted branch")
	check(inactivity.choose_long_idle_action(1.0, 0.99) == "", "rest no-op branch")
	check(inactivity.sleep_loop_cycles == 5, "sleep loop target five")

	inactivity.note_user_activity(2000)
	check(not inactivity.is_long_idle(3199), "activity resets long idle")
	check(inactivity.is_long_idle(3200), "activity reset threshold")
	var frozen_activity := inactivity.last_activity_ms
	inactivity.set_sleep_frozen(true)
	inactivity.note_user_activity(9999)
	check(inactivity.last_activity_ms == frozen_activity, "sleep freezes user activity timer")
	check(not inactivity.is_long_idle(9999), "frozen sleep never becomes long idle")
	inactivity.finish_sleep(10000)
	check(not inactivity.frozen and inactivity.last_activity_ms == 10000, "wake restarts timer")
	check(not inactivity.is_long_idle(11199) and inactivity.is_long_idle(11200), "wake threshold restarts from zero")

	var dream := DreamTalkManager.new()
	dream.configure({
		"chat": {"responses": ["我听见你说话了"]},
		"reminder": {"prefixes": ["好像有人提醒我"]},
		"weather": {"prefixes": ["外面的天气在说话"]},
		"fallback": {"prefixes": ["我听到了"]},
	})
	dream.set_seed(7)
	var chat := dream.chat_reply("")
	check(chat.contains("..."), "dream chat receives ellipsis")
	var weather := dream.format_notice("weather", "降雨概率 80%，气温 23°C。")
	check(weather.contains("..."), "dream weather receives ellipsis")
	check(weather.contains("80%") and weather.contains("23°C"), "dream ellipsis preserves weather tokens")

	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	check(scene.inactivity_manager.sleep_loop_cycles == 5, "scene config loop target")
	check(scene.inactivity_manager.long_idle_ms == 20 * 60 * 1000, "scene config twenty minutes")

	scene.sleep_phase = "waiting_loop"
	scene.state = scene.PetState.SLEEPING
	scene.inactivity_manager.set_sleep_frozen(true)
	scene.action_coordinator.cancel("test")
	scene.call("_handle_command_text", "晚安")
	await process_frame
	check(scene.sleep_phase == "waiting_loop", "chat does not wake sleeping pet")
	check(not scene.action_coordinator.is_busy(), "dream chat does not request normal dialogue action")
	check(scene.bubble.current_text.contains("..."), "sleep chat displays dream text")

	scene.call("_on_reminder_due", "喝点水吧，温度 23°C。")
	await process_frame
	check(scene.sleep_phase == "waiting_loop", "reminder does not wake sleeping pet")
	var reminder_pages := "".join(scene.bubble.pages).replace("\n", "")
	check(reminder_pages.contains("23°C"), "sleep reminder keeps core content across pages")

	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	scene.call("_input", right_click)
	await process_frame
	check(scene.sleep_phase == "waiting_loop", "right click menu does not wake sleeping pet")

	scene.call("_on_files_dropped", PackedStringArray())
	await process_frame
	check(scene.sleep_phase == "none", "file drop wakes waiting sleep")
	check(int(scene.state) == int(scene.PetState.IDLE), "file drop returns fallback sleep to idle")

	# Inject tiny in-memory clips only in this test process. Formal catalog/config
	# stays waiting_video; this verifies the already-prepared future path.
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
