  1 | extends RefCounted
  2 | 
  3 | 
  4 | static func panel_style() -> StyleBoxFlat:
  5 | 	var style := StyleBoxFlat.new()
  6 | 	style.bg_color = Color(0.98, 0.975, 0.995, 1.0)
  7 | 	style.border_width_left = 1
  8 | 	style.border_width_top = 1
  9 | 	style.border_width_right = 1
 10 | 	style.border_width_bottom = 1
 11 | 	style.border_color = Color(0.82, 0.79, 0.90, 0.95)
 12 | 	style.corner_radius_top_left = 18
 13 | 	style.corner_radius_top_right = 18
 14 | 	style.corner_radius_bottom_left = 18
 15 | 	style.corner_radius_bottom_right = 18
 16 | 	return style
 17 | 
 18 | 
 19 | static func workbench_theme() -> Theme:
 20 | 	var theme := Theme.new()
 21 | 	theme.default_font_size = 14
 22 | 	var text_color := Color(0.12, 0.10, 0.16)
 23 | 	var muted_color := Color(0.40, 0.36, 0.48)
 24 | 
 25 | 	theme.set_color("font_color", "Label", text_color)
 26 | 	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))
 27 | 	theme.set_color("font_color", "TooltipLabel", text_color)
 28 | 	theme.set_font_size("font_size", "TooltipLabel", 13)
 29 | 	theme.set_stylebox("panel", "TooltipPanel", _tooltip_panel_style())
 30 | 
 31 | 	for theme_type in ["Button", "OptionButton"]:
 32 | 		theme.set_color("font_color", theme_type, text_color)
 33 | 		theme.set_color("font_hover_color", theme_type, text_color)
 34 | 		theme.set_color("font_pressed_color", theme_type, text_color)
 35 | 		theme.set_color("font_disabled_color", theme_type, muted_color)
 36 | 		theme.set_stylebox("normal", theme_type, _button_style(Color(0.94, 0.925, 0.97), Color(0.79, 0.75, 0.87)))
 37 | 		theme.set_stylebox("hover", theme_type, _button_style(Color(0.91, 0.88, 0.96), Color(0.70, 0.64, 0.82)))
 38 | 		theme.set_stylebox("pressed", theme_type, _button_style(Color(0.86, 0.82, 0.93), Color(0.61, 0.53, 0.77)))
 39 | 		theme.set_stylebox("focus", theme_type, _button_style(Color(0.94, 0.925, 0.97), Color(0.52, 0.42, 0.72)))
 40 | 		theme.set_stylebox("disabled", theme_type, _button_style(Color(0.94, 0.93, 0.96), Color(0.86, 0.83, 0.90)))
 41 | 
 42 | 	theme.set_color("font_color", "LineEdit", text_color)
 43 | 	theme.set_color("font_uneditable_color", "LineEdit", muted_color)
 44 | 	theme.set_stylebox("normal", "LineEdit", _input_style(Color(0.985, 0.98, 0.995), Color(0.79, 0.75, 0.87), 1))
 45 | 	theme.set_stylebox("focus", "LineEdit", _input_style(Color(1.0, 0.995, 1.0), Color(0.52, 0.42, 0.72), 2))
 46 | 	theme.set_stylebox("read_only", "LineEdit", _input_style(Color(0.95, 0.94, 0.97), Color(0.84, 0.81, 0.89), 1))
 47 | 
 48 | 	theme.set_color("font_color", "CheckButton", text_color)
 49 | 	theme.set_color("font_hover_color", "CheckButton", text_color)
 50 | 	theme.set_color("font_pressed_color", "CheckButton", text_color)
 51 | 
 52 | 	theme.set_color("font_color", "ItemList", text_color)
 53 | 	theme.set_color("font_selected_color", "ItemList", Color(0.14, 0.10, 0.22))
 54 | 	theme.set_stylebox("panel", "ItemList", _list_panel_style())
 55 | 	theme.set_stylebox("focus", "ItemList", _list_focus_style())
 56 | 	theme.set_stylebox("selected", "ItemList", _list_selected_style())
 57 | 	theme.set_stylebox("selected_focus", "ItemList", _list_selected_style())
 58 | 
 59 | 	var separator := StyleBoxLine.new()
 60 | 	separator.color = Color(0.82, 0.79, 0.90, 0.75)
 61 | 	separator.thickness = 1
 62 | 	theme.set_stylebox("separator", "HSeparator", separator)
 63 | 	return theme
 64 | 
 65 | 
 66 | static func help_button_style(background: Color, border: Color) -> StyleBoxFlat:
 67 | 	var style := StyleBoxFlat.new()
 68 | 	style.bg_color = background
 69 | 	style.border_width_left = 1
 70 | 	style.border_width_top = 1
 71 | 	style.border_width_right = 1
 72 | 	style.border_width_bottom = 1
 73 | 	style.border_color = border
 74 | 	style.corner_radius_top_left = 10
 75 | 	style.corner_radius_top_right = 10
 76 | 	style.corner_radius_bottom_left = 10
 77 | 	style.corner_radius_bottom_right = 10
 78 | 	style.content_margin_left = 4.0
 79 | 	style.content_margin_right = 4.0
 80 | 	style.content_margin_top = 1.0
 81 | 	style.content_margin_bottom = 1.0
 82 | 	return style
 83 | 
 84 | 
 85 | static func _tooltip_panel_style() -> StyleBoxFlat:
 86 | 	var style := StyleBoxFlat.new()
 87 | 	style.bg_color = Color(0.985, 0.98, 0.995, 0.98)
 88 | 	style.border_width_left = 1
 89 | 	style.border_width_top = 1
 90 | 	style.border_width_right = 1
 91 | 	style.border_width_bottom = 1
 92 | 	style.border_color = Color(0.72, 0.67, 0.82, 0.95)
 93 | 	style.corner_radius_top_left = 10
 94 | 	style.corner_radius_top_right = 10
 95 | 	style.corner_radius_bottom_left = 10
 96 | 	style.corner_radius_bottom_right = 10
 97 | 	style.content_margin_left = 10.0
 98 | 	style.content_margin_right = 10.0
 99 | 	style.content_margin_top = 8.0
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
