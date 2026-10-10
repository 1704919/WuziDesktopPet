extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var failures: Array[String] = []

	if scene.clips.has("blink"):
		failures.append("legacy_blink_loaded")
	if scene.clips.has("shocked_native"):
		failures.append("legacy_shocked_loaded")
	if scene.clips.has("click_bounce"):
		failures.append("legacy_bounce_loaded")

	for node_path in [
		"PetVisual/BodyPivot/FaceOverlayA",
		"PetVisual/BodyPivot/FaceOverlayB",
		"PetVisual/BodyPivot/BlushOverlay"
	]:
		if scene.get_node_or_null(node_path) != null:
			failures.append("legacy_runtime_node:" + node_path)

	for expected_clip in ["click_happy_video", "click_shy_video", "march_in_place_video", "sleepy_video", "yawn_video", "click_angry_video", "drag_reaction_video", "sleep_down_video", "unbox_cards", "pc_game_rage", "sunglasses_proud", "pc_game_focused", "hop_bounce", "birthday_cake", "eat_noodles", "eat_fried_chicken", "eat_sushi", "eat_breakfast", "eat_bullfrog", "eat_fries"]:
		if not scene.clips.has(expected_clip):
			failures.append("current_clip_missing:" + expected_clip)

	for clip_id in scene.clips.keys():
		var clip := scene.clips[clip_id] as Dictionary
		if str(clip.get("source_type", "")) != "green_screen_video":
			failures.append("non_video_clip_loaded:" + str(clip_id))
		if str(clip.get("render_mode", "")) != "direct":
			failures.append("non_direct_clip_loaded:" + str(clip_id))
		if not str(clip.get("frames_dir", "")).begins_with(
			"res://assets_display/wuzi_chibi/video_"
		):
			failures.append("legacy_clip_path_loaded:" + str(clip_id))
		if (clip.get("frame_paths", []) as Array).size() != 121:
			failures.append("wrong_frame_count_loaded:" + str(clip_id))
		if clip.has("textures"):
			failures.append("clip_preloaded_textures:" + str(clip_id))

	var happy := {
		"id": "click_happy_video",
		"label": "开心",
		"kind": "clip"
	}
	scene.call("_play_manual_action", happy)
	await process_frame

	if not scene.sequence_running:
		failures.append("happy_not_running")
	if int(scene.state) != int(scene.PetState.REACTION):
		failures.append("happy_wrong_state")

	scene.call("_cancel_active_action")
	await process_frame

	for action_id in ["click_shy_video", "march_in_place_video", "sleepy_video", "yawn_video", "click_angry_video", "drag_reaction_video", "sleep_down_video", "unbox_cards", "pc_game_rage", "sunglasses_proud", "pc_game_focused", "hop_bounce", "birthday_cake", "eat_noodles", "eat_fried_chicken", "eat_sushi", "eat_breakfast", "eat_bullfrog", "eat_fries"]:
		var current := {
			"id": action_id,
			"label": action_id,
			"kind": "clip"
		}
		scene.call("_play_manual_action", current)
		await process_frame
		if not scene.sequence_running:
			failures.append(action_id + ":not_running")
		if int(scene.state) != int(scene.PetState.REACTION):
			failures.append(action_id + ":wrong_state")
		scene.call("_cancel_active_action")
		await process_frame

	# Ordinary action-to-action preemption must keep the outgoing visual until
	# the fully transparent midpoint instead of flashing through idle.
	scene.video_runtime_enabled = false
	scene.call("_cancel_active_action")
	await process_frame
	var first_transition_started := bool(scene.call(
		"_request_coordinated_clip",
		"march_in_place_video",
		"transition_preempt_smoke",
		scene.ACTION_PRIORITY_MANUAL,
		true,
		scene.PetState.REACTION
	))
	if not first_transition_started:
		failures.append("transition_preempt_first_not_started")
	await create_timer(0.22).timeout
	if scene.active_hit_action_id != "march_in_place_video":
		failures.append("transition_preempt_first_not_visible")

	var second_transition_started := bool(scene.call(
		"_request_coordinated_clip",
		"yawn_video",
		"transition_preempt_smoke",
		scene.ACTION_PRIORITY_MANUAL,
		true,
		scene.PetState.REACTION
	))
	if not second_transition_started:
		failures.append("transition_preempt_second_not_started")
	await create_timer(0.03).timeout
	if scene.active_hit_action_id != "march_in_place_video":
		failures.append("transition_preempt_flushed_to_idle_before_midpoint")
	await create_timer(0.12).timeout
	if scene.active_hit_action_id != "yawn_video":
		failures.append("transition_preempt_did_not_switch_at_midpoint")
	scene.call("_cancel_active_action")
	await process_frame

	# Ordinary action transitions use a short body fade on both entry and return
	# to idle. Use a one-frame in-memory clip so this can be exercised quickly
	# without changing production assets/config.
	var fade_frame_path := "res://assets_display/wuzi_chibi/video_idle/frames/000.png"
	var fade_texture := load(fade_frame_path) as Texture2D
	scene.clips["march_in_place_video"] = {
		"frame_paths": [fade_frame_path],
		"timing_ms": [20],
		"source_type": "green_screen_video",
		"render_mode": "direct",
		"frames_dir": "res://assets_display/wuzi_chibi/video_idle/frames",
		"start_texture": fade_texture,
		"runtime_stream": null,
		"loop": false,
		"fps": 12.0,
		"frame_count": 1,
	}
	scene.action_coordinator.cancel("transition_fade_smoke")
	var fade_started := bool(scene.call(
		"_request_coordinated_clip",
		"march_in_place_video",
		"transition_fade_smoke",
		scene.ACTION_PRIORITY_MANUAL,
		true,
		scene.PetState.REACTION
	))
	if not fade_started:
		failures.append("transition_fade_clip_not_started")
	var min_transition_alpha := float(scene.body_pivot.modulate.a)
	for _index in range(26):
		await create_timer(0.02).timeout
		min_transition_alpha = minf(
			min_transition_alpha,
			float(scene.body_pivot.modulate.a)
		)
	if min_transition_alpha > 0.65:
		failures.append("ordinary_transition_did_not_dim_enough")
	if min_transition_alpha < 0.45:
		failures.append("ordinary_transition_dimmed_too_deep")
	if int(scene.state) != int(scene.PetState.IDLE):
		failures.append("ordinary_transition_did_not_return_idle")
	if scene.sequence_running:
		failures.append("ordinary_transition_sequence_still_running")
	if absf(float(scene.body_pivot.modulate.a) - 1.0) > 0.02:
		failures.append("ordinary_transition_alpha_not_restored")
	scene.video_runtime_enabled = true
	scene.call("_cancel_active_action")
	await process_frame

	var idle := {
		"id": "idle",
		"label": "待机",
		"kind": "idle"
	}
	scene.call("_play_manual_action", idle)
	await process_frame
	if int(scene.state) != int(scene.PetState.IDLE):
		failures.append("idle_wrong_state")

	if failures.is_empty():
		print("MANUAL_ACTION_VIDEO_ONLY_OK")
		quit(0)
	else:
		push_error("MANUAL_ACTION_VIDEO_ONLY_FAILED: %s" % ", ".join(failures))
		quit(2)
