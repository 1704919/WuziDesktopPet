 1 | extends SceneTree
 2 | 
 3 | const Picker = preload("res://scripts/pet_idle_action_picker.gd")
 4 | const InactivityManager = preload("res://scripts/inactivity_manager.gd")
 5 | var failures: Array[String] = []
 6 | 
 7 | 
 8 | func check(value: bool, label: String) -> void:
 9 | 	if not value:
		failures.append(label)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var candidates: Array[Dictionary] = [
		{"id": "a", "weight": 1.0},
		{"id": "b", "weight": 3.0},
	]
	check(Picker.choose(candidates, 0.0) == "a", "weight_first_bucket_start")
	check(Picker.choose(candidates, 0.249) == "a", "weight_first_bucket_end")
	check(Picker.choose(candidates, 0.25) == "b", "weight_second_bucket_start")
	check(Picker.choose(candidates, 0.9999) == "b", "weight_second_bucket_end")

	# Previously the total was computed using the boosted weight but the
	# selection loop subtracted the original, causing an order-dependent bias.
	var inactive := InactivityManager.new()
	inactive.configure({"long_idle_minutes": 0.02, "sleepy_weight_multiplier": 4.0}, 1000)
	var boosted: Array[Dictionary] = [
		{"id": "sleepy_video", "weight": inactive.adjusted_idle_weight("sleepy_video", 1.0, 2200)},
		{"id": "a", "weight": inactive.adjusted_idle_weight("a", 1.0, 2200)},
	]
	check(float(boosted[0]["weight"]) == 4.0, "boosted_weight_is_four")
	check(Picker.choose(boosted, 0.79) == "sleepy_video", "boosted_80pct_bucket")
	check(Picker.choose(boosted, 0.80) == "a", "boosted_20pct_bucket")

	check(Picker.choose(candidates, 0.0, "a") == "b", "repeat_excluded_first")
	check(Picker.choose(candidates, 0.999, "b") == "a", "repeat_excluded_second")
	var only_one: Array[Dictionary] = [
		{"id": "a", "weight": 1.0},
		{"id": "invalid", "weight": 0.0},
	]
	check(Picker.choose(only_one, 0.42, "a") == "a", "single_action_remains_eligible")
	var invalid: Array[Dictionary] = [
		{"id": "", "weight": 12.0},
		{"id": "negative", "weight": -1.0},
		{"id": "zero", "weight": 0.0},
	]
	check(Picker.choose(invalid, 0.2).is_empty(), "invalid_candidates_not_selected")


	var categorized: Array[Dictionary] = [
		{"id": "noodles", "weight": 20.0, "category": "D"},
		{"id": "sushi", "weight": 20.0, "category": "D"},
		{"id": "sing", "weight": 1.0, "category": "C"},
	]
	check(Picker.choose(categorized, 0.0, "", "D") == "sing", "third_category_must_change")
	check(Picker.choose(categorized, 0.999, "sushi", "D") == "sing", "third_category_boundaries")
	check(Picker.choose(categorized, 0.1, "", "C") == "noodles", "unblocked_category_keeps_weights")
	var same_category: Array[Dictionary] = [
		{"id": "noodles", "weight": 1.0, "category": "D"},
		{"id": "sushi", "weight": 1.0, "category": "D"}
	]
	check(Picker.choose(same_category, 0.8, "noodles", "D").is_empty(), "all_blocked_skip_draw")
	check(Picker.choose(same_category, 0.8, "noodles") == "sushi", "second_same_category_allowed")

	if failures.is_empty():
		print("IDLE_ACTION_WEIGHT_SMOKE_OK")
		quit(0)
	else:
		for label in failures:
			push_error("idle_action_weight: " + label)
		quit(2)
