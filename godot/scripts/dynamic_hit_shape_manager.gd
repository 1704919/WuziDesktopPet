extends RefCounted

var catalog: Dictionary = {}
var actions: Dictionary = {}
var canvas_size := Vector2(360.0, 360.0)


func load_catalog(path: String = "res://config/video_hit_shapes.json") -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		catalog = {}
		actions = {}
		return false

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		catalog = {}
		actions = {}
		return false

	catalog = parsed as Dictionary
	actions = catalog.get("actions", {}) as Dictionary
	var canvas := catalog.get("canvas", [360, 360]) as Array
	if canvas.size() >= 2:
		canvas_size = Vector2(
			maxf(1.0, float(canvas[0])),
			maxf(1.0, float(canvas[1]))
		)
	return not actions.is_empty()


func has_action(action_id: String) -> bool:
	return actions.has(action_id)


func frame_count(action_id: String) -> int:
	var frames := actions.get(action_id, []) as Array
	return frames.size()


func polygon_for(action_id: String, frame_index: int) -> PackedVector2Array:
	var frames := actions.get(action_id, []) as Array
	if frames.is_empty():
		return PackedVector2Array()

	var index := clampi(frame_index, 0, frames.size() - 1)
	var raw_polygon := frames[index] as Array
	if raw_polygon.size() < 3:
		return PackedVector2Array()

	var polygon := PackedVector2Array()
	for raw_point in raw_polygon:
		if not raw_point is Array:
			continue
		var point := raw_point as Array
		if point.size() < 2:
			continue
		polygon.append(Vector2(float(point[0]), float(point[1])))
	return polygon
