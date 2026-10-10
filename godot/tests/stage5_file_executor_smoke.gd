extends SceneTree

const Planner = preload("res://scripts/file_operation_planner.gd")
const Executor = preload("res://scripts/file_operation_executor.gd")
const Bridge = preload("res://scripts/windows_file_bridge.gd")
const Manager = preload("res://scripts/file_drop_manager.gd")
const Workbench = preload("res://scripts/batch_file_window.gd")

var failures: Array[String] = []
var scratch: String
var planner := Planner.new()


class CancelAfterFirst extends Executor:
	func _publish(plan: Dictionary) -> void:
		super._publish(plan)
		for item: Dictionary in plan.items:
			if item.status == "completed":
				cancel()


class TargetRace extends Executor:
	var created := false
	func _publish(plan: Dictionary) -> void:
		super._publish(plan)
		if not created and plan.items[0].status == "processing":
			created = true
			var file := FileAccess.open(str(plan.items[0].target), FileAccess.WRITE)
			file.store_string("external file")
			file.close()


class RecoveryRace extends Executor:
	var created := false
	func _publish(plan: Dictionary) -> void:
		super._publish(plan)
		if not created and plan.items[0].has("temporary_path"):
			created = true
			# Another process claims both original and final names after staging.
			for path in [plan.items[0].source, plan.items[0].target]:
				var file := FileAccess.open(str(path), FileAccess.WRITE)
				file.store_string("external")
				file.close()


func _init() -> void:
	call_deferred("_run")


func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)


func _file(name: String, contents: String = "sample") -> String:
	var path := scratch.path_join(name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(contents)
	file.close()
	return path


func _execute(plan: Dictionary, executor: RefCounted = null) -> Dictionary:
	if executor == null:
		executor = Executor.new()
	return executor.execute(plan, str(plan.plan_version))


func _run() -> void:
	scratch = ProjectSettings.globalize_path("user://stage5b_" + Crypto.new().generate_random_bytes(6).hex_encode())
	DirAccess.make_dir_recursive_absolute(scratch)
	var caps := Bridge.run("caps")
	check(bool(caps.ok), "native Windows bridge available")
	print("HEIC_CAPABILITIES ", JSON.stringify(caps))
	# Single rename, source-directory semantics, case-only rename and extension case.
	var source := _file("simple/Original.TXT", "original")
	var plan := planner.build_plan([source], {"prefix": "new_"})
	var result := _execute(plan)
	check(result.counts.completed == 1 and not FileAccess.file_exists(source), "in-place rename removes original path")
	check(FileAccess.get_file_as_string(str(plan.items[0].target)) == "original", "rename preserves content")
	check(str(plan.items[0].target).ends_with(".TXT"), "extension case preserved")
	source = _file("case/alpha.txt", "case")
	plan = planner.build_plan([source], {"find_text": "alpha", "replace_text": "ALPHA"})
	check(plan.valid_count == 1 and _execute(plan).counts.completed == 1, "case-only rename supported")
	# Swaps and a 3-cycle produced by public regex replacement rules.
	var a := _file("swap/AB.txt", "A")
	var b := _file("swap/BA.txt", "B")
	plan = planner.build_plan([a, b], {"regex_enabled": true, "find_text": "^(.)(.)$", "replace_text": "$2$1"})
	result = _execute(plan)
	check(result.counts.completed == 2, "A B swap succeeds")
	check(FileAccess.get_file_as_string(a) == "B" and FileAccess.get_file_as_string(b) == "A", "swap contents preserved")
	var cycle := PackedStringArray([_file("cycle/ABC.txt", "A"), _file("cycle/BCA.txt", "B"), _file("cycle/CAB.txt", "C")])
	plan = planner.build_plan(cycle, {"regex_enabled": true, "find_text": "^(.)(.)(.)$", "replace_text": "$2$3$1"})
	result = _execute(plan)
	check(result.counts.completed == 3, "three-file cycle succeeds")
	check(FileAccess.get_file_as_string(cycle[0]) == "C" and FileAccess.get_file_as_string(cycle[1]) == "A" and FileAccess.get_file_as_string(cycle[2]) == "B", "three-cycle contents preserved")
	# A target owned by a non-moving item must not be silently overwritten.
	a = _file("blocked/a.txt")
	b = _file("blocked/pre_a.txt")
	plan = planner.build_plan([a, b], {"output_mode": "custom", "output_dir": b.get_base_dir(), "prefix": "pre_"})
	check(not bool(plan.items[0].can_execute), "copy cannot occupy queued source")
	# Exact frozen plan integrity and changed environment.
	source = _file("stale/input.txt")
	plan = planner.build_plan([source], {"prefix": "renamed_"})
	var edited := plan.duplicate(true)
	edited.items[0].target = scratch.path_join("unexpected.txt")
	check(_execute(edited).counts.failed == 1 and FileAccess.file_exists(source), "mutated frozen plan rejected")
	_file("stale/input.txt", "changed size")
	check(_execute(plan).counts.failed == 1 and FileAccess.file_exists(source), "source changed after preview rejected")
	plan = planner.build_plan([source], {"prefix": "renamed_"})
	_file("stale/renamed_input.txt", "external")
	check(_execute(plan).counts.failed == 1, "target created after preview rejected")
	check(FileAccess.get_file_as_string(str(plan.items[0].target)) == "external", "existing target untouched")
	# Native primitive itself must resist races, independent of the planner.
	check(not bool(Bridge.run("move", [source, str(plan.items[0].target)]).ok), "atomic rename refuses replacement")
	check(not bool(Bridge.run("copy", [source, str(plan.items[0].target)]).ok), "native copy refuses replacement")
	# Mid-execution target collision restores source and leaves conflict intact.
	source = _file("race/input.txt", "mine")
	plan = planner.build_plan([source], {"prefix": "renamed_"})
	result = _execute(plan, TargetRace.new())
	check(result.counts.failed == 1 and FileAccess.get_file_as_string(source) == "mine", "rename commit failure restores source")
	check(FileAccess.get_file_as_string(str(plan.items[0].target)) == "external file", "race target not replaced")
	source = _file("recovery/input.txt", "must survive")
	plan = planner.build_plan([source], {"prefix": "new_"})
	result = _execute(plan, RecoveryRace.new())
	var recovered: Dictionary = result.items[0]
	check(result.counts.failed == 1 and recovered.has("recovery_path"), "failed restoration exposes recovery path")
	if recovered.has("recovery_path"):
		check(FileAccess.get_file_as_string(str(recovered.recovery_path)) == "must survive", "original bytes retained in recovery file")
		check(str(recovered.message).contains(source) and str(recovered.message).contains(str(recovered.target)), "recovery report includes source temp and target")
		var recovery_manager := Manager.new()
		recovery_manager.enqueue([source])
		recovery_manager.apply_execution_result(result)
		check(recovery_manager.get_queued_files() == PackedStringArray([str(recovered.recovery_path)]), "failed item keeps actual recoverable source in queue")
		recovery_manager.free()
	# Custom output copies, never moves, including files from different folders.
	var output := scratch.path_join("output")
	DirAccess.make_dir_recursive_absolute(output)
	a = _file("copy/a/song.mp3", "audio bytes")
	b = _file("copy/b/movie.mp4", "video bytes")
	plan = planner.build_plan([a, b], {"output_mode": "custom", "output_dir": output})
	result = _execute(plan)
	check(result.counts.completed == 2 and FileAccess.file_exists(a) and FileAccess.file_exists(b), "custom output copies audio/video without conversion")
	check(FileAccess.get_file_as_string(output.path_join("song.mp3")) == "audio bytes", "custom copy byte preservation")
	# Real ACL failure, confined to our own isolated test directory.
	var protected_dir := scratch.path_join("wuzi-permission-fixture")
	DirAccess.make_dir_recursive_absolute(protected_dir)
	var acl_tool := ProjectSettings.globalize_path("res://tests/deny_fixture_writes.ps1")
	var acl_output: Array = []
	var powershell := OS.get_environment("SystemRoot").path_join("System32/WindowsPowerShell/v1.0/powershell.exe")
	check(OS.execute(powershell, ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", acl_tool, "-Path", protected_dir], acl_output, true, false) == 0, "install isolated permission fixture")
	print("ACL_FIXTURE ", acl_output)
	var probe := Bridge.run("probe", [protected_dir])
	check(not bool(probe.ok), "write probe detects denied directory")
	if not bool(probe.ok):
		plan = planner.build_plan([a], {"output_mode": "custom", "output_dir": protected_dir, "prefix": "wuzi_test_"})
		result = _execute(plan)
		check(result.counts.failed + result.counts.skipped == 1 and FileAccess.file_exists(a), "unwritable directory refused")
	check(OS.execute(powershell, ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", acl_tool, "-Path", protected_dir, "-Restore"], acl_output, true, false) == 0, "restore isolated fixture ACL")
	# Image format signatures, fresh decode, JPEG white background.
	var png := scratch.path_join("images/source.png")
	DirAccess.make_dir_recursive_absolute(png.get_base_dir())
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 0, 0, 0))
	image.set_pixel(16, 16, Color.RED)
	image.save_png(png)
	for format in ["png", "jpg", "webp"]:
		plan = planner.build_plan([png], {"prefix": format + "_", "image_format": format})
		result = _execute(plan)
		check(result.counts.completed == 1, "real image encode " + format)
		var path := str(plan.items[0].target)
		var bytes := FileAccess.get_file_as_bytes(path)
		var decoded := Image.load_from_file(path)
		check(decoded != null and decoded.get_width() == 32, "image re-decode " + format)
		if format == "png":
			check(bytes.slice(0, 8).hex_encode() == "89504e470d0a1a0a", "PNG signature")
		elif format == "jpg":
			check(bytes.slice(0, 3).hex_encode() == "ffd8ff", "JPEG signature")
			check(decoded.get_pixel(0, 0).r > 0.95 and decoded.get_pixel(0, 0).g > 0.95, "JPEG alpha flattened white")
		else:
			check(bytes.slice(0, 4).get_string_from_ascii() == "RIFF" and bytes.slice(8, 12).get_string_from_ascii() == "WEBP", "WebP signature")
	# Regression: WebP can decode as RGB8; a format-mismatched blend used to save solid white JPEGs.
	var opaque_webp := scratch.path_join("images/opaque.webp")
	var opaque_image := Image.create(32, 32, false, Image.FORMAT_RGB8)
	opaque_image.fill(Color(0.1, 0.25, 0.8))
	check(opaque_image.save_webp(opaque_webp, false, 1.0) == OK, "opaque RGB8 WebP fixture created")
	var transparent_webp := scratch.path_join("images/transparent.webp")
	var transparent_image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	transparent_image.fill(Color(0, 0, 0, 0))
	for y in range(8, 24):
		for x in range(8, 24):
			transparent_image.set_pixel(x, y, Color.RED)
	check(transparent_image.save_webp(transparent_webp, false, 1.0) == OK, "transparent RGBA8 WebP fixture created")
	for webp_source in [opaque_webp, transparent_webp]:
		plan = planner.build_plan([webp_source], {"image_format": "jpg"})
		result = _execute(plan)
		check(result.counts.completed == 1, "WebP to JPEG completes: " + webp_source.get_file())
		if result.counts.completed == 1:
			var jpg_output := Image.load_from_file(str(plan.items[0].target))
			check(jpg_output != null and jpg_output.get_width() == 32, "WebP JPEG re-decodes")
			if jpg_output != null:
				var center := jpg_output.get_pixel(16, 16)
				check(center.b > 0.5 and center.r < 0.5 if webp_source == opaque_webp else center.r > 0.65 and center.g < 0.3, "WebP JPEG retains visible image content")
				if webp_source == transparent_webp:
					var corner := jpg_output.get_pixel(0, 0)
					check(corner.r > 0.9 and corner.g > 0.9 and corner.b > 0.9, "transparent WebP becomes white only in transparent area")
		check(FileAccess.file_exists(webp_source), "WebP conversion retains original")
	check(FileAccess.file_exists(png), "conversion preserves source")
	# Missing HEIC capabilities block conversion only, never simple rename.
	plan = planner.build_plan([png], {"image_format": "heic"}, {"read": false, "write": false})
	check(plan.valid_count == 0, "missing HEIC encoder visible in preview")
	var heic := _file("fake/camera.heic", "bad image")
	plan = planner.build_plan([heic], {"prefix": "rename_"}, {"read": false, "write": false})
	check(plan.valid_count == 1 and _execute(plan).counts.completed == 1, "HEIC can rename without codec")
	if bool(caps.get("write", false)):
		plan = planner.build_plan([png], {"image_format": "heic"}, caps)
		result = _execute(plan)
		check(result.counts.completed == 1, "HEIC real encoding succeeds when encoder available")
		if result.counts.completed == 1:
			heic = str(plan.items[0].target)
			check(FileAccess.get_file_as_bytes(heic).slice(4, 8).get_string_from_ascii() == "ftyp", "HEIC ISO BMFF signature")
			if bool(caps.get("read", false)):
				plan = planner.build_plan([heic], {"image_format": "png", "prefix": "roundtrip_"}, caps)
				result = _execute(plan)
				check(result.counts.completed == 1, "HEIC WIC decode roundtrip")
				if result.counts.completed == 1:
					check(Image.load_from_file(str(plan.items[0].target)).get_width() == 32, "HEIC roundtrip dimensions")
	# Partial failure and cancellation retain unprocessed sources in the unique queue.
	a = _file("partial/good.txt")
	b = _file("partial/missing.txt")
	var manager := Manager.new()
	root.add_child(manager)
	manager.enqueue([a, b])
	plan = planner.build_plan(manager.get_queued_files(), {"prefix": "new_"})
	DirAccess.remove_absolute(b)
	result = _execute(plan)
	manager.apply_execution_result(result)
	check(result.counts.completed == 1 and result.counts.failed == 1, "partial success does not abort whole batch")
	check(manager.get_queued_files() == PackedStringArray([b]), "only success removed from queue")
	manager.clear_queue()
	heic = _file("partial/broken.heic", "corrupt HEIC data")
	manager.enqueue([png, heic])
	plan = planner.build_plan(manager.get_queued_files(), {"image_format": "jpg", "prefix": "partial_"}, caps)
	result = _execute(plan)
	manager.apply_execution_result(result)
	check(result.counts.completed == 1 and result.counts.failed + result.counts.skipped == 1, "corrupt image does not block valid image")
	check(manager.get_queued_files() == PackedStringArray([heic]), "failed image remains in unique queue")
	var cancel_paths := PackedStringArray([_file("cancel/one.txt"), _file("cancel/two.txt"), _file("cancel/three.txt")])
	plan = planner.build_plan(cancel_paths, {"prefix": "new_"})
	result = _execute(plan, CancelAfterFirst.new())
	check(result.counts.completed == 1 and result.counts.cancelled == 2, "cancel stops only not-started tasks")
	check(FileAccess.file_exists(cancel_paths[1]) and FileAccess.file_exists(cancel_paths[2]), "cancelled sources remain untouched")
	# UI uses a frozen plan, worker completion cleans queue, close leaves pet alive.
	manager.clear_queue()
	source = _file("ui/sample.txt")
	manager.enqueue([source])
	var window := Workbench.new()
	root.add_child(window)
	await process_frame
	check(not window.always_on_top, "file workbench does not stay topmost over native file dialogs")
	window.setup(manager)
	check(not window.number_start.editable, "numbering inputs initially locked")
	window.numbering_toggle.set_pressed(true)
	window._on_numbering_toggled(true)
	for spin in [window.number_start, window.number_step, window.number_digits]:
		check(spin.editable and spin.get_line_edit().editable, "numbering input unlocked")
	window._set_editing_enabled(window._editable_root, false)
	window._set_editing_enabled(window._editable_root, true)
	for spin in [window.number_start, window.number_step, window.number_digits]:
		check(spin.editable and spin.get_line_edit().editable, "numbering input restored after processing")
	window.numbering_toggle.set_pressed(false)
	window._on_numbering_toggled(false)
	window.prefix_input.text = "done_"
	window._refresh_plan()
	check(not window.start_button.disabled, "valid preview enables start")
	window._request_execution()
	window.prefix_input.text = "changed_"
	window._refresh_plan()
	check(window.frozen_plan.is_empty() and not window.confirmation.visible, "editing invalidates pending confirmation")
	window.prefix_input.text = "done_"
	window._refresh_plan()
	window._request_execution()
	var version := str(window.frozen_plan.plan_version)
	window._confirm_execution()
	var deadline := Time.get_ticks_msec() + 15000
	while window.busy and Time.get_ticks_msec() < deadline:
		await process_frame
	check(not window.busy and not window.last_result.is_empty(), "worker completes without blocking scene tree")
	check(not window.executor.is_cancelled(), "completion queue update does not cancel finished worker")
	if not window.last_result.is_empty():
		check(window.last_result.plan_version == version, "UI executes exact confirmed plan")
		check(window.last_result.counts.completed == 1 and manager.get_queued_files().is_empty(), "UI removes successful paths")
	var missing_folder_files := PackedStringArray()
	var folder_errors: Array[String] = []
	load("res://scripts/batch_workbench_file_picker.gd").collect_files(scratch.path_join("directory_that_does_not_exist"), true, missing_folder_files, folder_errors)
	check(missing_folder_files.is_empty() and folder_errors.size() == 1, "unreadable folder reports an error")
	window._close_workbench()
	window.open_workbench()
	check(window.output_mode.selected == 0, "reopened workbench resets output to source")
	window.queue_free()
	manager.queue_free()
	await process_frame
	print("STAGE5B_SCRATCH ", scratch)
	if failures.is_empty():
		print("STAGE5_FILE_EXECUTOR_SMOKE_OK")
		quit(0)
	else:
		for message in failures:
			push_error(message)
		quit(2)
