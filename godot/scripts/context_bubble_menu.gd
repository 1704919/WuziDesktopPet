extends Control

signal item_selected(id: int)
signal interactive_changed(enabled: bool)

@onready var card: PanelContainer = $Card
@onready var items_box: VBoxContainer = $Card/Margin/Items

var _active_tween: Tween
var _base_position := Vector2.ZERO


func _ready() -> void:
	hide()


func open_menu(items: Array, at_position: Vector2, window_size: Vector2) -> void:
	_rebuild(items)

	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()

	show()
	modulate.a = 0.0
	card.reset_size()
	items_box.reset_size()

	var min_size := card.get_combined_minimum_size()
	var target_size := Vector2(maxf(202.0, min_size.x), min_size.y)
	size = target_size
	card.size = target_size

	var x := clampf(
		at_position.x,
		8.0,
		maxf(8.0, window_size.x - target_size.x - 8.0)
	)
	var y := clampf(
		at_position.y,
		8.0,
		maxf(8.0, window_size.y - target_size.y - 8.0)
	)
	_base_position = Vector2(round(x), round(y))
	position = _base_position + Vector2(0.0, 4.0)
	scale = Vector2(0.97, 0.97)
	pivot_offset = size * Vector2(0.45, 0.22)
	interactive_changed.emit(true)

	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	_active_tween.set_trans(Tween.TRANS_BACK)
	_active_tween.set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(self, "scale", Vector2.ONE, 0.13)
	_active_tween.tween_property(self, "position", _base_position, 0.11)
	_active_tween.tween_property(self, "modulate:a", 1.0, 0.08)


func hide_menu(animated: bool = true) -> void:
	if not visible:
		interactive_changed.emit(false)
		return

	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()

	if not animated:
		hide()
		scale = Vector2.ONE
		modulate.a = 1.0
		interactive_changed.emit(false)
		return

	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	_active_tween.set_trans(Tween.TRANS_QUAD)
	_active_tween.set_ease(Tween.EASE_IN)
	_active_tween.tween_property(
		self,
		"scale",
		Vector2(0.985, 0.985),
		0.07
	)
	_active_tween.tween_property(
		self,
		"position",
		_base_position + Vector2(0.0, -2.0),
		0.07
	)
	_active_tween.tween_property(self, "modulate:a", 0.0, 0.07)
	await _active_tween.finished
	hide()
	scale = Vector2.ONE
	modulate.a = 1.0
	interactive_changed.emit(false)


func contains_point(local_point: Vector2) -> bool:
	return Rect2(position, size).has_point(local_point)


func _rebuild(items: Array) -> void:
	for child in items_box.get_children():
		items_box.remove_child(child)
		child.queue_free()

	for raw in items:
		var spec := raw as Dictionary
		if bool(spec.get("separator", false)):
			var separator := HSeparator.new()
			separator.add_theme_constant_override("separation", 5)
			items_box.add_child(separator)
			continue

		var button := Button.new()
		var label := str(spec.get("label", ""))
		if bool(spec.get("checked", false)):
			label = "✓  " + label
		else:
			label = "   " + label

		button.text = label
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(184, 34)
		button.focus_mode = Control.FOCUS_NONE
		button.disabled = bool(spec.get("disabled", false))
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_font_size_override("font_size", 14)
		button.add_theme_color_override("font_color", Color("#2B2440"))
		button.add_theme_color_override("font_hover_color", Color("#211A38"))
		button.add_theme_color_override("font_disabled_color", Color("#9A94A5"))
		button.add_theme_stylebox_override("normal", _item_style(Color(0, 0, 0, 0)))
		button.add_theme_stylebox_override("hover", _item_style(Color("#E8DEF8")))
		button.add_theme_stylebox_override("pressed", _item_style(Color("#D8CCEF")))
		button.add_theme_stylebox_override("disabled", _item_style(Color(0, 0, 0, 0)))

		var id := int(spec.get("id", -1))
		button.pressed.connect(_on_item_pressed.bind(id))
		items_box.add_child(button)


func _item_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 13
	style.corner_radius_top_right = 13
	style.corner_radius_bottom_left = 13
	style.corner_radius_bottom_right = 13
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style


func _on_item_pressed(id: int) -> void:
	if id < 0:
		return
	hide_menu(false)
	item_selected.emit(id)
