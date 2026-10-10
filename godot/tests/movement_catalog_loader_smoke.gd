extends SceneTree

const MovementCatalogLoader = preload("res://scripts/pet_movement_catalog_loader.gd")


func _init() -> void:
	var failures: Array[String] = []

	var disabled := MovementCatalogLoader.load_catalog({
		"roaming": {
			"enabled": false,
			"movement_catalog": "user://should_not_be_read.json"
		}
	})
	if not disabled.is_empty():
		failures.append("disabled_roaming_should_return_empty_catalog")

	var catalog_path := "user://movement_catalog_loader_smoke.json"
	var file := FileAccess.open(catalog_path, FileAccess.WRITE)
	if file == null:
		failures.append("unable_to_create_test_catalog")
	else:
		file.store_string(JSON.stringify({
			"ready": true,
			"clips": {
				"walk": {
					"frames_dir": "res://assets_display/wuzi_chibi/video_walk/frames",
					"frame_count": 3
				}
			}
		}))
		file.close()

	var loaded := MovementCatalogLoader.load_catalog({
		"roaming": {
			"enabled": true,
			"movement_catalog": catalog_path
		}
	})
	if not bool(loaded.get("ready", false)):
		failures.append("catalog_ready_flag_not_loaded")

	var paths := MovementCatalogLoader.frame_paths(loaded, "walk")
	if paths.size() != 3:
		failures.append("walk_frame_count_wrong")
	else:
		if paths[0] != "res://assets_display/wuzi_chibi/video_walk/frames/000.png":
			failures.append("walk_first_frame_wrong")
		if paths[2] != "res://assets_display/wuzi_chibi/video_walk/frames/002.png":
			failures.append("walk_last_frame_wrong")

	var missing := MovementCatalogLoader.frame_paths(loaded, "missing")
	if not missing.is_empty():
		failures.append("missing_clip_should_return_empty_paths")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(catalog_path))

	if failures.is_empty():
		print("MOVEMENT_CATALOG_LOADER_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(2)
