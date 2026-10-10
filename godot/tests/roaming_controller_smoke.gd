  1 | extends SceneTree
  2 | 
  3 | const RoamingController = preload("res://scripts/pet_roaming_controller.gd")
  4 | 
  5 | 
  6 | func _init() -> void:
  7 | 	var failures: Array[String] = []
  8 | 	var controller := RoamingController.new()
  9 | 	var config := {
 10 | 		"enabled": true,
 11 | 		"speed_px_sec": 100.0,
 12 | 		"pause_interval_sec": [0.0, 0.0],
 13 | 		"edge_margin_px": 20
 14 | 	}
 15 | 	var catalog := {
 16 | 		"ready": true,
 17 | 		"clips": {
 18 | 			"walk_left": {
 19 | 				"duration_sec": 10.0,
 20 | 				"direction": -1,
 21 | 				"motion": {
 22 | 					"start_sec": 1.5,
 23 | 					"decelerate_sec": 7.0,
 24 | 					"stop_sec": 8.0
 25 | 				}
 26 | 			},
 27 | 			"walk_right": {
 28 | 				"duration_sec": 10.0,
 29 | 				"direction": 1,
 30 | 				"motion": {
 31 | 					"start_sec": 1.5,
 32 | 					"decelerate_sec": 7.0,
 33 | 					"stop_sec": 8.0
 34 | 				}
 35 | 			}
 36 | 		}
 37 | 	}
 38 | 	var usable := Rect2i(0, 0, 1000, 800)
 39 | 	var anchor := Vector2(100.0, 200.0)
 40 | 
 41 | 	controller.configure(config, catalog, true)
 42 | 	if not controller.is_available() or not controller.is_enabled():
 43 | 		failures.append("configured_roaming_should_be_available_and_enabled")
 44 | 
 45 | 	var near_right := Vector2i(850, 100)
 46 | 	var action_id := controller.request_if_due(
 47 | 		0.1,
 48 | 		true,
 49 | 		near_right,
 50 | 		anchor,
 51 | 		usable
 52 | 	)
 53 | 	if action_id != "walk_left":
 54 | 		failures.append("near_right_edge_should_choose_left")
 55 | 	if not controller.mark_started(action_id):
 56 | 		failures.append("walk_left_should_start")
 57 | 
 58 | 	var turning := controller.step_active(1.0, near_right, anchor, usable)
 59 | 	if turning.get("position", near_right) != near_right:
 60 | 		failures.append("turning_phase_should_not_move_window")
 61 | 
 62 | 	controller.step_active(1.1, near_right, anchor, usable)
 63 | 	var walking := controller.step_active(1.0, near_right, anchor, usable)
 64 | 	var walking_position := walking.get("position", near_right) as Vector2i
 65 | 	if walking_position.x >= near_right.x:
 66 | 		failures.append("left_walk_phase_should_move_window_left")
 67 | 
 68 | 	var high_refresh_controller := RoamingController.new()
 69 | 	var high_refresh_config := config.duplicate(true)
 70 | 	high_refresh_config["speed_px_sec"] = 56.0
 71 | 	high_refresh_controller.configure(high_refresh_config, catalog, true)
 72 | 	if not high_refresh_controller.mark_started("walk_left"):
 73 | 		failures.append("high_refresh_walk_left_should_start")
 74 | 	var high_refresh_start := Vector2i(500, 100)
 75 | 	var high_refresh_position := high_refresh_start
 76 | 	var turning_synced := high_refresh_controller.step_active(
 77 | 		1.0 / 144.0,
 78 | 		high_refresh_position,
 79 | 		anchor,
 80 | 		usable,
 81 | 		1.4
 82 | 	)
 83 | 	high_refresh_position = turning_synced.get(
 84 | 		"position",
 85 | 		high_refresh_position
 86 | 	) as Vector2i
 87 | 	if high_refresh_position != high_refresh_start:
 88 | 		failures.append("synced_turning_phase_should_not_move_window")
 89 | 
 90 | 	for frame in range(1, 145):
 91 | 		var animation_time := 1.5 + float(frame) / 144.0
 92 | 		var step := high_refresh_controller.step_active(
 93 | 			1.0 / 144.0,
 94 | 			high_refresh_position,
 95 | 			anchor,
 96 | 			usable,
 97 | 			animation_time
 98 | 		)
 99 | 		high_refresh_position = step.get(
			"position",
			high_refresh_position
		) as Vector2i
	if high_refresh_position.x > high_refresh_start.x - 50:
		failures.append("high_refresh_subpixel_motion_should_accumulate")

	var stalled_position := high_refresh_position
	for _frame in range(12):
		var stalled_step := high_refresh_controller.step_active(
			1.0 / 144.0,
			high_refresh_position,
			anchor,
			usable,
			2.5
		)
		high_refresh_position = stalled_step.get(
			"position",
			high_refresh_position
		) as Vector2i
	if high_refresh_position != stalled_position:
		failures.append("stalled_animation_should_not_move_window")

	var move_to_stop := high_refresh_controller.step_active(
		0.1,
		high_refresh_position,
		anchor,
		usable,
		8.0
	)
	high_refresh_position = move_to_stop.get(
		"position",
		high_refresh_position
	) as Vector2i
	var stopped_position := high_refresh_position
	var finishing := high_refresh_controller.step_active(
		0.1,
		high_refresh_position,
		anchor,
		usable,
		9.0
	)
	high_refresh_position = finishing.get(
		"position",
		high_refresh_position
	) as Vector2i
	if high_refresh_position != stopped_position:
		failures.append("turn_back_phase_should_not_move_window")

	controller.cancel(false)
	var near_left := Vector2i(-70, 100)
	action_id = controller.request_if_due(
		0.1,
		true,
		near_left,
		anchor,
		usable
	)
	if action_id != "walk_right":
		failures.append("near_left_edge_should_choose_right")

	controller.set_enabled(false)
	if controller.is_enabled() or controller.is_active():
		failures.append("disabled_roaming_should_be_inactive")

	if failures.is_empty():
		print("ROAMING_CONTROLLER_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(2)
