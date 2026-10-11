extends SceneTree

# This test must run in release_slim staging, never as a replacement for the
# existing dev_full PNG-fallback tests.
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

	check(scene.release_slim, "explicit release_slim profile")
	check(scene.video_runtime_enabled, "OGV forced enabled")
	check(scene.idle_runtime_stream != null, "idle OGV loads")
	check(scene.idle_video_textures.is_empty(), "idle has no full PNG fallback")
	check(scene.master_texture != null, "idle first-frame anchor loads")
	check(scene.pet_video.is_playing(), "idle video playing")
	check(scene.clips.size() == 37, "37 action clips plus idle")
	var frame_before: int = scene.active_hit_frame
	await create_timer(0.35).timeout
	check(scene.active_hit_frame > frame_before, "video-driven idle hit frame advances")

	var played := 0
	for clip_id in scene.clips.keys():
		var clip := scene.clips[clip_id] as Dictionary
		check(bool(clip.get("release_slim", false)), "release profile: " + str(clip_id))
		check((clip.get("frame_paths", []) as Array).size() == 1,
			"only one PNG anchor: " + str(clip_id))
		check(int(clip.get("frame_count", 0)) == 121,
			"121 frames metadata intact: " + str(clip_id))
		check(clip.get("runtime_stream") != null, "OGV exists: " + str(clip_id))
		check(clip.get("start_texture") != null, "static anchor exists: " + str(clip_id))
		scene.call("_cancel_active_action")
		scene.call("_return_to_idle", false)
		scene.call("_start_clip_sequence", str(clip_id), scene.PetState.REACTION,
			true, false, false)
		await process_frame
		await process_frame
		check(scene.sequence_running, "clip sequence starts: " + str(clip_id))
		check(scene.pet_video.is_playing(), "video backend starts: " + str(clip_id))
		check(scene.active_video_action_id == str(clip_id),
			"correct video action: " + str(clip_id))
		if scene.pet_video.is_playing():
			played += 1
		scene.call("_cancel_active_action")
		await process_frame
		check(scene.active_video_action_id == "idle", "returns to idle: " + str(clip_id))

	check(played == 37, "all 37 non-idle videos start")

	# A broken action stream must not try an imaginary 121-frame PNG fallback,
	# remain stuck in a sequence, or strand the action coordinator.
	var broken := scene.clips["click_happy_video"] as Dictionary
	broken["runtime_stream"] = null
	scene.clips["click_happy_video"] = broken
	scene.call("_return_to_idle", false)
	var accepted := bool(scene.call("_request_coordinated_clip",
		"click_happy_video", "slim_missing_ogv",
		scene.ACTION_PRIORITY_MANUAL, true, scene.PetState.REACTION))
	check(not accepted, "missing OGV finishes synchronously without a false running state")
	await process_frame
	await process_frame
	check(not scene.sequence_running, "missing video does not hang")
	check(int(scene.state) == int(scene.PetState.IDLE), "missing video returns idle")
	check(not scene.action_coordinator.is_busy(), "missing video releases coordinator")
	check(scene.pet_video.is_playing(), "idle video resumed after missing action")

	# Missing idle OGV falls back to the master static texture without errors.
	scene.call("_cancel_active_action")
	scene.idle_runtime_stream = null
	scene.call("_return_to_idle", false)
	await process_frame
	check(not scene.pet_video.visible, "missing idle OGV hides video overlay")
	check(scene.pet_sprite.visible, "missing idle OGV shows PNG sprite")
	check(scene.pet_sprite.texture == scene.master_texture,
		"missing idle OGV shows original static anchor")
	scene.queue_free()
	await process_frame

	if failures.is_empty():
		print("RELEASE_SLIM_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error("RELEASE_SLIM_SMOKE_FAILED: " + failure)
		quit(2)
