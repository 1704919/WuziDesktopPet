 1 | extends SceneTree
 2 | 
 3 | var manager
 4 | var done := false
 5 | 
 6 | func _init() -> void:
 7 | 	call_deferred("_run")
 8 | 
 9 | 
func _run() -> void:
	var script = load("res://scripts/weather_manager.gd")
	manager = script.new()
	root.add_child(manager)
	await process_frame

	manager.weather_updated.connect(_on_weather_updated)
	manager.request_failed.connect(_on_failed)
	manager.configure({
		"enabled": true,
		"location_name": "",
		"check_interval_minutes": 600,
		"rain_probability_threshold": 50,
		"hot_threshold_c": 35,
		"cold_threshold_c": 5
	})
	manager.set_location("海口市", true)
	manager.refresh()

	await create_timer(12.0).timeout
	if not done:
		push_error("WEATHER_CN_SMOKE_TIMEOUT")
		quit(3)


func _on_weather_updated(summary: Dictionary) -> void:
	done = true
	var saved := manager.export_settings() as Dictionary
	if str(saved.get("location_query", "")) != "海口市":
		push_error("WEATHER_QUERY_WAS_OVERWRITTEN")
		quit(4)
		return
	print("WEATHER_CN_SMOKE_OK")
	print(JSON.stringify(summary))
	print(JSON.stringify(saved))
	quit(0)


func _on_failed(message: String) -> void:
	done = true
	push_error("WEATHER_CN_SMOKE_FAILED: " + message)
	quit(2)
