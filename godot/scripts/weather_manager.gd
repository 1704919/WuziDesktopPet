  1 | extends Node
  2 | 
  3 | signal weather_updated(summary: Dictionary)
  4 | signal reminder_due(text: String)
  5 | signal request_failed(message: String)
  6 | 
  7 | var location_query := ""
  8 | var location_name := ""
  9 | var latitude: Variant = null
 10 | var longitude: Variant = null
 11 | var enabled := false
 12 | 
 13 | var geocode_candidates := PackedStringArray()
 14 | var geocode_candidate_index := 0
 15 | 
 16 | var check_interval_sec := 36000.0
 17 | var check_countdown_sec := 0.0
 18 | var rain_threshold := 50
 19 | var hot_threshold_c := 35.0
 20 | var cold_threshold_c := 5.0
 21 | 
 22 | var geocode_request: HTTPRequest
 23 | var weather_request: HTTPRequest
 24 | var last_reminder_signature := ""
 25 | var last_reminder_unix := 0
 26 | 
 27 | 
 28 | func _ready() -> void:
 29 | 	geocode_request = HTTPRequest.new()
 30 | 	weather_request = HTTPRequest.new()
 31 | 	add_child(geocode_request)
 32 | 	add_child(weather_request)
 33 | 
 34 | 	geocode_request.request_completed.connect(_on_geocode_completed)
 35 | 	weather_request.request_completed.connect(_on_weather_completed)
 36 | 	set_process(true)
 37 | 
 38 | 
 39 | func configure(spec: Dictionary, stored: Dictionary = {}) -> void:
 40 | 	location_name = str(
 41 | 		stored.get("location_name", spec.get("location_name", ""))
 42 | 	).strip_edges()
 43 | 	location_query = str(
 44 | 		stored.get("location_query", location_name)
 45 | 	).strip_edges()
 46 | 
 47 | 	if "·" in location_query:
 48 | 		location_query = str(location_query.split("·")[0]).strip_edges()
 49 | 
 50 | 	if location_name.is_empty():
 51 | 		location_name = location_query
 52 | 
 53 | 	latitude = stored.get("latitude", spec.get("latitude"))
 54 | 	longitude = stored.get("longitude", spec.get("longitude"))
 55 | 	enabled = bool(stored.get("enabled", spec.get("enabled", false)))
 56 | 
 57 | 	check_interval_sec = maxf(
 58 | 		300.0,
 59 | 		float(spec.get("check_interval_minutes", 600.0)) * 60.0
 60 | 	)
 61 | 	rain_threshold = int(spec.get("rain_probability_threshold", 50))
 62 | 	hot_threshold_c = float(spec.get("hot_threshold_c", 35.0))
 63 | 	cold_threshold_c = float(spec.get("cold_threshold_c", 5.0))
 64 | 	# Check once on the first process frame after startup, then wait for
 65 | 	# the configured interval (10 hours in the default feature config).
 66 | 	check_countdown_sec = 0.0
 67 | 
 68 | 
 69 | func set_location(new_location_name: String, new_enabled: bool) -> void:
 70 | 	var clean := new_location_name.strip_edges()
 71 | 	location_query = clean
 72 | 	location_name = clean
 73 | 	enabled = new_enabled
 74 | 	latitude = null
 75 | 	longitude = null
 76 | 	check_countdown_sec = 2.0
 77 | 	last_reminder_signature = ""
 78 | 
 79 | 
 80 | func export_settings() -> Dictionary:
 81 | 	return {
 82 | 		"location_query": location_query,
 83 | 		"location_name": location_name,
 84 | 		"latitude": latitude,
 85 | 		"longitude": longitude,
 86 | 		"enabled": enabled
 87 | 	}
 88 | 
 89 | 
 90 | func _process(delta: float) -> void:
 91 | 	if not enabled or location_query.is_empty():
 92 | 		return
 93 | 
 94 | 	check_countdown_sec -= delta
 95 | 	if check_countdown_sec <= 0.0:
 96 | 		check_countdown_sec = check_interval_sec
 97 | 		refresh()
 98 | 
 99 | 
func refresh() -> void:
	if location_query.is_empty():
		request_failed.emit("请先设置天气城市。")
		return

	if latitude == null or longitude == null:
		_request_geocode()
	else:
		_request_weather()


func _request_geocode() -> void:
	if (
		geocode_request.get_http_client_status()
		!= HTTPClient.STATUS_DISCONNECTED
	):
		return

	geocode_candidates = _build_geocode_candidates(location_query)
	geocode_candidate_index = 0
	_request_current_geocode_candidate()


func _build_geocode_candidates(query: String) -> PackedStringArray:
	var result := PackedStringArray()
	var clean := query.strip_edges()
	if "·" in clean:
		clean = str(clean.split("·")[0]).strip_edges()

	if clean.is_empty():
		return result

	result.append(clean)

	for suffix in ["市", "省", "区", "县", "州"]:
		if clean.ends_with(suffix) and clean.length() > 1:
			var shorter := clean.left(clean.length() - 1).strip_edges()
			if not shorter.is_empty() and not result.has(shorter):
				result.append(shorter)

	return result


func _request_current_geocode_candidate() -> void:
	if geocode_candidates.is_empty():
		request_failed.emit("没有可用的城市搜索词。")
		return
	if geocode_candidate_index >= geocode_candidates.size():
		request_failed.emit("没有找到“%s”。" % location_query)
		return

	var query := geocode_candidates[geocode_candidate_index]
	var url := (
		"https://geocoding-api.open-meteo.com/v1/search"
		+ "?name=" + query.uri_encode()
		+ "&count=1&language=zh&format=json"
	)

	var error := geocode_request.request(url)
	if error != OK:
		request_failed.emit("天气城市查询启动失败。")


func _on_geocode_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		request_failed.emit("城市查询失败，请稍后重试。")
		return

	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		request_failed.emit("天气城市数据格式异常。")
		return

	var results := (parsed as Dictionary).get("results", []) as Array
	if results.is_empty():
		geocode_candidate_index += 1
		if geocode_candidate_index < geocode_candidates.size():
			call_deferred("_request_current_geocode_candidate")
		else:
			request_failed.emit("没有找到“%s”。" % location_query)
		return

	var first := results[0] as Dictionary
	latitude = first.get("latitude")
	longitude = first.get("longitude")

	var resolved_name := str(first.get("name", location_name))
	var admin1 := str(first.get("admin1", ""))
	var country := str(first.get("country", ""))

	var parts := PackedStringArray([resolved_name])
	if not admin1.is_empty() and admin1 != resolved_name:
		parts.append(admin1)
	if not country.is_empty():
		parts.append(country)

	location_name = " · ".join(parts)
	_request_weather()


func _request_weather() -> void:
	if (
		weather_request.get_http_client_status()
		!= HTTPClient.STATUS_DISCONNECTED
	):
		return

	var url := (
		"https://api.open-meteo.com/v1/forecast"
		+ "?latitude=" + str(latitude)
		+ "&longitude=" + str(longitude)
		+ "&current=temperature_2m,apparent_temperature,"
		+ "weather_code,wind_speed_10m"
		+ "&hourly=temperature_2m,precipitation_probability,weather_code"
		+ "&daily=temperature_2m_max,temperature_2m_min,"
		+ "precipitation_probability_max,weather_code"
		+ "&forecast_days=2&timezone=auto"
	)

	var error := weather_request.request(url)
	if error != OK:
		request_failed.emit("天气请求启动失败。")


func _on_weather_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		request_failed.emit("天气获取失败（HTTP %d）。" % response_code)
		return

	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		request_failed.emit("天气数据格式异常。")
		return

	var summary := _parse_weather(parsed as Dictionary)
	if summary.is_empty():
		request_failed.emit("天气数据不完整。")
		return

	weather_updated.emit(summary)
	_emit_weather_reminder_if_needed(summary)


func _parse_weather(data: Dictionary) -> Dictionary:
	var current := data.get("current", {}) as Dictionary
	if current.is_empty():
		return {}

	var hourly := data.get("hourly", {}) as Dictionary
	var daily := data.get("daily", {}) as Dictionary

	var max_rain_6h := _next_hours_max(
		hourly.get("time", []) as Array,
		hourly.get("precipitation_probability", []) as Array,
		str(current.get("time", "")),
		6
	)

	var temp := float(current.get("temperature_2m", 0.0))
	var feels := float(current.get("apparent_temperature", temp))
	var current_code := int(current.get("weather_code", -1))

	var today_max := _first_float(
		daily.get("temperature_2m_max", []) as Array,
		temp
	)
	var today_min := _first_float(
		daily.get("temperature_2m_min", []) as Array,
		temp
	)
	var today_rain := _first_int(
		daily.get("precipitation_probability_max", []) as Array,
		max_rain_6h
	)
	var today_code := _first_int(
		daily.get("weather_code", []) as Array,
		current_code
	)

	return {
		"location": location_name,
		"temperature_c": temp,
		"feels_like_c": feels,
		"condition": _weather_code_text(current_code),
		"wind_kph": float(current.get("wind_speed_10m", 0.0)),
		"rain_probability_next_6h": max_rain_6h,
		"today_min_c": today_min,
		"today_max_c": today_max,
		"today_rain_probability_max": today_rain,
		"today_condition": _weather_code_text(today_code),
		"today_weather_code": today_code
	}


func _first_float(values: Array, fallback: float) -> float:
	if values.is_empty():
		return fallback
	return float(values[0])


func _first_int(values: Array, fallback: int) -> int:
	if values.is_empty():
		return fallback
	return int(values[0])


func _next_hours_max(
	times: Array,
	values: Array,
	current_time: String,
	hours: int
) -> int:
	var result := 0
	var count := 0

	for i in range(mini(times.size(), values.size())):
		if str(times[i]) < current_time:
			continue

		result = maxi(result, int(values[i]))
		count += 1

		if count >= hours:
			break

	return result


func _emit_weather_reminder_if_needed(summary: Dictionary) -> void:
	var temp := float(summary.get("temperature_c", 0.0))
	var today_max := float(summary.get("today_max_c", temp))
	var today_min := float(summary.get("today_min_c", temp))
	var rain_6h := int(summary.get("rain_probability_next_6h", 0))
	var rain_today := int(
		summary.get("today_rain_probability_max", rain_6h)
	)
	var weather_code := int(summary.get("today_weather_code", -1))
	var city := _short_location(
		str(summary.get("location", location_name))
	)

	var message := ""
	var signature := ""

	if weather_code in [95, 96, 99]:
		message = "今天%s可能会有雷暴，天气有点闹腾，出门多留意一下呀～" % city
		signature = "storm|%s|%d" % [city, weather_code]
	elif rain_6h >= rain_threshold:
		message = (
			"%s接下来几小时下雨的机会不小，大概 %d%%，出门顺手带把伞吧～"
			% [city, rain_6h]
		)
		signature = "rain6h|%s|%d" % [city, int(rain_6h / 10)]
	elif rain_today >= rain_threshold + 20:
		message = (
			"今天%s下雨的可能挺高，最高大概 %d%%，有出门计划的话带伞更稳妥。"
			% [city, rain_today]
		)
		signature = "raintoday|%s|%d" % [
			city,
			int(rain_today / 10)
		]
	elif today_max >= hot_threshold_c:
		message = (
			"今天%s最高差不多 %.0f℃，会挺热的，记得防晒，也多喝点水～"
			% [city, today_max]
		)
		signature = "hot|%s|%d" % [city, roundi(today_max)]
	elif today_min <= cold_threshold_c:
		message = (
			"今天%s最低只有 %.0f℃ 左右，早晚会冷，出门多带一件吧。"
			% [city, today_min]
		)
		signature = "cold|%s|%d" % [city, roundi(today_min)]

	if message.is_empty():
		return

	var now_unix := int(Time.get_unix_time_from_system())
	if (
		signature == last_reminder_signature
		and now_unix - last_reminder_unix < 10800
	):
		return

	last_reminder_signature = signature
	last_reminder_unix = now_unix
	reminder_due.emit(message)


func _short_location(full_name: String) -> String:
	var parts := full_name.split("·")
	if parts.is_empty():
		return full_name.strip_edges()
	return str(parts[0]).strip_edges()


func _weather_code_text(code: int) -> String:
	if code == 0:
		return "晴"
	if code in [1, 2]:
		return "少云"
	if code == 3:
		return "阴"
	if code in [45, 48]:
		return "有雾"
	if code in [51, 53, 55, 56, 57]:
		return "有毛毛雨"
	if code in [61, 63, 65, 66, 67, 80, 81, 82]:
		return "有雨"
	if code in [71, 73, 75, 77, 85, 86]:
		return "有雪"
	if code in [95, 96, 99]:
		return "有雷暴"
	return "天气情况未知"
