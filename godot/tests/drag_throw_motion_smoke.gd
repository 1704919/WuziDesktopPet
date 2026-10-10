extends SceneTree

const DragThrowMotion = preload("res://scripts/pet_drag_throw_motion.gd")


func _init() -> void:
	var failures: Array[String] = []
	var config := {
		"interaction": {
			"drag_spring": {
				"stiffness": 100.0,
				"damping": 0.0,
				"max_speed": 10000.0
			},
			"throw": {
				"enabled": true,
				"velocity_multiplier": 0.5,
				"min_speed": 100.0,
				"gravity": 100.0,
				"max_fall_speed": 500.0,
				"bounce": 0.5,
				"friction": 0.8,
				"stop_speed": 55.0
			}
		}
	}

	var drag := DragThrowMotion.step_drag(
		Vector2.ZERO,
		Vector2(100.0, 0.0),
		Vector2.ZERO,
		0.01,
		config
	)
	_expect_vector(failures, "drag_velocity", drag.velocity, Vector2(100.0, 0.0))
	_expect_vector(failures, "drag_position", drag.position, Vector2(1.0, 0.0))

	var below := DragThrowMotion.prepare_throw(Vector2(100.0, 0.0), config)
	if not bool(below.assign_velocity):
		failures.append("below_threshold_should_assign_velocity")
	if bool(below.should_throw):
		failures.append("below_threshold_should_not_throw")
	_expect_vector(failures, "below_threshold_velocity", below.velocity, Vector2(50.0, 0.0))

	var above := DragThrowMotion.prepare_throw(Vector2(300.0, 0.0), config)
	if not bool(above.assign_velocity) or not bool(above.should_throw):
		failures.append("above_threshold_should_throw")
	_expect_vector(failures, "above_threshold_velocity", above.velocity, Vector2(150.0, 0.0))

	var reduce_motion := config.duplicate(true)
	reduce_motion["reduce_motion"] = true
	var reduced := DragThrowMotion.prepare_throw(Vector2(300.0, 0.0), reduce_motion)
	if bool(reduced.assign_velocity) or bool(reduced.should_throw):
		failures.append("reduce_motion_should_not_assign_or_throw")

	var usable := Rect2i(0, 0, 1000, 1000)
	var base_position := Vector2(550.0, 210.0)
	var free_step := DragThrowMotion.step_throw(
		Vector2(100.0, 100.0),
		Vector2(10.0, 0.0),
		0.01,
		config,
		usable,
		base_position
	)
	if not bool(free_step.enabled) or bool(free_step.settled):
		failures.append("free_throw_wrong_state")
	_expect_vector(failures, "free_throw_velocity", free_step.velocity, Vector2(10.0, 1.0))
	_expect_vector(failures, "free_throw_position", free_step.position, Vector2(100.1, 100.01))

	var side_bounce := DragThrowMotion.step_throw(
		Vector2(-500.0, 100.0),
		Vector2(-100.0, 0.0),
		0.01,
		config,
		usable,
		base_position
	)
	_expect_vector(failures, "side_bounce_velocity", side_bounce.velocity, Vector2(50.0, 1.0))
	_expect_vector(failures, "side_bounce_position", side_bounce.position, Vector2(-380.0, 100.01))

	var settle := DragThrowMotion.step_throw(
		Vector2(100.0, 700.0),
		Vector2(10.0, 20.0),
		0.01,
		config,
		usable,
		base_position
	)
	if not bool(settle.settled):
		failures.append("bottom_impact_should_settle")
	_expect_vector(failures, "settled_velocity", settle.velocity, Vector2.ZERO)
	_expect_vector(failures, "settled_position", settle.position, Vector2(100.1, 615.0))

	var disabled_config := config.duplicate(true)
	disabled_config["interaction"]["throw"]["enabled"] = false
	var disabled := DragThrowMotion.step_throw(
		Vector2(12.0, 34.0),
		Vector2(56.0, 78.0),
		0.01,
		disabled_config,
		usable,
		base_position
	)
	if bool(disabled.enabled):
		failures.append("disabled_throw_should_report_disabled")
	_expect_vector(failures, "disabled_position", disabled.position, Vector2(12.0, 34.0))
	_expect_vector(failures, "disabled_velocity", disabled.velocity, Vector2(56.0, 78.0))

	if failures.is_empty():
		print("DRAG_THROW_MOTION_SMOKE_OK")
		quit(0)
	else:
		push_error("DRAG_THROW_MOTION_SMOKE_FAILED: %s" % ", ".join(failures))
		quit(2)


func _expect_vector(
	failures: Array[String],
	label: String,
	actual: Vector2,
	expected: Vector2
) -> void:
	if actual.distance_to(expected) > 0.001:
		failures.append("%s:%s!=%s" % [label, actual, expected])
