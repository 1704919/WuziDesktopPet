extends SceneTree

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var stream := load("res://assets_display/wuzi_chibi/video_idle/runtime_alpha.ogv") as VideoStream
	check(stream != null, "runtime Theora stream loads")

	var player := VideoStreamPlayer.new()
	player.expand = true
	player.loop = false
	player.size = Vector2(480, 360)
	player.stream = stream
	root.add_child(player)
	await process_frame

	if stream != null:
		player.play()
		await process_frame
		await process_frame
		check(player.is_playing(), "runtime Theora starts playing")
		var first_position := player.stream_position
		await create_timer(0.30).timeout
		check(player.stream_position > first_position, "runtime Theora advances stream position")
		var video_texture := player.get_video_texture()
		check(video_texture != null, "runtime video texture exists")
		if video_texture != null:
			check(video_texture.get_width() == 960, "runtime video texture width is 960")
			check(video_texture.get_height() == 360, "runtime video texture height is 360")
		player.stop()

	if failures.is_empty():
		print("VIDEO_RUNTIME_PROBE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(2)
