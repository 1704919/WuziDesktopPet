 1 | extends RefCounted
 2 | 
 3 | 
 4 | static func build(summary: Dictionary) -> String:
 5 | 	var location := str(summary.get("location", ""))
 6 | 	var city := location
 7 | 	var parts := location.split("·")
 8 | 	if not parts.is_empty():
 9 | 		city = str(parts[0]).strip_edges()

	var condition := str(summary.get("today_condition", ""))
	var current := float(summary.get("temperature_c", 0.0))
	var feels := float(summary.get("feels_like_c", current))
	var today_min := float(summary.get("today_min_c", current))
	var today_max := float(summary.get("today_max_c", current))
	var rain_today := int(summary.get("today_rain_probability_max", 0))
	var rain_6h := int(summary.get("rain_probability_next_6h", 0))
	var wind_kph := float(summary.get("wind_kph", 0.0))

	var opening := ""
	if condition.contains("雷暴"):
		opening = "%s今天有雷雨，天气有点闹腾，%.0f～%.0f℃。" % [
			city, today_min, today_max
		]
	elif condition.contains("雨"):
		opening = "%s今天会下雨，%.0f～%.0f℃。" % [
			city, today_min, today_max
		]
	elif condition == "晴":
		opening = "%s今天挺晴朗，%.0f～%.0f℃。" % [
			city, today_min, today_max
		]
	elif condition == "阴":
		opening = "%s今天有点阴，%.0f～%.0f℃。" % [
			city, today_min, today_max
		]
	else:
		opening = "%s今天%s，%.0f～%.0f℃。" % [
			city, condition, today_min, today_max
		]

	var now_line := "现在 %.0f℃" % current
	if absf(feels - current) >= 1.5:
		now_line += "，体感大概 %.0f℃" % feels
	now_line += "。"

	var advice := ""
	if rain_today >= 70 or rain_6h >= 60:
		advice = (
			"雨的概率挺高，今天最高 %d%%，接下来 6 小时也有 %d%%，出门最好带把伞～"
			% [rain_today, rain_6h]
		)
	elif rain_6h >= 40:
		advice = (
			"接下来几小时有 %d%% 左右的下雨可能，带把伞会更稳妥。"
			% rain_6h
		)
	elif today_max >= 35.0:
		advice = "今天会比较热，记得防晒，也多喝点水。"
	elif today_min <= 10.0:
		advice = "早晚会偏凉，出门多带一件会舒服些。"
	elif wind_kph >= 35.0:
		advice = "风会有点大，出门注意一下就好。"
	else:
		advice = "整体还算舒服，正常出门就行～"

	return "%s\n%s\n%s" % [opening, now_line, advice]
