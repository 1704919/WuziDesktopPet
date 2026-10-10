  1 | extends SceneTree
  2 | 
  3 | var failures: Array[String] = []
  4 | 
  5 | 
  6 | func check(condition: bool, label: String) -> void:
  7 | 	if not condition:
  8 | 		failures.append(label)
  9 | 
 10 | 
 11 | func _init() -> void:
 12 | 	call_deferred("_run")
 13 | 
 14 | 
 15 | func _run() -> void:
 16 | 	var scene = load("res://scenes/main.tscn").instantiate()
 17 | 	root.add_child(scene)
 18 | 	await process_frame
 19 | 	await process_frame
 20 | 	await process_frame
 21 | 
 22 | 	check(scene.video_runtime_enabled, "video runtime enabled")
 23 | 	check(scene.pet_video.visible, "idle runtime video visible")
 24 | 	check(scene.pet_video.is_playing(), "idle runtime video playing")
 25 | 	check(not scene.pet_sprite.visible, "PNG sprite hidden while runtime video is active")
 26 | 	check(scene.active_video_action_id == "idle", "idle runtime action id")
 27 | 	check(scene.active_hit_action_id == "idle", "idle hit action id")
 28 | 	var idle_texture: Texture2D = scene.pet_video.get_video_texture()
 29 | 	check(idle_texture != null, "idle runtime video texture exists")
 30 | 	if idle_texture != null:
 31 | 		check(idle_texture.get_width() == 960, "packed idle video width is 960")
 32 | 		check(idle_texture.get_height() == 360, "packed idle video height is 360")
 33 | 
 34 | 	for clip_id in scene.clips.keys():
 35 | 		var clip := scene.clips[clip_id] as Dictionary
 36 | 		check(clip.get("runtime_stream") != null, "runtime stream loads: %s" % str(clip_id))
 37 | 		check(
 38 | 			ResourceLoader.exists(str(clip.get("runtime_video_path", ""))),
 39 | 			"runtime video resource exists: %s" % str(clip_id)
 40 | 		)
 41 | 
 42 | 	var idle_frame_before: int = scene.active_hit_frame
 43 | 	await create_timer(0.35).timeout
 44 | 	check(scene.active_hit_frame > idle_frame_before, "idle hit frame advances from video time")
 45 | 
 46 | 	var started := bool(scene.call(
 47 | 		"_request_coordinated_clip",
 48 | 		"click_happy_video",
 49 | 		"video_runtime_smoke",
 50 | 		scene.ACTION_PRIORITY_MANUAL,
 51 | 		true,
 52 | 		scene.PetState.REACTION
 53 | 	))
 54 | 	check(started, "runtime action starts")
 55 | 	check(scene.active_clip_uses_visual_fade, "ordinary runtime action enables visual fade")
 56 | 	var min_runtime_transition_alpha := float(scene.body_pivot.modulate.a)
 57 | 	for _index in range(8):
 58 | 		await create_timer(0.02).timeout
 59 | 		min_runtime_transition_alpha = minf(
 60 | 			min_runtime_transition_alpha,
 61 | 			float(scene.body_pivot.modulate.a)
 62 | 		)
 63 | 	check(
 64 | 		min_runtime_transition_alpha < 0.65,
 65 | 		"runtime action visibly dims through midpoint"
 66 | 	)
 67 | 	check(
 68 | 		min_runtime_transition_alpha > 0.45,
 69 | 		"runtime action never fully disappears"
 70 | 	)
 71 | 	await create_timer(0.22).timeout
 72 | 	check(absf(float(scene.body_pivot.modulate.a) - 1.0) < 0.02, "runtime action fade-in restores alpha")
 73 | 	check(scene.pet_video.visible, "action runtime video visible")
 74 | 	check(scene.pet_video.is_playing(), "action runtime video playing")
 75 | 	check(scene.active_video_action_id == "click_happy_video", "action runtime id")
 76 | 	check(scene.active_hit_action_id == "click_happy_video", "action hit id")
 77 | 	check(scene.active_hit_frame > 0, "action hit frame advances from video time")
 78 | 
 79 | 	scene.call("_cancel_active_action")
 80 | 	await process_frame
 81 | 	await process_frame
 82 | 	check(scene.pet_video.visible, "cancel returns to idle runtime video")
 83 | 	check(scene.pet_video.is_playing(), "idle runtime resumes after cancel")
 84 | 	check(scene.active_video_action_id == "idle", "cancel returns runtime id to idle")
 85 | 
 86 | 	scene.sleep_phase = "looping"
 87 | 	scene.state = scene.PetState.SLEEPING
 88 | 	scene.inactivity_manager.set_sleep_frozen(true)
 89 | 	var sleep_started := bool(scene.call(
 90 | 		"_request_coordinated_clip",
 91 | 		"sleep_loop",
 92 | 		"video_runtime_sleep_smoke",
 93 | 		scene.ACTION_PRIORITY_SLEEP,
 94 | 		false,
 95 | 		scene.PetState.SLEEPING
 96 | 	))
 97 | 	check(sleep_started, "sleep-loop runtime starts")
 98 | 	await process_frame
 99 | 	check(not scene.active_clip_uses_visual_fade, "sleep-loop excludes ordinary action fade")
	check(absf(float(scene.body_pivot.modulate.a) - 1.0) < 0.001, "sleep-loop keeps full alpha")
	await create_timer(0.20).timeout
	var sleep_runtime_id: String = scene.action_registry.resolve_action_id("sleep_loop")
	check(scene.active_video_action_id == sleep_runtime_id, "sleep-loop runtime id")
	check(scene.pet_video.is_playing(), "sleep-loop runtime video playing")

	scene.call("_stop_sequence_preserve_frame")
	await process_frame
	check(scene.pet_video.visible, "sleep interrupt preserves video frame")
	check(scene.pet_video.paused, "sleep interrupt pauses preserved video frame")

	scene.sleep_phase = "waking"
	var wake_started := bool(scene.call(
		"_request_coordinated_clip",
		"wake_up",
		"video_runtime_wake_smoke",
		scene.ACTION_PRIORITY_WAKE,
		true,
		scene.PetState.WAKING
	))
	check(wake_started, "wake runtime starts")
	await process_frame
	await create_timer(0.20).timeout
	var wake_runtime_id: String = scene.action_registry.resolve_action_id("wake_up")
	check(scene.active_video_action_id == wake_runtime_id, "wake runtime id")
	check(scene.pet_video.is_playing(), "wake runtime video playing")
	scene.call("_cancel_active_action")
	scene.sleep_phase = "none"
	scene.state = scene.PetState.IDLE
	scene.inactivity_manager.set_sleep_frozen(false)
	await process_frame

	scene.video_runtime_enabled = false
	scene.call("_cancel_active_action")
	await process_frame
	check(not scene.pet_video.visible, "disabled runtime hides video")
	check(scene.pet_sprite.visible, "disabled runtime uses PNG fallback")
	check(scene.pet_sprite.texture != null, "PNG fallback has texture")

	scene.video_runtime_enabled = true
	var fallback_clip := scene.clips["click_happy_video"] as Dictionary
	fallback_clip["runtime_stream"] = null
	scene.clips["click_happy_video"] = fallback_clip
	var fallback_started := bool(scene.call(
		"_request_coordinated_clip",
		"click_happy_video",
		"video_runtime_png_fallback_smoke",
		scene.ACTION_PRIORITY_MANUAL,
		true,
		scene.PetState.REACTION
	))
	check(fallback_started, "missing runtime stream falls back to PNG")
	await process_frame
	await create_timer(0.25).timeout
	check(not scene.pet_video.visible, "PNG fallback does not leave video overlay visible")
	check(scene.pet_sprite.visible, "PNG fallback sprite visible")
	check(scene.active_hit_action_id == "click_happy_video", "PNG fallback hit action id")
	check(scene.active_hit_frame > 0, "PNG fallback hit frame advances")
	scene.call("_cancel_active_action")
	await process_frame
	scene.queue_free()
	await process_frame

	if failures.is_empty():
		print("VIDEO_RUNTIME_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(2)
