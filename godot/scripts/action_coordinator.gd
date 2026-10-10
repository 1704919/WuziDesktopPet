  1 | extends Node
  2 | 
  3 | var registry: Node = null
  4 | var duplicate_merge_ms := 300
  5 | 
  6 | var current_action_id := ""
  7 | var current_requested_id := ""
  8 | var current_source := ""
  9 | var current_priority := -1
 10 | var current_started_ms := 0
 11 | var current_expires_at_ms := 0
 12 | var last_request_ms := -1
 13 | 
 14 | 
 15 | func configure(action_registry: Node, raw: Dictionary = {}) -> void:
 16 | 	registry = action_registry
 17 | 	duplicate_merge_ms = maxi(0, int(raw.get("duplicate_merge_ms", 300)))
 18 | 	cancel("configure")
 19 | 
 20 | 
 21 | func request_action(
 22 | 	action_id: String,
 23 | 	source: String,
 24 | 	priority: int,
 25 | 	now_ms: int = -1,
 26 | 	ttl_ms: int = 15000
 27 | ) -> Dictionary:
 28 | 	var now := Time.get_ticks_msec() if now_ms < 0 else now_ms
 29 | 	if action_id.is_empty() or not is_instance_valid(registry):
 30 | 		return _rejected("invalid_request", action_id)
 31 | 
 32 | 	if not bool(registry.call("is_action_ready", action_id)):
 33 | 		return _rejected("not_ready", action_id)
 34 | 
 35 | 	var runtime_id := str(registry.call("resolve_action_id", action_id))
 36 | 	if runtime_id.is_empty():
 37 | 		return _rejected("unresolved", action_id)
 38 | 	if not bool(registry.call("is_action_ready", runtime_id)):
 39 | 		return _rejected("runtime_not_ready", action_id)
 40 | 
 41 | 	_expire_if_needed(now)
 42 | 
 43 | 	if (
 44 | 		not current_action_id.is_empty()
 45 | 		and runtime_id == current_action_id
 46 | 		and last_request_ms >= 0
 47 | 		and now - last_request_ms <= duplicate_merge_ms
 48 | 	):
 49 | 		return _rejected("duplicate", action_id)
 50 | 
 51 | 	if not current_action_id.is_empty() and priority < current_priority:
 52 | 		return _rejected("blocked_by_priority", action_id)
 53 | 
 54 | 	var previous_id := current_action_id
 55 | 	current_requested_id = action_id
 56 | 	current_action_id = runtime_id
 57 | 	current_source = source
 58 | 	current_priority = priority
 59 | 	current_started_ms = now
 60 | 	current_expires_at_ms = now + ttl_ms if ttl_ms > 0 else 0
 61 | 	last_request_ms = now
 62 | 
 63 | 	return {
 64 | 		"accepted": true,
 65 | 		"reason": "",
 66 | 		"requested_id": action_id,
 67 | 		"action_id": runtime_id,
 68 | 		"source": source,
 69 | 		"priority": priority,
 70 | 		"preempted": not previous_id.is_empty() and previous_id != runtime_id,
 71 | 		"previous_action_id": previous_id
 72 | 	}
 73 | 
 74 | 
 75 | func mark_finished(action_id: String) -> void:
 76 | 	if action_id == current_action_id:
 77 | 		_clear_current()
 78 | 
 79 | 
 80 | func cancel(_reason: String = "") -> void:
 81 | 	_clear_current()
 82 | 
 83 | 
 84 | func is_busy() -> bool:
 85 | 	return not current_action_id.is_empty()
 86 | 
 87 | 
 88 | func get_snapshot() -> Dictionary:
 89 | 	return {
 90 | 		"action_id": current_action_id,
 91 | 		"requested_id": current_requested_id,
 92 | 		"source": current_source,
 93 | 		"priority": current_priority,
 94 | 		"started_ms": current_started_ms,
 95 | 		"expires_at_ms": current_expires_at_ms
 96 | 	}
 97 | 
 98 | 
 99 | func _expire_if_needed(now_ms: int) -> void:
	if current_expires_at_ms > 0 and now_ms >= current_expires_at_ms:
		_clear_current()


func _clear_current() -> void:
	current_action_id = ""
	current_requested_id = ""
	current_source = ""
	current_priority = -1
	current_started_ms = 0
	current_expires_at_ms = 0


func _rejected(reason: String, requested_id: String) -> Dictionary:
	return {
		"accepted": false,
		"reason": reason,
		"requested_id": requested_id,
		"action_id": "",
		"source": "",
		"priority": -1,
		"preempted": false,
		"previous_action_id": current_action_id
	}
