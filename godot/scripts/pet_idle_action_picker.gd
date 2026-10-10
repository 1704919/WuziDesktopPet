extends RefCounted

# Stateless sampler: callers pass *effective* weights after inactivity and
# availability filters. The same weights must define both total and buckets.
# roll_fraction belongs to [0, 1), allowing deterministic boundary tests.
static func choose(
	candidates: Array[Dictionary],
	roll_fraction: float,
	previous_id: String = "",
	blocked_category: String = ""
) -> String:
	var valid: Array[Dictionary] = []
	for spec in candidates:
		var action_id := str(spec.get("id", ""))
		var weight := float(spec.get("weight", 0.0))
		if not action_id.is_empty() and is_finite(weight) and weight > 0.0:
			if blocked_category.is_empty() or str(spec.get("category", "")) != blocked_category:
				valid.append({"id": action_id, "weight": weight})
	if valid.is_empty():
		# Do not violate the two-in-a-row category limit when no alternate
		# category is available. Skip this draw instead.
		return ""

	# Prevent immediate repeats only when at least one *valid* other choice
	# exists; otherwise a single enabled action must remain playable.
	if valid.size() > 1 and not previous_id.is_empty():
		var alternatives: Array[Dictionary] = []
		for spec in valid:
			if str(spec["id"]) != previous_id:
				alternatives.append(spec)
		if not alternatives.is_empty():
			valid = alternatives

	var total := 0.0
	for spec in valid:
		total += float(spec["weight"])
	var remaining := clampf(roll_fraction, 0.0, 0.9999999) * total
	for spec in valid:
		remaining -= float(spec["weight"])
		if remaining < 0.0:
			return str(spec["id"])
	return str(valid.back()["id"])
