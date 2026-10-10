extends SceneTree

const RoamingController = preload("res://scripts/pet_roaming_controller.gd")


func _init() -> void:
	var failures: Array[String] = []
	var controller := RoamingController.new()
	var config := {
		"enabled": true,
		"speed_px_sec": 100.0,
		"pause_interval_sec": [0.0, 0.0],
		"edge_margin_px": 20
	}
	var catalog := {
		"ready": true,
		"clips": {
			"walk_left": {
				"duration_sec": 10.0,
				"direction": -1,
				"motion": {
					"start_sec": 1.5,
					"decelerate_sec": 7.0,
					"stop_sec": 8.0
				}
			},
			"walk_right": {
				"duration_sec": 10.0,
				"direction": 1,
				"motion": {
					"start_sec": 1.5,
					"decelerate_sec": 7.0,
					"stop_sec": 8.0
				}
			}
		}
	}
	var usable := Rect2i(0, 0, 1000, 800)
	var anchor := Vector2(100.0, 200.0)

	controller.configure(config, catalog, true)
	if not controller.is_available() or not controller.is_enabled():
		failures.append("configured_roaming_should_be_available_and_enabled")

	var near_right := Vector2i(850, 100)
	var action_id := controller.request_if_due(
		0.1,
		true,
		near_right,
		anchor,
		usable
	)
	if action_id != "walk_left":
		failures.append("near_right_edge_should_choose_left")
	if not controller.mark_started(action_id):
		failures.append("walk_left_should_start")

	var turning := controller.step_active(1.0, near_right, anchor, usable)
	if turning.get("position", near_right) != near_right:
		failures.append("turning_phase_should_not_move_window")

	controller.step_active(1.1, near_right, anchor, usable)
	var walking := controller.step_active(1.0, near_right, anchor, usable)
	var walking_position := walking.get("position", near_right) as Vector2i
	if walking_position.x >= near_right.x:
		failures.append("left_walk_phase_should_move_window_left")

	var high_refresh_controller := RoamingController.new()
	var high_refresh_config := config.duplicate(true)
	high_refresh_config["speed_px_sec"] = 56.0
	high_refresh_controller.configure(high_refresh_config, catalog, true)
	if not high_refresh_controller.mark_started("walk_left"):
		failures.append("high_refresh_walk_left_should_start")
	var high_refresh_start := Vector2i(500, 100)
	var high_refresh_position := high_refresh_start
	var turning_synced := high_refresh_controller.step_active(
		1.0 / 144.0,
		high_refresh_position,
		anchor,
		usable,
		1.4
	)
	high_refresh_position = turning_synced.get(
		"position",
		high_refresh_position
	) as Vector2i
	if high_refresh_position != high_refresh_start:
		failures.append("synced_turning_phase_should_not_move_window")

	for frame in range(1, 145):
		var animation_time := 1.5 + float(frame) / 144.0
		var step := high_refresh_controller.step_active(
			1.0 / 144.0,
			high_refresh_position,
			anchor,
			usable,
			animation_time
		)
		high_refresh_position = step.get(
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
