extends RefCounted


static func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.98, 0.975, 0.995, 1.0)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.82, 0.79, 0.90, 0.95)
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	return style


static func workbench_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 14
	var text_color := Color(0.12, 0.10, 0.16)
	var muted_color := Color(0.40, 0.36, 0.48)

	theme.set_color("font_color", "Label", text_color)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))
	theme.set_color("font_color", "TooltipLabel", text_color)
	theme.set_font_size("font_size", "TooltipLabel", 13)
	theme.set_stylebox("panel", "TooltipPanel", _tooltip_panel_style())

	for theme_type in ["Button", "OptionButton"]:
		theme.set_color("font_color", theme_type, text_color)
		theme.set_color("font_hover_color", theme_type, text_color)
		theme.set_color("font_pressed_color", theme_type, text_color)
		theme.set_color("font_disabled_color", theme_type, muted_color)
		theme.set_stylebox("normal", theme_type, _button_style(Color(0.94, 0.925, 0.97), Color(0.79, 0.75, 0.87)))
		theme.set_stylebox("hover", theme_type, _button_style(Color(0.91, 0.88, 0.96), Color(0.70, 0.64, 0.82)))
		theme.set_stylebox("pressed", theme_type, _button_style(Color(0.86, 0.82, 0.93), Color(0.61, 0.53, 0.77)))
		theme.set_stylebox("focus", theme_type, _button_style(Color(0.94, 0.925, 0.97), Color(0.52, 0.42, 0.72)))
		theme.set_stylebox("disabled", theme_type, _button_style(Color(0.94, 0.93, 0.96), Color(0.86, 0.83, 0.90)))

	theme.set_color("font_color", "LineEdit", text_color)
	theme.set_color("font_uneditable_color", "LineEdit", muted_color)
	theme.set_stylebox("normal", "LineEdit", _input_style(Color(0.985, 0.98, 0.995), Color(0.79, 0.75, 0.87), 1))
	theme.set_stylebox("focus", "LineEdit", _input_style(Color(1.0, 0.995, 1.0), Color(0.52, 0.42, 0.72), 2))
	theme.set_stylebox("read_only", "LineEdit", _input_style(Color(0.95, 0.94, 0.97), Color(0.84, 0.81, 0.89), 1))

	theme.set_color("font_color", "CheckButton", text_color)
	theme.set_color("font_hover_color", "CheckButton", text_color)
	theme.set_color("font_pressed_color", "CheckButton", text_color)

	theme.set_color("font_color", "ItemList", text_color)
	theme.set_color("font_selected_color", "ItemList", Color(0.14, 0.10, 0.22))
	theme.set_stylebox("panel", "ItemList", _list_panel_style())
	theme.set_stylebox("focus", "ItemList", _list_focus_style())
	theme.set_stylebox("selected", "ItemList", _list_selected_style())
	theme.set_stylebox("selected_focus", "ItemList", _list_selected_style())

	var separator := StyleBoxLine.new()
	separator.color = Color(0.82, 0.79, 0.90, 0.75)
	separator.thickness = 1
	theme.set_stylebox("separator", "HSeparator", separator)
	return theme


static func help_button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 4.0
	style.content_margin_right = 4.0
	style.content_margin_top = 1.0
	style.content_margin_bottom = 1.0
	return style


static func _tooltip_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.985, 0.98, 0.995, 0.98)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.72, 0.67, 0.82, 0.95)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


static func _button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	return style


static func _input_style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	style.border_color = border
	style.corner_radius_top_left = 11
	style.corner_radius_top_right = 11
	style.corner_radius_bottom_left = 11
	style.corner_radius_bottom_right = 11
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	return style


static func _list_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.992, 0.988, 1.0)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.84, 0.81, 0.90)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


static func _list_focus_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.52, 0.42, 0.72, 0.8)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	return style


static func _list_selected_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.91, 0.88, 0.96)
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
	return style
