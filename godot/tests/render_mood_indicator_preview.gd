extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var indicator: Control = scene.get_node("MoodIndicator")
	indicator.set_process(false)
	indicator.call("set_mood", "shy", 58.0)
	indicator.show()
	await process_frame
	await process_frame

	if DisplayServer.get_name() == "headless":
		print("MOOD_INDICATOR_PREVIEW_SKIPPED_HEADLESS")
		quit(0)
		return

	var output_dir := ProjectSettings.globalize_path("res://test_output")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var image := root.get_texture().get_image()
	if image == null:
		# The dummy headless renderer has no framebuffer. This helper remains
		# usable from a normal renderer without making CI fail.
		print("MOOD_INDICATOR_PREVIEW_SKIPPED_HEADLESS")
		quit(0)
		return
	var error := image.save_png(output_dir.path_join("mood_indicator_preview.png"))
	if error != OK:
		push_error("MOOD_INDICATOR_PREVIEW_SAVE_FAILED")
		quit(2)
		return

	print("MOOD_INDICATOR_PREVIEW_OK")
	quit(0)
