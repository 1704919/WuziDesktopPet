 1 | extends RefCounted
 2 | 
 3 | var enabled := true
 4 | var long_idle_ms := 20 * 60 * 1000
 5 | var rest_interval_min_ms := 90 * 1000
 6 | var rest_interval_max_ms := 180 * 1000
 7 | var sleepy_weight_multiplier := 4.0
 8 | var rest_baseline_weight := 3.0
 9 | var sleep_trigger_probability := 0.18
var sleep_loop_cycles := 5

var frozen := false
var last_activity_ms := 0
var next_rest_check_ms := 0


func configure(raw: Dictionary, now_ms: int = -1) -> void:
	enabled = bool(raw.get("enabled", true))
	long_idle_ms = maxi(1000, int(float(raw.get("long_idle_minutes", 20.0)) * 60.0 * 1000.0))

	var interval := raw.get("rest_check_interval_sec", [90.0, 180.0]) as Array
	var min_sec := 90.0
	var max_sec := 180.0
	if interval.size() >= 2:
		min_sec = maxf(1.0, float(interval[0]))
		max_sec = maxf(min_sec, float(interval[1]))
	rest_interval_min_ms = int(min_sec * 1000.0)
	rest_interval_max_ms = int(max_sec * 1000.0)

	sleepy_weight_multiplier = maxf(1.0, float(raw.get("sleepy_weight_multiplier", 4.0)))
	rest_baseline_weight = maxf(0.0, float(raw.get("rest_baseline_weight", 3.0)))
	sleep_trigger_probability = clampf(float(raw.get("sleep_trigger_probability", 0.18)), 0.0, 1.0)
	sleep_loop_cycles = maxi(1, int(raw.get("sleep_loop_cycles", 5)))
	reset(now_ms)


func reset(now_ms: int = -1) -> void:
	var now := _now(now_ms)
	frozen = false
	last_activity_ms = now
	next_rest_check_ms = now + long_idle_ms


func note_user_activity(now_ms: int = -1) -> void:
	if frozen:
		return
	var now := _now(now_ms)
	last_activity_ms = now
	next_rest_check_ms = now + long_idle_ms


func set_sleep_frozen(value: bool) -> void:
	frozen = value


func finish_sleep(now_ms: int = -1) -> void:
	reset(now_ms)


func is_long_idle(now_ms: int = -1) -> bool:
	if not enabled or frozen:
		return false
	return _now(now_ms) - last_activity_ms >= long_idle_ms


func should_check_rest(now_ms: int = -1) -> bool:
	if not is_long_idle(now_ms):
		return false
	return _now(now_ms) >= next_rest_check_ms


func schedule_next_rest_check(rng: RandomNumberGenerator, now_ms: int = -1) -> void:
	var now := _now(now_ms)
	var delay_ms := rest_interval_min_ms
	if rest_interval_max_ms > rest_interval_min_ms:
		delay_ms = rng.randi_range(rest_interval_min_ms, rest_interval_max_ms)
	next_rest_check_ms = now + delay_ms


func choose_long_idle_action(sleep_roll: float, rest_roll: float) -> String:
	if sleep_roll < sleep_trigger_probability:
		return "sleep"
	var sleepy_weight := maxf(0.0, sleepy_weight_multiplier)
	var total := sleepy_weight + rest_baseline_weight
	if total <= 0.0:
		return ""
	return "sleepy" if rest_roll * total < sleepy_weight else ""


func adjusted_idle_weight(action_id: String, weight: float, now_ms: int = -1) -> float:
	if action_id == "sleepy_video" and is_long_idle(now_ms):
		return weight * sleepy_weight_multiplier
	return weight


func _now(now_ms: int) -> int:
	return Time.get_ticks_msec() if now_ms < 0 else now_ms
