extends SceneTree

const FramelessWindow = preload("res://scripts/frameless_window.gd")
var failures: Array[String] = []


func check(value: bool, label: String) -> void:
	if not value:
		failures.append(label)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	for entry in [
		["_open_command_window", "CommandBubble"],
		["_open_weather_window", "WeatherBubble"],
		["_open_stream_window", "StreamBubble"],
		["_open_nickname_window", "NicknameCard"],
	]:
		main.call(entry[0])
		await process_frame
		await process_frame
		var window := main.get_node(entry[1]) as Window
		check(window.visible and window.borderless and window.transparent, entry[1] + ": frameless")
		var card := window.get_node("Card") as Control
		check(Rect2(Vector2.ZERO, Vector2(window.size)).encloses(card.get_global_rect()), entry[1] + ": content fits")
		check(FramelessWindow.usable_rect(window).encloses(Rect2i(window.position, window.size)), entry[1] + ": on screen")
		var title := window.get_node("Card/Margin/Content/Title") as Control
		check(title.mouse_default_cursor_shape == Control.CURSOR_MOVE, entry[1] + ": title drag affordance")
		window.position = Vector2i(100, 100)
		root.position += Vector2i(30, 20)
		await process_frame
		check(window.position == Vector2i(100, 100), entry[1] + ": independent of pet")
		var escape := InputEventKey.new()
		escape.pressed = true
		escape.keycode = KEY_ESCAPE
		window.window_input.emit(escape)
		check(not window.visible and root.visible, entry[1] + ": Escape only closes form")
		check(not main.overlay_interactive, entry[1] + ": Escape clears interaction state")
		window.call("popup_card")
		check(window.position == Vector2i(100, 100), entry[1] + ": reopen retains position")
		window.call("hide_card", false)
	# Long status text must resize the real viewport, including the last button.
	main.call("_open_stream_window")
	var hint := main.get_node("StreamBubble/Card/Margin/Content/Hint") as Label
	hint.text = "第一行\n第二行\n第三行\n第四行\n第五行\n第六行"
	for _frame in range(8):
		await process_frame
	var stream := main.get_node("StreamBubble") as Window
	var save := stream.get_node("Card/Margin/Content/Actions/Save") as Control
	check(Rect2(Vector2.ZERO, Vector2(stream.size)).encloses(save.get_global_rect()), "wrapped hint cannot clip Save")
	main.call("_open_batch_file_window")
	await process_frame
	var workbench: Window = main.batch_file_window
	check(workbench.visible and workbench.borderless and not workbench.unresizable, "workbench frameless and resizable")
	check(workbench.find_child("DragHeader", true, false) != null, "workbench custom drag header")
	check(FramelessWindow.usable_rect(workbench).encloses(Rect2i(workbench.position, workbench.size)), "workbench starts within screen")
	check(workbench.confirmation.borderless, "confirmation has no engine title bar")
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("FRAMELESS_WINDOW_SMOKE_OK")
		quit(0)
	else:
		push_error("FRAMELESS_WINDOW_SMOKE_FAILED: " + ", ".join(failures))
		quit(2)
