extends SceneTree

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await process_frame

	check(scene.video_runtime_enabled, "video runtime enabled")
	check(scene.pet_video.visible, "idle runtime video visible")
	check(scene.pet_video.is_playing(), "idle runtime video playing")
	check(not scene.pet_sprite.visible, "PNG sprite hidden while runtime video is active")
	check(scene.active_video_action_id == "idle", "idle runtime action id")
	check(scene.active_hit_action_id == "idle", "idle hit action id")
	var idle_texture: Texture2D = scene.pet_video.get_video_texture()
	check(idle_texture != null, "idle runtime video texture exists")
	if idle_texture != null:
		check(idle_texture.get_width() == 960, "packed idle video width is 960")
		check(idle_texture.get_height() == 360, "packed idle video height is 360")

	for clip_id in scene.clips.keys():
		var clip := scene.clips[clip_id] as Dictionary
		check(clip.get("runtime_stream") != null, "runtime stream loads: %s" % str(clip_id))
		check(
			ResourceLoader.exists(str(clip.get("runtime_video_path", ""))),
			"runtime video resource exists: %s" % str(clip_id)
		)

	var idle_frame_before: int = scene.active_hit_frame
	await create_timer(0.35).timeout
	check(scene.active_hit_frame > idle_frame_before, "idle hit frame advances from video time")

	var started := bool(scene.call(
		"_request_coordinated_clip",
		"click_happy_video",
		"video_runtime_smoke",
		scene.ACTION_PRIORITY_MANUAL,
		true,
		scene.PetState.REACTION
	))
	check(started, "runtime action starts")
	check(scene.active_clip_uses_visual_fade, "ordinary runtime action enables visual fade")
	var min_runtime_transition_alpha := float(scene.body_pivot.modulate.a)
	for _index in range(8):
		await create_timer(0.02).timeout
		min_runtime_transition_alpha = minf(
			min_runtime_transition_alpha,
			float(scene.body_pivot.modulate.a)
		)
	check(
		min_runtime_transition_alpha < 0.65,
		"runtime action visibly dims through midpoint"
	)
	check(
		min_runtime_transition_alpha > 0.45,
		"runtime action never fully disappears"
	)
	await create_timer(0.22).timeout
	check(absf(float(scene.body_pivot.modulate.a) - 1.0) < 0.02, "runtime action fade-in restores alpha")
	check(scene.pet_video.visible, "action runtime video visible")
	check(scene.pet_video.is_playing(), "action runtime video playing")
	check(scene.active_video_action_id == "click_happy_video", "action runtime id")
	check(scene.active_hit_action_id == "click_happy_video", "action hit id")
	check(scene.active_hit_frame > 0, "action hit frame advances from video time")

	scene.call("_cancel_active_action")
	await process_frame
	await process_frame
	check(scene.pet_video.visible, "cancel returns to idle runtime video")
	check(scene.pet_video.is_playing(), "idle runtime resumes after cancel")
	check(scene.active_video_action_id == "idle", "cancel returns runtime id to idle")

	scene.sleep_phase = "looping"
	scene.state = scene.PetState.SLEEPING
	scene.inactivity_manager.set_sleep_frozen(true)
	var sleep_started := bool(scene.call(
		"_request_coordinated_clip",
		"sleep_loop",
		"video_runtime_sleep_smoke",
		scene.ACTION_PRIORITY_SLEEP,
		false,
		scene.PetState.SLEEPING
	))
	check(sleep_started, "sleep-loop runtime starts")
	await process_frame
	check(not scene.active_clip_uses_visual_fade, "sleep-loop excludes ordinary action fade")
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
