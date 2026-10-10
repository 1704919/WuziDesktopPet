 1 | extends SceneTree
 2 | 
 3 | 
 4 | func _init() -> void:
 5 | 	call_deferred("_run")
 6 | 
 7 | 
 8 | func _run() -> void:
 9 | 	var failures: Array[String] = []
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	if not bool(scene.movement_catalog.get("ready", false)):
		failures.append("movement_catalog_not_ready")

	var movement_clips := scene.movement_catalog.get("clips", {}) as Dictionary
	if not movement_clips.has("walk_left") or not movement_clips.has("walk_right"):
		failures.append("walk_clips_missing_from_movement_catalog")

	if not scene.roaming_controller.is_available():
		failures.append("roaming_controller_not_available")

	if not scene.clips.has("walk_left_video") or not scene.clips.has("walk_right_video"):
		failures.append("runtime_walk_clips_not_loaded")

	if scene.action_registry.resolve_action_id("walk_left") != "walk_left_video":
		failures.append("walk_left_registry_resolution_wrong")
	if scene.action_registry.resolve_action_id("walk_right") != "walk_right_video":
		failures.append("walk_right_registry_resolution_wrong")

	scene.call("_open_control_menu", Vector2(650.0, 200.0))
	await process_frame
	var context_menu: Control = scene.get_node("ContextBubble")
	var items_box: VBoxContainer = context_menu.get_node("Card/Margin/Items")
	var roaming_menu_found := false
	for child in items_box.get_children():
		if child is Button and str((child as Button).text).contains("桌面漫游"):
			roaming_menu_found = true
			break
	if not roaming_menu_found:
		failures.append("roaming_toggle_missing_from_context_menu")
	context_menu.call("hide_menu", false)

	var accepted := bool(scene.call(
		"_request_coordinated_clip",
		"walk_left",
		"roaming",
		scene.ACTION_PRIORITY_ROAMING,
		true,
		scene.PetState.ROAMING
	))
	if not accepted:
		failures.append("walk_left_roaming_request_rejected")
	else:
		await process_frame
		if scene.state != scene.PetState.ROAMING:
			failures.append("roaming_state_not_entered")
		if not scene.sequence_running:
			failures.append("roaming_sequence_not_running")
		if scene.active_clip_id != "walk_left_video":
			failures.append("wrong_roaming_runtime_clip")
		scene.call("_cancel_active_action")
		scene.call("_return_to_idle", false)

	if failures.is_empty():
		print("ROAMING_INTEGRATION_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(2)
