 1 | extends SceneTree
 2 | 
 3 | var failures: Array[String] = []
 4 | 
 5 | 
 6 | func check(condition: bool, label: String) -> void:
 7 | 	if not condition:
 8 | 		failures.append(label)
 9 | 

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var started := bool(scene.call(
		"_request_coordinated_clip",
		"click_happy_video",
		"video_runtime_completion_probe",
		scene.ACTION_PRIORITY_MANUAL,
		true,
		scene.PetState.REACTION
	))
	check(started, "runtime action starts")
	await process_frame
	check(scene.active_video_action_id == "click_happy_video", "runtime action selected")
	check(scene.pet_video.is_playing(), "runtime action playing")

	await create_timer(10.6).timeout
	check(not scene.sequence_running, "runtime sequence finishes at EOS")
	check(int(scene.state) == int(scene.PetState.IDLE), "runtime EOS returns idle state")
	check(scene.active_video_action_id == "idle", "runtime EOS returns idle video")
	check(scene.pet_video.is_playing(), "idle video playing after runtime EOS")
	check(not scene.action_coordinator.is_busy(), "coordinator released after runtime EOS")

	scene.queue_free()
	await process_frame

	if failures.is_empty():
		print("VIDEO_RUNTIME_COMPLETION_PROBE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(2)
