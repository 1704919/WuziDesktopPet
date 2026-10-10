  1 | extends RefCounted
  2 | 
  3 | const LEFT_ACTION_ID := "walk_left"
  4 | const RIGHT_ACTION_ID := "walk_right"
  5 | 
  6 | var _config: Dictionary = {}
  7 | var _catalog: Dictionary = {}
  8 | var _rng := RandomNumberGenerator.new()
  9 | 
 10 | var _user_enabled := true
 11 | var _ready := false
 12 | var _pause_remaining_sec := 0.0
 13 | 
 14 | var _active_action_id := ""
 15 | var _active_elapsed_sec := 0.0
 16 | var _active_center_x := 0.0
 17 | var _active_position_initialized := false
 18 | 
 19 | 
 20 | func configure(
 21 | 	roaming_config: Dictionary,
 22 | 	movement_catalog: Dictionary,
 23 | 	user_enabled: bool
 24 | ) -> void:
 25 | 	_config = roaming_config.duplicate(true)
 26 | 	_catalog = movement_catalog.duplicate(true)
 27 | 	_user_enabled = user_enabled
 28 | 	_ready = bool(_config.get("enabled", false)) and bool(_catalog.get("ready", false))
 29 | 	_rng.randomize()
 30 | 	_clear_active()
 31 | 	_schedule_next_pause()
 32 | 
 33 | 
 34 | func is_available() -> bool:
 35 | 	return _ready
 36 | 
 37 | 
 38 | func is_enabled() -> bool:
 39 | 	return _ready and _user_enabled
 40 | 
 41 | 
 42 | func set_enabled(value: bool) -> void:
 43 | 	_user_enabled = value
 44 | 	_clear_active()
 45 | 	_schedule_next_pause()
 46 | 
 47 | 
 48 | func is_active() -> bool:
 49 | 	return not _active_action_id.is_empty()
 50 | 
 51 | 
 52 | func active_action_id() -> String:
 53 | 	return _active_action_id
 54 | 
 55 | 
 56 | func cancel(schedule_next: bool = true) -> bool:
 57 | 	var was_active := is_active()
 58 | 	_clear_active()
 59 | 	if schedule_next:
 60 | 		_schedule_next_pause()
 61 | 	return was_active
 62 | 
 63 | 
 64 | func request_if_due(
 65 | 	delta: float,
 66 | 	can_start: bool,
 67 | 	window_position: Vector2i,
 68 | 	pet_anchor: Vector2,
 69 | 	usable_rect: Rect2i
 70 | ) -> String:
 71 | 	if not is_enabled() or is_active() or not can_start:
 72 | 		return ""
 73 | 
 74 | 	_pause_remaining_sec = maxf(0.0, _pause_remaining_sec - maxf(0.0, delta))
 75 | 	if _pause_remaining_sec > 0.0:
 76 | 		return ""
 77 | 
 78 | 	return _choose_direction(window_position, pet_anchor, usable_rect)
 79 | 
 80 | 
 81 | func mark_started(action_id: String) -> bool:
 82 | 	var spec := _clip_spec(action_id)
 83 | 	if spec.is_empty() or action_id not in [LEFT_ACTION_ID, RIGHT_ACTION_ID]:
 84 | 		_schedule_next_pause()
 85 | 		return false
 86 | 
 87 | 	_active_action_id = action_id
 88 | 	_active_elapsed_sec = 0.0
 89 | 	return true
 90 | 
 91 | 
 92 | func step_active(
 93 | 	delta: float,
 94 | 	window_position: Vector2i,
 95 | 	pet_anchor: Vector2,
 96 | 	usable_rect: Rect2i,
 97 | 	animation_time_sec: float = -1.0
 98 | ) -> Dictionary:
 99 | 	if not is_active():
		return {}

	var spec := _clip_spec(_active_action_id)
	if spec.is_empty():
		cancel()
		return {"finished": true, "position": window_position}

	var duration_sec := maxf(0.01, float(spec.get("duration_sec", 10.0)))
	var previous_elapsed := _active_elapsed_sec
	var next_elapsed := minf(
		duration_sec,
		previous_elapsed + maxf(0.0, delta)
	)
	if animation_time_sec >= 0.0:
		next_elapsed = clampf(animation_time_sec, previous_elapsed, duration_sec)

	var speed_px_sec := maxf(0.0, float(_config.get("speed_px_sec", 56.0)))
	var direction := float(spec.get("direction", 0))
	var motion_area_sec := _motion_area_between(
		spec,
		previous_elapsed,
		next_elapsed
	)
	var movement_px := direction * speed_px_sec * motion_area_sec

	if not _active_position_initialized:
		_active_center_x = float(window_position.x) + pet_anchor.x
		_active_position_initialized = true

	var target_position := window_position
	if not is_zero_approx(movement_px):
		var margin := maxi(0, int(_config.get("edge_margin_px", 28)))
		var min_center_x := float(usable_rect.position.x + margin)
		var max_center_x := float(usable_rect.end.x - margin)
		_active_center_x = clampf(
			_active_center_x + movement_px,
			min_center_x,
			max_center_x
		)
		target_position.x = roundi(_active_center_x - pet_anchor.x)

	_active_elapsed_sec = next_elapsed
	var motion_factor := _motion_factor(spec, next_elapsed)
	var finished := _active_elapsed_sec >= duration_sec
	if finished:
		_clear_active()
		_schedule_next_pause()

	return {
		"position": target_position,
		"finished": finished,
		"motion_factor": motion_factor
	}


func _choose_direction(
	window_position: Vector2i,
	pet_anchor: Vector2,
	usable_rect: Rect2i
) -> String:
	var clips := _catalog.get("clips", {}) as Dictionary
	var has_left := clips.has(LEFT_ACTION_ID)
	var has_right := clips.has(RIGHT_ACTION_ID)
	if not has_left and not has_right:
		return ""
	if has_left and not has_right:
		return LEFT_ACTION_ID
	if has_right and not has_left:
		return RIGHT_ACTION_ID

	var margin := maxi(0, int(_config.get("edge_margin_px", 28)))
	var pet_center_x := float(window_position.x) + pet_anchor.x
	var left_limit := float(usable_rect.position.x + margin)
	var right_limit := float(usable_rect.end.x - margin)
	var room_left := maxf(0.0, pet_center_x - left_limit)
	var room_right := maxf(0.0, right_limit - pet_center_x)
	var expected_travel := maxf(
		96.0,
		maxf(_expected_travel_px(LEFT_ACTION_ID), _expected_travel_px(RIGHT_ACTION_ID))
	)

	if room_left < expected_travel and room_right > room_left:
		return RIGHT_ACTION_ID
	if room_right < expected_travel and room_left > room_right:
		return LEFT_ACTION_ID
	return LEFT_ACTION_ID if _rng.randf() < 0.5 else RIGHT_ACTION_ID


func _expected_travel_px(action_id: String) -> float:
	var spec := _clip_spec(action_id)
	if spec.is_empty():
		return 0.0

	var motion := spec.get("motion", {}) as Dictionary
	var start_sec := maxf(0.0, float(motion.get("start_sec", 2.0)))
	var decelerate_sec := maxf(start_sec, float(motion.get("decelerate_sec", 7.0)))
	var stop_sec := maxf(decelerate_sec, float(motion.get("stop_sec", 9.0)))
	var full_speed_sec := decelerate_sec - start_sec
	var deceleration_area_sec := (stop_sec - decelerate_sec) * 0.5
	return maxf(0.0, float(_config.get("speed_px_sec", 56.0))) * (
		full_speed_sec + deceleration_area_sec
	)


func _motion_area_between(
	spec: Dictionary,
	start_sec: float,
	end_sec: float
) -> float:
	if end_sec <= start_sec:
		return 0.0
	return maxf(
		0.0,
		_motion_area_until(spec, end_sec) - _motion_area_until(spec, start_sec)
	)


func _motion_area_until(spec: Dictionary, elapsed_sec: float) -> float:
	var motion := spec.get("motion", {}) as Dictionary
	var start_sec := maxf(0.0, float(motion.get("start_sec", 2.0)))
	var decelerate_sec := maxf(start_sec, float(motion.get("decelerate_sec", 7.0)))
	var stop_sec := maxf(decelerate_sec, float(motion.get("stop_sec", 9.0)))
	if elapsed_sec <= start_sec:
		return 0.0

	var full_speed_end := minf(elapsed_sec, decelerate_sec)
	var area := maxf(0.0, full_speed_end - start_sec)
	if elapsed_sec <= decelerate_sec or is_equal_approx(stop_sec, decelerate_sec):
		return area

	var deceleration_duration := stop_sec - decelerate_sec
	var deceleration_elapsed := clampf(
		elapsed_sec - decelerate_sec,
		0.0,
		deceleration_duration
	)
	area += (
		deceleration_elapsed
		- (deceleration_elapsed * deceleration_elapsed)
		/ (2.0 * deceleration_duration)
	)
	return area


func _motion_factor(spec: Dictionary, elapsed_sec: float) -> float:
	var motion := spec.get("motion", {}) as Dictionary
	var start_sec := maxf(0.0, float(motion.get("start_sec", 2.0)))
	var decelerate_sec := maxf(start_sec, float(motion.get("decelerate_sec", 7.0)))
	var stop_sec := maxf(decelerate_sec, float(motion.get("stop_sec", 9.0)))

	if elapsed_sec < start_sec or elapsed_sec >= stop_sec:
		return 0.0
	if elapsed_sec < decelerate_sec:
		return 1.0
	if is_equal_approx(stop_sec, decelerate_sec):
		return 0.0
	return clampf(
		1.0 - ((elapsed_sec - decelerate_sec) / (stop_sec - decelerate_sec)),
		0.0,
		1.0
	)


func _clip_spec(action_id: String) -> Dictionary:
	var clips := _catalog.get("clips", {}) as Dictionary
	return clips.get(action_id, {}) as Dictionary


func _schedule_next_pause() -> void:
	var raw_interval := _config.get("pause_interval_sec", [14.0, 26.0]) as Array
	var min_sec := 14.0
	var max_sec := 26.0
	if raw_interval.size() >= 2:
		min_sec = maxf(0.0, float(raw_interval[0]))
		max_sec = maxf(min_sec, float(raw_interval[1]))
	_pause_remaining_sec = _rng.randf_range(min_sec, max_sec)


func _clear_active() -> void:
	_active_action_id = ""
	_active_elapsed_sec = 0.0
	_active_center_x = 0.0
	_active_position_initialized = false
