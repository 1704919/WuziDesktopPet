  1 | extends RefCounted
  2 | 
  3 | const IMAGE_EXTENSIONS := ["png", "jpg", "jpeg", "webp", "heic", "heif", "bmp", "tga"]
  4 | const RESERVED_WINDOWS_NAMES := [
  5 | 	"CON", "PRN", "AUX", "NUL",
  6 | 	"COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
  7 | 	"LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"
  8 | ]
  9 | const INVALID_WINDOWS_CHARS := ["<", ">", ":", "/", "\\", "|", "?", "*"]
 10 | 
 11 | 
 12 | func build_plan(paths: PackedStringArray, raw_params: Dictionary, capabilities: Dictionary = {}) -> Dictionary:
 13 | 	var params := _normalized_params(raw_params)
 14 | 	var source_keys: Dictionary = {}
 15 | 	for path in paths:
 16 | 		source_keys[_path_key(path)] = true
 17 | 
 18 | 	var items: Array = []
 19 | 	var target_counts: Dictionary = {}
 20 | 	var global_issues: Array[String] = []
 21 | 	var regex: RegEx = null
 22 | 
 23 | 	if bool(params.regex_enabled) and not str(params.find_text).is_empty():
 24 | 		var pattern := str(params.find_text)
 25 | 		if not _regex_is_complete_enough(pattern):
 26 | 			global_issues.append("正则表达式无效或尚未输入完整。")
 27 | 		else:
 28 | 			regex = RegEx.new()
 29 | 			if regex.compile(pattern) != OK:
 30 | 				global_issues.append("正则表达式无效。")
 31 | 				regex = null
 32 | 
 33 | 	if str(params.output_mode) == "custom" and str(params.output_dir).strip_edges().is_empty():
 34 | 		global_issues.append("请选择指定输出目录。")
 35 | 
 36 | 	for index in range(paths.size()):
 37 | 		var source := str(paths[index])
 38 | 		var item := _build_item(source, index, params, regex, source_keys)
 39 | 		items.append(item)
 40 | 		var target_key := _path_key(str(item.target))
 41 | 		target_counts[target_key] = int(target_counts.get(target_key, 0)) + 1
 42 | 
 43 | 	for index in range(items.size()):
 44 | 		var item := items[index] as Dictionary
 45 | 		var issues := item.issues as Array
 46 | 		if int(target_counts.get(_path_key(str(item.target)), 0)) > 1:
 47 | 			issues.append("批内有多个文件生成同一目标路径。")
 48 | 		for issue in global_issues:
 49 | 			issues.append(issue)
 50 | 		item.issues = _unique_strings(issues)
 51 | 		item.can_execute = (item.issues as Array).is_empty()
 52 | 		item.status = "ready" if bool(item.can_execute) else "blocked"
 53 | 		items[index] = item
 54 | 		if item.operation == "convert":
 55 | 			if source_needs_heic(str(item.source)) and not bool(capabilities.get("read", true)):
 56 | 				item.issues.append("当前 Windows 未提供所需 HEIC 读取支持。")
 57 | 			if params.image_format == "heic" and not bool(capabilities.get("write", true)):
 58 | 				item.issues.append("当前 Windows 未提供所需 HEIC 写入支持。")
 59 | 	# An occupied target is safe only when a valid rename will vacate it.
 60 | 	propagate_dependencies(items)
 61 | 
 62 | 	var valid_count := 0
 63 | 	var conflict_count := 0
 64 | 	for item in items:
 65 | 		if bool((item as Dictionary).can_execute):
 66 | 			valid_count += 1
 67 | 		else:
 68 | 			conflict_count += 1
 69 | 
 70 | 	var plan := {
 71 | 		"params": params,
 72 | 		"items": items,
 73 | 		"valid_count": valid_count,
 74 | 		"conflict_count": conflict_count,
 75 | 		"total": items.size(),
 76 | 		"global_issues": global_issues,
 77 | 		"preview_only": true,
 78 | 		"can_execute": valid_count > 0
 79 | 	}
 80 | 	plan["plan_version"] = version_for(plan)
 81 | 	return plan
 82 | 
 83 | 
 84 | func _build_item(
 85 | 	source: String,
 86 | 	index: int,
 87 | 	params: Dictionary,
 88 | 	regex: RegEx,
 89 | 	source_keys: Dictionary
 90 | ) -> Dictionary:
 91 | 	var issues: Array[String] = []
 92 | 	var warnings: Array[String] = []
 93 | 	var source_name := source.get_file()
 94 | 	var source_ext := source_name.get_extension().to_lower()
 95 | 	var source_stem := _stem_from_name(source_name)
 96 | 	var renamed_stem := source_stem
 97 | 	var find_text := str(params.find_text)
 98 | 
 99 | 	if not find_text.is_empty():
		if bool(params.regex_enabled):
			if regex != null:
				renamed_stem = regex.sub(renamed_stem, str(params.replace_text), true)
		else:
			renamed_stem = renamed_stem.replace(find_text, str(params.replace_text))

	renamed_stem = str(params.prefix) + renamed_stem + str(params.suffix)

	if bool(params.numbering_enabled):
		var number := int(params.number_start) + index * int(params.number_step)
		var digits := maxi(1, int(params.number_digits))
		renamed_stem += "_" + str(number).pad_zeros(digits)

	var target_ext := source_name.get_extension()
	var kind := _classify(source)
	var image_format := str(params.image_format)
	if kind == "image" and image_format != "keep":
		target_ext = image_format

	var target_name := renamed_stem
	if not target_ext.is_empty():
		target_name += "." + target_ext

	_validate_filename(target_name, issues)

	var output_dir := source.get_base_dir()
	if str(params.output_mode) == "custom":
		output_dir = str(params.output_dir).strip_edges()
	var target := output_dir.path_join(target_name) if not output_dir.is_empty() else target_name
	var operation := "rename" if params.output_mode == "source" else "copy"
	if kind == "image" and image_format != "keep":
		operation = "convert"

	if not FileAccess.file_exists(source):
		issues.append("源文件不存在或已被移动。")

	if output_dir.is_empty():
		issues.append("目标目录为空。")
	elif not DirAccess.dir_exists_absolute(output_dir):
		issues.append("目标目录不存在或已经失效。")
	elif DirAccess.open(output_dir) == null:
		issues.append("目标目录当前无法访问。")

	var source_key := _path_key(source)
	var target_key := _path_key(target)
	if source.replace("\\", "/").simplify_path() == target.replace("\\", "/").simplify_path() or (source_key == target_key and operation != "rename"):
		issues.append("源路径与目标路径完全相同，没有可执行变化。")
	elif FileAccess.file_exists(target) and not source_keys.has(target_key):
		issues.append("目标路径已经存在文件，默认禁止覆盖。")
	if DirAccess.dir_exists_absolute(target):
		issues.append("目标路径已经存在目录，默认禁止覆盖。")

	if kind in ["audio", "video"]:
		warnings.append("音频和视频只参与批量重命名；本项目不提供音视频格式转换。")
	elif kind == "other":
		warnings.append("该文件只参与批量重命名，不做格式转换。")

	if kind == "image" and image_format != "keep" and target.get_extension().to_lower() != image_format:
		issues.append("图片目标扩展名与转换格式不一致。")

	return {
		"index": index,
		"source": source,
		"target": target,
		"source_name": source_name,
		"target_name": target_name,
		"kind": kind,
		"operation": operation,
		"source_stamp": source_stamp(source),
		"issues": issues,
		"warnings": warnings,
		"can_execute": false,
		"status": "waiting"
	}


func _normalized_params(raw: Dictionary) -> Dictionary:
	var image_format := str(raw.get("image_format", "keep")).to_lower()
	if image_format == "jpeg":
		image_format = "jpg"
	if image_format not in ["keep", "png", "jpg", "webp", "heic"]:
		image_format = "keep"

	var output_mode := str(raw.get("output_mode", "source"))
	if output_mode not in ["source", "custom"]:
		output_mode = "source"

	return {
		"find_text": str(raw.get("find_text", "")),
		"replace_text": str(raw.get("replace_text", "")),
		"prefix": str(raw.get("prefix", "")),
		"suffix": str(raw.get("suffix", "")),
		"regex_enabled": bool(raw.get("regex_enabled", false)),
		"numbering_enabled": bool(raw.get("numbering_enabled", false)),
		"number_start": int(raw.get("number_start", 1)),
		"number_step": maxi(1, int(raw.get("number_step", 1))),
		"number_digits": clampi(int(raw.get("number_digits", 2)), 1, 8),
		"image_format": image_format,
		"output_mode": output_mode,
		"output_dir": str(raw.get("output_dir", "")).strip_edges()
	}


func _validate_filename(file_name: String, issues: Array[String]) -> void:
	var name_without_ext := _stem_from_name(file_name)
	if file_name.is_empty() or name_without_ext.is_empty():
		issues.append("文件名不能为空。")
		return

	for invalid_char in INVALID_WINDOWS_CHARS:
		if file_name.contains(invalid_char):
			issues.append("文件名包含 Windows 非法字符：%s" % invalid_char)
			break
	if file_name.contains(String.chr(34)):
		issues.append("文件名包含 Windows 非法字符：双引号")

	if file_name.ends_with(" ") or file_name.ends_with("."):
		issues.append("Windows 文件名不能以空格或句点结尾。")

	for character in file_name:
		if character.unicode_at(0) < 32:
			issues.append("文件名包含 Windows 非法控制字符。")
			break
	var reserved_candidate := file_name.get_slice(".", 0).strip_edges().to_upper()
	if reserved_candidate in RESERVED_WINDOWS_NAMES or reserved_candidate in ["COM¹", "COM²", "COM³", "LPT¹", "LPT²", "LPT³", "CONIN$", "CONOUT$"]:
		issues.append("文件名使用了 Windows 保留设备名：%s" % reserved_candidate)
	if file_name.length() > 255:
		issues.append("文件名超过 255 个字符。")


func _classify(path: String) -> String:
	var ext := path.get_extension().to_lower()
	if ext in IMAGE_EXTENSIONS:
		return "image"
	if ext in ["mp3", "wav", "flac", "ogg", "m4a", "aac", "opus"]:
		return "audio"
	if ext in ["mp4", "mov", "mkv", "webm", "avi", "gif"]:
		return "video"
	return "other"


func _stem_from_name(file_name: String) -> String:
	var ext := file_name.get_extension()
	if ext.is_empty():
		return file_name
	return file_name.left(file_name.length() - ext.length() - 1)


func _path_key(path: String) -> String:
	return path.replace("\\", "/").simplify_path().to_lower()


func _unique_strings(values: Array) -> Array[String]:
	var seen: Dictionary = {}
	var result: Array[String] = []
	for value in values:
		var text := str(value)
		if not seen.has(text):
			seen[text] = true
			result.append(text)
	return result


func _regex_is_complete_enough(pattern: String) -> bool:
	if pattern.is_empty():
		return true
	if pattern.begins_with("*") or pattern.begins_with("+") or pattern.begins_with("?"):
		return false

	var escaped := false
	var in_class := false
	var paren_depth := 0
	var brace_depth := 0
	for index in range(pattern.length()):
		var ch := pattern.substr(index, 1)
		if escaped:
			escaped = false
			continue
		if ch == "\\":
			escaped = true
			continue
		if in_class:
			if ch == "]":
				in_class = false
			continue
		match ch:
			"[":
				in_class = true
			"(":
				paren_depth += 1
			")":
				if paren_depth == 0:
					return false
				paren_depth -= 1
			"{":
				brace_depth += 1
			"}":
				if brace_depth == 0:
					return false
				brace_depth -= 1

	return not escaped and not in_class and paren_depth == 0 and brace_depth == 0


func _plan_version(signature: String) -> String:
	var hashing := HashingContext.new()
	if hashing.start(HashingContext.HASH_SHA256) != OK:
		return "5B-" + str(signature.hash())
	hashing.update(signature.to_utf8_buffer())
	return "5B-" + hashing.finish().hex_encode()


func version_for(plan: Dictionary) -> String:
	# Include exact paths and displayed operations, not a second application of rules.
	var records: Array = []
	for item: Dictionary in plan.get("items", []):
		records.append([item.source, item.target, item.operation, item.source_stamp, item.issues])
	return _plan_version(JSON.stringify([plan.get("params", {}), records]))


static func source_needs_heic(path: String) -> bool:
	return path.get_extension().to_lower() in ["heic", "heif"]


static func source_stamp(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	return [file.get_length(), FileAccess.get_modified_time(path)]


func propagate_dependencies(items: Array) -> void:
	var sources: Dictionary = {}
	for item: Dictionary in items:
		var key := _path_key(str(item.source))
		if sources.has(key):
			item.issues.append("同一源文件重复出现在队列中。")
			(sources[key] as Dictionary).issues.append("同一源文件重复出现在队列中。")
		sources[key] = item
	for _pass in range(items.size() + 1):
		var changed := false
		for item: Dictionary in items:
			if not (item.issues as Array).is_empty():
				item.can_execute = false
				item.status = "blocked"
				continue
			var key := _path_key(str(item.target))
			if FileAccess.file_exists(str(item.target)) and key != _path_key(str(item.source)):
				var owner: Dictionary = sources.get(key, {})
				if owner.is_empty() or owner.operation != "rename" or not (owner.issues as Array).is_empty():
					item.issues.append("目标路径已经存在且不会由有效重命名腾空，默认禁止覆盖。")
					changed = true
			item.can_execute = (item.issues as Array).is_empty()
			item.status = "ready" if item.can_execute else "blocked"
		if not changed:
			break

