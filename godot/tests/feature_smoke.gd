 1 | extends SceneTree
 2 | 
 3 | func _init() -> void:
 4 | 	var failures: Array[String] = []
 5 | 
 6 | 	var settings_script = load("res://scripts/settings_store.gd")
 7 | 	var settings = settings_script.new()
 8 | 	root.add_child(settings)
 9 | 	settings.load_settings()
	settings.set_value("smoke_test_value", 29, false)
	if int(settings.get_value("smoke_test_value", 0)) != 29:
		failures.append("settings_store")
	settings.erase_value("smoke_test_value", true)

	var registry_script = load("res://scripts/action_registry.gd")
	var registry = registry_script.new()
	root.add_child(registry)
	registry.load_catalog()
	if not registry.get_action("eat_noodles").has("status"):
		failures.append("action_registry")

	var source_image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	source_image.fill(Color(0.8, 0.2, 0.6, 0.75))
	var source_path := ProjectSettings.globalize_path("user://wuzi_feature_smoke.png")
	if source_image.save_png(source_path) != OK:
		failures.append("create_test_png")
	else:
		var manager_script = load("res://scripts/file_drop_manager.gd")
		var manager = manager_script.new()
		root.add_child(manager)
		manager.configure({
			"image_quality": 0.9,
			"output_suffix": "_converted"
		})
		manager.enqueue(PackedStringArray([source_path]))
		var bytes: PackedByteArray = manager.encode_image(source_path, "webp", 0.9)
		var decoded := Image.new()
		if decoded.load_webp_from_buffer(bytes) != OK:
			failures.append("image_conversion")

	if failures.is_empty():
		print("FEATURE_SMOKE_OK")
		quit(0)
	else:
		push_error("FEATURE_SMOKE_FAILED: %s" % ", ".join(failures))
		quit(2)
