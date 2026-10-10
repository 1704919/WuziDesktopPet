extends RefCounted


static func populate(
	target: Dictionary,
	config: Dictionary,
	video_runtime_enabled: bool
) -> void:
	var clip_cfg := config.get("clips", {}) as Dictionary

	for clip_id in clip_cfg.keys():
		var spec := clip_cfg[clip_id] as Dictionary
		var source_type := str(spec.get("source_type", ""))
		var render_mode := str(spec.get("render_mode", "direct"))
		var frames_dir := str(spec.get("frames_dir", ""))

		if source_type != "green_screen_video":
			push_warning("Skipped non-video runtime clip: %s" % str(clip_id))
			continue
		if render_mode != "direct":
			push_warning("Skipped non-direct runtime clip: %s" % str(clip_id))
			continue
		if not frames_dir.begins_with("res://assets_display/wuzi_chibi/video_"):
			push_warning("Skipped clip outside current video runtime: %s" % str(clip_id))
			continue

		var fps := maxf(1.0, float(spec.get("fps", 12.0)))
		var configured_frame_count := maxi(0, int(spec.get("frame_count", 0)))
		var frame_paths: Array[String] = []
		var configured_paths := spec.get("frames", []) as Array
		if configured_paths.is_empty():
			for index in range(configured_frame_count):
				frame_paths.append("%s/%03d.png" % [frames_dir, index])
		else:
			for frame_path in configured_paths:
				frame_paths.append(str(frame_path))

		var valid_paths: Array[String] = []
		for frame_path_text in frame_paths:
			if not frame_path_text.begins_with(frames_dir + "/"):
				push_warning("Skipped frame outside clip directory: %s" % frame_path_text)
				continue
			if not ResourceLoader.exists(frame_path_text):
				push_error("Missing clip frame: %s" % frame_path_text)
				continue
			valid_paths.append(frame_path_text)

		var timings: Array = spec.get("timing_ms", []) as Array
		if timings.is_empty() and not valid_paths.is_empty():
			var hold_ms := maxi(1, roundi(1000.0 / fps))
			for _index in range(valid_paths.size()):
				timings.append(hold_ms)

		var start_texture: Texture2D = null
		if not valid_paths.is_empty():
			start_texture = load(valid_paths[0]) as Texture2D
			if start_texture == null:
				push_error("Failed to load clip start frame: %s" % valid_paths[0])

		var runtime_video_path := "%s/runtime_alpha.ogv" % frames_dir.get_base_dir()
		var runtime_stream: VideoStream = null
		if video_runtime_enabled and ResourceLoader.exists(runtime_video_path):
			runtime_stream = load(runtime_video_path) as VideoStream
			if runtime_stream == null:
				push_warning("Failed to load runtime video; PNG fallback remains active: %s" % runtime_video_path)

		target[str(clip_id)] = {
			"frame_paths": valid_paths,
			"timing_ms": timings,
			"source_type": source_type,
			"render_mode": render_mode,
			"frames_dir": frames_dir,
			"start_texture": start_texture,
			"loop": bool(spec.get("loop", false)),
			"fps": fps,
			"frame_count": configured_frame_count if configured_frame_count > 0 else valid_paths.size(),
			"runtime_video_path": runtime_video_path,
			"runtime_stream": runtime_stream
		}
