  1 | extends SceneTree
  2 | 
  3 | const MoodManager = preload("res://scripts/mood_manager.gd")
  4 | const ActionRegistry = preload("res://scripts/action_registry.gd")
  5 | const ActionCoordinator = preload("res://scripts/action_coordinator.gd")
  6 | 
  7 | var failures: Array[String] = []
  8 | 
  9 | 
 10 | func check(condition: bool, label: String) -> void:
 11 | 	if not condition:
 12 | 		failures.append(label)
 13 | 
 14 | 
 15 | func _init() -> void:
 16 | 	call_deferred("_run")
 17 | 
 18 | 
 19 | func _run() -> void:
 20 | 	var mood := MoodManager.new()
 21 | 	root.add_child(mood)
 22 | 	mood.configure({
 23 | 		"click_window_ms": 1000,
 24 | 		"recovery_interval_sec": 60.0,
 25 | 		"recovery_step": 5.0
 26 | 	})
 27 | 	await process_frame
 28 | 
 29 | 	var click: Dictionary = mood.register_click(1000)
 30 | 	check(click.click_count == 1 and click.tier == "normal", "click 1 normal")
 31 | 	click = mood.register_click(1100)
 32 | 	check(click.click_count == 2 and click.tier == "normal", "click 2 normal")
 33 | 	click = mood.register_click(1200)
 34 | 	check(click.click_count == 3 and click.tier == "shy", "click 3 shy")
 35 | 	check(click.mood == "shy", "shy mood active")
 36 | 	mood.register_click(1300)
 37 | 	mood.register_click(1400)
 38 | 	click = mood.register_click(1500)
 39 | 	check(click.click_count == 6 and click.tier == "angry", "click 6 angry")
 40 | 	check(click.action_id == "click_angry_video", "angry action selected")
 41 | 	check(click.mood == "angry", "angry mood active")
 42 | 
 43 | 	var reset_click: Dictionary = mood.register_click(2601)
 44 | 	check(reset_click.click_count == 1, "click window reset")
 45 | 
 46 | 	var happy := mood.apply_event("happy", 2700)
 47 | 	check(happy.mood == "happy", "happy mood event active")
 48 | 
 49 | 	for _index in range(40):
 50 | 		mood.apply_event("angry", 3000)
 51 | 	check(mood.mood_score >= mood.min_score, "score lower bound")
 52 | 	var before_recover := absf(mood.mood_score)
 53 | 	mood.recover_once(20000)
 54 | 	check(absf(mood.mood_score) < before_recover, "score recovers toward zero")
 55 | 
 56 | 	var registry := ActionRegistry.new()
 57 | 	root.add_child(registry)
 58 | 	registry.load_catalog()
 59 | 	var coordinator := ActionCoordinator.new()
 60 | 	root.add_child(coordinator)
 61 | 	coordinator.configure(registry, {"duplicate_merge_ms": 50})
 62 | 
 63 | 	var wake: Dictionary = coordinator.request_action("wake_up", "test", 100, 1000)
 64 | 	check(wake.accepted and wake.action_id == "wake_up_video", "wake alias resolves")
 65 | 	coordinator.cancel("test")
 66 | 	var sleep_loop: Dictionary = coordinator.request_action("sleep_loop", "test", 100, 1200)
 67 | 	check(sleep_loop.accepted and sleep_loop.action_id == "sleep_loop_video", "sleep loop alias resolves")
 68 | 	coordinator.cancel("test")
 69 | 
 70 | 	var yawn: Dictionary = coordinator.request_action("yawn", "dialogue", 50, 2000)
 71 | 	check(yawn.accepted and yawn.action_id == "yawn_video", "alias resolves to runtime clip")
 72 | 	var blocked: Dictionary = coordinator.request_action("idle", "idle", 10, 2100)
 73 | 	check(not blocked.accepted and blocked.reason == "blocked_by_priority", "low priority blocked")
 74 | 	var preempt: Dictionary = coordinator.request_action("click_angry_video", "click", 60, 2200)
 75 | 	check(preempt.accepted and preempt.action_id == "click_angry_video", "higher priority preempts")
 76 | 
 77 | 	var scene = load("res://scenes/main.tscn").instantiate()
 78 | 	root.add_child(scene)
 79 | 	await process_frame
 80 | 	await process_frame
 81 | 
 82 | 	for clip_id in [
 83 | 		"yawn_video",
 84 | 		"click_angry_video",
 85 | 		"drag_reaction_video",
 86 | 		"sleep_down_video",
 87 | 		"startle_video",
 88 | 		"yawn_small_video",
 89 | 		"game_rage_video",
 90 | 		"click_wave_video",
 91 | 		"sleep_loop_video",
 92 | 		"wake_up_video",
 93 | 		"sing_video"
 94 | 	]:
 95 | 		check(scene.clips.has(clip_id), "stage4 clip loaded: " + clip_id)
 96 | 
 97 | 	check(scene.get_node_or_null("MoodIndicator") != null, "mood indicator exists")
 98 | 	check(scene.mood_indicator.position.x > scene.base_position.x, "mood indicator is right of pet")
 99 | 	check(scene.mood_indicator.position.distance_to(Vector2(644.0, 176.0)) < 1.0, "mood indicator uses compact pet-relative position")
	check(scene.mood_indicator.size.distance_to(Vector2(12.0, 160.0)) < 1.0, "mood indicator uses compact size")
	check(scene.mood_indicator.size.y > scene.mood_indicator.size.x * 10.0, "mood indicator is slim and vertical")
	check(
		float(scene.mood_indicator.call("get_score_marker_y")) > 0.0,
		"mood indicator marker position is valid"
	)
	var hover_polygon: PackedVector2Array = scene.mood_indicator.hover_polygon
	check(hover_polygon.size() >= 6, "mood indicator receives dynamic pet polygon")
	check(scene.mood_indicator.should_show_for_point(scene.base_position), "pet hover shows mood indicator")
	var indicator_control: Control = scene.get_node("MoodIndicator")
	var indicator_far_side: Vector2 = (
		indicator_control.position
		+ Vector2(indicator_control.size.x - 4.0, 8.0)
	)
	check(not scene.mood_indicator.should_show_for_point(indicator_far_side), "indicator-side hover alone does not show")
	check(scene.dynamic_hit_shapes_ready, "dynamic hit-shape catalog loaded")
	check(scene.debug_character_passthrough_polygon.size() >= 6, "character passthrough uses silhouette polygon")
	check(bool(scene.call("_sleep_loop_ready")), "complete sleep chain is ready")

	var started := bool(scene.call("_start_sleep_entry", "test", scene.ACTION_PRIORITY_MANUAL))
	check(started, "sleep entry uses existing material")
	check(scene.sleep_phase == "entering", "sleep entry phase")
	check(int(scene.state) == int(scene.PetState.SLEEPING), "sleep entry state")
	scene.call("_interrupt_sleep_by_user")
	await process_frame
	check(scene.sleep_phase == "none", "entering sleep interruption clears phase")
	check(int(scene.state) == int(scene.PetState.IDLE), "entering sleep interruption returns idle")
	check(not scene.sequence_running, "entering sleep interruption stops sequence")

	if failures.is_empty():
		print("STAGE4_MOOD_ACTION_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(2)
