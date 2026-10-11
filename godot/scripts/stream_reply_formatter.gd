extends RefCounted

# Builds the bubble text for the stream reminder.
#
# The room API does not return the streamer's nickname, so the display name is
# whatever the user typed in the settings window; when it is empty a neutral
# wording is used.

const DEFAULT_LABEL := "你关注的主播"


# Wording for the automatic announcement. It is repeated on every poll until the
# user confirms it or the broadcast ends, so it reads as a request for an answer
# rather than as a one-off notice.
static func build(status: Dictionary, label: String) -> String:
	var name := display_name(label)
	var title := str(status.get("title", "")).strip_edges()
	var area := str(status.get("area_name", "")).strip_edges()

	if title.is_empty():
		return "%s开播啦，一起去看看吧～" % name
	if area.is_empty():
		return "%s开播啦！正在播《%s》，要不要去看看？" % [name, title]
	return "%s开播啦！正在播《%s》（%s），要不要去看看？" % [
		name, title, area
	]


# Wording for the answer to a check the user asked for, which has to make sense
# for every state instead of only the live one.
static func build_check(status: Dictionary, label: String) -> String:
	var name := display_name(label)
	var title := str(status.get("title", "")).strip_edges()

	match int(status.get("live_status", 0)):
		1:
			if title.is_empty():
				return "%s正在直播，快去看看～" % name
			return "%s正在直播《%s》，快去看看～" % [name, title]
		2:
			return "%s现在在轮播，还不算开播，真的开播了我再叫你。" % name

	return "%s现在没有开播，等开播了我会告诉你的～" % name


static func display_name(label: String) -> String:
	var name := label.strip_edges()
	if name.is_empty():
		return DEFAULT_LABEL
	return name


# Wording for the hint in the settings window.
#
# Built from the intervals the manager actually runs at instead of being written
# out by hand, so the card cannot end up describing a cadence the code no longer
# follows. That is exactly how the earlier text came to promise that a broadcast
# is announced once while the reminder in fact kept coming back until it was
# answered.
static func build_settings_hint(
	check_interval_sec: float,
	retry_interval_sec: float
) -> String:
	return (
		"每 %s看一次；开播会提醒你点「知道啦」，没确认就每 %s再问，"
		+ "直到这场直播结束。确认过的重开桌宠也不会再提醒。"
	) % [
		_duration_text(check_interval_sec),
		_duration_text(retry_interval_sec)
	]


static func _duration_text(seconds: float) -> String:
	var total := int(roundf(seconds))
	if total <= 0:
		return "一会儿"
	if total < 60:
		return "%d 秒" % total
	if total % 60 == 0:
		return "%d 分钟" % (total / 60)
	return "%d 分 %d 秒" % [total / 60, total % 60]
