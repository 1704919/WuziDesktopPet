 1 | extends RefCounted
 2 | 
 3 | const BatchWorkbenchTheme = preload("res://scripts/batch_workbench_theme.gd")
 4 | 
 5 | 
 6 | static func add_section_title(parent: VBoxContainer, text: String) -> void:
 7 | 	var label := Label.new()
 8 | 	label.text = text
 9 | 	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.31, 0.24, 0.44))
	parent.add_child(label)


static func add_line_field(parent: VBoxContainer, label_text: String) -> LineEdit:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(52, 0)
	row.add_child(label)

	var edit := LineEdit.new()
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(edit)
	return edit


static func add_spin_field(
	parent: HBoxContainer,
	label_text: String,
	default_value: float,
	minimum: float,
	maximum: float,
	help_text: String = ""
) -> SpinBox:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(box)

	var label_row := HBoxContainer.new()
	label_row.add_theme_constant_override("separation", 4)
	box.add_child(label_row)

	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 12)
	label_row.add_child(label)
	if not help_text.is_empty():
		add_help_button(label_row, help_text)

	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = 1
	spin.value = default_value
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(spin)
	return spin


static func add_help_button(parent: Control, help_text: String) -> Button:
	var help := Button.new()
	help.text = "?"
	help.tooltip_text = help_text
	help.focus_mode = Control.FOCUS_NONE
	help.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	help.custom_minimum_size = Vector2(20, 20)
	help.add_theme_font_size_override("font_size", 11)
	help.add_theme_color_override("font_color", Color(0.34, 0.27, 0.48))
	help.add_theme_color_override("font_hover_color", Color(0.20, 0.14, 0.32))
	help.add_theme_stylebox_override(
		"normal",
		BatchWorkbenchTheme.help_button_style(Color(0.94, 0.925, 0.97), Color(0.73, 0.68, 0.82))
	)
	help.add_theme_stylebox_override(
		"hover",
		BatchWorkbenchTheme.help_button_style(Color(0.89, 0.86, 0.95), Color(0.60, 0.52, 0.75))
	)
	help.add_theme_stylebox_override(
		"pressed",
		BatchWorkbenchTheme.help_button_style(Color(0.86, 0.82, 0.93), Color(0.56, 0.48, 0.71))
	)
	help.add_theme_stylebox_override(
		"focus",
		BatchWorkbenchTheme.help_button_style(Color(0.94, 0.925, 0.97), Color(0.73, 0.68, 0.82))
	)
	parent.add_child(help)
	return help
