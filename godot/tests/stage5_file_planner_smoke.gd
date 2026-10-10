extends SceneTree

const FileOperationPlanner = preload("res://scripts/file_operation_planner.gd")
const FileDropManager = preload("res://scripts/file_drop_manager.gd")
const BatchFileWindow = preload("res://scripts/batch_file_window.gd")

var failures: Array[String] = []
var scratch := ""


func check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	scratch = ProjectSettings.globalize_path("user://stage5_file_planner_smoke")
	_prepare_scratch()

	var a := scratch.path_join("IMG_001.png")
	var b := scratch.path_join("IMG_002.png")
	var c := scratch.path_join("safe.txt")
	_write_file(a)
	_write_file(b)
	_write_file(c)

	var planner := FileOperationPlanner.new()
	var paths := PackedStringArray([a, b])
	var params := {
		"prefix": "图_",
		"numbering_enabled": true,
		"number_start": 1,
		"number_step": 1,
		"number_digits": 2,
		"image_format": "jpg",
		"output_mode": "source"
	}
	var plan1 := planner.build_plan(paths, params)
	var plan2 := planner.build_plan(paths, params)

	check(bool(plan1.preview_only), "planner is preview only")
	check(bool(plan1.can_execute), "valid frozen plan is executable in 5B")
	check(str(plan1.plan_version) == str(plan2.plan_version), "stable inputs produce stable plan version")
	check(int(plan1.valid_count) == 2, "two renamed image targets are valid")
	check(int(plan1.conflict_count) == 0, "valid plan has no conflicts")
	var items := plan1.items as Array
	check(str((items[0] as Dictionary).target_name) == "图_IMG_001_01.jpg", "prefix numbering and image format")
	check(str((items[1] as Dictionary).target_name) == "图_IMG_002_02.jpg", "number increments")

	var heic_plan := planner.build_plan(
		PackedStringArray([a]),
		{"prefix": "heic_", "image_format": "heic", "output_mode": "source"}
	)
	var heic_item := (heic_plan.items as Array)[0] as Dictionary
	check(str(heic_item.target_name) == "heic_IMG_001.heic", "HEIC target participates in 5A preview plan")

	var changed_params := params.duplicate(true)
	changed_params.prefix = "新_"
	var changed := planner.build_plan(paths, changed_params)
	check(str(changed.plan_version) != str(plan1.plan_version), "parameter change invalidates old plan version")
	check(str(plan1.plan_version).length() > 40, "plan version uses a strong deterministic digest")

	var rename_rules := planner.build_plan(
		PackedStringArray([c]),
		{
			"find_text": "safe",
			"replace_text": "note",
			"prefix": "pre_",
			"suffix": "_done",
			"output_mode": "source"
		}
	)
	var rename_item := (rename_rules.items as Array)[0] as Dictionary
	check(str(rename_item.target_name) == "pre_note_done.txt", "find replace prefix suffix preserve extension")

	var invalid_regex := planner.build_plan(
		PackedStringArray([c]),
		{"find_text": "([", "regex_enabled": true, "prefix": "x_", "output_mode": "source"}
	)
	check(_plan_has_issue(invalid_regex, "正则表达式无效"), "invalid regex blocks plan")

	var reserved := planner.build_plan(
		PackedStringArray([c]),
		{"find_text": "safe", "replace_text": "CON", "output_mode": "source"}
	)
	check(_plan_has_issue(reserved, "保留设备名"), "reserved Windows device name blocked")

	var illegal := planner.build_plan(
		PackedStringArray([c]),
		{"find_text": "safe", "replace_text": "bad:name", "output_mode": "source"}
	)
	check(_plan_has_issue(illegal, "非法字符"), "illegal Windows filename character blocked")

	var quote_name := planner.build_plan(
		PackedStringArray([c]),
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
