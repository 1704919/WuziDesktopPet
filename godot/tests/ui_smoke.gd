  1 | extends SceneTree
  2 | 
  3 | const WINDOW_SIZE := Vector2(760.0, 420.0)
  4 | const PET_VISIBLE_LEFT := 424.0
  5 | const REPLY_CARD_BOTTOM_RIGHT := Vector2(468.0, 158.0)
  6 | 
  7 | func _init() -> void:
  8 | 	call_deferred("_run")
  9 | 
 10 | 
 11 | func _run() -> void:
 12 | 	var scene = load("res://scenes/main.tscn").instantiate()
 13 | 	root.add_child(scene)
 14 | 	await process_frame
 15 | 	await process_frame
 16 | 
 17 | 	var failures: Array[String] = []
 18 | 
 19 | 	var context_menu: Control = scene.get_node("ContextBubble")
 20 | 	var expected_fixed_anchor := scene.CONTEXT_MENU_FIXED_ANCHOR as Vector2
 21 | 	for click_position in [Vector2(240, 20), Vector2(740, 20), Vector2(240, 400), Vector2(740, 400)]:
 22 | 		var right_click := InputEventMouseButton.new()
 23 | 		right_click.button_index = MOUSE_BUTTON_RIGHT
 24 | 		right_click.pressed = true
 25 | 		right_click.position = click_position
 26 | 		scene.call("_input", right_click)
 27 | 		await create_timer(0.16).timeout
 28 | 
 29 | 		if not context_menu.visible:
 30 | 			failures.append("context_menu_not_visible")
 31 | 			continue
 32 | 		if (scene.context_menu_anchor as Vector2).distance_to(expected_fixed_anchor) > 0.1:
 33 | 			failures.append("context_menu_anchor_not_fixed")
 34 | 		if (context_menu.get("_base_position") as Vector2).distance_to(expected_fixed_anchor) > 0.1:
 35 | 			failures.append("context_menu_base_not_fixed")
 36 | 		if context_menu.position.distance_to(expected_fixed_anchor) > 0.1:
 37 | 			failures.append("context_menu_visual_position_not_fixed")
 38 | 		if context_menu.position.x + context_menu.size.x > WINDOW_SIZE.x + 0.1:
 39 | 			failures.append("context_menu_overflow_x")
 40 | 		if context_menu.position.y + context_menu.size.y > WINDOW_SIZE.y + 0.1:
 41 | 			failures.append("context_menu_overflow_y")
 42 | 
 43 | 		context_menu.call("hide_menu", false)
 44 | 
 45 | 	scene.call("_open_action_picker")
 46 | 	await process_frame
 47 | 	if not context_menu.visible:
 48 | 		failures.append("action_picker_not_visible")
 49 | 	if scene.manual_category_map.size() != 6:
 50 | 		failures.append("action_category_count")
 51 | 	if not scene.manual_action_map.is_empty():
 52 | 		failures.append("action_picker_should_show_categories_first")
 53 | 
 54 | 	scene.call("_open_action_category", "click")
 55 | 	await process_frame
 56 | 	if scene.manual_action_map.size() != 4:
 57 | 		failures.append("click_action_count")
 58 | 	scene.call("_open_action_category", "daily")
 59 | 	await process_frame
 60 | 	if scene.manual_action_map.size() != 6:
 61 | 		failures.append("daily_action_count")
 62 | 	scene.call("_open_action_category", "entertainment")
 63 | 	await process_frame
 64 | 	if scene.manual_action_map.size() != 5:
 65 | 		failures.append("entertainment_action_count")
 66 | 	scene.call("_open_action_category", "leisure_work")
 67 | 	await process_frame
 68 | 	if scene.manual_action_map.size() != 4:
 69 | 		failures.append("leisure_work_action_count")
 70 | 	scene.call("_open_action_category", "food")
 71 | 	await process_frame
 72 | 	# The food category now has eight real clips: six on the first
 73 | 	# page and two on the next. Both pages must remain reachable.
 74 | 	if scene.manual_action_map.size() != scene.PetContextMenu.ACTION_PAGE_SIZE:
 75 | 		failures.append("food_action_count")
 76 | 	if not scene.manual_category_map.has(scene.MENU_ACTION_PAGE_DOWN):
 77 | 		failures.append("food_action_next_page_missing")
 78 | 	scene.call("_open_action_category", "food", 1)
 79 | 	await process_frame
 80 | 	if scene.manual_action_map.size() != 2:
 81 | 		failures.append("food_action_second_page_count")
 82 | 	if not scene.manual_category_map.has(scene.MENU_ACTION_PAGE_UP):
 83 | 		failures.append("food_action_previous_page_missing")
 84 | 	var second_food_ids: Array[String] = []
 85 | 	for food_action in scene.manual_action_map.values():
 86 | 		second_food_ids.append(str((food_action as Dictionary).get("id", "")))
 87 | 	if not second_food_ids.has("eat_fries") or not second_food_ids.has("eat_bullfrog"):
 88 | 		failures.append("food_action_second_page_content")
 89 | 	scene.call("_open_action_category", "rest")
 90 | 	await process_frame
 91 | 	if scene.manual_action_map.size() != 4:
 92 | 		failures.append("rest_action_count")
 93 | 
 94 | 	var manual_actions := scene.config.get("manual_actions", []) as Array
 95 | 	for index in range(3):
 96 | 		manual_actions.append({
 97 | 			"id": "pagination_test_%d" % index,
 98 | 			"label": "分页测试 %d" % index,
 99 | 			"kind": "idle",
			"category": "daily"
		})
	scene.call("_open_action_category", "daily", 0)
	await process_frame
	if scene.manual_action_map.size() != scene.PetContextMenu.ACTION_PAGE_SIZE:
		failures.append("action_page_size")
	if not scene.manual_category_map.has(scene.MENU_ACTION_PAGE_DOWN):
		failures.append("action_page_down_missing")
	scene.call(
		"_on_control_menu_id_pressed",
		scene.MENU_ACTION_PAGE_DOWN
	)
	await process_frame
	await process_frame
	if scene.manual_action_map.size() != 5:
		failures.append("action_second_page_count")
	if not scene.manual_category_map.has(scene.MENU_ACTION_PAGE_UP):
		failures.append("action_page_up_missing")
	if context_menu.position.y + context_menu.size.y > WINDOW_SIZE.y + 0.1:
		failures.append("paged_action_menu_overflow_y")
	context_menu.call("hide_menu", false)

	var command_bubble: Control = scene.get_node("CommandBubble")
	# Opening "对她说" must remain immediate even while a video action is
	# transitioning/loading in the background.
	scene.call("_start_clip_sequence", "click_happy_video", scene.PetState.REACTION, true)
	await process_frame
	scene.call("_open_command_window")
	if not command_bubble.visible:
		failures.append("command_bubble_not_immediate_during_action")
	await process_frame
	if not command_bubble.visible:
		failures.append("command_bubble_not_visible")
	if command_bubble.position.x + command_bubble.size.x >= PET_VISIBLE_LEFT:
		failures.append("command_bubble_overlaps_pet")
	command_bubble.call("hide_card", false)
	scene.call("_cancel_active_action")
	await process_frame

	var weather_bubble: Control = scene.get_node("WeatherBubble")
	scene.call("_open_weather_window")
	await process_frame
	if not weather_bubble.visible:
		failures.append("weather_bubble_not_visible")
	if weather_bubble.position.x + weather_bubble.size.x >= PET_VISIBLE_LEFT:
		failures.append("weather_bubble_overlaps_pet")
	weather_bubble.call("hide_card", false)

	var bubble = scene.get_node("Bubble")
	bubble.say(
		"今天海口市有雷暴，气温 26～34°C。\n"
		+ "现在 34°C，体感 40°C。\n"
		+ "今天最高降雨概率 86%，未来 6 小时 86%。",
		0.0
	)
	await process_frame
	await process_frame

	var reply_card: PanelContainer = bubble.get_node("Card")
	var weather_card: PanelContainer = scene.get_node("WeatherBubble/Card")
	var reply_style := reply_card.get_theme_stylebox("panel") as StyleBoxFlat
	var weather_style := weather_card.get_theme_stylebox("panel") as StyleBoxFlat
	if reply_style == null or weather_style == null:
		failures.append("bubble_or_weather_style_missing")
	else:
		if reply_style.bg_color != weather_style.bg_color:
			failures.append("bubble_weather_background_color_mismatch")
		if reply_style.border_color != weather_style.border_color:
			failures.append("bubble_weather_border_color_mismatch")
	var reply_target := bubble.get("target_position") as Vector2
	if (reply_target + reply_card.size).distance_to(REPLY_CARD_BOTTOM_RIGHT) > 3.0:
		failures.append("reply_bubble_wrong_anchor")
	if bubble.size.distance_to(reply_card.size) > 0.1:
		failures.append("reply_bubble_has_extra_shape")
	if bubble.position.x + bubble.size.x > WINDOW_SIZE.x:
		failures.append("reply_bubble_overflow")

	var weather_text := str(scene.call("_build_weather_reply", {
		"location": "上海 · 上海 · 中国",
		"today_condition": "有雷暴",
		"temperature_c": 21.0,
		"feels_like_c": 22.0,
		"today_min_c": 19.0,
		"today_max_c": 23.0,
		"today_rain_probability_max": 84,
		"rain_probability_next_6h": 65,
		"wind_kph": 9.0
	}))
	if weather_text.contains("最高降雨概率") or weather_text.contains("气温 "):
		failures.append("weather_reply_is_raw_report")
	if not weather_text.contains("出门最好带把伞"):
		failures.append("weather_reply_missing_advice")

	if failures.is_empty():
		print("UI_BUBBLE_SMOKE_OK")
		print("context=", context_menu.position, " size=", context_menu.size)
		print("command=", command_bubble.position, " size=", command_bubble.size)
		print("weather=", weather_bubble.position, " size=", weather_bubble.size)
		print("reply=", bubble.position, " size=", bubble.size, " card=", reply_card.size)
		quit(0)
	else:
		push_error("UI_BUBBLE_SMOKE_FAILED: %s" % ", ".join(failures))
		quit(2)
