 1 | extends SceneTree
 2 | 
 3 | var count := 0
 4 | var last_text := ""
 5 | 
 6 | func _init() -> void:
 7 | 	call_deferred("_run")
 8 | 
 9 | 
func _run() -> void:
	var script = load("res://scripts/weather_manager.gd")
	var manager = script.new()
	root.add_child(manager)
	await process_frame

	manager.reminder_due.connect(_on_reminder)
	manager._emit_weather_reminder_if_needed({
		"location": "测试市 · 测试省 · 中国",
		"temperature_c": 30.0,
		"today_max_c": 33.0,
		"today_min_c": 24.0,
		"rain_probability_next_6h": 80,
		"today_rain_probability_max": 85,
		"today_weather_code": 95
	})
	manager._emit_weather_reminder_if_needed({
		"location": "测试市 · 测试省 · 中国",
		"temperature_c": 30.0,
		"today_max_c": 33.0,
		"today_min_c": 24.0,
		"rain_probability_next_6h": 80,
		"today_rain_probability_max": 85,
		"today_weather_code": 95
	})

	if count != 1:
		push_error("WEATHER_REMINDER_COUNT_FAILED: %d" % count)
		quit(2)
		return
	if "雷暴" not in last_text:
		push_error("WEATHER_REMINDER_TEXT_FAILED: " + last_text)
		quit(3)
		return

	print("WEATHER_REMINDER_SMOKE_OK")
	print(last_text)
	quit(0)


func _on_reminder(text: String) -> void:
	count += 1
	last_text = text
