extends Node

# Global desktop coordinates keep movement stable while the HWND itself moves.
# Godot's native SC_MOVE path can be ignored by borderless tool windows.
var target_window: Window
var resize := false
var _mouse_start := Vector2i.ZERO
var _position_start := Vector2i.ZERO
var _size_start := Vector2i.ZERO


func bind(handle: Control, window: Window, resizing: bool = false) -> void:
	target_window = window
	resize = resizing
	handle.mouse_filter = Control.MOUSE_FILTER_STOP
	handle.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE if resize else Control.CURSOR_MOVE
	handle.gui_input.connect(_on_gui_input.bind(handle))
	window.visibility_changed.connect(_stop)
	window.focus_exited.connect(_stop)
	set_process(false)


func _on_gui_input(event: InputEvent, handle: Control) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_mouse_start = DisplayServer.mouse_get_position()
			_position_start = target_window.position
			_size_start = target_window.size
			set_process(true)
		else:
			_stop()
		handle.accept_event()


func _process(_delta: float) -> void:
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_stop()
		return
	var offset := DisplayServer.mouse_get_position() - _mouse_start
	if resize:
		target_window.size = (_size_start + offset).max(target_window.min_size)
	else:
		target_window.position = _position_start + offset


func _stop() -> void:
	set_process(false)
