  1 | extends Control
  2 | 
  3 | signal action_selected(action_id: String)
  4 | signal interactive_changed(enabled: bool)
  5 | signal bounds_changed
  6 | 
  7 | @onready var card: PanelContainer = $Card
  8 | @onready var message_label: Label = $Card/Margin/Content/Message
  9 | @onready var actions_row: HBoxContainer = $Card/Margin/Content/Actions
 10 | @onready var hide_timer: Timer = $HideTimer
 11 | 
 12 | const WINDOW_WIDTH := 760.0
 13 | const WINDOW_HEIGHT := 420.0
 14 | const MIN_TEXT_WIDTH := 104.0
 15 | const MAX_TEXT_WIDTH := 270.0
 16 | const CARD_HORIZONTAL_PADDING := 28.0
 17 | const CARD_VERTICAL_PADDING := 20.0
 18 | const ACTION_ROW_HEIGHT := 32.0
 19 | const CONTENT_GAP := 8.0
 20 | const WINDOW_MARGIN := 8.0
 21 | # New 220 px character layout: keep the card close to the character's upper-left
 22 | # edge without overlapping the face. The card grows up/left from this point.
 23 | const BUBBLE_BOTTOM_RIGHT_ANCHOR := Vector2(468.0, 158.0)
 24 | const MAX_LINES_PER_PAGE := 4
 25 | const LINE_EXTRA_SPACING := 2.0
 26 | const APPEAR_OFFSET_Y := 5.0
 27 | const APPEAR_SCALE := 0.96
 28 | const APPEAR_DURATION := 0.15
 29 | const FADE_DURATION := 0.10
 30 | const HIDE_DURATION := 0.08
 31 | var current_text := ""
 32 | var active_tween: Tween
 33 | var interactive := false
 34 | var target_position := Vector2.ZERO
 35 | var show_generation := 0
 36 | 
 37 | var pages: Array[String] = []
 38 | var page_index := 0
 39 | var pending_actions: Array = []
 40 | var requested_duration_sec := 3.8
 41 | 
 42 | 
 43 | func _ready() -> void:
 44 | 	hide_timer.timeout.connect(_on_hide_timer_timeout)
 45 | 	hide()
 46 | 
 47 | 
 48 | func say(text: String, duration_sec: float = 3.8) -> void:
 49 | 	_prepare_content(text, [], duration_sec)
 50 | 
 51 | 
 52 | func ask(text: String, actions: Array, duration_sec: float = 0.0) -> void:
 53 | 	_prepare_content(text, actions, duration_sec)
 54 | 
 55 | 
 56 | func dismiss(animated: bool = true) -> void:
 57 | 	hide_timer.stop()
 58 | 	pages.clear()
 59 | 	page_index = 0
 60 | 	pending_actions.clear()
 61 | 
 62 | 	if not visible:
 63 | 		_set_interactive(false)
 64 | 		return
 65 | 
 66 | 	if active_tween != null and active_tween.is_valid():
 67 | 		active_tween.kill()
 68 | 
 69 | 	_set_interactive(false)
 70 | 
 71 | 	if not animated:
 72 | 		hide()
 73 | 		scale = Vector2.ONE
 74 | 		modulate.a = 1.0
 75 | 		bounds_changed.emit()
 76 | 		return
 77 | 
 78 | 	active_tween = create_tween()
 79 | 	active_tween.set_parallel(true)
 80 | 	active_tween.set_trans(Tween.TRANS_QUAD)
 81 | 	active_tween.set_ease(Tween.EASE_IN)
 82 | 	active_tween.tween_property(self, "modulate:a", 0.0, HIDE_DURATION)
 83 | 	active_tween.tween_property(
 84 | 		self,
 85 | 		"scale",
 86 | 		Vector2(0.98, 0.98),
 87 | 		HIDE_DURATION
 88 | 	)
 89 | 	active_tween.tween_property(
 90 | 		self,
 91 | 		"position",
 92 | 		target_position + Vector2(0.0, -2.0),
 93 | 		HIDE_DURATION
 94 | 	)
 95 | 	await active_tween.finished
 96 | 	hide()
 97 | 	scale = Vector2.ONE
 98 | 	modulate.a = 1.0
 99 | 	bounds_changed.emit()


func has_actions() -> bool:
	return interactive


func get_page_count() -> int:
	return pages.size()


func get_page_index() -> int:
	return page_index


func get_window_bounds() -> Rect2:
	return Rect2(target_position, size).grow(14.0)


func _prepare_content(
	text: String,
	actions: Array,
	duration_sec: float
) -> void:
	var clean := text.strip_edges()
	if clean.is_empty():
		return

	pages = _paginate_text(clean)
	if pages.is_empty():
		return

	page_index = 0
	pending_actions = actions.duplicate(true)
	requested_duration_sec = duration_sec
	_show_current_page()


func _show_current_page() -> void:
	if pages.is_empty() or page_index >= pages.size():
		dismiss()
		return

	var is_last_page := page_index == pages.size() - 1
	var page_actions: Array = []
	if is_last_page:
		page_actions = pending_actions

	var page_duration := requested_duration_sec
	if not is_last_page:
		page_duration = _page_read_duration(pages[page_index])

	_show_content(
		pages[page_index],
		page_actions,
		page_duration
	)


func _page_read_duration(text: String) -> float:
	var visible_chars := text.replace("\n", "").length()
	return clampf(
		2.8 + float(visible_chars) / 28.0,
		3.2,
		5.2
	)


func _paginate_text(text: String) -> Array[String]:
	var wrapped_lines := _wrap_text_to_lines(text, MAX_TEXT_WIDTH)
	var result: Array[String] = []
	var page_lines: Array[String] = []

	for line in wrapped_lines:
		page_lines.append(line)
		if page_lines.size() >= MAX_LINES_PER_PAGE:
			result.append("\n".join(page_lines))
			page_lines.clear()

	if not page_lines.is_empty():
		result.append("\n".join(page_lines))

	return result


func _wrap_text_to_lines(text: String, max_width: float) -> Array[String]:
	var font := message_label.get_theme_font("font")
	var font_size := message_label.get_theme_font_size("font_size")
	var result: Array[String] = []

	for paragraph in text.split("\n", true):
		if paragraph.is_empty():
			result.append("")
			continue

		var current := ""
		for character in paragraph:
			var candidate := current + character
			var candidate_width := font.get_string_size(
				candidate,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				font_size
			).x

			if not current.is_empty() and candidate_width > max_width:
				result.append(current)
				current = character
			else:
				current = candidate

		if not current.is_empty():
			result.append(current)

	if result.is_empty():
		result.append("")

	return result


func _show_content(
	text: String,
	actions: Array,
	duration_sec: float
) -> void:
	show_generation += 1
	var generation := show_generation

	current_text = text
	message_label.text = text
	_rebuild_actions(actions)
	_set_interactive(not actions.is_empty())

	hide_timer.stop()
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()

	show()
	modulate.a = 0.0
	_layout_for_content(text, not actions.is_empty())

	await get_tree().process_frame
	if generation != show_generation:
		return

	# Re-apply exact geometry after the containers have accepted the new
	# minimum sizes. Text wrapping itself is already deterministic here.
	_layout_for_content(text, not actions.is_empty())

	if duration_sec > 0.0:
		hide_timer.start(duration_sec)

	scale = Vector2.ONE * APPEAR_SCALE
	position = target_position + Vector2(0.0, APPEAR_OFFSET_Y)
	pivot_offset = size * Vector2(0.68, 0.88)

	# Update the Windows passthrough region only after the bubble has reached
	# its real screen position. Updating earlier used the old x=0 position,
	# which clipped the right side until another UI event refreshed the window.
	bounds_changed.emit()

	active_tween = create_tween()
	active_tween.set_parallel(true)
	active_tween.set_trans(Tween.TRANS_BACK)
	active_tween.set_ease(Tween.EASE_OUT)
	active_tween.tween_property(
		self,
		"scale",
		Vector2.ONE,
		APPEAR_DURATION
	)
	active_tween.tween_property(
		self,
		"position",
		target_position,
		APPEAR_DURATION - 0.02
	)
	active_tween.tween_property(
		self,
		"modulate:a",
		1.0,
		FADE_DURATION
	)


func _layout_for_content(text: String, has_actions: bool) -> void:
	var font := message_label.get_theme_font("font")
	var font_size := message_label.get_theme_font_size("font_size")
	var lines := text.split("\n", true)
	var measured_width := MIN_TEXT_WIDTH

	for line in lines:
		var line_width := font.get_string_size(
			line,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size
		).x
		measured_width = maxf(measured_width, line_width)

	var text_width := clampf(
		ceil(measured_width + 2.0),
		MIN_TEXT_WIDTH,
		MAX_TEXT_WIDTH
	)
	if has_actions:
		text_width = maxf(text_width, 250.0)

	var line_height: float = ceilf(
		font.get_height(font_size) + LINE_EXTRA_SPACING
	)
	var line_count: int = maxi(1, lines.size())
	var text_height: float = maxf(
		line_height,
		line_height * float(line_count)
	)

	message_label.custom_minimum_size = Vector2(
		text_width,
		text_height
	)
	message_label.size = message_label.custom_minimum_size

	var action_width := 0.0
	if has_actions:
		var action_count := maxi(1, actions_row.get_child_count())
		action_width = (
			float(action_count) * 64.0
			+ float(maxi(0, action_count - 1)) * 7.0
		)

	var content_width := maxf(text_width, action_width)
	var planned_card_width := content_width + CARD_HORIZONTAL_PADDING
	var planned_card_height := text_height + CARD_VERTICAL_PADDING
	if has_actions:
		planned_card_height += CONTENT_GAP + ACTION_ROW_HEIGHT

	card.custom_minimum_size = Vector2.ZERO
	card.size = Vector2(planned_card_width, planned_card_height)
	card.reset_size()

	var card_size := card.get_combined_minimum_size()
	card.size = card_size

	# Single-card mode: no tail, dots, or separate decorative bubble.
	size = card_size

	# Keep the card's lower-right corner near the character. Longer text makes
	# the same card grow up/left rather than introducing a second shape.
	var preferred := BUBBLE_BOTTOM_RIGHT_ANCHOR - card_size
	target_position = Vector2(
		clampf(
			preferred.x,
			WINDOW_MARGIN,
			maxf(WINDOW_MARGIN, WINDOW_WIDTH - size.x - WINDOW_MARGIN)
		),
		clampf(
			preferred.y,
			WINDOW_MARGIN,
			maxf(WINDOW_MARGIN, WINDOW_HEIGHT - size.y - WINDOW_MARGIN)
		)
	)



func _rebuild_actions(actions: Array) -> void:
	for child in actions_row.get_children():
		actions_row.remove_child(child)
		child.queue_free()

	actions_row.visible = not actions.is_empty()
	if actions.is_empty():
		return

	for item in actions:
		var spec := item as Dictionary
		var button := Button.new()
		button.text = str(spec.get("label", "确定"))
		button.custom_minimum_size = Vector2(64, 32)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_font_size_override("font_size", 13)
		button.add_theme_color_override("font_color", Color("#2B2440"))
		button.add_theme_color_override("font_hover_color", Color("#211A38"))
		button.add_theme_stylebox_override(
			"normal",
			_chip_style(Color("#E8DEF8"))
		)
		button.add_theme_stylebox_override(
			"hover",
			_chip_style(Color("#DDD2F2"))
		)
		button.add_theme_stylebox_override(
			"pressed",
			_chip_style(Color("#D0C3EA"))
		)
		button.pressed.connect(
			_on_action_pressed.bind(str(spec.get("id", "")))
		)
		actions_row.add_child(button)


func _chip_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style


func _set_interactive(value: bool) -> void:
	if interactive == value:
		return
	interactive = value
	interactive_changed.emit(interactive)


func _on_action_pressed(action_id: String) -> void:
	if action_id.is_empty():
		return
	action_selected.emit(action_id)
	dismiss()


func _on_hide_timer_timeout() -> void:
	if page_index + 1 < pages.size():
		page_index += 1
		_show_current_page()
		return

	dismiss()
