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
	if absf(float(manager.check_interval_sec) - 36000.0) > 0.1:
		push_error("WEATHER_INTERVAL_NOT_10_HOURS")
		quit(4)
		return
	if absf(float(manager.check_countdown_sec)) > 0.1:
		push_error("WEATHER_STARTUP_CHECK_NOT_IMMEDIATE")
		quit(5)
		return
	manager.set_location("Haikou", true)
	manager.refresh()

	await create_timer(12.0).timeout
	if not done:
		push_error("WEATHER_SMOKE_TIMEOUT")
		quit(3)


func _on_weather_updated(summary: Dictionary) -> void:
	done = true
	if (
		not summary.has("today_min_c")
		or not summary.has("today_max_c")
		or not summary.has("today_rain_probability_max")
	):
		push_error("WEATHER_SMOKE_MISSING_DAILY")
		quit(2)
		return

	print("WEATHER_SMOKE_OK")
	print(JSON.stringify(summary))
	quit(0)


func _on_failed(message: String) -> void:
	done = true
	push_error("WEATHER_SMOKE_FAILED: " + message)
	quit(2)
