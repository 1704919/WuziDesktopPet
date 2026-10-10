extends RefCounted

const PET_COLLISION_HALF_SIZE := Vector2(170.0, 175.0)


static func step_drag(
	current_position: Vector2,
	target_position: Vector2,
	velocity: Vector2,
	delta: float,
	config: Dictionary
) -> Dictionary:
	var interaction := config.get("interaction", {}) as Dictionary
	var spring := interaction.get("drag_spring", {}) as Dictionary
	var stiffness := float(spring.get("stiffness", 95.0))
	var damping := float(spring.get("damping", 15.5))
	var max_speed := float(spring.get("max_speed", 3200.0))
	var dt := minf(maxf(delta, 0.001), 0.033)

	var displacement := target_position - current_position
	var acceleration := displacement * stiffness - velocity * damping
	var next_velocity := (velocity + acceleration * dt).limit_length(max_speed)
	var next_position := current_position + next_velocity * dt
	return {
		"position": next_position,
		"velocity": next_velocity
	}


static func prepare_throw(drag_velocity: Vector2, config: Dictionary) -> Dictionary:
	var interaction := config.get("interaction", {}) as Dictionary
	var throw_cfg := interaction.get("throw", {}) as Dictionary

	if bool(config.get("reduce_motion", false)) or not bool(throw_cfg.get("enabled", true)):
		return {
			"assign_velocity": false,
			"should_throw": false,
			"velocity": Vector2.ZERO
		}

	var multiplier := float(throw_cfg.get("velocity_multiplier", 0.82))
	var min_speed := float(throw_cfg.get("min_speed", 145.0))
	var velocity := drag_velocity * multiplier
	return {
		"assign_velocity": true,
		"should_throw": velocity.length() >= min_speed,
		"velocity": velocity
	}


static func step_throw(
	current_position: Vector2,
	velocity: Vector2,
	delta: float,
	config: Dictionary,
	usable: Rect2i,
	base_position: Vector2
) -> Dictionary:
	var interaction := config.get("interaction", {}) as Dictionary
	var throw_cfg := interaction.get("throw", {}) as Dictionary
	if not bool(throw_cfg.get("enabled", true)):
		return {
			"enabled": false,
			"position": current_position,
			"velocity": velocity,
			"settled": false
		}

	var gravity := float(throw_cfg.get("gravity", 680.0))
	var max_fall_speed := float(throw_cfg.get("max_fall_speed", 760.0))
	var bounce := float(throw_cfg.get("bounce", 0.48))
	var friction := float(throw_cfg.get("friction", 0.88))
	var stop_speed := float(throw_cfg.get("stop_speed", 55.0))
	var dt := minf(maxf(delta, 0.001), 0.033)

	var next_velocity := velocity
	next_velocity.y = minf(next_velocity.y + gravity * dt, max_fall_speed)
	var next_position := current_position + next_velocity * dt

	var left := (
		float(usable.position.x)
		- (base_position.x - PET_COLLISION_HALF_SIZE.x)
	)
	var top := (
		float(usable.position.y)
		- (base_position.y - PET_COLLISION_HALF_SIZE.y)
	)
	var right := (
		float(usable.position.x + usable.size.x)
		- (base_position.x + PET_COLLISION_HALF_SIZE.x)
	)
	var bottom := (
		float(usable.position.y + usable.size.y)
		- (base_position.y + PET_COLLISION_HALF_SIZE.y)
	)

	if next_position.x < left:
		next_position.x = left
		next_velocity.x = absf(next_velocity.x) * bounce
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
