extends RefCounted

const WindowsFileBridge = preload("res://scripts/windows_file_bridge.gd")


static func hide_from_taskbar(window: Window) -> void:
	if OS.get_name() != "Windows" or DisplayServer.get_name() == "headless":
		return
	var executable := WindowsFileBridge.executable_path()
	if not FileAccess.file_exists(executable):
		push_warning("Windows 窗口组件缺失，无法隐藏任务栏图标。")
		return
	var handle := DisplayServer.window_get_native_handle(
		DisplayServer.WINDOW_HANDLE, window.get_window_id()
	)
	if handle == 0:
		return
	# Native style changes send messages back to this UI thread. Do not OS.execute
	# and synchronously wait for the helper: that would deadlock those messages.
	var pid := OS.create_process(executable, PackedStringArray([
		"window-style", str(handle), str(OS.get_process_id())
	]), false)
	if pid < 0:
		push_warning("Windows 窗口组件启动失败。")
