extends SceneTree

const DynamicHitShapeManager = preload("res://scripts/dynamic_hit_shape_manager.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func polygon_rect(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var min_x := points[0].x
	var min_y := points[0].y
	var max_x := points[0].x
	var max_y := points[0].y
	for point in points:
		min_x = minf(min_x, point.x)
		min_y = minf(min_y, point.y)
		max_x = maxf(max_x, point.x)
		max_y = maxf(max_y, point.y)
	return Rect2(
		Vector2(min_x, min_y),
		Vector2(max_x - min_x, max_y - min_y)
	)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := DynamicHitShapeManager.new()
	check(manager.load_catalog(), "dynamic catalog loads")

	for action_id in [
		"idle",
		"click_happy_video",
		"click_shy_video",
		"march_in_place_video",
		"sleepy_video",
		"yawn_video",
		"click_angry_video",
		"sleep_down_video",
		"drag_reaction_video",
	]:
		check(manager.has_action(action_id), "catalog action exists: " + action_id)
		check(manager.frame_count(action_id) == 121, "catalog has 121 frames: " + action_id)
		var first := manager.polygon_for(action_id, 0)
		var last := manager.polygon_for(action_id, 120)
		check(first.size() >= 6, "first polygon valid: " + action_id)
		check(last.size() >= 6, "last polygon valid: " + action_id)

	var sleep_start := manager.polygon_for("sleep_down_video", 0)
	var sleep_end := manager.polygon_for("sleep_down_video", 120)
	var start_rect := polygon_rect(sleep_start)
	var end_rect := polygon_rect(sleep_end)
	print("sleep_hit_start=", start_rect, " sleep_hit_end=", end_rect)
	check(start_rect.size.y > start_rect.size.x, "sleep starts as standing shape")
	check(end_rect.size.x > end_rect.size.y, "sleep ends as lying shape")
	check(
		absf(end_rect.size.x - start_rect.size.x) > 35.0
		or absf(end_rect.size.y - start_rect.size.y) > 35.0,
		"sleep polygon materially changes with pose"
	)

	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	check(scene.dynamic_hit_shapes_ready, "scene loads dynamic hit shapes")
	scene.call("_set_active_hit_frame", "sleep_down_video", 0)
	var scene_start := polygon_rect(scene.debug_character_passthrough_polygon)
	scene.call("_set_active_hit_frame", "sleep_down_video", 120)
	var scene_end := polygon_rect(scene.debug_character_passthrough_polygon)
	print("scene_sleep_start=", scene_start, " scene_sleep_end=", scene_end)
	check(scene_start.size.y > scene_start.size.x, "runtime starts standing hit shape")
	check(scene_end.size.x > scene_end.size.y, "runtime ends lying hit shape")
	check(
		scene.debug_last_passthrough_polygon == scene.debug_character_passthrough_polygon,
		"character-only passthrough stays exact silhouette when UI hidden"
	)

	scene.body_pivot.scale = Vector2(1.0, 0.6)
	scene.call("_configure_mouse_passthrough")
	var squashed := polygon_rect(scene.debug_character_passthrough_polygon)
	check(
		squashed.size.y < scene_end.size.y,
		"Q-bounce transform also deforms current hit shape"
	)

	if failures.is_empty():
		print("DYNAMIC_HIT_SHAPE_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(2)
