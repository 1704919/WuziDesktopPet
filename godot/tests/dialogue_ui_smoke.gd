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
 19 | 	check(scene.nickname_card == null, "nickname card lazy and no first-run prompt")
 20 | 	scene.call("_open_command_window")
 21 | 	check(scene.command_input.max_length == 50, "chat UI limit")
 22 | 	check(scene.command_send.disabled, "empty send disabled")
 23 | 	scene.command_input.text = "🙂".repeat(51)
 24 | 	check(scene.command_input.text.length() == 50, "paste constrained to 50")
 25 | 	scene.call("_on_command_text_submitted", "  ")
 26 | 	check(scene.command_bubble.visible, "blank submit does not dismiss input")
 27 | 	var queue_before: Dictionary = scene.file_drop_manager.get_summary().duplicate(true)
 28 | 	var action_before: int = scene.sequence_token
 29 | 	scene.call("_handle_command_text", "帮我批量改名")
 30 | 	check(scene.file_drop_manager.get_summary() == queue_before, "chat does not change file queue")
 31 | 	check(scene.sequence_token == action_before, "chat does not run actions")
 32 | 	scene.call("_open_control_menu", scene.CONTEXT_MENU_FIXED_ANCHOR)
 33 | 	scene.call("_on_control_menu_id_pressed", scene.MENU_SETTINGS)
 34 | 	await process_frame
 35 | 	await create_timer(0.18).timeout
 36 | 	var labels: Array[String] = []
 37 | 	for child in scene.context_menu.items_box.get_children():
 38 | 		if child is Button:
 39 | 			labels.append(child.text.strip_edges())
 40 | 	check(labels.has("用户昵称…") and labels.has("天气设置…"), "settings submenu entries")
 41 | 	check(scene.context_menu.position.y + scene.context_menu.size.y <= 420, "settings menu fits")
 42 | 	scene.call("_on_control_menu_id_pressed", scene.MENU_NICKNAME)
 43 | 	await create_timer(0.1).timeout
 44 | 	var card = scene.nickname_card
 45 | 	check(card.visible and scene.overlay_interactive, "nickname overlay active")
 46 | 	check(card.nickname_input.max_length == 12 and card.nickname_input.has_focus(), "nickname limit and focus")
 47 | 	check(card.position.x + card.size.x < 424 and card.position.y + card.size.y <= 420, "nickname card fits beside pet")
 48 | 	var panel: PanelContainer = card.get_node("Card")
 49 | 	check(panel.size.x <= card.size.x + 1 and panel.size.y <= card.size.y + 1, "nickname content fits card")
 50 | 	check(
 51 | 		Geometry2D.is_point_in_polygon(
 52 | 			card.get_global_rect().get_center(),
 53 | 			scene.debug_last_passthrough_polygon
 54 | 		),
 55 | 		"nickname card is inside passthrough"
 56 | 	)
 57 | 	check(
 58 | 		not Geometry2D.is_point_in_polygon(
 59 | 			Vector2(759, 419),
 60 | 			scene.debug_last_passthrough_polygon
 61 | 		),
 62 | 		"nickname no longer captures the whole transparent window"
 63 | 	)
 64 | 	card.nickname_input.text = "测试昵称"
 65 | 	card.get_node("Card/Margin/Content/Actions/Save").pressed.emit()
 66 | 	await create_timer(0.1).timeout
 67 | 	check(scene.settings_store.get_nickname() == "测试昵称" and not card.visible, "save button")
 68 | 	scene.call("_open_nickname_window")
 69 | 	check(card.nickname_input.text == "测试昵称", "reopen loads nickname")
 70 | 	scene.call("_on_nickname_submitted", "字".repeat(13))
 71 | 	check(card.visible and scene.settings_store.get_nickname() == "测试昵称", "backend rejects overlong name")
 72 | 	card.nickname_input.text = "未保存"
 73 | 	var escape := InputEventKey.new()
 74 | 	escape.keycode = KEY_ESCAPE
 75 | 	escape.pressed = true
 76 | 	scene.call("_input", escape)
 77 | 	await create_timer(0.1).timeout
 78 | 	check(not card.visible and not scene.overlay_interactive, "Esc clears overlay")
 79 | 	check(scene.settings_store.get_nickname() == "测试昵称", "Esc does not save draft")
 80 | 	scene.call("_open_nickname_window")
 81 | 	scene.call("_open_weather_window")
 82 | 	check(not card.visible and scene.weather_bubble.visible, "weather closes nickname")
 83 | 	scene.call("_open_nickname_window")
 84 | 	scene.call("_open_command_window")
 85 | 	check(not card.visible and scene.command_bubble.visible, "chat closes nickname")
 86 | 	scene.call("_open_nickname_window")
 87 | 	card.get_node("Card/Margin/Content/Actions/Clear").pressed.emit()
 88 | 	await create_timer(0.1).timeout
 89 | 	check(scene.settings_store.get_nickname().is_empty(), "clear button")
 90 | 	scene.call("_cancel_active_action")
 91 | 	scene.queue_free()
 92 | 	await process_frame
 93 | 	await process_frame
 94 | 	if failures.is_empty():
 95 | 		print("DIALOGUE_UI_SMOKE_OK")
 96 | 		quit(0)
 97 | 	else:
 98 | 		push_error("DIALOGUE_UI_SMOKE_FAILED: " + ", ".join(failures))
 99 | 		quit(2)
