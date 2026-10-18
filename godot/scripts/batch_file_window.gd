extends Window

signal feedback_requested(kind: String)

const FileOperationPlanner = preload("res://scripts/file_operation_planner.gd")
const FileOperationExecutor = preload("res://scripts/file_operation_executor.gd")
const WindowsFileBridge = preload("res://scripts/windows_file_bridge.gd")
const BatchWorkbenchTheme = preload("res://scripts/batch_workbench_theme.gd")
const BatchWorkbenchUI = preload("res://scripts/batch_workbench_ui.gd")
const BatchWorkbenchFilePicker = preload("res://scripts/batch_workbench_file_picker.gd")
const FramelessWindow = preload("res://scripts/frameless_window.gd")

var file_drop_manager: Node
var planner := FileOperationPlanner.new()
var current_plan: Dictionary = {}
var last_result: Dictionary = {}
var capabilities: Dictionary = {}
var executor: RefCounted
var worker_id := -1
var busy := false
var frozen_plan: Dictionary = {}
var confirmation: ConfirmationDialog
var progress_bar: ProgressBar
var cancel_button: Button
var retry_button: Button
var capability_label: Label
var _editable_root: Control
var _shown_revision := -1
var _applying_execution_result := false

var file_list: ItemList
var count_label: Label
var status_label: Label
var character_feedback_label: Label
var last_duplicate_feedback_ms := -100000
var start_button: Button
var remove_button: Button
var include_subfolders: CheckButton

var find_input: LineEdit
var replace_input: LineEdit
var prefix_input: LineEdit
var suffix_input: LineEdit
var advanced_toggle: Button
var regex_toggle: CheckButton
var numbering_toggle: CheckButton
var number_start: SpinBox
var number_step: SpinBox
var number_digits: SpinBox
var image_format: OptionButton
var output_mode: OptionButton
var output_path: LineEdit
var choose_output_button: Button

var add_files_dialog: FileDialog
var add_folder_dialog: FileDialog
var output_folder_dialog: FileDialog


func _ready() -> void:
	title = "舞梓 · 文件处理"
	var available := FramelessWindow.usable_rect(self).size
	min_size = Vector2i(900, 600).min(available)
	size = Vector2i(1060, 700).min(available)
	always_on_top = false
	transient = false
	exclusive = false
	FramelessWindow.configure(self)
	close_requested.connect(_close_workbench)
	_build_ui()
	FramelessWindow.add_resize_grip(self)
	_build_dialogs()
	capabilities = WindowsFileBridge.run("caps")
	_update_capability_label()
	set_process(false)
	hide()


func setup(manager: Node) -> void:
	if file_drop_manager == manager:
		_refresh_plan()
		return
	if file_drop_manager != null and file_drop_manager.queue_changed.is_connected(_on_queue_changed):
		file_drop_manager.queue_changed.disconnect(_on_queue_changed)
	file_drop_manager = manager
	if file_drop_manager != null and not file_drop_manager.queue_changed.is_connected(_on_queue_changed):
		file_drop_manager.queue_changed.connect(_on_queue_changed)
	_refresh_plan()


func open_workbench() -> void:
	if busy:
		_show_workbench()
		return
	capabilities = WindowsFileBridge.run("caps")
	_update_capability_label()
	output_mode.select(0)
	output_path.text = ""
	_sync_output_controls()
	_refresh_plan()
	_show_workbench()
	# Also handle a queue where every item is blocked: no Start button exists
	# to trigger a duplicate warning.
	if (
		int(current_plan.get("total", 0)) > 0
		and int(current_plan.get("valid_count", 0)) == 0
		and preview_feedback_kind(current_plan) == "file_duplicate"
	):
		feedback_requested.emit("file_duplicate")
	find_input.grab_focus()


func _show_workbench() -> void:
	# Keep this as a regular independent window: raise it when opened, but do not
	# keep it permanently topmost, so native Windows file dialogs can appear above it.
	if not visible:
		var usable := DisplayServer.screen_get_usable_rect(current_screen)
		if usable.size.x > 0 and usable.size.y > 0:
			position = usable.position + (usable.size - size) / 2
	position = FramelessWindow.clamp_position(self, position)
	FramelessWindow.show_window(self)


func _build_ui() -> void:
	var root_panel := PanelContainer.new()
	root_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_panel.theme = BatchWorkbenchTheme.workbench_theme()
	root_panel.add_theme_stylebox_override("panel", BatchWorkbenchTheme.panel_style())
	add_child(root_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	root_panel.add_child(margin)

	var root_box := VBoxContainer.new()
	_editable_root = root_box
	root_box.add_theme_constant_override("separation", 12)
	margin.add_child(root_box)

	var header := HBoxContainer.new()
	header.name = "DragHeader"
	header.add_theme_constant_override("separation", 10)
	root_box.add_child(header)
	FramelessWindow.bind_drag_handle(header, self)

	var title_label := Label.new()
	title_label.text = "文件处理"
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color(0.18, 0.14, 0.25))
	header.add_child(title_label)

	var header_spacer := Control.new()
	header_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)

	count_label = Label.new()
	count_label.text = "0 个文件"
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label.add_theme_color_override("font_color", Color(0.42, 0.37, 0.52))
	header.add_child(count_label)
	var close_header := Button.new()
	close_header.text = "×"
	close_header.tooltip_text = "关闭文件处理"
	close_header.custom_minimum_size = Vector2(32, 32)
	close_header.flat = true
	close_header.pressed.connect(_close_workbench)
	header.add_child(close_header)

	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	root_box.add_child(toolbar)

	var add_files := Button.new()
	add_files.text = "添加文件"
	add_files.pressed.connect(_open_add_files)
	toolbar.add_child(add_files)

	var add_folder := Button.new()
	add_folder.text = "添加文件夹"
	add_folder.pressed.connect(_open_add_folder)
	toolbar.add_child(add_folder)

	include_subfolders = CheckButton.new()
	include_subfolders.text = "包含子文件夹"
	include_subfolders.tooltip_text = "默认关闭；只有主动开启时才递归加入子目录。"
	toolbar.add_child(include_subfolders)

	remove_button = Button.new()
	remove_button.text = "移除选中"
	remove_button.pressed.connect(_remove_selected)
	toolbar.add_child(remove_button)

	var clear_button := Button.new()
	clear_button.text = "清空"
	clear_button.pressed.connect(_clear_queue)
	toolbar.add_child(clear_button)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 610
	root_box.add_child(split)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(520, 0)
	left.add_theme_constant_override("separation", 8)
	split.add_child(left)

	var preview_title := Label.new()
	preview_title.text = "文件预览"
	preview_title.add_theme_font_size_override("font_size", 17)
	preview_title.add_theme_color_override("font_color", Color(0.25, 0.20, 0.34))
	left.add_child(preview_title)

	var preview_hint := Label.new()
	preview_hint.text = "原文件名  →  目标文件名；冲突会直接标在对应行。"
	preview_hint.add_theme_font_size_override("font_size", 12)
	preview_hint.add_theme_color_override("font_color", Color(0.48, 0.43, 0.58))
	left.add_child(preview_hint)

	file_list = ItemList.new()
	file_list.select_mode = ItemList.SELECT_MULTI
	file_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	file_list.allow_reselect = true
	left.add_child(file_list)

	var right_scroll := ScrollContainer.new()
	right_scroll.custom_minimum_size = Vector2(360, 0)
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(right_scroll)

	var settings := VBoxContainer.new()
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings.add_theme_constant_override("separation", 8)
	right_scroll.add_child(settings)

	var settings_title := Label.new()
	settings_title.text = "处理设置"
	settings_title.add_theme_font_size_override("font_size", 17)
	settings_title.add_theme_color_override("font_color", Color(0.25, 0.20, 0.34))
	settings.add_child(settings_title)

	BatchWorkbenchUI.add_section_title(settings, "批量重命名")
	find_input = BatchWorkbenchUI.add_line_field(settings, "查找")
	replace_input = BatchWorkbenchUI.add_line_field(settings, "替换")
	prefix_input = BatchWorkbenchUI.add_line_field(settings, "前缀")
	suffix_input = BatchWorkbenchUI.add_line_field(settings, "后缀")

	advanced_toggle = Button.new()
	advanced_toggle.text = "高级 ▸"
	advanced_toggle.toggle_mode = true
	advanced_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	advanced_toggle.toggled.connect(_on_advanced_toggled)
	settings.add_child(advanced_toggle)

	var regex_row := HBoxContainer.new()
	regex_row.visible = false
	regex_row.add_theme_constant_override("separation", 6)
	settings.add_child(regex_row)

	regex_toggle = CheckButton.new()
	regex_toggle.text = "使用正则表达式"
	regex_toggle.visible = false
	regex_toggle.toggled.connect(_on_param_toggled)
	regex_row.add_child(regex_toggle)
	BatchWorkbenchUI.add_help_button(
		regex_row,
		"正则表达式是一种按“模式”查找文字的高级方式。\n"
		+ "例如 IMG_.* 可以匹配以 IMG_ 开头的文件名。\n"
		+ "如果不熟悉，保持关闭即可，普通查找 / 替换已经能完成大多数重命名。"
	)

	advanced_toggle.set_meta("regex_row", regex_row)

	numbering_toggle = CheckButton.new()
	numbering_toggle.text = "添加编号"
	numbering_toggle.toggled.connect(_on_numbering_toggled)
	settings.add_child(numbering_toggle)

	var numbering_row := HBoxContainer.new()
	numbering_row.add_theme_constant_override("separation", 8)
	settings.add_child(numbering_row)
	number_start = BatchWorkbenchUI.add_spin_field(
		numbering_row,
		"起始",
		1,
		-999999,
		999999,
		"编号从哪个数字开始。例如起始为 1，会从 1 开始编号。"
	)
	number_step = BatchWorkbenchUI.add_spin_field(
		numbering_row,
		"步长",
		1,
		1,
		999999,
		"每个文件的编号增加多少。\n例如步长为 1：1、2、3；步长为 2：1、3、5。"
	)
	number_digits = BatchWorkbenchUI.add_spin_field(
		numbering_row,
		"位数",
		2,
		1,
		8,
		"编号固定显示多少位。\n例如位数为 3 时，1 会显示为 001。"
	)

	BatchWorkbenchUI.add_section_title(settings, "图片转换")
	image_format = OptionButton.new()
	image_format.add_item("保持原格式")
	image_format.add_item("PNG")
	image_format.add_item("JPG")
	image_format.add_item("WebP")
	image_format.add_item("HEIC")
	image_format.item_selected.connect(_on_param_item_selected)
	settings.add_child(image_format)

	var image_note := Label.new()
	image_note.text = (
		"图片支持 PNG / JPG / WebP / HEIC 真格式转换。"
		+ "HEIC 使用 Windows 系统图片支持；系统缺少相应组件时会明确提示。"
	)
	image_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	image_note.add_theme_font_size_override("font_size", 12)
	image_note.add_theme_color_override("font_color", Color(0.48, 0.43, 0.58))
	settings.add_child(image_note)
	capability_label = Label.new()
	capability_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	capability_label.add_theme_font_size_override("font_size", 12)
	capability_label.add_theme_color_override("font_color", Color(0.48, 0.43, 0.58))
	settings.add_child(capability_label)

	BatchWorkbenchUI.add_section_title(settings, "输出位置")
	output_mode = OptionButton.new()
	output_mode.add_item("原文件目录")
	output_mode.add_item("指定目录")
	output_mode.item_selected.connect(_on_output_mode_changed)
	settings.add_child(output_mode)

	var output_row := HBoxContainer.new()
	output_row.add_theme_constant_override("separation", 8)
	settings.add_child(output_row)
	output_path = LineEdit.new()
	output_path.placeholder_text = "尚未选择目录"
	output_path.editable = false
	output_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	output_row.add_child(output_path)
	choose_output_button = Button.new()
	choose_output_button.text = "选择…"
	choose_output_button.pressed.connect(_open_output_folder)
	output_row.add_child(choose_output_button)

	progress_bar = ProgressBar.new()
	progress_bar.visible = false
	progress_bar.custom_minimum_size.y = 8
	progress_bar.show_percentage = false
	root_box.add_child(progress_bar)
	character_feedback_label = Label.new()
	character_feedback_label.visible = false
	character_feedback_label.add_theme_font_size_override("font_size", 14)
	character_feedback_label.add_theme_color_override("font_color", Color(0.40, 0.28, 0.49))
	root_box.add_child(character_feedback_label)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	root_box.add_child(footer)

	status_label = Label.new()
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color(0.40, 0.34, 0.52))
	footer.add_child(status_label)

	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.pressed.connect(_close_workbench)
	footer.add_child(close_button)
	close_button.set_meta("keep_enabled", true)
	retry_button = Button.new()
	retry_button.text = "重新预览剩余"
	retry_button.visible = false
	retry_button.pressed.connect(_refresh_plan)
	footer.add_child(retry_button)
	cancel_button = Button.new()
	cancel_button.text = "取消处理"
	cancel_button.visible = false
	cancel_button.set_meta("keep_enabled", true)
	cancel_button.pressed.connect(_cancel_processing)
	footer.add_child(cancel_button)

	start_button = Button.new()
	start_button.text = "开始处理"
	start_button.disabled = true
	start_button.tooltip_text = "确认当前预览后开始处理；已有文件不会被覆盖。"
	start_button.pressed.connect(_request_execution)
	footer.add_child(start_button)

	for line_edit in [find_input, replace_input, prefix_input, suffix_input]:
		line_edit.text_changed.connect(_on_param_text_changed)
	for spin in [number_start, number_step, number_digits]:
		spin.value_changed.connect(_on_param_value_changed)

	_on_numbering_toggled(false)
	_sync_output_controls()


func _build_dialogs() -> void:
	add_files_dialog = BatchWorkbenchFilePicker.create_files_dialog(_on_files_selected)
	add_child(add_files_dialog)

	add_folder_dialog = BatchWorkbenchFilePicker.create_folder_dialog(_on_folder_selected)
	add_child(add_folder_dialog)

	output_folder_dialog = BatchWorkbenchFilePicker.create_output_folder_dialog(_on_output_folder_selected)
	add_child(output_folder_dialog)
	confirmation = ConfirmationDialog.new()
	confirmation.title = "确认文件处理"
	confirmation.ok_button_text = "确认处理"
	confirmation.cancel_button_text = "返回预览"
	confirmation.confirmed.connect(_confirm_execution)
	add_child(confirmation)
	# Keep the confirmation modal while removing the engine's native title bar.
	confirmation.borderless = true
	confirmation.theme = BatchWorkbenchTheme.workbench_theme()
	FramelessWindow.bind_drag_handle(confirmation.get_label(), confirmation)


func _open_add_files() -> void:
	add_files_dialog.popup_centered_ratio(0.75)


func _open_add_folder() -> void:
	add_folder_dialog.popup_centered_ratio(0.75)


func _open_output_folder() -> void:
	output_folder_dialog.popup_centered_ratio(0.75)


func _on_files_selected(paths: PackedStringArray) -> void:
	if file_drop_manager != null:
		file_drop_manager.enqueue(paths)


func _on_folder_selected(path: String) -> void:
	if file_drop_manager == null:
		return
	var collected := PackedStringArray()
	var errors: Array[String] = []
	BatchWorkbenchFilePicker.collect_files(path, include_subfolders.button_pressed, collected, errors)
	if not collected.is_empty():
		file_drop_manager.enqueue(collected)
	if not errors.is_empty():
		status_label.text = "添加文件夹时有 %d 个目录无法读取。首个问题：%s" % [errors.size(), errors[0]]


func _on_output_folder_selected(path: String) -> void:
	output_path.text = path
	_refresh_plan()


func _remove_selected() -> void:
	if file_drop_manager == null:
		return
	var selected := file_list.get_selected_items()
	var paths := PackedStringArray()
	var items := current_plan.get("items", []) as Array
	for item_index in selected:
		var index := int(item_index)
		if index >= 0 and index < items.size():
			paths.append(str((items[index] as Dictionary).get("source", "")))
	if not paths.is_empty():
		file_drop_manager.remove_paths(paths)


func _clear_queue() -> void:
	if file_drop_manager != null:
		file_drop_manager.clear_queue()


func _on_queue_changed(_summary: Dictionary) -> void:
	if _applying_execution_result:
		return
	if busy:
		executor.cancel()
		return
	_refresh_plan()


func _on_param_text_changed(_text: String) -> void:
	_refresh_plan()


func _on_param_toggled(_enabled: bool) -> void:
	_refresh_plan()


func _on_advanced_toggled(enabled: bool) -> void:
	regex_toggle.visible = enabled
	var regex_row := advanced_toggle.get_meta("regex_row", null) as Control
	if regex_row != null:
		regex_row.visible = enabled
	advanced_toggle.text = "高级 ▾" if enabled else "高级 ▸"


func _on_numbering_toggled(enabled: bool) -> void:
	for spin in [number_start, number_step, number_digits]:
		spin.editable = enabled
		spin.get_line_edit().editable = enabled
	_refresh_plan()


func _on_param_value_changed(_value: float) -> void:
	_refresh_plan()


func _on_param_item_selected(_index: int) -> void:
	_refresh_plan()


func _on_output_mode_changed(_index: int) -> void:
	if output_mode.selected == 0:
		output_path.text = ""
	_sync_output_controls()
	_refresh_plan()


func _sync_output_controls() -> void:
	if choose_output_button == null or output_path == null or output_mode == null:
		return
	var custom := output_mode.selected == 1
	choose_output_button.disabled = not custom
	output_path.visible = custom
	choose_output_button.visible = custom


func _build_params() -> Dictionary:
	var formats := ["keep", "png", "jpg", "webp", "heic"]
	return {
		"find_text": find_input.text,
		"replace_text": replace_input.text,
		"prefix": prefix_input.text,
		"suffix": suffix_input.text,
		"regex_enabled": regex_toggle.button_pressed,
		"numbering_enabled": numbering_toggle.button_pressed,
		"number_start": int(number_start.value),
		"number_step": int(number_step.value),
		"number_digits": int(number_digits.value),
		"image_format": formats[clampi(image_format.selected, 0, formats.size() - 1)],
		"output_mode": "custom" if output_mode.selected == 1 else "source",
		"output_dir": output_path.text
	}


func set_character_feedback(text: String) -> void:
	if character_feedback_label == null:
		return
	character_feedback_label.text = "舞梓：" + text if not text.is_empty() else ""
	character_feedback_label.visible = not text.is_empty()


static func preview_feedback_kind(plan: Dictionary) -> String:
	for raw_item in plan.get("items", []):
		var item := raw_item as Dictionary
		for raw_issue in item.get("issues", []):
			var issue := str(raw_issue)
			if (
				issue.contains("多个文件生成同一目标")
				or issue.contains("目标路径已经存在")
				or issue.contains("重名")
			):
				return "file_duplicate"
	return "file_preview"


static func execution_feedback_kind(counts: Dictionary) -> String:
	var completed := int(counts.get("completed", 0))
	var failed := int(counts.get("failed", 0))
	var skipped := int(counts.get("skipped", 0))
	var cancelled := int(counts.get("cancelled", 0))
	if failed > 0 or skipped > 0:
		return "file_failure"
	if cancelled > 0:
		return ""  # User cancellation is not a processing error.
	if completed > 0:
		return "file_success"
	return ""


func _refresh_plan() -> void:
	if file_list == null or busy:
		return
	set_character_feedback("")
	if confirmation != null and confirmation.visible:
		confirmation.hide()
	frozen_plan.clear()
	last_result.clear()
	if retry_button != null:
		retry_button.visible = false
	if progress_bar != null:
		progress_bar.visible = false
	var paths := PackedStringArray()
	if file_drop_manager != null:
		paths = file_drop_manager.get_queued_files()

	current_plan = planner.build_plan(paths, _build_params(), capabilities)
	file_list.clear()

	var items := current_plan.get("items", []) as Array
	for raw_item in items:
		var item := raw_item as Dictionary
		var issues := item.get("issues", []) as Array
		var warnings := item.get("warnings", []) as Array
		var marker := "✓" if issues.is_empty() else "!"
		var row := "%s  %s  →  %s" % [
			marker,
			str(item.get("source_name", "")),
			str(item.get("target_name", ""))
		]
		if not issues.is_empty():
			row += "  ·  " + str(issues[0])
		var item_index := file_list.add_item(row)
		var tooltip_parts: PackedStringArray = [
			"源：%s" % str(item.get("source", "")),
			"目标：%s" % str(item.get("target", ""))
		]
		for issue in issues:
			tooltip_parts.append("冲突：%s" % str(issue))
		for warning in warnings:
			tooltip_parts.append("提示：%s" % str(warning))
		file_list.set_item_tooltip(item_index, "\n".join(tooltip_parts))
		if issues.is_empty():
			file_list.set_item_custom_fg_color(item_index, Color(0.20, 0.42, 0.30))
		else:
			file_list.set_item_custom_fg_color(item_index, Color(0.72, 0.28, 0.30))

	var total := int(current_plan.get("total", 0))
	var valid := int(current_plan.get("valid_count", 0))
	var conflicts := int(current_plan.get("conflict_count", 0))
	count_label.text = "%d 个文件" % total
	remove_button.disabled = total == 0
	if total == 0:
		status_label.text = "把文件拖给我吧～也可以在这里添加文件。确认预览后开始处理。"
	elif conflicts > 0:
		status_label.text = "⚠ %d 个项目将跳过 · ✓ %d 个项目可以处理" % [conflicts, valid]
	else:
		status_label.text = "✓ %d 个项目预览通过 · 请核对目标文件名和输出位置" % valid

	start_button.text = "开始处理 %d 项" % valid
	start_button.disabled = valid == 0
	start_button.tooltip_text = "执行当前预览；冲突项会保留在队列中。"
	if visible and total > 0 and valid == 0 and preview_feedback_kind(current_plan) == "file_duplicate":
		var now_ms := Time.get_ticks_msec()
		if now_ms - last_duplicate_feedback_ms >= 4000:
			last_duplicate_feedback_ms = now_ms
			feedback_requested.emit("file_duplicate")


func _update_capability_label() -> void:
	if capability_label == null:
		return
	capability_label.text = "HEIC 系统支持：读取%s · 写入%s" % [
		"可用" if bool(capabilities.get("read", false)) else "不可用",
		"可用" if bool(capabilities.get("write", false)) else "不可用"
	]
	if not bool(capabilities.get("read", false)) or not bool(capabilities.get("write", false)):
		capability_label.text += "\n当前 Windows 未提供所需 HEIC 支持；仍可重命名。"


func _request_execution() -> void:
	if busy or int(current_plan.get("valid_count", 0)) == 0:
		return
	frozen_plan = current_plan.duplicate(true)
	confirmation.dialog_text = "按左侧预览处理 %d 项，跳过 %d 项。\n%s\n已有文件不会被覆盖。" % [
		current_plan.valid_count, current_plan.conflict_count,
		"在原位置重命名；图片转换保留原图。" if current_plan.params.output_mode == "source" else "在指定目录生成结果，保留原文件。"
	]
	feedback_requested.emit(preview_feedback_kind(current_plan))
	confirmation.popup_centered(Vector2i(480, 190))


func _confirm_execution() -> void:
	if busy or frozen_plan.is_empty() or frozen_plan.plan_version != current_plan.plan_version:
		_refresh_plan()
		return
	busy = true
	confirmation.hide()
	_shown_revision = -1
	set_process(true)
	executor = FileOperationExecutor.new()
	var submitted := frozen_plan.duplicate(true)
	var version := str(submitted.plan_version)
	var quality := float(file_drop_manager.image_quality)
	# Worker owns only RefCounted data; it never reads a Window or queue Node.
	worker_id = WorkerThreadPool.add_task(executor.execute.bind(submitted, version, quality), false, "Wuzi file operations")
	_set_editing_enabled(_editable_root, false)
	cancel_button.visible = true
	cancel_button.disabled = false
	retry_button.visible = false
	progress_bar.visible = true
	progress_bar.max_value = maxi(1, int(submitted.total))
	progress_bar.value = 0
	status_label.text = "正在复查源文件和输出目录…"


func _process(_delta: float) -> void:
	if not busy or worker_id < 0:
		return
	var revision: int = executor.revision()
	if revision != _shown_revision:
		var state: Dictionary = executor.snapshot()
		_shown_revision = revision
		if not state.is_empty():
			_show_execution(state)
	if WorkerThreadPool.is_task_completed(worker_id):
		WorkerThreadPool.wait_for_task_completion(worker_id)
		worker_id = -1
		last_result = executor.snapshot()
		# Do not cancel a finished worker or erase its result when updating the queue.
		_applying_execution_result = true
		file_drop_manager.apply_execution_result(last_result)
		_applying_execution_result = false
		busy = false
		set_process(false)
		_set_editing_enabled(_editable_root, true)
		_sync_output_controls()
		number_start.editable = numbering_toggle.button_pressed
		number_step.editable = numbering_toggle.button_pressed
		number_digits.editable = numbering_toggle.button_pressed
		cancel_button.visible = false
		retry_button.visible = true
		start_button.disabled = true
		_show_execution(last_result)
		var feedback_kind := execution_feedback_kind(
			last_result.get("counts", {}) as Dictionary
		)
		if not feedback_kind.is_empty():
			feedback_requested.emit(feedback_kind)


func _show_execution(state: Dictionary) -> void:
	current_plan = state
	var labels := {"waiting": "等待", "processing": "处理中", "completed": "完成", "failed": "失败", "skipped": "跳过", "cancelled": "已取消"}
	var done := 0
	file_list.clear()
	for item: Dictionary in state.get("items", []):
		var status := str(item.status)
		if status in ["completed", "failed", "skipped", "cancelled"]:
			done += 1
		var message := str(item.get("message", ""))
		var row := "%s  %s → %s" % [labels.get(status, "等待"), item.source_name, item.target_name]
		if not message.is_empty():
			row += " · " + message.get_slice("\n", 0)
		var index := file_list.add_item(row)
		file_list.set_item_tooltip(index, "源：%s\n目标：%s\n%s" % [item.source, item.target, message])
		file_list.set_item_custom_fg_color(index, Color(0.72, 0.28, 0.30) if status == "failed" else Color(0.20, 0.32, 0.30))
	progress_bar.value = done
	status_label.text = "已处理 %d / %d 项；取消会等待正在处理的文件或改名组结束。" % [done, int(state.total)]
	if bool(state.get("finished", false)):
		var counts: Dictionary = state.counts
		status_label.text = "完成 %d · 失败 %d · 跳过 %d · 已取消 %d。未完成项留在队列中。" % [counts.completed, counts.failed, counts.skipped, counts.cancelled]
		var recovery_count := 0
		for item: Dictionary in state.get("items", []):
			if not str(item.get("recovery_path", "")).is_empty():
				recovery_count += 1
		if recovery_count > 0:
			status_label.text += " ⚠ %d 个文件保存在临时恢复路径，查看失败行详情后再处理。" % recovery_count
		elif counts.completed > 0 and counts.failed > 0:
			status_label.text += " 本批次部分成功，已完成项不会自动撤销。"


func _set_editing_enabled(node: Node, enabled: bool) -> void:
	if node is BaseButton and not node.has_meta("keep_enabled"):
		(node as BaseButton).disabled = not enabled
	elif node is SpinBox:
		var spin := node as SpinBox
		var can_edit := enabled and numbering_toggle.button_pressed
		spin.editable = can_edit
		spin.get_line_edit().editable = can_edit
	elif node is LineEdit:
		var can_edit := enabled and node != output_path
		if node.get_parent() is SpinBox:
			can_edit = can_edit and numbering_toggle.button_pressed
		(node as LineEdit).editable = can_edit
	for child in node.get_children():
		_set_editing_enabled(child, enabled)


func _cancel_processing() -> void:
	if busy:
		executor.cancel()
		cancel_button.disabled = true
		status_label.text = "已请求取消；正在完成当前文件或相互依赖的改名组。"


func _close_workbench() -> void:
	_cancel_processing()
	confirmation.hide()
	hide()


func _exit_tree() -> void:
	if worker_id >= 0:
		executor.cancel()
		WorkerThreadPool.wait_for_task_completion(worker_id)
		worker_id = -1
