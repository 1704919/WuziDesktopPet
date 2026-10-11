extends RefCounted

# Builds the bubble text for the stream reminder.
#
# The room API does not return the streamer's nickname, so the display name is
# whatever the user typed in the settings window; when it is empty a neutral
# wording is used.

const DEFAULT_LABEL := "你关注的主播"


# Wording for the automatic announcement, sent once per broadcast.
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
