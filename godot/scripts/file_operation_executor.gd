extends RefCounted

const Planner = preload("res://scripts/file_operation_planner.gd")
const Bridge = preload("res://scripts/windows_file_bridge.gd")
const FileDrop = preload("res://scripts/file_drop_manager.gd")

var _mutex := Mutex.new()
var _cancelled := false
var _snapshot: Dictionary = {}
var _revision := 0


func cancel() -> void:
	_mutex.lock()
	_cancelled = true
	_mutex.unlock()


func is_cancelled() -> bool:
	_mutex.lock()
	var value := _cancelled
	_mutex.unlock()
	return value


func snapshot() -> Dictionary:
	_mutex.lock()
	var value := _snapshot.duplicate(true)
	_mutex.unlock()
	return value


func revision() -> int:
	_mutex.lock()
	var value := _revision
	_mutex.unlock()
	return value


func _publish(plan: Dictionary) -> void:
	_mutex.lock()
	_snapshot = plan.duplicate(true)
	_revision += 1
	_mutex.unlock()


func execute(frozen: Dictionary, expected_version: String, quality: float = 0.92) -> Dictionary:
	var plan := frozen.duplicate(true)
	var planner := Planner.new()
	var items: Array = plan.get("items", [])
	if expected_version.is_empty() or str(plan.get("plan_version", "")) != expected_version or planner.version_for(plan) != expected_version:
		for item: Dictionary in items:
			_set_status(item, "failed", "预览计划已失效，请重新预览。")
		plan["error"] = "预览计划已失效，请重新预览。"
		return _finish(plan)
	var caps := Bridge.run("caps")
	var directory_checks: Dictionary = {}
	# Revalidate these exact paths; never run rename rules again.
	for item: Dictionary in items:
		if not (item.issues as Array).is_empty():
			_set_status(item, "skipped", str(item.issues[0]))
			continue
		var issue := _check_source(item)
		if issue.is_empty() and item.operation == "convert":
			if Planner.source_needs_heic(str(item.source)) and not bool(caps.get("read", false)):
				issue = "当前 Windows 未提供所需 HEIC 读取支持。"
			if str(plan.params.image_format) == "heic" and not bool(caps.get("write", false)):
				issue = "当前 Windows 未提供所需 HEIC 写入支持。"
		var directory := str(item.target).get_base_dir()
		if issue.is_empty():
			if not directory_checks.has(directory):
				directory_checks[directory] = Bridge.run("probe", [directory])
			if not bool(directory_checks[directory].get("ok", false)):
				issue = "目标目录不可写或已失效：%s（%s）" % [directory, directory_checks[directory].get("error", "")]
		if not issue.is_empty():
			item.issues.append(issue)
		_set_status(item, "waiting" if issue.is_empty() else "failed", issue)
	planner.propagate_dependencies(items)
	for item: Dictionary in items:
		if not (item.issues as Array).is_empty() and str(item.get("result_status", "")) != "skipped":
			_set_status(item, "failed", str(item.issues[0]))
		else:
			item.status = item.get("result_status", "waiting")
	_publish(plan)
	# Connected rename components preserve A<->B and longer cycles. A component,
	# once started, finishes both phases before honoring cancellation.
	var groups := _rename_groups(items)
	for group: Array in groups:
		if is_cancelled():
			for item: Dictionary in group:
				_set_status(item, "cancelled", "尚未开始，已取消。")
		else:
			_rename_group(group, plan)
		_publish(plan)
	for item: Dictionary in items:
		if item.status != "waiting":
			continue
		if is_cancelled():
			_set_status(item, "cancelled", "尚未开始，已取消。")
		else:
			_set_status(item, "processing")
			_publish(plan)
			_output_item(item, str(plan.params.image_format), quality)
		_publish(plan)
	return _finish(plan)


func _check_source(item: Dictionary) -> String:
	if not FileAccess.file_exists(str(item.source)):
		return "源文件不存在或已被移动。"
	var stamp := Planner.source_stamp(str(item.source))
	if stamp.is_empty():
		return "源文件无法读取或已被占用。"
	if stamp != item.source_stamp:
		return "源文件在预览后已变化，请重新预览。"
	return ""


func _rename_groups(items: Array) -> Array:
	var remaining: Array = []
	for item: Dictionary in items:
		if item.status == "waiting" and item.operation == "rename":
			remaining.append(item)
	var groups: Array = []
	while not remaining.is_empty():
		var group: Array = [remaining.pop_front()]
		var expanded := true
		while expanded:
			expanded = false
			for index in range(remaining.size() - 1, -1, -1):
				var candidate: Dictionary = remaining[index]
				for member: Dictionary in group:
					if _key(candidate.target) == _key(member.source) or _key(candidate.source) == _key(member.target):
						group.append(candidate)
						remaining.remove_at(index)
						expanded = true
						break
		groups.append(group)
	return groups


func _rename_group(group: Array, plan: Dictionary) -> void:
	var staged: Array = []
	var failure := ""
	for item: Dictionary in group:
		_set_status(item, "processing")
	_publish(plan)
	for item: Dictionary in group:
		failure = _check_source(item)
		if not failure.is_empty():
			break
		var temporary := str(item.source).get_base_dir().path_join(".wuzi-rename-%s.%s" % [_token(), str(item.source).get_extension() if not str(item.source).get_extension().is_empty() else "tmp"])
		var moved := Bridge.run("move", [str(item.source), temporary])
		if not bool(moved.ok):
			failure = "暂存重命名失败：%s（%s）" % [item.source, moved.error]
			break
		item["temporary_path"] = temporary
		staged.append(item)
	if not failure.is_empty():
		for item: Dictionary in staged:
			_restore(item)
		for item: Dictionary in group:
			_set_status(item, "failed", failure + _recovery_message(item))
		return
	_publish(plan)
	for item: Dictionary in group:
		var moved := Bridge.run("move", [str(item.temporary_path), str(item.target)])
		if bool(moved.ok):
			_set_status(item, "completed")
		else:
			_set_status(item, "failed", "最终改名失败：%s（%s）" % [item.target, moved.error])
		_publish(plan)
	# No rollback of completed outputs. Recover failed sources only into free paths.
	for item: Dictionary in group:
		if item.status == "failed":
			_restore(item)
			item["message"] = str(item.message) + _recovery_message(item)


func _restore(item: Dictionary) -> void:
	var temp := str(item.get("temporary_path", ""))
	if not temp.is_empty() and FileAccess.file_exists(temp):
		var restored := Bridge.run("move", [temp, str(item.source)])
		if not bool(restored.ok):
			item["recovery_path"] = temp


func _recovery_message(item: Dictionary) -> String:
	if str(item.get("recovery_path", "")).is_empty():
		return ""
	return "\n原路径：%s\n保留临时文件：%s\n目标：%s；请从临时文件恢复。" % [item.source, item.recovery_path, item.target]


func _output_item(item: Dictionary, image_format: String, quality: float) -> void:
	var issue := _check_source(item)
	if not issue.is_empty():
		_set_status(item, "failed", issue)
		return
	if FileAccess.file_exists(str(item.target)) or DirAccess.dir_exists_absolute(str(item.target)):
		_set_status(item, "failed", "目标路径已经存在，禁止覆盖。")
		return
	var folder := str(item.target).get_base_dir().path_join(".wuzi-output-%s" % _token())
	if DirAccess.make_dir_absolute(folder) != OK:
		_set_status(item, "failed", "无法创建独占输出暂存目录。")
		return
	var output := folder.path_join("result." + str(item.target).get_extension())
	var decoded := folder.path_join("decoded.png")
	var intermediate := folder.path_join("input.png")
	var result: Dictionary = {"ok": false, "error": "图片解码或编码失败。"}
	if item.operation == "copy":
		result = Bridge.run("copy", [str(item.source), output])
	else:
		var input := str(item.source)
		var can_encode := true
		if Planner.source_needs_heic(input):
			result = Bridge.run("decode", [input, decoded])
			can_encode = bool(result.ok)
			input = decoded
		if can_encode:
			var bytes := FileDrop.encode_image(input, "png" if image_format == "heic" else image_format, quality)
			if not bytes.is_empty():
				var path := intermediate if image_format == "heic" else output
				var file := FileAccess.open(path, FileAccess.WRITE)
				if file != null:
					file.store_buffer(bytes)
					file.flush()
					result = {"ok": file.get_error() == OK, "error": "图片写入失败。"}
					file.close()
					if bool(result.ok) and image_format == "heic":
						result = Bridge.run("encode", [intermediate, output, str(quality)])
			else:
				result = {"ok": false, "error": "图片无法解码或编码，源文件可能损坏。"}
	if bool(result.ok):
		issue = _check_source(item)
		if not issue.is_empty():
			result = {"ok": false, "error": issue}
	if bool(result.ok):
		# Atomic no-replace final commit also catches targets created during encoding.
		result = Bridge.run("move", [output, str(item.target)])
	_set_status(item, "completed" if bool(result.ok) else "failed", "" if bool(result.ok) else str(result.error))
	# Only remove known files in the private directory we successfully created.
	for path in [output, decoded, intermediate]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(folder)


func _set_status(item: Dictionary, status: String, message: String = "") -> void:
	item["status"] = status
	item["result_status"] = status
	item["message"] = message


func _finish(plan: Dictionary) -> Dictionary:
	var counts := {"completed": 0, "failed": 0, "skipped": 0, "cancelled": 0}
	for item: Dictionary in plan.get("items", []):
		if counts.has(str(item.status)):
			counts[str(item.status)] += 1
	plan["counts"] = counts
	plan["finished"] = true
	_publish(plan)
	return plan


func _key(path: String) -> String:
	return path.replace("\\", "/").simplify_path().to_lower()


func _token() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()
