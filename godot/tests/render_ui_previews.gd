extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	scene.call("_open_command_window")
	await process_frame
	await process_frame

	var command: Control = scene.get_node("CommandBubble")
	if not command.visible:
		push_error("COMMAND_BUBBLE_PREVIEW_FAILED")
		quit(2)
		return

	var bubble = scene.get_node("Bubble")
	bubble.say("这是完整显示的长文本气泡预览。\n第二行也应该完整显示。", 0.0)
	await process_frame
	await process_frame

	print("UI_PREVIEW_SMOKE_OK")
	quit(0)
