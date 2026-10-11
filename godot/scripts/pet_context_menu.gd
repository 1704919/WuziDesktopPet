extends RefCounted

const MENU_TOGGLE_RANDOM := 1
const MENU_RESET_POSITION := 2
const MENU_EXIT := 3
const MENU_TALK := 4
const MENU_TOGGLE_REMINDERS := 5
const MENU_PLAY_ACTION := 6
const MENU_ACTION_BACK := 7
const MENU_FILE_WORKBENCH := 8
const MENU_CLEAR_FILES := 9
const MENU_WEATHER_SETTINGS := 10
const MENU_WEATHER_NOW := 11
const MENU_SETTINGS := 12
const MENU_NICKNAME := 13
const MENU_ACTION_CATEGORY_BACK := 14
const MENU_TOGGLE_ROAMING := 15
const MENU_ACTION_PAGE_UP := 16
const MENU_ACTION_PAGE_DOWN := 17
const MENU_STREAM_SETTINGS := 18
const ACTION_PAGE_SIZE := 6
const ACTION_CATEGORY_MENU_BASE := 100
const ACTION_MENU_BASE := 1000
const CONTEXT_MENU_FIXED_ANCHOR := Vector2(550.0, 8.0)


static func open_root(
	context_menu: Control,
	config: Dictionary,
	local_position: Vector2,
	reminders_enabled: bool,
	random_actions_paused: bool,
	roaming_enabled: bool,
	manual_action_map: Dictionary,
	manual_category_map: Dictionary
) -> void:
	manual_action_map.clear()
	manual_category_map.clear()

	var items: Array = [
		{"id": MENU_TALK, "label": "对她说…"},
		{"id": MENU_PLAY_ACTION, "label": "点播动作…"},
		{
			"id": MENU_TOGGLE_REMINDERS,
			"label": "日常提醒",
			"checked": reminders_enabled
		},
		{"id": MENU_WEATHER_NOW, "label": "查看天气"},
		{"id": MENU_SETTINGS, "label": "设置…"},
		{
			"id": MENU_TOGGLE_RANDOM,
			"label": "暂停自主行为",
			"checked": random_actions_paused
		},
		{
			"id": MENU_TOGGLE_ROAMING,
			"label": "桌面漫游",
			"checked": roaming_enabled
		},
		{"separator": true},
		{
			"id": MENU_FILE_WORKBENCH,
			"label": "文件处理…"
		},
		{"separator": true},
		{"id": MENU_RESET_POSITION, "label": "重置位置"},
		{"id": MENU_EXIT, "label": "退出"}
	]

	var window_cfg := config.get("window", {}) as Dictionary
	var window_size := Vector2(
		float(window_cfg.get("width", 760)),
		float(window_cfg.get("height", 420))
	)
	context_menu.call("open_menu", items, local_position, window_size)


static func open_settings(
	context_menu: Control,
	context_menu_anchor: Vector2,
	manual_action_map: Dictionary,
	manual_category_map: Dictionary
) -> void:
	manual_action_map.clear()
	manual_category_map.clear()
	context_menu.call("open_menu", [
		{"id": MENU_NICKNAME, "label": "用户昵称…"},
		{"id": MENU_WEATHER_SETTINGS, "label": "天气设置…"},
		{"id": MENU_STREAM_SETTINGS, "label": "开播提醒…"},
		{"separator": true},
		{"id": MENU_ACTION_BACK, "label": "← 返回"}
	], context_menu_anchor, Vector2(760, 420))


static func open_action_picker(
	context_menu: Control,
	config: Dictionary,
	context_menu_anchor: Vector2,
	manual_action_map: Dictionary,
	manual_category_map: Dictionary
) -> void:
	var category_specs := config.get("manual_action_categories", []) as Array
	if category_specs.is_empty():
		category_specs = [{"id": "general", "label": "一般动作"}]
	var items: Array = []
	manual_action_map.clear()
	manual_category_map.clear()

	for index in range(category_specs.size()):
		var category_spec := category_specs[index] as Dictionary
		var category_id := str(category_spec.get("id", "")).strip_edges()
		if category_id.is_empty():
			continue
		var category_actions := _manual_actions_for_category(config, category_id)
		if category_actions.is_empty():
			continue
		var menu_id := ACTION_CATEGORY_MENU_BASE + index
		manual_category_map[menu_id] = category_id
		items.append({
			"id": menu_id,
			"label": "%s  ›" % str(category_spec.get("label", category_id))
		})

	if items.is_empty():
		open_action_category(
			context_menu,
			config,
			context_menu_anchor,
			"general",
			manual_action_map,
			manual_category_map
		)
		return

	items.append({"separator": true})
	items.append({"id": MENU_ACTION_BACK, "label": "← 返回"})

	var window_cfg := config.get("window", {}) as Dictionary
	var window_size := Vector2(
		float(window_cfg.get("width", 760)),
		float(window_cfg.get("height", 420))
	)
	context_menu.call("open_menu", items, context_menu_anchor, window_size)


static func open_action_category(
	context_menu: Control,
	config: Dictionary,
	context_menu_anchor: Vector2,
	category_id: String,
	manual_action_map: Dictionary,
	manual_category_map: Dictionary,
	page_index: int = 0
) -> int:
	var action_specs := _manual_actions_for_category(config, category_id)
	var items: Array = []
	manual_action_map.clear()
	manual_category_map.clear()

	var page_count := maxi(
		1,
		ceili(float(action_specs.size()) / float(ACTION_PAGE_SIZE))
	)
	var page := clampi(page_index, 0, page_count - 1)
	var start_index := page * ACTION_PAGE_SIZE
	var end_index := mini(
		action_specs.size(),
		start_index + ACTION_PAGE_SIZE
	)

	for index in range(start_index, end_index):
		var spec := action_specs[index] as Dictionary
		var action_id := ACTION_MENU_BASE + index
		manual_action_map[action_id] = spec
		items.append({
			"id": action_id,
			"label": str(spec.get("label", spec.get("id", "动作")))
		})

	if items.is_empty():
		items.append({"id": -1, "label": "暂无动作", "disabled": true})

	if page_count > 1:
		items.append({"separator": true})
		var has_previous := page > 0
		var has_next := page < page_count - 1
		if has_previous:
			manual_category_map[MENU_ACTION_PAGE_UP] = {
				"category_id": category_id,
				"page_index": page - 1
			}
		if has_next:
			manual_category_map[MENU_ACTION_PAGE_DOWN] = {
				"category_id": category_id,
				"page_index": page + 1
			}
		items.append({
			"id": MENU_ACTION_PAGE_UP,
			"label": "▲ 上一页",
			"disabled": not has_previous
		})
		items.append({
			"id": MENU_ACTION_PAGE_DOWN,
			"label": "▼ 下一页",
			"disabled": not has_next
		})

	items.append({"separator": true})
	items.append({"id": MENU_ACTION_CATEGORY_BACK, "label": "← 动作分类"})

	var window_cfg := config.get("window", {}) as Dictionary
	var window_size := Vector2(
		float(window_cfg.get("width", 760)),
		float(window_cfg.get("height", 420))
	)
	context_menu.call("open_menu", items, context_menu_anchor, window_size)
	return page


static func _manual_actions_for_category(config: Dictionary, category_id: String) -> Array:
	var result: Array = []
	for raw in config.get("manual_actions", []) as Array:
		var spec := raw as Dictionary
		if str(spec.get("category", "general")) == category_id:
			result.append(spec)
	return result
