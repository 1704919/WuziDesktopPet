extends Node

# Polls one Bilibili live room and asks the user to confirm when it goes live.
#
# A reminder is never marked as delivered by the program: it repeats on every
# poll until the user presses the confirm button or the broadcast ends. Only the
# user's answer is written to disk (confirmed_key).
#
# One room is polled at a time, and only the answer to the request that was
# started last is applied, see _drop_in_flight: a room switch in the middle of a
# request must not let the room that was left behind publish its status.
#
# API contract measured on 2026-10-11 against the live endpoint; the field
# expectations are pinned by godot/tests/stream_status_smoke.gd.
#   GET https://api.live.bilibili.com/room/v1/Room/get_info?room_id=<id>
#   A User-Agent header is required; without any header the endpoint answers
#   HTTP 412. /xlive/web-room/v1/index/getInfoByRoom currently answers with
#   code -352 (risk control), so it is deliberately not used here.
#
# Long-term risk: the platform tightens endpoint protection over time, so if
# this stops working the first thing to re-check is the endpoint contract above.

signal stream_updated(status: Dictionary, manual: bool)
# repeated is false for the first ask of a broadcast and true for the ones that
# follow it while the user has not answered yet, so the caller can keep the
# repeat quiet without having to know the reminder rules itself.
signal reminder_due(text: String, repeated: bool)
signal request_failed(message: String)

const StreamStatus = preload("res://scripts/stream_status.gd")
const StreamReplyFormatter = preload("res://scripts/stream_reply_formatter.gd")

const ENDPOINT := "https://api.live.bilibili.com/room/v1/Room/get_info?room_id="
const USER_AGENT := (
	"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
	+ "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
)
const DEFAULT_INTERVAL_SEC := 120.0
const MIN_INTERVAL_SEC := 60.0
# While a reminder is waiting for an answer the poll (which is also the ask)
# runs at this cadence instead of the regular interval.
const DEFAULT_RETRY_INTERVAL_SEC := 30.0
const MIN_RETRY_INTERVAL_SEC := 10.0
const MAX_BACKOFF_MULTIPLIER := 4.0
const REQUEST_TIMEOUT_SEC := 15.0
# How soon to try again when a request could not even be started because the
# previous one is still finishing, see _process.
const BUSY_RETRY_SEC := 2.0

var room_query := ""          # what the user typed; may be a short id
var resolved_room_id := ""    # canonical id from the API, cached after success
var label := ""
var enabled := false

var check_interval_sec := DEFAULT_INTERVAL_SEC
# Cadence used while a reminder is unanswered, see _effective_interval.
var retry_interval_sec := DEFAULT_RETRY_INTERVAL_SEC
var check_countdown_sec := 0.0
var consecutive_failures := 0
# The broadcast the user confirmed, so it stops asking. Persisted: a confirmed
# broadcast stays confirmed across a restart.
var confirmed_key := ""
# The broadcast currently waiting for an answer. In memory only: after a restart
# an unanswered reminder is supposed to come back.
var reminder_key := ""
# True while a request started by the user is still on its way, so its result
# is reported even though automatic polls stay silent.
var manual_check_pending := false
# Switching rooms, or switching the reminder off, makes whatever a request that
# is already on its way was going to say obsolete. intent_token is bumped by
# every such change and request_token records the value a request left with, so
# a late answer for a room the user has already left can neither overwrite
# resolved_room_id -- which would pin the following polls, and the reminder, to
# the old room -- nor raise a reminder that has just been switched off.
var intent_token := 0
var request_token := -1

var status_request: HTTPRequest


func _ready() -> void:
	status_request = HTTPRequest.new()
	status_request.timeout = REQUEST_TIMEOUT_SEC
	add_child(status_request)
	status_request.request_completed.connect(_on_status_completed)
	set_process(true)


func configure(spec: Dictionary, stored: Dictionary = {}) -> void:
	room_query = StreamStatus.normalize_room_id(
		stored.get("room_query", spec.get("room_id", ""))
	)
	resolved_room_id = str(stored.get("resolved_room_id", ""))
	label = str(stored.get("label", spec.get("label", ""))).strip_edges()
	enabled = bool(stored.get("enabled", spec.get("enabled", false)))
	# Restored from disk so a broadcast the user already confirmed stays quiet
	# after a restart. A stored "last_notified_key" from an older build is
	# ignored on purpose: that mark was set by the program, not by the user, and
	# the whole point of this field is that only an answer settles a reminder.
	confirmed_key = str(stored.get("confirmed_key", ""))
	check_interval_sec = maxf(
		MIN_INTERVAL_SEC,
		float(spec.get("check_interval_seconds", DEFAULT_INTERVAL_SEC))
	)
	retry_interval_sec = maxf(
		MIN_RETRY_INTERVAL_SEC,
		float(
			spec.get(
				"reminder_retry_seconds",
				DEFAULT_RETRY_INTERVAL_SEC
			)
		)
	)
	# Being configured again invalidates anything that is already on its way.
	_drop_in_flight()
	# Check on the first frame after startup, then wait for the interval.
	check_countdown_sec = 0.0
	consecutive_failures = 0


func set_room(raw: String, new_label: String, new_enabled: bool) -> void:
	var clean := StreamStatus.normalize_room_id(raw)
	if clean != room_query:
		# The cached canonical id belongs to the previous room. The confirmation
		# key itself already contains the room id, so it stays valid and
		# switching rooms cannot hide a new broadcast.
		resolved_room_id = ""
	if clean != room_query or not new_enabled:
		# The pending question belongs to the configuration that was just left
		# behind: it is either about a room the user has moved away from, or
		# about a reminder that has just been switched off. Either way it can no
		# longer be answered, so a click that is still on screen settles nothing.
		reminder_key = ""
	if clean != room_query or new_enabled != enabled:
		# Whatever is on its way describes the previous configuration, so it is
		# dropped instead of being applied to the new one.
		_drop_in_flight()
	room_query = clean
	label = new_label.strip_edges()
	enabled = new_enabled
	check_countdown_sec = 2.0
	consecutive_failures = 0


# Makes every answer that is already on its way stale, and stops waiting for it
# so the new configuration is queried straight away instead of after the old
# request has run into its timeout.
#
# cancel_request() reports itself as a failed request; the token bump turns that
# into a silent no-op. Waiting a moment before the next attempt (the countdown
# set by set_room) is what keeps the cancellation from being mistaken for the
# answer to the request that replaces it.
func _drop_in_flight() -> void:
	intent_token += 1
	request_token = -1
	if (
		status_request != null
		and status_request.get_http_client_status()
		!= HTTPClient.STATUS_DISCONNECTED
	):
		status_request.cancel_request()


func export_settings() -> Dictionary:
	return {
		"room_query": room_query,
		"resolved_room_id": resolved_room_id,
		"label": label,
		"enabled": enabled,
		"confirmed_key": confirmed_key
	}


# Records the user's answer for the broadcast that is currently asking. Returns
# true when a confirmation was stored, so the caller knows to persist it.
#
# Only the broadcast the reminder was actually shown for can be confirmed: a
# late click after the stream ended (or after a new one started) is refused, so
# it cannot silence a stream the user has not seen a reminder for.
func confirm() -> bool:
	if reminder_key.is_empty() or reminder_key == confirmed_key:
		return false
	confirmed_key = reminder_key
	reminder_key = ""
	return true


func _process(delta: float) -> void:
	if not enabled or room_query.is_empty():
		return

	check_countdown_sec -= delta
	if check_countdown_sec > 0.0:
		return
	check_countdown_sec = _effective_interval()
	if not refresh() and consecutive_failures == 0:
		# A request that could not start because the previous one is still
		# finishing (switching rooms cancels it, which takes a moment) comes
		# back soon, instead of sitting out a whole interval before the new room
		# is ever queried. A request that genuinely failed to start has already
		# bumped the failure counter and keeps the backoff it earns.
		check_countdown_sec = minf(check_countdown_sec, BUSY_RETRY_SEC)


# How long to wait before the next poll.
#
# Three cases, in order of priority:
#   * a failing request keeps the growing backoff, so an outage or a risk-control
#     block does not turn into a request every few seconds;
#   * a reminder that is still unanswered is retried at the faster cadence --
#     the poll is what re-asks, so this is what makes "keep asking until the
#     live ends" actually reach the user;
#   * otherwise the configured interval.
func _effective_interval() -> float:
	if consecutive_failures > 0:
		var multiplier := minf(
			1.0 + float(consecutive_failures),
			MAX_BACKOFF_MULTIPLIER
		)
		return check_interval_sec * multiplier
	if not reminder_key.is_empty():
		return retry_interval_sec
	return check_interval_sec


# Explicit user request: report the outcome even if the last poll already
# failed, and drop the accumulated backoff. Returns false when no request
# could be started (already busy, or no room configured).
func refresh_now() -> bool:
	consecutive_failures = 0
	check_countdown_sec = check_interval_sec
	manual_check_pending = true
	var started := refresh()
	if not started:
		manual_check_pending = false
	return started


func refresh() -> bool:
	if room_query.is_empty():
		request_failed.emit("还没设置要关注的直播间，右键「设置…」里的开播提醒填一个吧～")
		return false
	if status_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return false

	var target := resolved_room_id if not resolved_room_id.is_empty() else room_query
	# The User-Agent header is mandatory: this endpoint answers HTTP 412
	# without it.
	var headers := PackedStringArray(["User-Agent: " + USER_AGENT])
	note_request_started()
	var error := status_request.request(ENDPOINT + target, headers)
	if error != OK:
		# Nothing will answer this one after all.
		request_token = -1
		_note_failure("开播查询没能启动，等会儿再试试～")
		return false
	return true


# Records which configuration the answer to the next request belongs to. Called
# right before a request leaves; reachable on its own so a test can put a
# request "in flight" without a network round trip and then check what a late
# answer does to the state.
func note_request_started() -> void:
	request_token = intent_token


func _on_status_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	# An answer is only applied while it still belongs to the configuration it
	# was asked for. If the user switched rooms, or switched the reminder off, in
	# the meantime, this one is stale: it must not write resolved_room_id and it
	# must not raise a reminder. A cancelled request lands here too, so dropping
	# it silently is also what keeps a room switch from looking like a network
	# failure.
	if request_token != intent_token:
		return
	request_token = -1

	if result != HTTPRequest.RESULT_SUCCESS:
		_note_failure("连不上开播接口，等会儿再帮你看看～")
		return
	if response_code != 200:
		_note_failure("开播查询失败（HTTP %d）～" % response_code)
		return

	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		_note_failure("开播数据格式异常，等会儿再试～")
		return

	var status := StreamStatus.parse_room_info(parsed as Dictionary)
	if status.is_empty():
		# Kept out of the bubble on purpose, but useful in the log when the
		# endpoint starts rejecting requests or the room id stops resolving.
		push_warning(
			"Stream status rejected: code=%s target=%s"
			% [str((parsed as Dictionary).get("code", "?")), _current_target()]
		)
		_note_failure("没能读到开播信息，等会儿再试试～")
		return

	consecutive_failures = 0
	resolved_room_id = str(status.get("room_id", ""))
	var manual := manual_check_pending
	manual_check_pending = false
	stream_updated.emit(status, manual)

	var ask_key := StreamStatus.session_key(status)
	# Backstop, not the primary guard: the token check above already drops the
	# answer that was on its way when the reminder was switched off, so this only
	# matters if a later change stops invalidating in-flight requests.
	var pending := enabled and StreamStatus.should_remind(status, confirmed_key)
	# Whether this broadcast is already being asked about. The first ask is the
	# one that animates the pet; the repeats only show the question again.
	var repeated := pending and ask_key == reminder_key
	if pending:
		# Nothing is marked as told here on purpose. reminder_key only records
		# which broadcast is asking, so the next poll asks again until the user
		# answers, and the question disappears by itself once the broadcast ends.
		reminder_key = ask_key
	else:
		# Either the room is not broadcasting (which includes the looping state)
		# or the user already confirmed this broadcast. Dropping the pending key
		# also means a stale click can no longer confirm anything.
		reminder_key = ""

	# The answer can change the cadence -- a manual check may just have turned
	# into a pending reminder, and a confirmed one stops being pending -- so the
	# next poll is scheduled from here, not from the value picked before the
	# request was sent.
	check_countdown_sec = _effective_interval()

	if not pending:
		return
	reminder_due.emit(StreamReplyFormatter.build(status, label), repeated)


func _current_target() -> String:
	return resolved_room_id if not resolved_room_id.is_empty() else room_query


func _note_failure(message: String) -> void:
	consecutive_failures += 1
	manual_check_pending = false
	# Only the first failure of a streak is announced; the rest stay silent
	# until a poll succeeds again.
	if consecutive_failures == 1:
		request_failed.emit(message)
