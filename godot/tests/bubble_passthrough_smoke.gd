extends SceneTree

func _polygon_rect(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var min_x := points[0].x
	var min_y := points[0].y
	var max_x := points[0].x
	var max_y := points[0].y
	for p in points:
		min_x = minf(min_x, p.x)
		min_y = minf(min_y, p.y)
		max_x = maxf(max_x, p.x)
		max_y = maxf(max_y, p.y)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var bubble: Control = scene.get_node("Bubble")
	bubble.say(
		"今天海口市有雷暴，气温 26～34°C。\n"
		+ "现在 34°C，体感 40°C。\n"
		+ "今天最高降雨概率 86%，未来 6 小时 86%。",
		0.0
	)
	for _i in range(3):
		await process_frame

	var before_rect := _polygon_rect(scene.debug_last_passthrough_polygon)
	var bubble_rect := bubble.call("get_window_bounds") as Rect2
	var failures: Array[String] = []

	if not before_rect.encloses(bubble_rect):
		failures.append("reply_bubble_not_in_passthrough_before_right_click")

	scene.call("_open_control_menu", Vector2(550, 210))
	await process_frame
	var after_rect := _polygon_rect(scene.debug_last_passthrough_polygon)
	var menu_rect: Rect2 = scene.context_menu.get_global_rect()

	if not after_rect.encloses(menu_rect):
		failures.append("context_menu_not_in_passthrough")
	if after_rect.size.x >= 759 and after_rect.size.y >= 419:
		failures.append("context_menu_still_captures_full_window")
	if scene.debug_character_passthrough_polygon.size() < 6:
		failures.append("character_passthrough_not_dynamic_polygon")

	print("bubble=", bubble_rect, " before=", before_rect, " menu=", menu_rect, " after=", after_rect)

	if failures.is_empty():
		print("PASSTHROUGH_BUBBLE_SMOKE_OK")
		quit(0)
	else:
		push_error("PASSTHROUGH_BUBBLE_SMOKE_FAILED: %s" % ", ".join(failures))
		quit(2)
