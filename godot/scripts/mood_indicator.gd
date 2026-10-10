extends Control

const BAR_SIZE := Vector2(12.0, 160.0)
const OUTER_RECT := Rect2(0.5, 0.5, 11.0, 159.0)
const CASING_RECT := Rect2(1.5, 1.5, 9.0, 157.0)
const INNER_BORDER_RECT := Rect2(2.5, 2.5, 7.0, 155.0)
const TRACK_RECT := Rect2(3.5, 3.5, 5.0, 153.0)

# Match the shared interaction-card palette in main.tscn.
const COLOR_SHADOW := Color(0.08, 0.06, 0.14, 0.26)
const COLOR_OUTER := Color(0.82, 0.79, 0.90, 0.90)
const COLOR_CASING := Color(0.98, 0.975, 0.995, 0.99)
const COLOR_INNER := Color(0.97, 0.96, 0.995, 1.0)
const COLOR_TRACK_BORDER := Color(0.82, 0.79, 0.90, 0.90)

# Sampled from the user's reference: warm coral -> muted mauve -> soft blue.
const COLOR_WARM := Color("#DE7A6B")
const COLOR_MID := Color("#B49AA2")
const COLOR_COOL := Color("#90B0C7")

const COLOR_MARKER_RING := Color("#F7F5EA")

var mood := "normal"
var hover_polygon := PackedVector2Array()
var score := 0.0
var min_score := -100.0
var max_score := 100.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = BAR_SIZE
	set_process(true)
	queue_redraw()


func configure(raw: Dictionary) -> void:
	min_score = float(raw.get("min_score", -100.0))
	max_score = float(raw.get("max_score", 100.0))
	if min_score >= max_score:
		min_score = -100.0
		max_score = 100.0
	queue_redraw()


func set_mood(next_mood: String, next_score: float) -> void:
	mood = next_mood
	score = clampf(next_score, min_score, max_score)
	queue_redraw()


func set_hover_polygon(polygon: PackedVector2Array) -> void:
	hover_polygon = polygon


func should_show_for_point(point: Vector2) -> bool:
	return (
		hover_polygon.size() >= 3
		and Geometry2D.is_point_in_polygon(point, hover_polygon)
	)


func get_score_marker_y() -> float:
	var normalized := clampf(
		(score - min_score) / maxf(0.001, max_score - min_score),
		0.0,
		1.0
	)
	var cap_radius := TRACK_RECT.size.x * 0.5
	var travel := TRACK_RECT.size.y - cap_radius * 2.0
	return (
		TRACK_RECT.position.y
		+ cap_radius
		+ (1.0 - normalized) * travel
	)


func _process(_delta: float) -> void:
	var mouse := get_viewport().get_mouse_position()
	var should_show := should_show_for_point(mouse)
	if visible != should_show:
		visible = should_show
		if visible:
			queue_redraw()


func _draw() -> void:
	_draw_capsule(
		Rect2(OUTER_RECT.position + Vector2(1.0, 2.0), OUTER_RECT.size),
		COLOR_SHADOW
	)
	_draw_capsule(OUTER_RECT, COLOR_OUTER)
	_draw_capsule(CASING_RECT, COLOR_CASING)
	_draw_capsule(INNER_BORDER_RECT, COLOR_TRACK_BORDER)
	_draw_capsule(
		Rect2(
			INNER_BORDER_RECT.position + Vector2.ONE,
			INNER_BORDER_RECT.size - Vector2(2.0, 2.0)
		),
		COLOR_INNER
	)
	_draw_gradient_capsule(TRACK_RECT)
	_draw_score_marker()


func _draw_capsule(rect: Rect2, color: Color) -> void:
	var radius := minf(rect.size.x, rect.size.y) * 0.5
	if rect.size.y >= rect.size.x:
		var center_x := rect.position.x + rect.size.x * 0.5
		draw_rect(
			Rect2(
				Vector2(rect.position.x, rect.position.y + radius),
				Vector2(rect.size.x, maxf(0.0, rect.size.y - radius * 2.0))
			),
			color,
			true
		)
		draw_circle(Vector2(center_x, rect.position.y + radius), radius, color)
		draw_circle(Vector2(center_x, rect.end.y - radius), radius, color)
		return

	var center_y := rect.position.y + rect.size.y * 0.5
	draw_rect(
		Rect2(
			Vector2(rect.position.x + radius, rect.position.y),
			Vector2(maxf(0.0, rect.size.x - radius * 2.0), rect.size.y)
		),
		color,
		true
	)
	draw_circle(Vector2(rect.position.x + radius, center_y), radius, color)
	draw_circle(Vector2(rect.end.x - radius, center_y), radius, color)


func _draw_gradient_capsule(rect: Rect2) -> void:
	var radius := rect.size.x * 0.5
	var center_x := rect.position.x + radius
	var rows := maxi(1, ceili(rect.size.y))
	for row in range(rows):
		var local_y := clampf(float(row) + 0.5, 0.5, rect.size.y - 0.5)
		var half_width := radius
		if local_y < radius:
			var dy_top := radius - local_y
			half_width = sqrt(maxf(0.0, radius * radius - dy_top * dy_top))
		elif local_y > rect.size.y - radius:
			var dy_bottom := local_y - (rect.size.y - radius)
			half_width = sqrt(maxf(0.0, radius * radius - dy_bottom * dy_bottom))

		var t := clampf(local_y / rect.size.y, 0.0, 1.0)
		var row_color := _gradient_color(t)
		var y := rect.position.y + local_y
		draw_line(
			Vector2(center_x - half_width, y),
			Vector2(center_x + half_width, y),
			row_color,
			1.2,
			true
		)


func _gradient_color(t: float) -> Color:
	if t <= 0.5:
		return COLOR_WARM.lerp(COLOR_MID, t * 2.0)
	return COLOR_MID.lerp(COLOR_COOL, (t - 0.5) * 2.0)


func _draw_score_marker() -> void:
	var center := Vector2(BAR_SIZE.x * 0.5, get_score_marker_y())
	draw_circle(center + Vector2(0.0, 0.8), 3.6, Color(0.15, 0.14, 0.12, 0.20))
	draw_circle(center, 3.0, COLOR_MARKER_RING)
	draw_circle(center, 1.75, _mood_color())


func _mood_color() -> Color:
	match mood:
		"happy":
			return Color("#E5A36F")
		"shy":
			return Color("#D98FAE")
		"angry":
			return Color("#D96E66")
		"sleepy":
			return Color("#86AFCB")
		_:
			return Color("#B49AA2")
