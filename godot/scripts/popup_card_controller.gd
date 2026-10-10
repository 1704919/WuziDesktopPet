extends Control

signal interactive_changed(enabled: bool)

@export var appear_offset_y := 3.0
@export var appear_scale := 0.985
@export var appear_duration := 0.07
@export var hide_duration := 0.05

var _base_position := Vector2.ZERO
var _active_tween: Tween
var _generation := 0


func _ready() -> void:
	_base_position = position
	hide()


func popup_card() -> void:
	_generation += 1

	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()

	show()
	modulate.a = 0.0
	scale = Vector2.ONE * appear_scale
	position = _base_position + Vector2(0.0, appear_offset_y)
	pivot_offset = size * Vector2(0.5, 0.72)
	interactive_changed.emit(true)

	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	_active_tween.set_trans(Tween.TRANS_BACK)
	_active_tween.set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(
		self,
		"scale",
		Vector2.ONE,
		appear_duration
	)
	_active_tween.tween_property(
		self,
		"position",
		_base_position,
		appear_duration - 0.015
	)
	_active_tween.tween_property(self, "modulate:a", 1.0, 0.045)


func hide_card(animated: bool = true) -> void:
	_generation += 1

	if not visible:
		interactive_changed.emit(false)
		return

	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()

	if not animated:
		hide()
		scale = Vector2.ONE
		modulate.a = 1.0
		position = _base_position
		interactive_changed.emit(false)
		return

	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	_active_tween.set_trans(Tween.TRANS_QUAD)
	_active_tween.set_ease(Tween.EASE_IN)
	_active_tween.tween_property(
		self,
		"scale",
		Vector2(0.985, 0.985),
		hide_duration
	)
	_active_tween.tween_property(
		self,
		"position",
		_base_position + Vector2(0.0, -2.0),
		hide_duration
	)
	_active_tween.tween_property(
		self,
		"modulate:a",
		0.0,
		hide_duration
	)
	await _active_tween.finished

	hide()
	scale = Vector2.ONE
	modulate.a = 1.0
	position = _base_position
	interactive_changed.emit(false)
