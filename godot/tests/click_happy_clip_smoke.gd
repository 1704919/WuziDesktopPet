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
 14 | 	var clips: Dictionary = scene.clips
 15 | 	if not clips.has("click_happy_video"):
 16 | 		failures.append("click_happy_clip_missing")
 17 | 	else:
 18 | 		var clip := clips["click_happy_video"] as Dictionary
 19 | 		var frame_paths := clip.get("frame_paths", []) as Array
 20 | 		var timings := clip.get("timing_ms", []) as Array
 21 | 		if frame_paths.size() != 121:
 22 | 			failures.append("click_happy_frame_count:%d" % frame_paths.size())
 23 | 		if timings.size() != 121:
 24 | 			failures.append("click_happy_timing_count:%d" % timings.size())
 25 | 		if clip.has("textures"):
 26 | 			failures.append("click_happy_preloaded_textures")
 27 | 		if not timings.is_empty() and abs(int(timings[0]) - 83) > 1:
 28 | 			failures.append("click_happy_wrong_frame_timing")
 29 | 		if str(clip.get("source_type", "")) != "green_screen_video":
 30 | 			failures.append("click_happy_not_video")
 31 | 		if str(clip.get("render_mode", "")) != "direct":
 32 | 			failures.append("click_happy_not_direct")
 33 | 		if not str(clip.get("frames_dir", "")).begins_with(
 34 | 			"res://assets_display/wuzi_chibi/video_"
 35 | 		):
 36 | 			failures.append("click_happy_legacy_path")
 37 | 
 38 | 	# The long click-reaction clip keeps its cooldown, but Q-bounce must respond
 39 | 	# to every click. Exercise the bounce deterministically at 60 fps so the
 40 | 	# regression test does not depend on headless frame timing.
 41 | 	scene.call("_trigger_click_reaction")
 42 | 	await process_frame
 43 | 	var first_token := int(scene.sequence_token)
 44 | 	if scene.active_clip_uses_visual_fade:
 45 | 		failures.append("click_reaction_should_not_use_action_fade")
 46 | 	if absf(float(scene.body_pivot.modulate.a) - 1.0) > 0.001:
 47 | 		failures.append("click_reaction_changed_body_alpha")
 48 | 	if not scene.sequence_running:
 49 | 		failures.append("first_click_not_running")
 50 | 	if not scene.click_squash_active:
 51 | 		failures.append("first_click_q_bounce_not_started")
 52 | 	var start_texture: Texture2D = scene.pet_sprite.texture
 53 | 	var runtime_mode := bool(scene.video_runtime_enabled and scene._runtime_video_is_active())
 54 | 
 55 | 	# Reach the rebound phase.
 56 | 	for _i in range(7):
 57 | 		scene.call("_update_click_squash", 1.0 / 60.0)
 58 | 	var before_retrigger_y: float = float(scene.body_pivot.scale.y)
 59 | 	if before_retrigger_y <= scene.CLICK_SQUASH_SCALE_Y + 0.03:
 60 | 		failures.append("click_squash_never_entered_rebound")
 61 | 
 62 | 	# A rapid second click must NOT restart/cancel the video clip, and must NOT
 63 | 	# snap the body directly back to 55%. It restarts compression from the
 64 | 	# current visual scale.
 65 | 	scene.call("_trigger_click_reaction")
 66 | 	var after_retrigger_y: float = float(scene.body_pivot.scale.y)
 67 | 	if int(scene.sequence_token) != first_token:
 68 | 		failures.append("double_click_restarted_clip")
 69 | 	if not scene.sequence_running:
 70 | 		failures.append("double_click_cancelled_clip")
 71 | 	if not scene.click_squash_active or int(scene.click_squash_phase) != 0:
 72 | 		failures.append("double_click_did_not_retrigger_q_bounce")
 73 | 	if absf(after_retrigger_y - before_retrigger_y) > 0.001:
 74 | 		failures.append("double_click_q_bounce_snapped")
 75 | 	if absf(float(scene.click_squash_from_y) - before_retrigger_y) > 0.001:
 76 | 		failures.append("double_click_q_bounce_wrong_restart_scale")
 77 | 
 78 | 	for _i in range(3):
 79 | 		scene.call("_update_click_squash", 1.0 / 60.0)
 80 | 	if scene.body_pivot.scale.y >= before_retrigger_y - 0.02:
 81 | 		failures.append("double_click_q_bounce_not_recompressing")
 82 | 
 83 | 	# Four more rapid clicks cross the stage-four mood tiers: click 3 switches
 84 | 	# to shy and click 6 switches to angry. Those two video upgrades may replace
 85 | 	# the running clip, but the Q-bounce transform must remain continuous.
 86 | 	var max_retrigger_jump := 0.0
 87 | 	var max_scale_x_error := 0.0
 88 | 	var max_pivot_error := 0.0
 89 | 	for click_index in range(4):
 90 | 		for _frame_index in range(2):
 91 | 			scene.call("_update_click_squash", 1.0 / 60.0)
 92 | 		var before_y: float = float(scene.body_pivot.scale.y)
 93 | 		var token_before := int(scene.sequence_token)
 94 | 		scene.call("_trigger_click_reaction")
 95 | 		var token_after := int(scene.sequence_token)
 96 | 		var after_y: float = float(scene.body_pivot.scale.y)
 97 | 		max_retrigger_jump = maxf(max_retrigger_jump, absf(after_y - before_y))
 98 | 		max_scale_x_error = maxf(
 99 | 			max_scale_x_error,
			absf(scene.body_pivot.scale.x - 1.0)
		)
		max_pivot_error = maxf(
			max_pivot_error,
			scene.body_pivot.position.distance_to(scene.base_body_pivot_position)
		)
		if click_index == 0 or click_index == 3:
			if token_after == token_before:
				failures.append("tier_upgrade_did_not_replace_clip")
		elif token_after != token_before:
			failures.append("same_tier_rapid_click_restarted_clip")

	if max_retrigger_jump > 0.001:
		failures.append("rapid_click_q_bounce_has_scale_jump")
	if max_scale_x_error > 0.001:
		failures.append("rapid_click_q_bounce_changed_width")
	if max_pivot_error > 0.01:
		failures.append("rapid_click_q_bounce_moved_foot_anchor")

	# Let the final retrigger complete and verify the easeOutBack overshoot and
	# clean settle at scale 1.
	var max_scale_y: float = float(scene.body_pivot.scale.y)
	for _i in range(28):
		scene.call("_update_click_squash", 1.0 / 60.0)
		max_scale_y = maxf(max_scale_y, scene.body_pivot.scale.y)
		max_scale_x_error = maxf(
			max_scale_x_error,
			absf(scene.body_pivot.scale.x - 1.0)
		)
		max_pivot_error = maxf(
			max_pivot_error,
			scene.body_pivot.position.distance_to(scene.base_body_pivot_position)
		)

	if max_scale_y < 1.01:
		failures.append("click_squash_no_back_overshoot")
	if absf(scene.body_pivot.scale.y - 1.0) > 0.02:
		failures.append("click_squash_did_not_recover")
	if scene.click_squash_active:
		failures.append("click_squash_state_did_not_finish")
	if max_scale_x_error > 0.001:
		failures.append("click_squash_changed_width")
	if max_pivot_error > 0.01:
		failures.append("click_squash_not_foot_anchored")

	var final_token := int(scene.sequence_token)
	await create_timer(0.32).timeout
	if int(scene.sequence_token) != final_token or not scene.sequence_running:
		failures.append("streaming_clip_stopped_early")
	if runtime_mode:
		if not scene._runtime_video_is_active() or not scene.pet_video.is_playing():
			failures.append("streaming_video_not_playing")
		if scene.pet_video.stream_position <= 0.05:
			failures.append("streaming_video_did_not_advance")
		if scene.active_hit_frame <= 0:
			failures.append("streaming_video_hit_frame_did_not_advance")
	else:
		if scene.pet_sprite.texture == start_texture:
			failures.append("streaming_clip_did_not_advance")
	if scene.pet_sprite_next.texture != null or scene.pet_sprite_next.modulate.a > 0.001:
		failures.append("transition_uses_alpha_crossfade")

	scene.call("_cancel_active_action")
	await process_frame
	if runtime_mode and scene._idle_runtime_is_ready():
		if not scene.pet_video.visible or not scene.pet_video.is_playing():
			failures.append("cancel_did_not_restore_idle_video")
		if scene.active_video_action_id != "idle":
			failures.append("cancel_idle_video_action_id")
		if scene.pet_sprite.visible:
			failures.append("cancel_left_png_sprite_visible")
	elif scene._idle_video_is_ready():
		var idle_texture: Texture2D = scene.idle_video_textures[scene.idle_video_frame]
		if scene.pet_sprite.texture != idle_texture:
			failures.append("cancel_returned_through_master_texture")
	if scene.pet_sprite_next.texture != null or scene.pet_sprite_next.modulate.a > 0.001:
		failures.append("cancel_left_transition_sprite_visible")

	if failures.is_empty():
		print("CLICK_HAPPY_CLIP_OK")
		quit(0)
	else:
		push_error("CLICK_HAPPY_CLIP_FAILED: %s" % ", ".join(failures))
		quit(2)
