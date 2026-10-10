  1 | extends SceneTree
  2 | 
  3 | const DynamicHitShapeManager = preload("res://scripts/dynamic_hit_shape_manager.gd")
  4 | 
  5 | var failures: Array[String] = []
  6 | 
  7 | 
  8 | func check(condition: bool, label: String) -> void:
  9 | 	if not condition:
 10 | 		failures.append(label)
 11 | 
 12 | 
 13 | func polygon_rect(points: PackedVector2Array) -> Rect2:
 14 | 	if points.is_empty():
 15 | 		return Rect2()
 16 | 	var min_x := points[0].x
 17 | 	var min_y := points[0].y
 18 | 	var max_x := points[0].x
 19 | 	var max_y := points[0].y
 20 | 	for point in points:
 21 | 		min_x = minf(min_x, point.x)
 22 | 		min_y = minf(min_y, point.y)
 23 | 		max_x = maxf(max_x, point.x)
 24 | 		max_y = maxf(max_y, point.y)
 25 | 	return Rect2(
 26 | 		Vector2(min_x, min_y),
 27 | 		Vector2(max_x - min_x, max_y - min_y)
 28 | 	)
 29 | 
 30 | 
 31 | func _init() -> void:
 32 | 	call_deferred("_run")
 33 | 
 34 | 
 35 | func _run() -> void:
 36 | 	var manager := DynamicHitShapeManager.new()
 37 | 	check(manager.load_catalog(), "dynamic catalog loads")
 38 | 
 39 | 	for action_id in [
 40 | 		"idle",
 41 | 		"click_happy_video",
 42 | 		"click_shy_video",
 43 | 		"march_in_place_video",
 44 | 		"sleepy_video",
 45 | 		"yawn_video",
 46 | 		"click_angry_video",
 47 | 		"sleep_down_video",
 48 | 		"drag_reaction_video",
 49 | 	]:
 50 | 		check(manager.has_action(action_id), "catalog action exists: " + action_id)
 51 | 		check(manager.frame_count(action_id) == 121, "catalog has 121 frames: " + action_id)
 52 | 		var first := manager.polygon_for(action_id, 0)
 53 | 		var last := manager.polygon_for(action_id, 120)
 54 | 		check(first.size() >= 6, "first polygon valid: " + action_id)
 55 | 		check(last.size() >= 6, "last polygon valid: " + action_id)
 56 | 
 57 | 	var sleep_start := manager.polygon_for("sleep_down_video", 0)
 58 | 	var sleep_end := manager.polygon_for("sleep_down_video", 120)
 59 | 	var start_rect := polygon_rect(sleep_start)
 60 | 	var end_rect := polygon_rect(sleep_end)
 61 | 	print("sleep_hit_start=", start_rect, " sleep_hit_end=", end_rect)
 62 | 	check(start_rect.size.y > start_rect.size.x, "sleep starts as standing shape")
 63 | 	check(end_rect.size.x > end_rect.size.y, "sleep ends as lying shape")
 64 | 	check(
 65 | 		absf(end_rect.size.x - start_rect.size.x) > 35.0
 66 | 		or absf(end_rect.size.y - start_rect.size.y) > 35.0,
 67 | 		"sleep polygon materially changes with pose"
 68 | 	)
 69 | 
 70 | 	var scene = load("res://scenes/main.tscn").instantiate()
 71 | 	root.add_child(scene)
 72 | 	await process_frame
 73 | 	await process_frame
 74 | 
 75 | 	check(scene.dynamic_hit_shapes_ready, "scene loads dynamic hit shapes")
 76 | 	scene.call("_set_active_hit_frame", "sleep_down_video", 0)
 77 | 	var scene_start := polygon_rect(scene.debug_character_passthrough_polygon)
 78 | 	scene.call("_set_active_hit_frame", "sleep_down_video", 120)
 79 | 	var scene_end := polygon_rect(scene.debug_character_passthrough_polygon)
 80 | 	print("scene_sleep_start=", scene_start, " scene_sleep_end=", scene_end)
 81 | 	check(scene_start.size.y > scene_start.size.x, "runtime starts standing hit shape")
 82 | 	check(scene_end.size.x > scene_end.size.y, "runtime ends lying hit shape")
 83 | 	check(
 84 | 		scene.debug_last_passthrough_polygon == scene.debug_character_passthrough_polygon,
 85 | 		"character-only passthrough stays exact silhouette when UI hidden"
 86 | 	)
 87 | 
 88 | 	scene.body_pivot.scale = Vector2(1.0, 0.6)
 89 | 	scene.call("_configure_mouse_passthrough")
 90 | 	var squashed := polygon_rect(scene.debug_character_passthrough_polygon)
 91 | 	check(
 92 | 		squashed.size.y < scene_end.size.y,
 93 | 		"Q-bounce transform also deforms current hit shape"
 94 | 	)
 95 | 
 96 | 	if failures.is_empty():
 97 | 		print("DYNAMIC_HIT_SHAPE_SMOKE_OK")
 98 | 		quit(0)
 99 | 	else:
		for failure in failures:
			push_error(failure)
		quit(2)
