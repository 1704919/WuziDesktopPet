extends Node

var registry: Node = null
var duplicate_merge_ms := 300

var current_action_id := ""
var current_requested_id := ""
var current_source := ""
var current_priority := -1
var current_started_ms := 0
var current_expires_at_ms := 0
var last_request_ms := -1


func configure(action_registry: Node, raw: Dictionary = {}) -> void:
	registry = action_registry
	duplicate_merge_ms = maxi(0, int(raw.get("duplicate_merge_ms", 300)))
	cancel("configure")


func request_action(
	action_id: String,
	source: String,
	priority: int,
	now_ms: int = -1,
	ttl_ms: int = 15000
) -> Dictionary:
	var now := Time.get_ticks_msec() if now_ms < 0 else now_ms
	if action_id.is_empty() or not is_instance_valid(registry):
		return _rejected("invalid_request", action_id)

	if not bool(registry.call("is_action_ready", action_id)):
		return _rejected("not_ready", action_id)

	var runtime_id := str(registry.call("resolve_action_id", action_id))
	if runtime_id.is_empty():
		return _rejected("unresolved", action_id)
	if not bool(registry.call("is_action_ready", runtime_id)):
		return _rejected("runtime_not_ready", action_id)

	_expire_if_needed(now)

	if (
		not current_action_id.is_empty()
		and runtime_id == current_action_id
		and last_request_ms >= 0
		and now - last_request_ms <= duplicate_merge_ms
	):
		return _rejected("duplicate", action_id)

	if not current_action_id.is_empty() and priority < current_priority:
		return _rejected("blocked_by_priority", action_id)

	var previous_id := current_action_id
	current_requested_id = action_id
	current_action_id = runtime_id
	current_source = source
	current_priority = priority
	current_started_ms = now
	current_expires_at_ms = now + ttl_ms if ttl_ms > 0 else 0
	last_request_ms = now

	return {
		"accepted": true,
		"reason": "",
		"requested_id": action_id,
		"action_id": runtime_id,
		"source": source,
		"priority": priority,
		"preempted": not previous_id.is_empty() and previous_id != runtime_id,
		"previous_action_id": previous_id
	}


func mark_finished(action_id: String) -> void:
	if action_id == current_action_id:
		_clear_current()


func cancel(_reason: String = "") -> void:
	_clear_current()


func is_busy() -> bool:
	return not current_action_id.is_empty()


func get_snapshot() -> Dictionary:
	return {
		"action_id": current_action_id,
		"requested_id": current_requested_id,
		"source": current_source,
		"priority": current_priority,
		"started_ms": current_started_ms,
		"expires_at_ms": current_expires_at_ms
	}


func _expire_if_needed(now_ms: int) -> void:
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
