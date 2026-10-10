 1 | extends RefCounted
 2 | 
 3 | 
 4 | static func executable_path() -> String:
 5 | 	if OS.has_feature("editor"):
 6 | 		return ProjectSettings.globalize_path("res://native/wuzi_file_bridge.exe")
 7 | 	return OS.get_executable_path().get_base_dir().path_join("native/wuzi_file_bridge.exe")
 8 | 
 9 | 
static func run(operation: String, arguments: PackedStringArray = []) -> Dictionary:
	var executable := executable_path()
	if OS.get_name() != "Windows" or not FileAccess.file_exists(executable):
		return {"ok": false, "read": false, "write": false, "error": "Windows 文件组件不可用。"}
	var args := PackedStringArray([operation])
	args.append_array(arguments)
	var output: Array = []
	var code := OS.execute(executable, args, output, false, false)
	var result: Variant = JSON.parse_string("".join(output))
	if result is Dictionary:
		result["ok"] = bool(result.get("ok", false)) and code == 0
		if not bool(result.ok):
			var error_code := str(result.get("error", ""))
			var descriptions := {
				"0x80070005": "没有文件或目录的访问权限",
				"0x80070020": "文件正在被其他程序占用",
				"0x80070050": "目标已经存在，禁止覆盖",
				"0x800700B7": "目标已经存在，禁止覆盖",
				"0x80070002": "源文件不存在或已被移动",
				"0x80070003": "目录不存在或已经失效",
				"0x80070070": "磁盘空间不足",
				"0x88982F50": "当前 Windows 未提供所需图片编解码支持",
				"0x88982F07": "图片数据损坏或不是有效图片",
				"0x88982F80": "系统图片组件无法处理此图片的像素格式"
			}
			result["error"] = "%s（%s）" % [descriptions.get(error_code, "Windows 文件操作或图片转换失败"), error_code]
		return result
	return {"ok": false, "read": false, "write": false, "error": "Windows 文件组件返回异常（%d）。" % code}
