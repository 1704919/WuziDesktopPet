  1 | extends Node
  2 | 
  3 | signal queue_changed(summary: Dictionary)
  4 | 
  5 | const IMAGE_EXTENSIONS := ["png", "jpg", "jpeg", "webp", "heic", "heif", "bmp", "tga"]
  6 | const AUDIO_EXTENSIONS := ["mp3", "wav", "flac", "ogg", "m4a", "aac", "opus"]
  7 | const VIDEO_EXTENSIONS := ["mp4", "mov", "mkv", "webm", "avi", "gif"]
  8 | 
  9 | var queued_files: PackedStringArray = []
 10 | var image_quality := 0.92
 11 | var output_suffix := "_converted"
 12 | 
 13 | 
 14 | func configure(spec: Dictionary) -> void:
 15 | 	image_quality = clampf(float(spec.get("image_quality", 0.92)), 0.1, 1.0)
 16 | 	output_suffix = str(spec.get("output_suffix", "_converted"))
 17 | 
 18 | 
 19 | func enqueue(paths: PackedStringArray) -> Dictionary:
 20 | 	var known: Dictionary = {}
 21 | 	for path in queued_files:
 22 | 		known[path.replace("\\", "/").simplify_path().to_lower()] = true
 23 | 	for path in paths:
 24 | 		var key := path.replace("\\", "/").simplify_path().to_lower()
 25 | 		if not known.has(key):
 26 | 			queued_files.append(path)
 27 | 			known[key] = true
 28 | 
 29 | 	var summary := get_summary()
 30 | 	queue_changed.emit(summary)
 31 | 	return summary
 32 | 
 33 | 
 34 | func clear_queue() -> void:
 35 | 	queued_files.clear()
 36 | 	queue_changed.emit(get_summary())
 37 | 
 38 | 
 39 | func get_queued_files() -> PackedStringArray:
 40 | 	return queued_files.duplicate()
 41 | 
 42 | 
 43 | func remove_paths(paths: PackedStringArray) -> void:
 44 | 	if paths.is_empty():
 45 | 		return
 46 | 	var remove_lookup: Dictionary = {}
 47 | 	for path in paths:
 48 | 		remove_lookup[str(path)] = true
 49 | 	var kept := PackedStringArray()
 50 | 	for path in queued_files:
 51 | 		if not remove_lookup.has(path):
 52 | 			kept.append(path)
 53 | 	queued_files = kept
 54 | 	queue_changed.emit(get_summary())
 55 | 
 56 | 
 57 | func apply_execution_result(result: Dictionary) -> void:
 58 | 	var successful := PackedStringArray()
 59 | 	var recovery: Dictionary = {}
 60 | 	for item: Dictionary in result.get("items", []):
 61 | 		if item.status == "completed":
 62 | 			successful.append(str(item.source))
 63 | 		elif not str(item.get("recovery_path", "")).is_empty():
 64 | 			recovery[str(item.source)] = str(item.recovery_path)
 65 | 	var kept := PackedStringArray()
 66 | 	for path in queued_files:
 67 | 		if not successful.has(path):
 68 | 			var remaining := str(recovery.get(path, path))
 69 | 			if not kept.has(remaining):
 70 | 				kept.append(remaining)
 71 | 	queued_files = kept
 72 | 	queue_changed.emit(get_summary())
 73 | 
 74 | 
 75 | func get_summary() -> Dictionary:
 76 | 	var images := 0
 77 | 	var audio := 0
 78 | 	var video := 0
 79 | 	var other := 0
 80 | 
 81 | 	for path in queued_files:
 82 | 		match classify(path):
 83 | 			"image":
 84 | 				images += 1
 85 | 			"audio":
 86 | 				audio += 1
 87 | 			"video":
 88 | 				video += 1
 89 | 			_:
 90 | 				other += 1
 91 | 
 92 | 	return {
 93 | 		"total": queued_files.size(),
 94 | 		"images": images,
 95 | 		"audio": audio,
 96 | 		"video": video,
 97 | 		"other": other
 98 | 	}
 99 | 

func classify(path: String) -> String:
	var ext := path.get_extension().to_lower()
	if ext in IMAGE_EXTENSIONS:
		return "image"
	if ext in AUDIO_EXTENSIONS:
		return "audio"
	if ext in VIDEO_EXTENSIONS:
		return "video"
	return "other"


static func encode_image(source: String, target: String, quality: float) -> PackedByteArray:
	var image := Image.new()
	if image.load(source) != OK or image.is_empty():
		return PackedByteArray()
	match target:
		"png":
			return image.save_png_to_buffer()
		"jpg":
			# blend_rect requires matching formats; WebP may decode as RGB8.
			image.convert(Image.FORMAT_RGBA8)
			var flattened := Image.create(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
			flattened.fill(Color.WHITE)
			flattened.blend_rect(image, Rect2i(0, 0, image.get_width(), image.get_height()), Vector2i.ZERO)
			flattened.convert(Image.FORMAT_RGB8)
			return flattened.save_jpg_to_buffer(quality)
		"webp":
			return image.save_webp_to_buffer(false, quality)
	return PackedByteArray()
