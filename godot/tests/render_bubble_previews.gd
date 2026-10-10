 1 | extends SceneTree
 2 | 
 3 | func _init() -> void:
 4 | 	call_deferred("_run")
 5 | 
 6 | 
 7 | func _capture(scene: Node, path: String) -> void:
 8 | 	await process_frame
 9 | 	await process_frame
	await process_frame
	if DisplayServer.get_name() == "headless":
		return
	var image: Image = scene.get_viewport().get_texture().get_image()
	if image == null:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test_output/bubbles"))
	image.save_png(path)


func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var bubble = scene.get_node("Bubble")
	bubble.say(
		"今天海口市有雷暴，气温 26～34°C。\n"
		+ "现在 34°C，体感 40°C。\n"
		+ "今天最高降雨概率 86%，未来 6 小时 86%。",
		0.0
	)
	await create_timer(0.28).timeout
	await _capture(
		scene,
		"res://test_output/bubbles/bubble_weather_preview.png"
	)

	bubble.dismiss(false)
	var long_text := ""
	for i in range(7):
		long_text += "这一行用于检查满页气泡的文字和边缘是否完整显示。"
		if i < 6:
			long_text += "\n"
	bubble.say(long_text, 0.0)
	await create_timer(0.28).timeout
	await _capture(
		scene,
		"res://test_output/bubbles/bubble_fullpage_preview.png"
	)

	print("BUBBLE_PREVIEW_OK")
	quit(0)
