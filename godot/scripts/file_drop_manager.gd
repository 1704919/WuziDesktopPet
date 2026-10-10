extends Node

signal queue_changed(summary: Dictionary)

const IMAGE_EXTENSIONS := ["png", "jpg", "jpeg", "webp", "heic", "heif", "bmp", "tga"]
const AUDIO_EXTENSIONS := ["mp3", "wav", "flac", "ogg", "m4a", "aac", "opus"]
const VIDEO_EXTENSIONS := ["mp4", "mov", "mkv", "webm", "avi", "gif"]

var queued_files: PackedStringArray = []
var image_quality := 0.92
var output_suffix := "_converted"


func configure(spec: Dictionary) -> void:
	image_quality = clampf(float(spec.get("image_quality", 0.92)), 0.1, 1.0)
	output_suffix = str(spec.get("output_suffix", "_converted"))


func enqueue(paths: PackedStringArray) -> Dictionary:
	var known: Dictionary = {}
	for path in queued_files:
		known[path.replace("\\", "/").simplify_path().to_lower()] = true
	for path in paths:
		var key := path.replace("\\", "/").simplify_path().to_lower()
		if not known.has(key):
			queued_files.append(path)
			known[key] = true

	var summary := get_summary()
	queue_changed.emit(summary)
	return summary


func clear_queue() -> void:
	queued_files.clear()
	queue_changed.emit(get_summary())


func get_queued_files() -> PackedStringArray:
	return queued_files.duplicate()


func remove_paths(paths: PackedStringArray) -> void:
	if paths.is_empty():
		return
	var remove_lookup: Dictionary = {}
	for path in paths:
		remove_lookup[str(path)] = true
	var kept := PackedStringArray()
	for path in queued_files:
		if not remove_lookup.has(path):
			kept.append(path)
	queued_files = kept
	queue_changed.emit(get_summary())


func apply_execution_result(result: Dictionary) -> void:
	var successful := PackedStringArray()
	var recovery: Dictionary = {}
	for item: Dictionary in result.get("items", []):
		if item.status == "completed":
			successful.append(str(item.source))
		elif not str(item.get("recovery_path", "")).is_empty():
			recovery[str(item.source)] = str(item.recovery_path)
	var kept := PackedStringArray()
	for path in queued_files:
		if not successful.has(path):
			var remaining := str(recovery.get(path, path))
			if not kept.has(remaining):
				kept.append(remaining)
	queued_files = kept
	queue_changed.emit(get_summary())


func get_summary() -> Dictionary:
	var images := 0
	var audio := 0
	var video := 0
	var other := 0

	for path in queued_files:
		match classify(path):
			"image":
				images += 1
			"audio":
				audio += 1
			"video":
				video += 1
			_:
				other += 1

	return {
		"total": queued_files.size(),
		"images": images,
		"audio": audio,
		"video": video,
		"other": other
	}


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
