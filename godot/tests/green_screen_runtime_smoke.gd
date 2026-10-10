 1 | extends SceneTree
 2 | 
 3 | func _init() -> void:
 4 | 	call_deferred("_run")
 5 | 
 6 | 
 7 | func _run() -> void:
 8 | 	var failures: Array[String] = []
 9 | 	var file := FileAccess.open("res://config/pet_behavior.json", FileAccess.READ)
	if file == null:
		push_error("GREENSCREEN_RUNTIME_SMOKE_FAILED: missing pet_behavior.json")
		quit(2)
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("GREENSCREEN_RUNTIME_SMOKE_FAILED: invalid pet_behavior.json")
		quit(2)
		return

	var cfg := parsed as Dictionary
	var master := str(cfg.get("master_texture", ""))
	if not master.begins_with("res://assets_display/wuzi_chibi/video_idle/frames/"):
		failures.append("master_not_video_idle")

	var idle := cfg.get("idle_video", {}) as Dictionary
	if not bool(idle.get("enabled", false)):
		failures.append("idle_video_disabled")
	if not str(idle.get("frames_dir", "")).contains("video_idle/frames"):
		failures.append("idle_video_wrong_path")
	if int(idle.get("frame_count", 0)) != 121:
		failures.append("idle_video_wrong_frame_count")
	if absf(float(idle.get("fps", 0.0)) - 12.0) > 0.01:
		failures.append("idle_video_wrong_fps")

	var clips := cfg.get("clips", {}) as Dictionary
	for expected_clip in ["click_happy_video", "click_shy_video", "march_in_place_video", "sleepy_video", "yawn_video", "click_angry_video", "drag_reaction_video", "sleep_down_video"]:
		if not clips.has(expected_clip):
			failures.append("current_clip_missing:" + expected_clip)

	for clip_id in clips.keys():
		var spec := clips[clip_id] as Dictionary
		if str(spec.get("source_type", "")) != "green_screen_video":
			failures.append("clip_not_green_screen:" + str(clip_id))
		if str(spec.get("render_mode", "")) != "direct":
			failures.append("clip_not_direct:" + str(clip_id))
		var frames_dir := str(spec.get("frames_dir", ""))
		if not frames_dir.begins_with("res://assets_display/wuzi_chibi/video_"):
			failures.append("legacy_clip_path:" + str(clip_id))
		if int(spec.get("frame_count", 0)) != 121:
			failures.append("clip_wrong_frame_count:" + str(clip_id))
		if absf(float(spec.get("fps", 0.0)) - 12.0) > 0.01:
			failures.append("clip_wrong_fps:" + str(clip_id))

	for obsolete_key in ["breathing", "blink_interval_sec", "crossfade_ms"]:
		if cfg.has(obsolete_key):
			failures.append("obsolete_runtime_key:" + obsolete_key)

	var serialized := JSON.stringify(cfg)
	for legacy in [
		"res://assets/wuzi_chibi",
		"runtime_assets",
		"/clips/click_shy",
		"/clips/idle_breathe"
	]:
		if serialized.contains(legacy):
			failures.append("legacy_reference:" + legacy)

	if failures.is_empty():
		print("GREENSCREEN_RUNTIME_SMOKE_OK")
		quit(0)
	else:
		push_error("GREENSCREEN_RUNTIME_SMOKE_FAILED: %s" % ", ".join(failures))
		quit(2)
