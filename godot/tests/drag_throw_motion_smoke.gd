  1 | extends SceneTree
  2 | 
  3 | const DragThrowMotion = preload("res://scripts/pet_drag_throw_motion.gd")
  4 | 
  5 | 
  6 | func _init() -> void:
  7 | 	var failures: Array[String] = []
  8 | 	var config := {
  9 | 		"interaction": {
 10 | 			"drag_spring": {
 11 | 				"stiffness": 100.0,
 12 | 				"damping": 0.0,
 13 | 				"max_speed": 10000.0
 14 | 			},
 15 | 			"throw": {
 16 | 				"enabled": true,
 17 | 				"velocity_multiplier": 0.5,
 18 | 				"min_speed": 100.0,
 19 | 				"gravity": 100.0,
 20 | 				"max_fall_speed": 500.0,
 21 | 				"bounce": 0.5,
 22 | 				"friction": 0.8,
 23 | 				"stop_speed": 55.0
 24 | 			}
 25 | 		}
 26 | 	}
 27 | 
 28 | 	var drag := DragThrowMotion.step_drag(
 29 | 		Vector2.ZERO,
 30 | 		Vector2(100.0, 0.0),
 31 | 		Vector2.ZERO,
 32 | 		0.01,
 33 | 		config
 34 | 	)
 35 | 	_expect_vector(failures, "drag_velocity", drag.velocity, Vector2(100.0, 0.0))
 36 | 	_expect_vector(failures, "drag_position", drag.position, Vector2(1.0, 0.0))
 37 | 
 38 | 	var below := DragThrowMotion.prepare_throw(Vector2(100.0, 0.0), config)
 39 | 	if not bool(below.assign_velocity):
 40 | 		failures.append("below_threshold_should_assign_velocity")
 41 | 	if bool(below.should_throw):
 42 | 		failures.append("below_threshold_should_not_throw")
 43 | 	_expect_vector(failures, "below_threshold_velocity", below.velocity, Vector2(50.0, 0.0))
 44 | 
 45 | 	var above := DragThrowMotion.prepare_throw(Vector2(300.0, 0.0), config)
 46 | 	if not bool(above.assign_velocity) or not bool(above.should_throw):
 47 | 		failures.append("above_threshold_should_throw")
 48 | 	_expect_vector(failures, "above_threshold_velocity", above.velocity, Vector2(150.0, 0.0))
 49 | 
 50 | 	var reduce_motion := config.duplicate(true)
 51 | 	reduce_motion["reduce_motion"] = true
 52 | 	var reduced := DragThrowMotion.prepare_throw(Vector2(300.0, 0.0), reduce_motion)
 53 | 	if bool(reduced.assign_velocity) or bool(reduced.should_throw):
 54 | 		failures.append("reduce_motion_should_not_assign_or_throw")
 55 | 
 56 | 	var usable := Rect2i(0, 0, 1000, 1000)
 57 | 	var base_position := Vector2(550.0, 210.0)
 58 | 	var free_step := DragThrowMotion.step_throw(
 59 | 		Vector2(100.0, 100.0),
 60 | 		Vector2(10.0, 0.0),
 61 | 		0.01,
 62 | 		config,
 63 | 		usable,
 64 | 		base_position
 65 | 	)
 66 | 	if not bool(free_step.enabled) or bool(free_step.settled):
 67 | 		failures.append("free_throw_wrong_state")
 68 | 	_expect_vector(failures, "free_throw_velocity", free_step.velocity, Vector2(10.0, 1.0))
 69 | 	_expect_vector(failures, "free_throw_position", free_step.position, Vector2(100.1, 100.01))
 70 | 
 71 | 	var side_bounce := DragThrowMotion.step_throw(
 72 | 		Vector2(-500.0, 100.0),
 73 | 		Vector2(-100.0, 0.0),
 74 | 		0.01,
 75 | 		config,
 76 | 		usable,
 77 | 		base_position
 78 | 	)
 79 | 	_expect_vector(failures, "side_bounce_velocity", side_bounce.velocity, Vector2(50.0, 1.0))
 80 | 	_expect_vector(failures, "side_bounce_position", side_bounce.position, Vector2(-380.0, 100.01))
 81 | 
 82 | 	var settle := DragThrowMotion.step_throw(
 83 | 		Vector2(100.0, 700.0),
 84 | 		Vector2(10.0, 20.0),
 85 | 		0.01,
 86 | 		config,
 87 | 		usable,
 88 | 		base_position
 89 | 	)
 90 | 	if not bool(settle.settled):
 91 | 		failures.append("bottom_impact_should_settle")
 92 | 	_expect_vector(failures, "settled_velocity", settle.velocity, Vector2.ZERO)
 93 | 	_expect_vector(failures, "settled_position", settle.position, Vector2(100.1, 615.0))
 94 | 
 95 | 	var disabled_config := config.duplicate(true)
 96 | 	disabled_config["interaction"]["throw"]["enabled"] = false
 97 | 	var disabled := DragThrowMotion.step_throw(
 98 | 		Vector2(12.0, 34.0),
 99 | 		Vector2(56.0, 78.0),
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
