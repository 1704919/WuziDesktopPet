extends RefCounted

const WINDOW_LAYOUT_VERSION := 2
const LEGACY_PET_X := 210.0


static func configure(
	viewport: Viewport,
	config: Dictionary,
	settings_store: Node,
	base_position: Vector2
) -> void:
	viewport.transparent_bg = true
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true)
	DisplayServer.window_set_flag(
		DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP,
		bool((config.get("window", {}) as Dictionary).get("always_on_top", true))
	)

	var window_cfg := config.get("window", {}) as Dictionary
	var window_size := Vector2i(
		int(window_cfg.get("width", 760)),
		int(window_cfg.get("height", 420))
	)
	DisplayServer.window_set_size(window_size)

	var usable := DisplayServer.screen_get_usable_rect()
	var initial_pos := Vector2i(
		usable.position.x
			+ usable.size.x
			- window_size.x
			- int(window_cfg.get("margin_right", 28)),
		usable.position.y
			+ usable.size.y
			- window_size.y
			- int(window_cfg.get("margin_bottom", 28))
	)

	var stored_position: Variant = settings_store.get_window_position()
	var layout_version := int(
		settings_store.get_value("window_layout_version", 1)
	)
	var migrated := false

	if stored_position is Vector2i:
		var candidate := stored_position as Vector2i
		if layout_version < WINDOW_LAYOUT_VERSION:
			candidate.x -= roundi(base_position.x - LEGACY_PET_X)
			migrated = true

		if _position_is_visible(candidate, window_size, base_position):
			initial_pos = candidate

	DisplayServer.window_set_position(initial_pos)

	if migrated or layout_version != WINDOW_LAYOUT_VERSION:
		settings_store.set_value(
			"window_layout_version",
			WINDOW_LAYOUT_VERSION,
			false
		)
		settings_store.set_window_position(initial_pos, false)
		settings_store.save_settings()


static func persist_position(settings_store: Node) -> void:
	settings_store.set_window_position(DisplayServer.window_get_position())


static func usable_rect_for_pet(
	window_position: Vector2i,
	base_position: Vector2
) -> Rect2i:
	var pet_center := window_position + Vector2i(
		roundi(base_position.x),
		roundi(base_position.y)
	)
	for screen in range(DisplayServer.get_screen_count()):
		var rect := DisplayServer.screen_get_usable_rect(screen)
		if rect.has_point(pet_center):
			return rect
	return DisplayServer.screen_get_usable_rect()


static func _position_is_visible(
	position: Vector2i,
	_window_size: Vector2i,
	base_position: Vector2
) -> bool:
	var rect := usable_rect_for_pet(position, base_position)
	var pet_center := position + Vector2i(
		roundi(base_position.x),
		roundi(base_position.y)
	)
	return rect.has_point(pet_center)
