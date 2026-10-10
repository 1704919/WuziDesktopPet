extends Node

signal mood_changed(mood: String, score: float)

const MOOD_NORMAL := "normal"
const MOOD_HAPPY := "happy"
const MOOD_SHY := "shy"
const MOOD_ANGRY := "angry"
const MOOD_SLEEPY := "sleepy"

var mood_score := 0.0
var current_mood := MOOD_NORMAL
var click_count := 0
var last_click_ms := -1

var min_score := -100.0
var max_score := 100.0
var happy_threshold := 25.0
var angry_threshold := -25.0
var click_window_ms := 3500
var recovery_interval_sec := 5.0
var recovery_step := 4.0
var happy_duration_ms := 6500
var shy_duration_ms := 6500
var angry_duration_ms := 9000
var sleepy_duration_ms := 10000

var temporary_mood := ""
var temporary_until_ms := 0
var _recovery_timer: Timer
var _last_emitted_score := INF


func _ready() -> void:
	_recovery_timer = Timer.new()
	_recovery_timer.name = "RecoveryTimer"
	_recovery_timer.one_shot = false
	_recovery_timer.wait_time = recovery_interval_sec
	_recovery_timer.timeout.connect(_on_recovery_tick)
	add_child(_recovery_timer)
	_recovery_timer.start()
	_refresh_mood(Time.get_ticks_msec(), true)


func configure(raw: Dictionary) -> void:
	min_score = float(raw.get("min_score", -100.0))
	max_score = float(raw.get("max_score", 100.0))
	if min_score >= max_score:
		min_score = -100.0
		max_score = 100.0

	happy_threshold = clampf(
		float(raw.get("happy_threshold", 25.0)),
		0.0,
		max_score
	)
	angry_threshold = clampf(
		float(raw.get("angry_threshold", -25.0)),
		min_score,
		0.0
	)
	click_window_ms = maxi(250, int(raw.get("click_window_ms", 3500)))
	recovery_interval_sec = maxf(
		1.0,
		float(raw.get("recovery_interval_sec", 5.0))
	)
	recovery_step = maxf(0.1, float(raw.get("recovery_step", 4.0)))
	happy_duration_ms = maxi(500, int(raw.get("happy_duration_ms", 6500)))
	shy_duration_ms = maxi(500, int(raw.get("shy_duration_ms", 6500)))
	angry_duration_ms = maxi(500, int(raw.get("angry_duration_ms", 9000)))
	sleepy_duration_ms = maxi(500, int(raw.get("sleepy_duration_ms", 10000)))

	mood_score = clampf(mood_score, min_score, max_score)
	if is_instance_valid(_recovery_timer):
		_recovery_timer.wait_time = recovery_interval_sec
		if _recovery_timer.is_stopped():
			_recovery_timer.start()

	_refresh_mood(Time.get_ticks_msec(), true)


func apply_event(event_type: String, now_ms: int = -1) -> Dictionary:
	var now := Time.get_ticks_msec() if now_ms < 0 else now_ms

	match event_type:
		"praise":
			mood_score = clampf(mood_score + 18.0, min_score, max_score)
			_set_temporary_mood(MOOD_SHY, shy_duration_ms, now)
		"touch":
			mood_score = clampf(mood_score + 15.0, min_score, max_score)
		"positive":
			mood_score = clampf(mood_score + 8.0, min_score, max_score)
		"happy":
			mood_score = clampf(mood_score + 12.0, min_score, max_score)
			_set_temporary_mood(MOOD_HAPPY, happy_duration_ms, now)
		"sleepy":
			mood_score = clampf(mood_score - 4.0, min_score, max_score)
			_set_temporary_mood(MOOD_SLEEPY, sleepy_duration_ms, now)
		"angry":
			mood_score = minf(mood_score, angry_threshold - 10.0)
			_set_temporary_mood(MOOD_ANGRY, angry_duration_ms, now)
		"reset":
			mood_score = 0.0
			temporary_mood = ""
			temporary_until_ms = 0
		_:
			pass

	_refresh_mood(now)
	return get_snapshot(now)


func register_click(now_ms: int = -1) -> Dictionary:
	var now := Time.get_ticks_msec() if now_ms < 0 else now_ms
	if last_click_ms < 0 or now - last_click_ms > click_window_ms:
		click_count = 0

	click_count += 1
	last_click_ms = now

	var tier := "normal"
	var action_id := "click_happy_video"

	if click_count >= 6:
		tier = "angry"
		action_id = "click_angry_video"
		if click_count == 6:
			mood_score = minf(mood_score, angry_threshold - 10.0)
		else:
			mood_score = clampf(mood_score - 6.0, min_score, max_score)
		_set_temporary_mood(MOOD_ANGRY, angry_duration_ms, now)
	elif click_count >= 3:
		tier = "shy"
		action_id = "click_shy_video"
		mood_score = clampf(mood_score + 4.0, min_score, max_score)
		_set_temporary_mood(MOOD_SHY, shy_duration_ms, now)
	else:
		mood_score = clampf(mood_score + 3.0, min_score, max_score)

	_refresh_mood(now)
	var snapshot := get_snapshot(now)
	snapshot["tier"] = tier
	snapshot["action_id"] = action_id
	return snapshot


func recover_once(now_ms: int = -1) -> Dictionary:
	var now := Time.get_ticks_msec() if now_ms < 0 else now_ms

	if mood_score > 0.0:
		mood_score = maxf(0.0, mood_score - recovery_step)
	elif mood_score < 0.0:
		mood_score = minf(0.0, mood_score + recovery_step)

	if last_click_ms >= 0 and now - last_click_ms > click_window_ms:
		click_count = 0

	_refresh_mood(now)
	return get_snapshot(now)


func get_snapshot(now_ms: int = -1) -> Dictionary:
	var now := Time.get_ticks_msec() if now_ms < 0 else now_ms
	_expire_temporary(now)
	return {
		"mood": _calculate_mood(now),
		"score": mood_score,
		"click_count": click_count,
		"temporary_mood": temporary_mood,
		"temporary_until_ms": temporary_until_ms
	}


func describe_mood() -> String:
	match current_mood:
		MOOD_HAPPY:
			return "开心"
		MOOD_SHY:
			return "害羞"
		MOOD_ANGRY:
			return "生气"
		MOOD_SLEEPY:
			return "困倦"
		_:
			return "平常"


func _on_recovery_tick() -> void:
	recover_once()


func _set_temporary_mood(mood: String, duration_ms: int, now_ms: int) -> void:
	temporary_mood = mood
	temporary_until_ms = now_ms + duration_ms


func _expire_temporary(now_ms: int) -> void:
	if not temporary_mood.is_empty() and now_ms >= temporary_until_ms:
		temporary_mood = ""
		temporary_until_ms = 0


func _calculate_mood(now_ms: int) -> String:
	if not temporary_mood.is_empty() and now_ms < temporary_until_ms:
		return temporary_mood
	if mood_score >= happy_threshold:
		return MOOD_HAPPY
	if mood_score <= angry_threshold:
		return MOOD_ANGRY
	return MOOD_NORMAL


func _refresh_mood(now_ms: int, force: bool = false) -> void:
	_expire_temporary(now_ms)
	var next_mood := _calculate_mood(now_ms)
	var changed := (
		force
		or next_mood != current_mood
		or is_inf(_last_emitted_score)
		or absf(_last_emitted_score - mood_score) > 0.001
	)
	current_mood = next_mood
	if changed:
		_last_emitted_score = mood_score
		mood_changed.emit(current_mood, mood_score)
