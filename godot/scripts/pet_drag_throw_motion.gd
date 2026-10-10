  1 | extends RefCounted
  2 | 
  3 | const PET_COLLISION_HALF_SIZE := Vector2(170.0, 175.0)
  4 | 
  5 | 
  6 | static func step_drag(
  7 | 	current_position: Vector2,
  8 | 	target_position: Vector2,
  9 | 	velocity: Vector2,
 10 | 	delta: float,
 11 | 	config: Dictionary
 12 | ) -> Dictionary:
 13 | 	var interaction := config.get("interaction", {}) as Dictionary
 14 | 	var spring := interaction.get("drag_spring", {}) as Dictionary
 15 | 	var stiffness := float(spring.get("stiffness", 95.0))
 16 | 	var damping := float(spring.get("damping", 15.5))
 17 | 	var max_speed := float(spring.get("max_speed", 3200.0))
 18 | 	var dt := minf(maxf(delta, 0.001), 0.033)
 19 | 
 20 | 	var displacement := target_position - current_position
 21 | 	var acceleration := displacement * stiffness - velocity * damping
 22 | 	var next_velocity := (velocity + acceleration * dt).limit_length(max_speed)
 23 | 	var next_position := current_position + next_velocity * dt
 24 | 	return {
 25 | 		"position": next_position,
 26 | 		"velocity": next_velocity
 27 | 	}
 28 | 
 29 | 
 30 | static func prepare_throw(drag_velocity: Vector2, config: Dictionary) -> Dictionary:
 31 | 	var interaction := config.get("interaction", {}) as Dictionary
 32 | 	var throw_cfg := interaction.get("throw", {}) as Dictionary
 33 | 
 34 | 	if bool(config.get("reduce_motion", false)) or not bool(throw_cfg.get("enabled", true)):
 35 | 		return {
 36 | 			"assign_velocity": false,
 37 | 			"should_throw": false,
 38 | 			"velocity": Vector2.ZERO
 39 | 		}
 40 | 
 41 | 	var multiplier := float(throw_cfg.get("velocity_multiplier", 0.82))
 42 | 	var min_speed := float(throw_cfg.get("min_speed", 145.0))
 43 | 	var velocity := drag_velocity * multiplier
 44 | 	return {
 45 | 		"assign_velocity": true,
 46 | 		"should_throw": velocity.length() >= min_speed,
 47 | 		"velocity": velocity
 48 | 	}
 49 | 
 50 | 
 51 | static func step_throw(
 52 | 	current_position: Vector2,
 53 | 	velocity: Vector2,
 54 | 	delta: float,
 55 | 	config: Dictionary,
 56 | 	usable: Rect2i,
 57 | 	base_position: Vector2
 58 | ) -> Dictionary:
 59 | 	var interaction := config.get("interaction", {}) as Dictionary
 60 | 	var throw_cfg := interaction.get("throw", {}) as Dictionary
 61 | 	if not bool(throw_cfg.get("enabled", true)):
 62 | 		return {
 63 | 			"enabled": false,
 64 | 			"position": current_position,
 65 | 			"velocity": velocity,
 66 | 			"settled": false
 67 | 		}
 68 | 
 69 | 	var gravity := float(throw_cfg.get("gravity", 680.0))
 70 | 	var max_fall_speed := float(throw_cfg.get("max_fall_speed", 760.0))
 71 | 	var bounce := float(throw_cfg.get("bounce", 0.48))
 72 | 	var friction := float(throw_cfg.get("friction", 0.88))
 73 | 	var stop_speed := float(throw_cfg.get("stop_speed", 55.0))
 74 | 	var dt := minf(maxf(delta, 0.001), 0.033)
 75 | 
 76 | 	var next_velocity := velocity
 77 | 	next_velocity.y = minf(next_velocity.y + gravity * dt, max_fall_speed)
 78 | 	var next_position := current_position + next_velocity * dt
 79 | 
 80 | 	var left := (
 81 | 		float(usable.position.x)
 82 | 		- (base_position.x - PET_COLLISION_HALF_SIZE.x)
 83 | 	)
 84 | 	var top := (
 85 | 		float(usable.position.y)
 86 | 		- (base_position.y - PET_COLLISION_HALF_SIZE.y)
 87 | 	)
 88 | 	var right := (
 89 | 		float(usable.position.x + usable.size.x)
 90 | 		- (base_position.x + PET_COLLISION_HALF_SIZE.x)
 91 | 	)
 92 | 	var bottom := (
 93 | 		float(usable.position.y + usable.size.y)
 94 | 		- (base_position.y + PET_COLLISION_HALF_SIZE.y)
 95 | 	)
 96 | 
 97 | 	if next_position.x < left:
 98 | 		next_position.x = left
 99 | 		next_velocity.x = absf(next_velocity.x) * bounce
	elif next_position.x > right:
		next_position.x = right
		next_velocity.x = -absf(next_velocity.x) * bounce

	if next_position.y < top:
		next_position.y = top
		next_velocity.y = absf(next_velocity.y) * bounce
	elif next_position.y > bottom:
		var impact_speed := absf(next_velocity.y)
		next_position.y = bottom
		next_velocity.y = -impact_speed * bounce
		next_velocity.x *= friction

		if impact_speed < stop_speed * 2.0 and absf(next_velocity.x) < stop_speed:
			next_velocity = Vector2.ZERO
			return {
				"enabled": true,
				"position": next_position,
				"velocity": next_velocity,
				"settled": true
			}

	return {
		"enabled": true,
		"position": next_position,
		"velocity": next_velocity,
		"settled": false
	}
