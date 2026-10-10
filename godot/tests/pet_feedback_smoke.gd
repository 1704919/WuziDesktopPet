 1 | extends SceneTree
 2 | 
 3 | const Workbench = preload("res://scripts/batch_file_window.gd")
 4 | 
 5 | var failures: Array[String] = []
 6 | 
 7 | 
 8 | func check(condition: bool, name: String) -> void:
 9 | 	if not condition:
		failures.append(name)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	for test_case in [
		["normal", "reset"],
		["happy", "happy"],
		["shy", "praise"],
		["angry", "angry"],
		["sleepy", "sleepy"]
	]:
		var mood: String = test_case[0]
		var event_type: String = test_case[1]
		scene.mood_manager.apply_event("reset")
		if event_type != "reset":
			scene.mood_manager.apply_event(event_type)
		check(str(scene.mood_manager.get_snapshot().get("mood", "")) == mood, "mood_precondition_" + mood)
		scene.call("_handle_command_text", "心情怎么样")
		var allowed: Array = scene.dialogue_manager.mood_state_responses.get(mood, [])
		check(allowed.has(scene.bubble.current_text), "real_mood_reply_" + mood)

	check(Workbench.execution_feedback_kind({
		"completed": 2, "failed": 0, "skipped": 0, "cancelled": 0
	}) == "file_success", "all_completed_success")
	check(Workbench.execution_feedback_kind({
		"completed": 1, "failed": 1, "skipped": 0, "cancelled": 0
	}) == "file_failure", "partially_failed_never_success")
	check(Workbench.execution_feedback_kind({
		"completed": 1, "failed": 0, "skipped": 1, "cancelled": 0
	}) == "file_failure", "partially_skipped_never_success")
	check(Workbench.execution_feedback_kind({
		"completed": 1, "failed": 0, "skipped": 0, "cancelled": 1
	}).is_empty(), "cancellation_not_success")
	check(Workbench.execution_feedback_kind({}).is_empty(), "nothing_done_no_success")
	check(Workbench.preview_feedback_kind({"items": [{"issues": ["目标路径已经存在文件，默认禁止覆盖。"]}]}) == "file_duplicate", "duplicate_preview")
	check(Workbench.preview_feedback_kind({"items": [{"issues": []}]}) == "file_preview", "valid_preview")
	check(Workbench.preview_feedback_kind({"items": [{"issues": ["源路径与目标路径完全相同，没有可执行变化。"]}]}) == "file_preview", "unchanged_path_not_duplicate")
	check(Workbench.preview_feedback_kind({"items": [{"issues": ["批内有多个文件生成同一目标路径。"]}]}) == "file_duplicate", "within_batch_duplicate")

	scene.call("_open_batch_file_window")
	var workbench = scene.batch_file_window
	check(workbench.feedback_requested.is_connected(scene._on_file_feedback_requested), "workbench_signal_connected")
	for key in ["file_success", "file_failure", "file_preview", "file_duplicate"]:
		workbench.feedback_requested.emit(key)
		var allowed: Array = scene.dialogue_manager.event_feedback.get(key, [])
		check(allowed.has(scene.bubble.current_text), "event_bubble_" + key)
		check(workbench.character_feedback_label.text == "舞梓：" + scene.bubble.current_text, "workbench_feedback_visible_" + key)

	scene.mood_manager.apply_event("reset")
	for i in range(6):
		scene.call("_trigger_click_reaction")
	check(int(scene.mood_manager.get_snapshot().get("click_count", 0)) == 6, "six_actual_clicks")
	check((scene.dialogue_manager.event_feedback.get("click_spam", []) as Array).has(scene.bubble.current_text), "six_clicks_speak")
	check(scene.click_squash_active, "click_q_bounce_preserved")

	scene.call("_say_event_feedback", "drag_start")
	check(scene.dialogue_manager.event_feedback["drag_start"].has(scene.bubble.current_text), "drag_start_text")
	scene.call("_say_event_feedback", "drag_end")
	check(scene.dialogue_manager.event_feedback["drag_end"].has(scene.bubble.current_text), "drag_end_text")

	scene.call("_cancel_active_action")
	if is_instance_valid(workbench):
		workbench.call("_close_workbench")
	scene.queue_free()
	await process_frame
	await process_frame

	if failures.is_empty():
		print("PET_FEEDBACK_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error("pet_feedback: " + failure)
		quit(2)
