  1 | extends Control
  2 | 
  3 | signal item_selected(id: int)
  4 | signal interactive_changed(enabled: bool)
  5 | 
  6 | @onready var card: PanelContainer = $Card
  7 | @onready var items_box: VBoxContainer = $Card/Margin/Items
  8 | 
  9 | var _active_tween: Tween
 10 | var _base_position := Vector2.ZERO
 11 | 
 12 | 
 13 | func _ready() -> void:
 14 | 	hide()
 15 | 
 16 | 
 17 | func open_menu(items: Array, at_position: Vector2, window_size: Vector2) -> void:
 18 | 	_rebuild(items)
 19 | 
 20 | 	if _active_tween != null and _active_tween.is_valid():
 21 | 		_active_tween.kill()
 22 | 
 23 | 	show()
 24 | 	modulate.a = 0.0
 25 | 	card.reset_size()
 26 | 	items_box.reset_size()
 27 | 
 28 | 	var min_size := card.get_combined_minimum_size()
 29 | 	var target_size := Vector2(maxf(202.0, min_size.x), min_size.y)
 30 | 	size = target_size
 31 | 	card.size = target_size
 32 | 
 33 | 	var x := clampf(
 34 | 		at_position.x,
 35 | 		8.0,
 36 | 		maxf(8.0, window_size.x - target_size.x - 8.0)
 37 | 	)
 38 | 	var y := clampf(
 39 | 		at_position.y,
 40 | 		8.0,
 41 | 		maxf(8.0, window_size.y - target_size.y - 8.0)
 42 | 	)
 43 | 	_base_position = Vector2(round(x), round(y))
 44 | 	position = _base_position + Vector2(0.0, 4.0)
 45 | 	scale = Vector2(0.97, 0.97)
 46 | 	pivot_offset = size * Vector2(0.45, 0.22)
 47 | 	interactive_changed.emit(true)
 48 | 
 49 | 	_active_tween = create_tween()
 50 | 	_active_tween.set_parallel(true)
 51 | 	_active_tween.set_trans(Tween.TRANS_BACK)
 52 | 	_active_tween.set_ease(Tween.EASE_OUT)
 53 | 	_active_tween.tween_property(self, "scale", Vector2.ONE, 0.13)
 54 | 	_active_tween.tween_property(self, "position", _base_position, 0.11)
 55 | 	_active_tween.tween_property(self, "modulate:a", 1.0, 0.08)
 56 | 
 57 | 
 58 | func hide_menu(animated: bool = true) -> void:
 59 | 	if not visible:
 60 | 		interactive_changed.emit(false)
 61 | 		return
 62 | 
 63 | 	if _active_tween != null and _active_tween.is_valid():
 64 | 		_active_tween.kill()
 65 | 
 66 | 	if not animated:
 67 | 		hide()
 68 | 		scale = Vector2.ONE
 69 | 		modulate.a = 1.0
 70 | 		interactive_changed.emit(false)
 71 | 		return
 72 | 
 73 | 	_active_tween = create_tween()
 74 | 	_active_tween.set_parallel(true)
 75 | 	_active_tween.set_trans(Tween.TRANS_QUAD)
 76 | 	_active_tween.set_ease(Tween.EASE_IN)
 77 | 	_active_tween.tween_property(
 78 | 		self,
 79 | 		"scale",
 80 | 		Vector2(0.985, 0.985),
 81 | 		0.07
 82 | 	)
 83 | 	_active_tween.tween_property(
 84 | 		self,
 85 | 		"position",
 86 | 		_base_position + Vector2(0.0, -2.0),
 87 | 		0.07
 88 | 	)
 89 | 	_active_tween.tween_property(self, "modulate:a", 0.0, 0.07)
 90 | 	await _active_tween.finished
 91 | 	hide()
 92 | 	scale = Vector2.ONE
 93 | 	modulate.a = 1.0
 94 | 	interactive_changed.emit(false)
 95 | 
 96 | 
 97 | func contains_point(local_point: Vector2) -> bool:
 98 | 	return Rect2(position, size).has_point(local_point)
 99 | 

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
