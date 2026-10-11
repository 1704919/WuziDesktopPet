extends Node

const CLIP_PREFETCH_LOOKAHEAD := 12

var pet_sprite: Sprite2D
var pet_sprite_next: Sprite2D
var pet_video: VideoStreamPlayer
var body_pivot: Node2D

var token_is_current: Callable
var show_runtime_video: Callable
var hide_runtime_video: Callable
var set_active_hit_frame: Callable

var visual_fade_tween: Tween


func configure(
	sprite: Sprite2D,
	next_sprite: Sprite2D,
	video: VideoStreamPlayer,
	pivot: Node2D,
	token_checker: Callable,
	runtime_show: Callable,
	runtime_hide: Callable,
	hit_frame_setter: Callable
) -> void:
	pet_sprite = sprite
	pet_sprite_next = next_sprite
	pet_video = video
	body_pivot = pivot
	token_is_current = token_checker
	show_runtime_video = runtime_show
	hide_runtime_video = runtime_hide
	set_active_hit_frame = hit_frame_setter


func cancel_visual_fade(restore_alpha: bool = true) -> void:
	if visual_fade_tween != null and visual_fade_tween.is_valid():
		visual_fade_tween.kill()
	visual_fade_tween = null
	if restore_alpha and is_instance_valid(body_pivot):
		body_pivot.modulate.a = 1.0


func fade_visual_alpha(
	target_alpha: float,
	duration_sec: float,
	token: int,
	reduce_motion: bool
) -> bool:
	if not _token_matches(token):
		return false

	cancel_visual_fade(false)
	var target := clampf(target_alpha, 0.0, 1.0)
	if (
		reduce_motion
		or duration_sec <= 0.0
		or is_equal_approx(body_pivot.modulate.a, target)
	):
		body_pivot.modulate.a = target
		return _token_matches(token)

	var tween := create_tween()
	visual_fade_tween = tween
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(body_pivot, "modulate:a", target, duration_sec)

	# A cancelled tween does not provide a reliable finished signal. Keep the
	# cancellation check independent from the tween itself.
	await get_tree().create_timer(duration_sec).timeout

	if not _token_matches(token):
		return false
	if visual_fade_tween == tween:
		if tween.is_valid():
			tween.kill()
		visual_fade_tween = null
	body_pivot.modulate.a = target
	return true


func transition_to_texture(texture: Texture2D, token: int) -> void:
	if texture == null or not _token_matches(token):
		return

	# Keep the outgoing frame visible until the replacement is ready. Blending
	# two transparent character frames can create bright/ghosted edges.
	pet_sprite_next.texture = null
	pet_sprite_next.modulate.a = 0.0
	pet_sprite.modulate = Color.WHITE
	pet_sprite.texture = texture

	# Preserve coroutine behaviour for callers without delaying the swap.
	await get_tree().process_frame


func play_clip(
	clip: Dictionary,
	token: int,
	clip_id: String,
	loop_playback: bool,
	loop_limit: int,
	use_visual_fade: bool,
	video_runtime_enabled: bool,
	reduce_motion: bool,
	fade_min_alpha: float,
	fade_out_sec: float,
	fade_in_sec: float
) -> Dictionary:
	var runtime_stream := clip.get("runtime_stream") as VideoStream
	var release_slim := bool(clip.get("release_slim", false))
	if video_runtime_enabled and runtime_stream != null:
		return await _play_runtime_backend(
			clip,
			token,
			clip_id,
			loop_playback,
			loop_limit,
			use_visual_fade,
			reduce_motion,
			fade_min_alpha,
			fade_out_sec,
			fade_in_sec,
			release_slim
		)

	if release_slim:
		return _degraded_static_result(clip, clip_id)

	return await _play_direct_backend(
		clip.get("frame_paths", []) as Array,
		clip.get("timing_ms", []) as Array,
		clip.get("start_texture") as Texture2D,
		token,
		clip_id,
		loop_playback,
		loop_limit,
		use_visual_fade,
		false,
		reduce_motion,
		fade_min_alpha,
		fade_out_sec,
		fade_in_sec
	)


func _play_runtime_backend(
	clip: Dictionary,
	token: int,
	clip_id: String,
	loop_playback: bool,
	loop_limit: int,
	use_visual_fade: bool,
	reduce_motion: bool,
	fade_min_alpha: float,
	fade_out_sec: float,
	fade_in_sec: float,
	release_slim: bool = false
) -> Dictionary:
	var runtime_stream := clip.get("runtime_stream") as VideoStream
	if runtime_stream == null:
		if release_slim:
			return _degraded_static_result(clip, clip_id)
		return await _play_direct_backend(
			clip.get("frame_paths", []) as Array,
			clip.get("timing_ms", []) as Array,
			clip.get("start_texture") as Texture2D,
			token,
			clip_id,
			loop_playback,
			loop_limit,
			use_visual_fade,
			false,
			reduce_motion,
			fade_min_alpha,
			fade_out_sec,
			fade_in_sec
		)

	var fps := maxf(1.0, float(clip.get("fps", 12.0)))
	var frame_count := maxi(1, int(clip.get("frame_count", 121)))
	var completed_loops := 0
	var entry_faded := false

	if use_visual_fade:
		if not await fade_visual_alpha(
			fade_min_alpha,
			fade_out_sec,
			token,
			reduce_motion
		):
			return _cancelled_result()
		entry_faded = true

	while _token_matches(token):
		if not bool(show_runtime_video.call(
			runtime_stream,
			clip_id,
			fps,
			frame_count,
			false
		)):
			if release_slim:
				return _degraded_static_result(clip, clip_id)
			return await _play_direct_backend(
				clip.get("frame_paths", []) as Array,
				clip.get("timing_ms", []) as Array,
				clip.get("start_texture") as Texture2D,
				token,
				clip_id,
				loop_playback,
				loop_limit,
				use_visual_fade,
				entry_faded,
				reduce_motion,
				fade_min_alpha,
				fade_out_sec,
				fade_in_sec
			)

		await get_tree().process_frame
		if not _token_matches(token):
			return _cancelled_result()

		if not pet_video.is_playing():
			if release_slim:
				return _degraded_static_result(clip, clip_id)
			push_warning("Runtime video failed to start; falling back to PNG sequence: %s" % clip_id)
			hide_runtime_video.call()
			return await _play_direct_backend(
				clip.get("frame_paths", []) as Array,
				clip.get("timing_ms", []) as Array,
				clip.get("start_texture") as Texture2D,
				token,
				clip_id,
				loop_playback,
				loop_limit,
				use_visual_fade,
				entry_faded,
				reduce_motion,
				fade_min_alpha,
				fade_out_sec,
				fade_in_sec
			)

		if entry_faded:
			if not await fade_visual_alpha(
				1.0,
				fade_in_sec,
				token,
				reduce_motion
			):
				return _cancelled_result()
			entry_faded = false

		while _token_matches(token) and pet_video.is_playing():
			await get_tree().process_frame

		if not _token_matches(token):
			return _cancelled_result()

		set_active_hit_frame.call(clip_id, frame_count - 1)
		completed_loops += 1
		if not loop_playback:
			break
		if loop_limit > 0 and completed_loops >= loop_limit:
			break

	if not _token_matches(token):
		return _cancelled_result()
	return {
		"status": "finished",
		"backend": "runtime",
	}


# A slim release has no animated PNG fallback. Restore a stable static frame
# and let the caller release the action coordinator and return to idle.
func _degraded_static_result(clip: Dictionary, clip_id: String) -> Dictionary:
	push_warning("Runtime video unavailable; static fallback: %s" % clip_id)
	cancel_visual_fade()
	hide_runtime_video.call()
	var anchor := clip.get("start_texture") as Texture2D
	if anchor != null:
		pet_sprite.texture = anchor
		pet_sprite.modulate = Color.WHITE
	pet_sprite_next.texture = null
	pet_sprite_next.modulate.a = 0.0
	return {"status": "degraded", "backend": "static"}


func _play_direct_backend(
	frame_paths: Array,
	timings: Array,
	start_texture: Texture2D,
	token: int,
	clip_id: String,
	loop_playback: bool,
	loop_limit: int,
	use_visual_fade: bool,
	entry_already_faded: bool,
	reduce_motion: bool,
	fade_min_alpha: float,
	fade_out_sec: float,
	fade_in_sec: float
) -> Dictionary:
	if use_visual_fade and not entry_already_faded:
		if not await fade_visual_alpha(
			fade_min_alpha,
			fade_out_sec,
			token,
			reduce_motion
		):
			return _cancelled_result()
		entry_already_faded = true

	# Switch display backends only after the entry fade reaches its midpoint.
	hide_runtime_video.call()
	pet_sprite_next.texture = null
	pet_sprite_next.modulate.a = 0.0

	_prefetch_clip_frames(frame_paths, 1)
	var entry_revealed := not use_visual_fade

	if start_texture != null:
		set_active_hit_frame.call(clip_id, 0)
		await transition_to_texture(start_texture, token)
		if not _token_matches(token):
			return _cancelled_result()
		if use_visual_fade:
			if not await fade_visual_alpha(
				1.0,
				fade_in_sec,
				token,
				reduce_motion
			):
				return _cancelled_result()
			entry_revealed = true

	var completed_loops := 0
	while _token_matches(token):
		for i in range(frame_paths.size()):
			if not _token_matches(token):
				return _cancelled_result()

			var lookahead_index := i + CLIP_PREFETCH_LOOKAHEAD
			if lookahead_index < frame_paths.size():
				_queue_clip_frame(str(frame_paths[lookahead_index]))

			var texture: Texture2D = start_texture if i == 0 else null
			if texture == null:
				texture = await _await_clip_texture(str(frame_paths[i]), token)
			if not _token_matches(token):
				return _cancelled_result()
			if texture == null:
				continue

			pet_sprite.texture = texture
			pet_sprite.modulate = Color.WHITE
			set_active_hit_frame.call(clip_id, i)
			if use_visual_fade and not entry_revealed:
				if not await fade_visual_alpha(
					1.0,
					fade_in_sec,
					token,
					reduce_motion
				):
					return _cancelled_result()
				entry_revealed = true

			var hold_ms := 40
			if i < timings.size():
				hold_ms = maxi(1, int(timings[i]))

			if hold_ms > 0:
				await get_tree().create_timer(float(hold_ms) / 1000.0).timeout

		completed_loops += 1
		if not loop_playback:
			break
		if loop_limit > 0 and completed_loops >= loop_limit:
			break

	if not _token_matches(token):
		return _cancelled_result()
	return {
		"status": "finished",
		"backend": "direct",
	}


func _queue_clip_frame(path: String) -> void:
	var status := ResourceLoader.load_threaded_get_status(path)
	if status != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		return

	var error := ResourceLoader.load_threaded_request(path)
	if error != OK and error != ERR_BUSY:
		push_warning("Failed to queue runtime clip frame: %s (%s)" % [path, error_string(error)])


func _prefetch_clip_frames(frame_paths: Array, start_index: int) -> void:
	var end_index := mini(frame_paths.size(), start_index + CLIP_PREFETCH_LOOKAHEAD)
	for index in range(maxi(0, start_index), end_index):
		_queue_clip_frame(str(frame_paths[index]))


func _await_clip_texture(path: String, token: int) -> Texture2D:
	_queue_clip_frame(path)

	while _token_matches(token):
		var status := ResourceLoader.load_threaded_get_status(path)
		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				return ResourceLoader.load_threaded_get(path) as Texture2D
			ResourceLoader.THREAD_LOAD_FAILED:
				push_error("Failed to load runtime clip frame asynchronously: %s" % path)
				return null
			ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				# The request may only become visible to the loader on the next frame.
				_queue_clip_frame(path)
			_:
				pass

		await get_tree().process_frame

	return null


func _token_matches(token: int) -> bool:
	return token_is_current.is_valid() and bool(token_is_current.call(token))


func _cancelled_result() -> Dictionary:
	return {
		"status": "cancelled",
		"backend": "",
	}
