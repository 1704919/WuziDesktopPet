 1 | extends Node
 2 | 
 3 | const CATALOG_PATH := "res://config/action_catalog.json"
 4 | 
 5 | var catalog: Dictionary = {}
 6 | 
 7 | 
 8 | func load_catalog() -> Dictionary:
 9 | 	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		catalog = {}
		return catalog

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		catalog = {}
		return catalog

	catalog = parsed as Dictionary
	return catalog


func get_action(action_id: String) -> Dictionary:
	var actions := catalog.get("actions", {}) as Dictionary
	return actions.get(action_id, {}) as Dictionary


func is_action_ready(action_id: String) -> bool:
	var spec := get_action(action_id)
	return bool(spec.get("ready", false))


func resolve_action_id(action_id: String) -> String:
	var current := action_id
	for _step in range(4):
		var spec := get_action(current)
		if spec.is_empty():
			return ""
		var source_action := str(spec.get("source_action", ""))
		if source_action.is_empty():
			return current
		if source_action == current:
			return ""
		current = source_action
	return ""


func all_action_ids() -> PackedStringArray:
	var result := PackedStringArray()
	var actions := catalog.get("actions", {}) as Dictionary
	for action_id in actions.keys():
		result.append(str(action_id))
	return result
