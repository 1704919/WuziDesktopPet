 1 | extends Node
 2 | 
 3 | signal reminder_due(text: String)
 4 | 
 5 | var enabled := true
 6 | var water_interval_sec := 5400.0
 7 | var water_countdown_sec := 5400.0
 8 | var meal_times: Array = []
 9 | var random_chatter_enabled := false
var chatter_paused := false
var random_messages: Array = []
var chatter_min_sec := 1200.0
var chatter_max_sec := 2700.0
var chatter_countdown_sec := 1800.0
var rng := RandomNumberGenerator.new()
var fired_meal_keys: Dictionary = {}


func _ready() -> void:
	rng.randomize()
	set_process(true)


func configure(spec: Dictionary) -> void:
	enabled = bool(spec.get("enabled", true))
	water_interval_sec = maxf(60.0, float(spec.get("water_interval_minutes", 90.0)) * 60.0)
	water_countdown_sec = water_interval_sec
	meal_times = spec.get("meal_times", []) as Array
	random_chatter_enabled = bool(spec.get("random_chatter_enabled", false))
	random_messages = spec.get("random_messages", []) as Array

	var chatter_range := spec.get("random_chatter_interval_minutes", [20.0, 45.0]) as Array
	if chatter_range.size() >= 2:
		chatter_min_sec = maxf(60.0, float(chatter_range[0]) * 60.0)
		chatter_max_sec = maxf(chatter_min_sec, float(chatter_range[1]) * 60.0)
	chatter_countdown_sec = rng.randf_range(chatter_min_sec, chatter_max_sec)


func set_enabled(value: bool) -> void:
	enabled = value


func set_chatter_paused(value: bool) -> void:
	chatter_paused = value
	if not value:
		chatter_countdown_sec = rng.randf_range(chatter_min_sec, chatter_max_sec)


func _process(delta: float) -> void:
	if not enabled:
		return

	water_countdown_sec -= delta
	if water_countdown_sec <= 0.0:
		water_countdown_sec = water_interval_sec
		reminder_due.emit("喝点水吧，别一直盯着屏幕。")

	_check_meal_time()

	if random_chatter_enabled and not chatter_paused and not random_messages.is_empty():
		chatter_countdown_sec -= delta
		if chatter_countdown_sec <= 0.0:
			chatter_countdown_sec = rng.randf_range(chatter_min_sec, chatter_max_sec)
			var index := rng.randi_range(0, random_messages.size() - 1)
			reminder_due.emit(str(random_messages[index]))


func _check_meal_time() -> void:
	var now := Time.get_datetime_dict_from_system()
	var hhmm := "%02d:%02d" % [int(now.get("hour", 0)), int(now.get("minute", 0))]
	var date_key := "%04d-%02d-%02d" % [
		int(now.get("year", 0)),
		int(now.get("month", 0)),
		int(now.get("day", 0))
	]

	for item in meal_times:
		var meal := item as Dictionary
		if str(meal.get("time", "")) != hhmm:
			continue
		var key := "%s|%s" % [date_key, hhmm]
		if fired_meal_keys.has(key):
			continue
		fired_meal_keys[key] = true
		reminder_due.emit(str(meal.get("text", "该吃饭啦。")))
