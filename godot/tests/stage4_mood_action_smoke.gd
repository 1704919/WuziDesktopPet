extends SceneTree

const MoodManager = preload("res://scripts/mood_manager.gd")
const ActionRegistry = preload("res://scripts/action_registry.gd")
const ActionCoordinator = preload("res://scripts/action_coordinator.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var mood := MoodManager.new()
	root.add_child(mood)
	mood.configure({
		"click_window_ms": 1000,
		"recovery_interval_sec": 60.0,
		"recovery_step": 5.0
	})
	await process_frame

	var click: Dictionary = mood.register_click(1000)
	check(click.click_count == 1 and click.tier == "normal", "click 1 normal")
	click = mood.register_click(1100)
	check(click.click_count == 2 and click.tier == "normal", "click 2 normal")
	click = mood.register_click(1200)
	check(click.click_count == 3 and click.tier == "shy", "click 3 shy")
	check(click.mood == "shy", "shy mood active")
	mood.register_click(1300)
	mood.register_click(1400)
	click = mood.register_click(1500)
	check(click.click_count == 6 and click.tier == "angry", "click 6 angry")
	check(click.action_id == "click_angry_video", "angry action selected")
	check(click.mood == "angry", "angry mood active")

	var reset_click: Dictionary = mood.register_click(2601)
	check(reset_click.click_count == 1, "click window reset")

	var happy := mood.apply_event("happy", 2700)
	check(happy.mood == "happy", "happy mood event active")

	for _index in range(40):
		mood.apply_event("angry", 3000)
	check(mood.mood_score >= mood.min_score, "score lower bound")
	var before_recover := absf(mood.mood_score)
	mood.recover_once(20000)
	check(absf(mood.mood_score) < before_recover, "score recovers toward zero")

	var registry := ActionRegistry.new()
	root.add_child(registry)
	registry.load_catalog()
	var coordinator := ActionCoordinator.new()
	root.add_child(coordinator)
	coordinator.configure(registry, {"duplicate_merge_ms": 50})

	var wake: Dictionary = coordinator.request_action("wake_up", "test", 100, 1000)
	check(wake.accepted and wake.action_id == "wake_up_video", "wake alias resolves")
	coordinator.cancel("test")
	var sleep_loop: Dictionary = coordinator.request_action("sleep_loop", "test", 100, 1200)
	check(sleep_loop.accepted and sleep_loop.action_id == "sleep_loop_video", "sleep loop alias resolves")
	coordinator.cancel("test")

	var yawn: Dictionary = coordinator.request_action("yawn", "dialogue", 50, 2000)
	check(yawn.accepted and yawn.action_id == "yawn_video", "alias resolves to runtime clip")
	var blocked: Dictionary = coordinator.request_action("idle", "idle", 10, 2100)
	check(not blocked.accepted and blocked.reason == "blocked_by_priority", "low priority blocked")
	var preempt: Dictionary = coordinator.request_action("click_angry_video", "click", 60, 2200)
	check(preempt.accepted and preempt.action_id == "click_angry_video", "higher priority preempts")

	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	for clip_id in [
		"yawn_video",
		"click_angry_video",
		"drag_reaction_video",
		"sleep_down_video",
		"startle_video",
		"yawn_small_video",
		"game_rage_video",
		"click_wave_video",
		"sleep_loop_video",
		"wake_up_video",
		"sing_video"
	]:
		check(scene.clips.has(clip_id), "stage4 clip loaded: " + clip_id)

	check(scene.get_node_or_null("MoodIndicator") != null, "mood indicator exists")
	check(scene.mood_indicator.position.x > scene.base_position.x, "mood indicator is right of pet")
	check(scene.mood_indicator.position.distance_to(Vector2(644.0, 176.0)) < 1.0, "mood indicator uses compact pet-relative position")
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
