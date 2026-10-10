extends RefCounted


static func load_catalog(config: Dictionary) -> Dictionary:
	var roaming := config.get("roaming", {}) as Dictionary
	if not bool(roaming.get("enabled", false)):
		return {}

	var catalog_path := str(roaming.get("movement_catalog", "res://config/movement_catalog.json"))
	var file := FileAccess.open(catalog_path, FileAccess.READ)
	if file == null:
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("movement_catalog.json is invalid")
		return {}

	var catalog := parsed as Dictionary
	if bool(roaming.get("enabled", false)) and not bool(catalog.get("ready", false)):
		push_warning("Roaming is enabled but movement assets are not ready; roaming stays inactive.")
	return catalog


static func frame_paths(catalog: Dictionary, clip_id: String) -> PackedStringArray:
	var result := PackedStringArray()
	var movement_clips := catalog.get("clips", {}) as Dictionary
	var spec := movement_clips.get(clip_id, {}) as Dictionary
	if spec.is_empty():
		return result

	var frames_dir := str(spec.get("frames_dir", ""))
	var frame_count := int(spec.get("frame_count", 0))
	for index in range(frame_count):
		result.append("%s/%03d.png" % [frames_dir, index])

	return result
