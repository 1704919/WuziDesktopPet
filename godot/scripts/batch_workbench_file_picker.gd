 1 | extends RefCounted
 2 | 
 3 | 
 4 | static func create_files_dialog(callback: Callable) -> FileDialog:
 5 | 	var dialog := FileDialog.new()
 6 | 	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
 7 | 	dialog.access = FileDialog.ACCESS_FILESYSTEM
 8 | 	dialog.use_native_dialog = true
 9 | 	dialog.files_selected.connect(callback)
	return dialog


static func create_folder_dialog(callback: Callable) -> FileDialog:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = true
	dialog.dir_selected.connect(callback)
	return dialog


static func create_output_folder_dialog(callback: Callable) -> FileDialog:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = true
	dialog.dir_selected.connect(callback)
	return dialog


static func collect_files(path: String, recursive: bool, output: PackedStringArray, errors: Array[String] = []) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		errors.append("无法读取目录：%s" % path)
		return
	var open_error := dir.list_dir_begin()
	if open_error != OK:
		errors.append("无法列出目录：%s" % path)
		return
	while true:
		var entry := dir.get_next()
		if entry.is_empty():
			break
		if entry == "." or entry == "..":
			continue
		var full := path.path_join(entry)
		if dir.is_link(entry) or entry.begins_with(".wuzi-"):
			continue
		if dir.current_is_dir():
			if recursive:
				collect_files(full, true, output, errors)
		else:
			output.append(full)
	dir.list_dir_end()
