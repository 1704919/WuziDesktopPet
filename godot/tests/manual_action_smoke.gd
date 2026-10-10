  1 | extends SceneTree
  2 | 
  3 | func _init() -> void:
  4 | 	call_deferred("_run")
  5 | 
  6 | 
  7 | func _run() -> void:
  8 | 	var scene = load("res://scenes/main.tscn").instantiate()
  9 | 	root.add_child(scene)
 10 | 	await process_frame
 11 | 	await process_frame
 12 | 
 13 | 	var failures: Array[String] = []
 14 | 
 15 | 	if scene.clips.has("blink"):
 16 | 		failures.append("legacy_blink_loaded")
 17 | 	if scene.clips.has("shocked_native"):
 18 | 		failures.append("legacy_shocked_loaded")
 19 | 	if scene.clips.has("click_bounce"):
 20 | 		failures.append("legacy_bounce_loaded")
 21 | 
 22 | 	for node_path in [
 23 | 		"PetVisual/BodyPivot/FaceOverlayA",
 24 | 		"PetVisual/BodyPivot/FaceOverlayB",
 25 | 		"PetVisual/BodyPivot/BlushOverlay"
 26 | 	]:
 27 | 		if scene.get_node_or_null(node_path) != null:
 28 | 			failures.append("legacy_runtime_node:" + node_path)
 29 | 
 30 | 	for expected_clip in ["click_happy_video", "click_shy_video", "march_in_place_video", "sleepy_video", "yawn_video", "click_angry_video", "drag_reaction_video", "sleep_down_video", "unbox_cards", "pc_game_rage", "sunglasses_proud", "pc_game_focused", "hop_bounce", "birthday_cake", "eat_noodles", "eat_fried_chicken", "eat_sushi", "eat_breakfast", "eat_bullfrog", "eat_fries"]:
 31 | 		if not scene.clips.has(expected_clip):
 32 | 			failures.append("current_clip_missing:" + expected_clip)
 33 | 
 34 | 	for clip_id in scene.clips.keys():
 35 | 		var clip := scene.clips[clip_id] as Dictionary
 36 | 		if str(clip.get("source_type", "")) != "green_screen_video":
 37 | 			failures.append("non_video_clip_loaded:" + str(clip_id))
 38 | 		if str(clip.get("render_mode", "")) != "direct":
 39 | 			failures.append("non_direct_clip_loaded:" + str(clip_id))
 40 | 		if not str(clip.get("frames_dir", "")).begins_with(
 41 | 			"res://assets_display/wuzi_chibi/video_"
 42 | 		):
 43 | 			failures.append("legacy_clip_path_loaded:" + str(clip_id))
 44 | 		if (clip.get("frame_paths", []) as Array).size() != 121:
 45 | 			failures.append("wrong_frame_count_loaded:" + str(clip_id))
 46 | 		if clip.has("textures"):
 47 | 			failures.append("clip_preloaded_textures:" + str(clip_id))
 48 | 
 49 | 	var happy := {
 50 | 		"id": "click_happy_video",
 51 | 		"label": "开心",
 52 | 		"kind": "clip"
 53 | 	}
 54 | 	scene.call("_play_manual_action", happy)
 55 | 	await process_frame
 56 | 
 57 | 	if not scene.sequence_running:
 58 | 		failures.append("happy_not_running")
 59 | 	if int(scene.state) != int(scene.PetState.REACTION):
 60 | 		failures.append("happy_wrong_state")
 61 | 
 62 | 	scene.call("_cancel_active_action")
 63 | 	await process_frame
 64 | 
 65 | 	for action_id in ["click_shy_video", "march_in_place_video", "sleepy_video", "yawn_video", "click_angry_video", "drag_reaction_video", "sleep_down_video", "unbox_cards", "pc_game_rage", "sunglasses_proud", "pc_game_focused", "hop_bounce", "birthday_cake", "eat_noodles", "eat_fried_chicken", "eat_sushi", "eat_breakfast", "eat_bullfrog", "eat_fries"]:
 66 | 		var current := {
 67 | 			"id": action_id,
 68 | 			"label": action_id,
 69 | 			"kind": "clip"
 70 | 		}
 71 | 		scene.call("_play_manual_action", current)
 72 | 		await process_frame
 73 | 		if not scene.sequence_running:
 74 | 			failures.append(action_id + ":not_running")
 75 | 		if int(scene.state) != int(scene.PetState.REACTION):
 76 | 			failures.append(action_id + ":wrong_state")
 77 | 		scene.call("_cancel_active_action")
 78 | 		await process_frame
 79 | 
 80 | 	# Ordinary action-to-action preemption must keep the outgoing visual until
 81 | 	# the fully transparent midpoint instead of flashing through idle.
 82 | 	scene.video_runtime_enabled = false
 83 | 	scene.call("_cancel_active_action")
 84 | 	await process_frame
 85 | 	var first_transition_started := bool(scene.call(
 86 | 		"_request_coordinated_clip",
 87 | 		"march_in_place_video",
 88 | 		"transition_preempt_smoke",
 89 | 		scene.ACTION_PRIORITY_MANUAL,
 90 | 		true,
 91 | 		scene.PetState.REACTION
 92 | 	))
 93 | 	if not first_transition_started:
 94 | 		failures.append("transition_preempt_first_not_started")
 95 | 	await create_timer(0.22).timeout
 96 | 	if scene.active_hit_action_id != "march_in_place_video":
 97 | 		failures.append("transition_preempt_first_not_visible")
 98 | 
 99 | 	var second_transition_started := bool(scene.call(
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
