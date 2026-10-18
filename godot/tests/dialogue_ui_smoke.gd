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
	check(scene.nickname_card == null, "nickname card lazy and no first-run prompt")
	scene.call("_open_command_window")
	check(scene.command_input.max_length == 50, "chat UI limit")
	check(scene.command_send.disabled, "empty send disabled")
	scene.command_input.text = "🙂".repeat(51)
	check(scene.command_input.text.length() == 50, "paste constrained to 50")
	scene.call("_on_command_text_submitted", "  ")
	check(scene.command_bubble.visible, "blank submit does not dismiss input")
	var queue_before: Dictionary = scene.file_drop_manager.get_summary().duplicate(true)
	var action_before: int = scene.sequence_token
	scene.call("_handle_command_text", "帮我批量改名")
	check(scene.file_drop_manager.get_summary() == queue_before, "chat does not change file queue")
	check(scene.sequence_token == action_before, "chat does not run actions")
	scene.call("_open_control_menu", scene.CONTEXT_MENU_FIXED_ANCHOR)
	scene.call("_on_control_menu_id_pressed", scene.MENU_SETTINGS)
	await process_frame
	await create_timer(0.18).timeout
	var labels: Array[String] = []
	for child in scene.context_menu.items_box.get_children():
		if child is Button:
			labels.append(child.text.strip_edges())
	check(labels.has("用户昵称…") and labels.has("天气设置…"), "settings submenu entries")
	check(scene.context_menu.position.y + scene.context_menu.size.y <= 420, "settings menu fits")
	scene.call("_on_control_menu_id_pressed", scene.MENU_NICKNAME)
	await create_timer(0.1).timeout
	var card = scene.nickname_card
	check(card.visible and scene.overlay_interactive, "nickname overlay active")
	check(card.nickname_input.max_length == 12 and card.nickname_input.has_focus(), "nickname limit and focus")
	check(card is Window and card.borderless, "nickname has its own frameless window")
	var panel: PanelContainer = card.get_node("Card")
	check(panel.size.x <= card.size.x + 1 and panel.size.y <= card.size.y + 1, "nickname content fits card")
	check(card.nickname_input.get_window() == card, "nickname receives input in its own window")
	check(
		not Geometry2D.is_point_in_polygon(
			Vector2(759, 419),
			scene.debug_last_passthrough_polygon
		),
		"nickname no longer captures the whole transparent window"
	)
	card.nickname_input.text = "测试昵称"
	card.get_node("Card/Margin/Content/Actions/Save").pressed.emit()
	await create_timer(0.1).timeout
	check(scene.settings_store.get_nickname() == "测试昵称" and not card.visible, "save button")
	scene.call("_open_nickname_window")
	check(card.nickname_input.text == "测试昵称", "reopen loads nickname")
	scene.call("_on_nickname_submitted", "字".repeat(13))
	check(card.visible and scene.settings_store.get_nickname() == "测试昵称", "backend rejects overlong name")
	card.nickname_input.text = "未保存"
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	scene.call("_input", escape)
	await create_timer(0.1).timeout
	check(not card.visible and not scene.overlay_interactive, "Esc clears overlay")
	check(scene.settings_store.get_nickname() == "测试昵称", "Esc does not save draft")
	scene.call("_open_nickname_window")
	scene.call("_open_weather_window")
	check(not card.visible and scene.weather_bubble.visible, "weather closes nickname")
	scene.call("_open_nickname_window")
	scene.call("_open_command_window")
	check(not card.visible and scene.command_bubble.visible, "chat closes nickname")
	scene.call("_open_nickname_window")
	card.get_node("Card/Margin/Content/Actions/Clear").pressed.emit()
	await create_timer(0.1).timeout
	check(scene.settings_store.get_nickname().is_empty(), "clear button")
	scene.call("_cancel_active_action")
	scene.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("DIALOGUE_UI_SMOKE_OK")
		quit(0)
	else:
		push_error("DIALOGUE_UI_SMOKE_FAILED: " + ", ".join(failures))
		quit(2)
