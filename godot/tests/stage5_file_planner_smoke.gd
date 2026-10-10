  1 | extends SceneTree
  2 | 
  3 | const FileOperationPlanner = preload("res://scripts/file_operation_planner.gd")
  4 | const FileDropManager = preload("res://scripts/file_drop_manager.gd")
  5 | const BatchFileWindow = preload("res://scripts/batch_file_window.gd")
  6 | 
  7 | var failures: Array[String] = []
  8 | var scratch := ""
  9 | 
 10 | 
 11 | func check(condition: bool, label: String) -> void:
 12 | 	if not condition:
 13 | 		failures.append(label)
 14 | 
 15 | 
 16 | func _init() -> void:
 17 | 	call_deferred("_run")
 18 | 
 19 | 
 20 | func _run() -> void:
 21 | 	scratch = ProjectSettings.globalize_path("user://stage5_file_planner_smoke")
 22 | 	_prepare_scratch()
 23 | 
 24 | 	var a := scratch.path_join("IMG_001.png")
 25 | 	var b := scratch.path_join("IMG_002.png")
 26 | 	var c := scratch.path_join("safe.txt")
 27 | 	_write_file(a)
 28 | 	_write_file(b)
 29 | 	_write_file(c)
 30 | 
 31 | 	var planner := FileOperationPlanner.new()
 32 | 	var paths := PackedStringArray([a, b])
 33 | 	var params := {
 34 | 		"prefix": "图_",
 35 | 		"numbering_enabled": true,
 36 | 		"number_start": 1,
 37 | 		"number_step": 1,
 38 | 		"number_digits": 2,
 39 | 		"image_format": "jpg",
 40 | 		"output_mode": "source"
 41 | 	}
 42 | 	var plan1 := planner.build_plan(paths, params)
 43 | 	var plan2 := planner.build_plan(paths, params)
 44 | 
 45 | 	check(bool(plan1.preview_only), "planner is preview only")
 46 | 	check(bool(plan1.can_execute), "valid frozen plan is executable in 5B")
 47 | 	check(str(plan1.plan_version) == str(plan2.plan_version), "stable inputs produce stable plan version")
 48 | 	check(int(plan1.valid_count) == 2, "two renamed image targets are valid")
 49 | 	check(int(plan1.conflict_count) == 0, "valid plan has no conflicts")
 50 | 	var items := plan1.items as Array
 51 | 	check(str((items[0] as Dictionary).target_name) == "图_IMG_001_01.jpg", "prefix numbering and image format")
 52 | 	check(str((items[1] as Dictionary).target_name) == "图_IMG_002_02.jpg", "number increments")
 53 | 
 54 | 	var heic_plan := planner.build_plan(
 55 | 		PackedStringArray([a]),
 56 | 		{"prefix": "heic_", "image_format": "heic", "output_mode": "source"}
 57 | 	)
 58 | 	var heic_item := (heic_plan.items as Array)[0] as Dictionary
 59 | 	check(str(heic_item.target_name) == "heic_IMG_001.heic", "HEIC target participates in 5A preview plan")
 60 | 
 61 | 	var changed_params := params.duplicate(true)
 62 | 	changed_params.prefix = "新_"
 63 | 	var changed := planner.build_plan(paths, changed_params)
 64 | 	check(str(changed.plan_version) != str(plan1.plan_version), "parameter change invalidates old plan version")
 65 | 	check(str(plan1.plan_version).length() > 40, "plan version uses a strong deterministic digest")
 66 | 
 67 | 	var rename_rules := planner.build_plan(
 68 | 		PackedStringArray([c]),
 69 | 		{
 70 | 			"find_text": "safe",
 71 | 			"replace_text": "note",
 72 | 			"prefix": "pre_",
 73 | 			"suffix": "_done",
 74 | 			"output_mode": "source"
 75 | 		}
 76 | 	)
 77 | 	var rename_item := (rename_rules.items as Array)[0] as Dictionary
 78 | 	check(str(rename_item.target_name) == "pre_note_done.txt", "find replace prefix suffix preserve extension")
 79 | 
 80 | 	var invalid_regex := planner.build_plan(
 81 | 		PackedStringArray([c]),
 82 | 		{"find_text": "([", "regex_enabled": true, "prefix": "x_", "output_mode": "source"}
 83 | 	)
 84 | 	check(_plan_has_issue(invalid_regex, "正则表达式无效"), "invalid regex blocks plan")
 85 | 
 86 | 	var reserved := planner.build_plan(
 87 | 		PackedStringArray([c]),
 88 | 		{"find_text": "safe", "replace_text": "CON", "output_mode": "source"}
 89 | 	)
 90 | 	check(_plan_has_issue(reserved, "保留设备名"), "reserved Windows device name blocked")
 91 | 
 92 | 	var illegal := planner.build_plan(
 93 | 		PackedStringArray([c]),
 94 | 		{"find_text": "safe", "replace_text": "bad:name", "output_mode": "source"}
 95 | 	)
 96 | 	check(_plan_has_issue(illegal, "非法字符"), "illegal Windows filename character blocked")
 97 | 
 98 | 	var quote_name := planner.build_plan(
 99 | 		PackedStringArray([c]),
		{"find_text": "safe", "replace_text": "bad%sname" % String.chr(34), "output_mode": "source"}
	)
	check(_plan_has_issue(quote_name, "双引号"), "double quote filename blocked")

	var one := scratch.path_join("one.txt")
	var two := scratch.path_join("two.txt")
	_write_file(one)
	_write_file(two)
	var duplicate := planner.build_plan(
		PackedStringArray([one, two]),
		{
			"find_text": "^.*$",
			"replace_text": "same",
			"regex_enabled": true,
			"output_mode": "source"
		}
	)
	check(int(duplicate.conflict_count) == 2, "batch duplicate targets block both items")
	check(_plan_has_issue(duplicate, "批内"), "batch duplicate reason is visible")

	var output_dir := scratch.path_join("output")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var custom := planner.build_plan(
		PackedStringArray([c]),
		{
			"prefix": "copy_",
			"output_mode": "custom",
			"output_dir": output_dir
		}
	)
	check(int(custom.valid_count) == 1, "custom existing output directory is valid")
	var custom_item := (custom.items as Array)[0] as Dictionary
	check(str(custom_item.target).get_base_dir() == output_dir, "custom output target uses selected directory")

	var missing_output := planner.build_plan(
		PackedStringArray([c]),
		{
			"prefix": "copy_",
			"output_mode": "custom",
			"output_dir": scratch.path_join("not_created")
		}
	)
	check(_plan_has_issue(missing_output, "目标目录"), "missing custom output directory is blocked")

	var existing_target := scratch.path_join("existing.txt")
	_write_file(existing_target)
	var disk_conflict := planner.build_plan(
		PackedStringArray([c]),
		{"find_text": "safe", "replace_text": "existing", "output_mode": "source"}
	)
	check(_plan_has_issue(disk_conflict, "已经存在"), "existing disk target is blocked")

	var sub_dir := scratch.path_join("sub")
	DirAccess.make_dir_recursive_absolute(sub_dir)
	var sub_file := sub_dir.path_join("second.txt")
	_write_file(sub_file)
	var multi_dir := planner.build_plan(
		PackedStringArray([c, sub_file]),
		{"prefix": "multi_", "output_mode": "source"}
	)
	var multi_items := multi_dir.items as Array
	check(
		str((multi_items[0] as Dictionary).target).get_base_dir() == scratch
		and str((multi_items[1] as Dictionary).target).get_base_dir() == sub_dir,
		"source output mode preserves each source directory"
	)

	var missing := planner.build_plan(
		PackedStringArray([scratch.path_join("missing.png")]),
		{"prefix": "x_", "output_mode": "source"}
	)
	check(_plan_has_issue(missing, "源文件不存在"), "missing source is blocked")

	var noop := planner.build_plan(
		PackedStringArray([c]),
		{"output_mode": "source"}
	)
	check(_plan_has_issue(noop, "完全相同"), "no-op source target is blocked")

	var manager := FileDropManager.new()
	root.add_child(manager)
	check(manager.classify(scratch.path_join("camera.heic")) == "image", "HEIC is classified as an image")
	check(manager.classify(scratch.path_join("camera.heif")) == "image", "HEIF is classified as an image")
	manager.enqueue(PackedStringArray([a, b, c]))
	manager.remove_paths(PackedStringArray([b]))
	var queued := manager.get_queued_files()
	check(queued.size() == 2 and queued.has(a) and queued.has(c) and not queued.has(b), "queue removes only selected paths")

	var window := BatchFileWindow.new()
	root.add_child(window)
	await process_frame
	window.setup(manager)
	await process_frame
	check(bool(window.current_plan.preview_only), "workbench consumes preview-only plan")
	check(window.start_button.disabled, "5A workbench execution button remains disabled")
	check(window.file_list.item_count == 2, "workbench previews manager queue")
	check(window.image_format.item_count == 5, "workbench exposes four image target formats plus keep")
	check(window.image_format.get_item_text(4) == "HEIC", "workbench exposes HEIC target")
	check(not window.regex_toggle.visible, "advanced regex control is collapsed by default")
	check(window.file_list.get_item_text(0).contains("完全相同"), "conflict reason is shown directly in preview row")
	window.queue_free()
	manager.queue_free()

	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.call("_open_control_menu", scene.CONTEXT_MENU_FIXED_ANCHOR)
	await process_frame
	var menu_items: VBoxContainer = scene.get_node("ContextBubble/Card/Margin/Items")
	var has_file_workbench := false
	var has_legacy_clear := false
	for child in menu_items.get_children():
		if child is Button:
			var label := str((child as Button).text)
			has_file_workbench = has_file_workbench or label.contains("文件处理")
			has_legacy_clear = has_legacy_clear or label.contains("清空拖入文件")
	check(has_file_workbench, "right click menu exposes unified file workbench")
	check(not has_legacy_clear, "legacy clear-only top-level entry is replaced")
	scene.context_menu.call("hide_menu", false)

	scene.call("_on_files_dropped", PackedStringArray([a]))
	await process_frame
	await process_frame
	check(is_instance_valid(scene.batch_file_window), "file drop opens batch workbench")
	if is_instance_valid(scene.batch_file_window):
		check(scene.batch_file_window.visible, "file workbench is visible after drop")
		check(int(scene.batch_file_window.current_plan.total) == 1, "drop and workbench share FileDropManager queue")
		check(scene.batch_file_window.start_button.disabled, "drop path remains preview-only in 5A")
		scene.batch_file_window.hide()
	var main_bubble: Control = scene.get_node("Bubble")
	main_bubble.call("say", "5A close smoke", 0.0)
	await process_frame
	check(main_bubble.visible, "closing workbench does not block main bubble interaction")
	scene.queue_free()
	await process_frame

	_cleanup_scratch()

	if failures.is_empty():
		print("STAGE5_FILE_PLANNER_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(2)


func _plan_has_issue(plan: Dictionary, fragment: String) -> bool:
	for raw_item in plan.get("items", []) as Array:
		var item := raw_item as Dictionary
		for issue in item.get("issues", []) as Array:
			if str(issue).contains(fragment):
				return true
	for issue in plan.get("global_issues", []) as Array:
		if str(issue).contains(fragment):
			return true
	return false


func _write_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("unable to create test file: " + path)
		return
	file.store_string("stage5 planner smoke")
	file.close()


func _prepare_scratch() -> void:
	_cleanup_scratch()
	DirAccess.make_dir_recursive_absolute(scratch)


func _cleanup_scratch() -> void:
	if scratch.is_empty() or not DirAccess.dir_exists_absolute(scratch):
		return
	_remove_tree(scratch)


func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry.is_empty():
			break
		if entry == "." or entry == "..":
			continue
		var full := path.path_join(entry)
		if dir.current_is_dir():
			_remove_tree(full)
		else:
			DirAccess.remove_absolute(full)
	dir.list_dir_end()
	DirAccess.remove_absolute(path)
