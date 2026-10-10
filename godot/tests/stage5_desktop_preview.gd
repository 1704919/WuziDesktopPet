 1 | extends SceneTree
 2 | 
 3 | 
 4 | func _init() -> void:
 5 | 	call_deferred("_run")
 6 | 
 7 | 
 8 | func _run() -> void:
 9 | 	if not OS.get_user_data_dir().contains("WuziPetBaseline"):
		push_error("Desktop preview requires an isolated baseline project.")
		quit(2)
		return
	var sample_dir := ProjectSettings.globalize_path("user://desktop_samples")
	DirAccess.make_dir_recursive_absolute(sample_dir)
	var file := FileAccess.open(sample_dir.path_join("选择器测试.txt"), FileAccess.WRITE)
	file.store_string("Stage 5B desktop picker sample")
	file.close()
	var image := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.8, 0.3, 0.6, 0.5))
	image.save_png(sample_dir.path_join("图片测试.png"))
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.call("_open_batch_file_window")
	var window: Window = scene.batch_file_window
	window.title = "舞梓 · 文件处理 · 5B 隔离验收"
	window.add_files_dialog.current_dir = sample_dir
	window.add_folder_dialog.current_dir = sample_dir
	window.output_folder_dialog.current_dir = sample_dir
	print("DESKTOP_SAMPLE_DIR ", sample_dir)
