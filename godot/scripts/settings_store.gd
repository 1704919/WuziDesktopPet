 1 | extends Node
 2 | 
 3 | const InputGuard = preload("res://scripts/input_guard.gd")
 4 | const SETTINGS_PATH := "user://wuzi_pet_settings.json"
 5 | 
 6 | var data: Dictionary = {
 7 | 	"window_position": null,
 8 | 	"reminders_enabled": true,
 9 | 	"random_actions_paused": false,
	"roaming_enabled": true,
	"last_birthday_auto_trigger_year": -1
}


func load_settings() -> Dictionary:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return data

	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return data

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		for key in (parsed as Dictionary).keys():
			data[key] = (parsed as Dictionary)[key]

	return data


func save_settings() -> bool:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Unable to save desktop-pet settings")
		return false
	file.store_string(JSON.stringify(data, "\t") + "\n")
	file.flush()
	var saved := file.get_error() == OK
	file.close()
	return saved


func get_nickname() -> String:
	var checked := InputGuard.check(data.get("nickname", ""), InputGuard.NICKNAME_LIMIT, true)
	return checked.text if checked.ok else ""


func set_nickname(raw: Variant) -> bool:
	var checked := InputGuard.check(raw, InputGuard.NICKNAME_LIMIT, true)
	if not checked.ok:
		return false
	var previous := data.duplicate(true)
	if checked.text.is_empty():
		data.erase("nickname")
	else:
		data["nickname"] = checked.text
	if not save_settings():
		data = previous
		return false
	return true


func get_value(key: String, default_value: Variant = null) -> Variant:
	return data.get(key, default_value)


func set_value(key: String, value: Variant, save_now: bool = true) -> void:
	data[key] = value
	if save_now:
		save_settings()


func erase_value(key: String, save_now: bool = true) -> void:
	data.erase(key)
	if save_now:
		save_settings()


func get_window_position() -> Variant:
	var raw: Variant = data.get("window_position")
	if typeof(raw) != TYPE_ARRAY:
		return null
	var values := raw as Array
	if values.size() < 2:
		return null
	return Vector2i(int(values[0]), int(values[1]))


func set_window_position(position: Vector2i, save_now: bool = true) -> void:
	set_value("window_position", [position.x, position.y], save_now)
