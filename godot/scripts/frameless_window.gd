extends RefCounted

const WindowsWindowPolicy = preload("res://scripts/windows_window_policy.gd")
const WindowDragHandle = preload("res://scripts/window_drag_handle.gd")


static func configure(window: Window) -> void:
	window.borderless = true
	window.transparent = true
	window.transparent_bg = true
	window.transient = false
	window.exclusive = false
	window.minimize_disabled = true
	window.maximize_disabled = true


static func bind_drag_handle(handle: Control, window: Window) -> void:
	var drag := WindowDragHandle.new()
	handle.add_child(drag)
	drag.bind(handle, window)


static func show_window(window: Window) -> void:
	window.show()
	WindowsWindowPolicy.hide_from_taskbar(window)
	window.grab_focus()


static func add_resize_grip(window: Window) -> void:
	var grip := Label.new()
	grip.text = "◢"
	grip.tooltip_text = "拖动调整大小"
	window.add_child(grip)
	grip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	grip.position -= Vector2(18, 18)
	var drag := WindowDragHandle.new()
	grip.add_child(drag)
	drag.bind(grip, window, true)


static func usable_rect(window: Window) -> Rect2i:
	if DisplayServer.get_name() == "headless":
		return Rect2i(0, 0, 1920, 1080)
	return DisplayServer.screen_get_usable_rect(window.current_screen)


static func clamp_position(window: Window, proposed: Vector2i) -> Vector2i:
	var area := usable_rect(window)
	return Vector2i(
		clampi(proposed.x, area.position.x, maxi(area.position.x, area.end.x - window.size.x)),
		clampi(proposed.y, area.position.y, maxi(area.position.y, area.end.y - window.size.y))
	)
