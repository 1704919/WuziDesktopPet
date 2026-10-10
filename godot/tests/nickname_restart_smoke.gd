extends SceneTree

const Settings = preload("res://scripts/settings_store.gd")


func _init() -> void:
	var settings := Settings.new()
	settings.load_settings()
	var ok := true
	if OS.get_cmdline_user_args().has("write"):
		settings.set_value("stage2_existing_key", "preserved", false)
		ok = settings.set_nickname("水🙂".repeat(6)) and settings.get_nickname().length() == 12
		ok = ok and not settings.set_nickname("水".repeat(13))
		ok = ok and settings.get_nickname() == "水🙂".repeat(6)
	else:
		ok = settings.get_nickname() == "水🙂".repeat(6)
		ok = ok and settings.get_value("stage2_existing_key") == "preserved"
		ok = ok and settings.set_nickname("小水")
		var reloaded := Settings.new()
		reloaded.load_settings()
		ok = ok and reloaded.get_nickname() == "小水"
		ok = ok and reloaded.set_nickname("")
		reloaded.free()
		var cleared := Settings.new()
		cleared.load_settings()
		ok = ok and cleared.get_nickname().is_empty() and not cleared.data.has("nickname")
		for invalid in [null, {}, 92, "字".repeat(13)]:
			cleared.set_value("nickname", invalid, false)
			ok = ok and cleared.get_nickname().is_empty()
		cleared.erase_value("nickname", false)
		cleared.erase_value("stage2_existing_key", true)
		cleared.free()
	settings.free()
	if ok:
		print("NICKNAME_RESTART_OK")
		quit(0)
	else:
		push_error("NICKNAME_RESTART_FAILED")
		quit(2)
