extends Node2D

enum PetState { IDLE, REACTION, DRAGGING, THROWING, ROAMING, SLEEPING, WAKING }

const InputGuard = preload("res://scripts/input_guard.gd")
const DialogueManager = preload("res://scripts/dialogue_manager.gd")
const InactivityManager = preload("res://scripts/inactivity_manager.gd")
const DreamTalkManager = preload("res://scripts/dream_talk_manager.gd")
const DynamicHitShapeManager = preload("res://scripts/dynamic_hit_shape_manager.gd")
const BatchFileWindow = preload("res://scripts/batch_file_window.gd")
const PetWindowLayout = preload("res://scripts/pet_window_layout.gd")
const PetContextMenu = preload("res://scripts/pet_context_menu.gd")
const PetDragThrowMotion = preload("res://scripts/pet_drag_throw_motion.gd")
const WeatherReplyFormatter = preload("res://scripts/weather_reply_formatter.gd")
const PetClipCatalogLoader = preload("res://scripts/pet_clip_catalog_loader.gd")
const PetMovementCatalogLoader = preload("res://scripts/pet_movement_catalog_loader.gd")
const PetRoamingController = preload("res://scripts/pet_roaming_controller.gd")
const PetAnimationPlayback = preload("res://scripts/pet_animation_playback.gd")
const PetIdleActionPicker = preload("res://scripts/pet_idle_action_picker.gd")

var dialogue_manager := DialogueManager.new()
var inactivity_manager := InactivityManager.new()
var dream_talk_manager := DreamTalkManager.new()
var dynamic_hit_shape_manager := DynamicHitShapeManager.new()
var roaming_controller := PetRoamingController.new()
var animation_playback := PetAnimationPlayback.new()
var nickname_card: Control
var batch_file_window: Window

@onready var pet_visual: Node2D = $PetVisual
@onready var body_pivot: Node2D = $PetVisual/BodyPivot
@onready var pet_sprite: Sprite2D = $PetVisual/BodyPivot/PetSprite
@onready var pet_sprite_next: Sprite2D = $PetVisual/BodyPivot/PetSpriteNext
@onready var pet_video: VideoStreamPlayer = $PetVisual/BodyPivot/PetVideo
@onready var bubble = $Bubble
@onready var context_menu: Control = $ContextBubble
@onready var command_bubble: Control = $CommandBubble
@onready var command_input: LineEdit = $CommandBubble/Card/Margin/Content/CommandInput
@onready var command_cancel: Button = $CommandBubble/Card/Margin/Content/Actions/Cancel
@onready var command_send: Button = $CommandBubble/Card/Margin/Content/Actions/Send
@onready var weather_bubble: Control = $WeatherBubble
@onready var weather_city: LineEdit = $WeatherBubble/Card/Margin/Content/City
@onready var weather_enabled: CheckButton = $WeatherBubble/Card/Margin/Content/Enabled
@onready var weather_cancel: Button = $WeatherBubble/Card/Margin/Content/Actions/Cancel
@onready var weather_save: Button = $WeatherBubble/Card/Margin/Content/Actions/Save
@onready var settings_store = $SettingsStore
@onready var reminder_manager = $ReminderManager
@onready var file_drop_manager = $FileDropManager
@onready var action_registry = $ActionRegistry
@onready var mood_manager = $MoodManager
@onready var action_coordinator = $ActionCoordinator
@onready var mood_indicator: Control = $MoodIndicator
@onready var weather_manager = $WeatherManager

var config: Dictionary = {}
var feature_config: Dictionary = {}
var clips: Dictionary = {}
var movement_catalog: Dictionary = {}
var idle_video_textures: Array[Texture2D] = []
var idle_video_frame := 0
var idle_video_accum_sec := 0.0
var idle_runtime_stream: VideoStream
var video_runtime_enabled := false
var active_video_action_id := ""
var active_video_fps := 12.0
var active_video_frame_count := 0
var rng := RandomNumberGenerator.new()

var state: PetState = PetState.IDLE
var master_texture: Texture2D
var base_scale := 1.0
var base_position := Vector2(550, 210)
var base_body_pivot_position := Vector2(0, 161)

var idle_action_countdown_sec := 9.0
var last_idle_action_id := ""
var last_idle_action_category := ""
var idle_category_streak := 0
# Existing persisted preference; now pauses all autonomous behavior.
var random_actions_paused := false

const MENU_TOGGLE_RANDOM := PetContextMenu.MENU_TOGGLE_RANDOM
const MENU_RESET_POSITION := PetContextMenu.MENU_RESET_POSITION
const MENU_EXIT := PetContextMenu.MENU_EXIT
const MENU_TALK := PetContextMenu.MENU_TALK
const MENU_TOGGLE_REMINDERS := PetContextMenu.MENU_TOGGLE_REMINDERS
const MENU_PLAY_ACTION := PetContextMenu.MENU_PLAY_ACTION
const MENU_ACTION_BACK := PetContextMenu.MENU_ACTION_BACK
const MENU_FILE_WORKBENCH := PetContextMenu.MENU_FILE_WORKBENCH
const MENU_CLEAR_FILES := PetContextMenu.MENU_CLEAR_FILES
const MENU_WEATHER_SETTINGS := PetContextMenu.MENU_WEATHER_SETTINGS
const MENU_WEATHER_NOW := PetContextMenu.MENU_WEATHER_NOW
const MENU_SETTINGS := PetContextMenu.MENU_SETTINGS
const MENU_NICKNAME := PetContextMenu.MENU_NICKNAME
const MENU_ACTION_CATEGORY_BACK := PetContextMenu.MENU_ACTION_CATEGORY_BACK
const MENU_TOGGLE_ROAMING := PetContextMenu.MENU_TOGGLE_ROAMING
const MENU_ACTION_PAGE_UP := PetContextMenu.MENU_ACTION_PAGE_UP
const MENU_ACTION_PAGE_DOWN := PetContextMenu.MENU_ACTION_PAGE_DOWN
const ACTION_CATEGORY_MENU_BASE := PetContextMenu.ACTION_CATEGORY_MENU_BASE
const ACTION_MENU_BASE := PetContextMenu.ACTION_MENU_BASE
const CONTEXT_MENU_FIXED_ANCHOR := PetContextMenu.CONTEXT_MENU_FIXED_ANCHOR

const ACTION_PRIORITY_IDLE := 10
const ACTION_PRIORITY_ROAMING := 20
const ACTION_PRIORITY_DIALOGUE := 50
const ACTION_PRIORITY_CLICK := 60
const ACTION_PRIORITY_SLEEP := 80
const ACTION_PRIORITY_MANUAL := 90
const ACTION_PRIORITY_DRAG := 100
const ACTION_PRIORITY_WAKE := 110

var sequence_token := 0
var sequence_running := false
var active_clip_uses_visual_fade := false
const ACTION_VISUAL_FADE_MIN_ALPHA := 0.55
const ACTION_VISUAL_FADE_OUT_SEC := 0.045
const ACTION_VISUAL_FADE_IN_SEC := 0.060

var last_reaction_id := ""
var last_reaction_tier := ""
var reaction_cooldown_until_ms := 0
var last_rapid_click_line_ms := -100000
const RAPID_CLICK_LINE_COOLDOWN_MS := 1500
var active_clip_id := ""
var sleep_phase := "none"

# dsh-pet style Q-bounce state. Keep this independent from the click-reaction
# video cooldown so every completed click can retrigger the tactile feedback.
var click_squash_active := false
var click_squash_phase := 0
var click_squash_elapsed_sec := 0.0
var click_squash_from_y := 1.0
const CLICK_SQUASH_SCALE_Y := 0.55
const CLICK_SQUASH_COMPRESS_SEC := 0.055
const CLICK_SQUASH_REBOUND_SEC := 0.285

var pointer_pressed := false
var dragging := false
var drag_moved := false
var drag_mouse_start := Vector2i.ZERO
var drag_window_start := Vector2.ZERO
var drag_current_position := Vector2.ZERO
var drag_target_position := Vector2.ZERO
var drag_velocity := Vector2.ZERO
var throw_velocity := Vector2.ZERO
var drag_threshold_px := 12

var bubble_interactive := false
var overlay_interactive := false
var debug_last_passthrough_polygon := PackedVector2Array()
var debug_character_passthrough_polygon := PackedVector2Array()
var active_hit_action_id := "idle"
var active_hit_frame := 0
var dynamic_hit_shapes_ready := false
var context_menu_anchor := Vector2.ZERO
var manual_action_map: Dictionary = {}
var manual_category_map: Dictionary = {}


func _ready() -> void:
	rng.randomize()
	animation_playback.name = "PetAnimationPlayback"
	add_child(animation_playback)
	animation_playback.configure(
		pet_sprite,
		pet_sprite_next,
		pet_video,
		body_pivot,
		Callable(self, "_is_sequence_token_current"),
		Callable(self, "_show_runtime_video"),
		Callable(self, "_hide_runtime_video"),
		Callable(self, "_set_active_hit_frame")
	)
	settings_store.load_settings()
	_load_config()
	_load_feature_config()
	base_position = pet_visual.position
	PetWindowLayout.configure(get_viewport(), config, settings_store, base_position)
	_load_clips()
	_load_dynamic_hit_shapes()
	_load_idle_video()
	_load_movement_catalog()
	action_registry.load_catalog()
	_configure_feature_modules()

	base_scale = float(config.get("sprite_scale", 1.0))
	base_position = pet_visual.position
	base_body_pivot_position = body_pivot.position
	pet_visual.scale = Vector2.ONE * base_scale
	var interaction := config.get("interaction", {}) as Dictionary
	drag_threshold_px = int(interaction.get("drag_threshold_px", 12))

	master_texture = load(str(config.get("master_texture", ""))) as Texture2D
	if master_texture == null:
		push_error("Failed to load master texture")
		get_tree().quit(2)
		return

	pet_sprite.texture = master_texture
	pet_sprite_next.texture = null
	pet_sprite.modulate = Color.WHITE
	pet_sprite_next.modulate.a = 0.0

	_configure_mouse_passthrough()
	_setup_control_menu()
	_schedule_next_idle_action()
	_return_to_idle(false)
	call_deferred("_try_auto_birthday_easter_egg")


func _load_config() -> void:
	var file := FileAccess.open("res://config/pet_behavior.json", FileAccess.READ)
	if file == null:
		push_error("Unable to open pet_behavior.json")
		get_tree().quit(2)
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("pet_behavior.json is not a JSON object")
		get_tree().quit(2)
		return

	config = parsed as Dictionary


func _load_feature_config() -> void:
	var file := FileAccess.open("res://config/feature_config.json", FileAccess.READ)
	if file == null:
		feature_config = {}
		push_warning("feature_config.json not found")
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		feature_config = {}
		push_warning("feature_config.json is not a JSON object")
		return

	feature_config = parsed as Dictionary


func _configure_feature_modules() -> void:
	dialogue_manager.load_config()
	dream_talk_manager.load_config()
	inactivity_manager.configure(
		feature_config.get("inactivity", {}) as Dictionary,
		Time.get_ticks_msec()
	)
	var mood_cfg := feature_config.get("mood", {}) as Dictionary
	mood_manager.configure(mood_cfg)
	mood_indicator.call("configure", mood_cfg)
	if not mood_indicator.visibility_changed.is_connected(_on_mood_indicator_visibility_changed):
		mood_indicator.visibility_changed.connect(_on_mood_indicator_visibility_changed)
	action_coordinator.configure(
		action_registry,
		feature_config.get("action_coordinator", {}) as Dictionary
	)
	if not mood_manager.mood_changed.is_connected(_on_mood_changed):
		mood_manager.mood_changed.connect(_on_mood_changed)
	_on_mood_changed(mood_manager.current_mood, mood_manager.mood_score)
	command_input.max_length = InputGuard.MESSAGE_LIMIT
	var reminder_cfg := feature_config.get("reminders", {}) as Dictionary
	reminder_manager.configure(reminder_cfg)
	var stored_reminders := bool(settings_store.get_value(
		"reminders_enabled",
		bool(reminder_cfg.get("enabled", true))
	))
	reminder_manager.set_enabled(stored_reminders)

	var file_cfg := feature_config.get("file_conversion", {}) as Dictionary
	file_drop_manager.configure(file_cfg)

	var weather_cfg := feature_config.get("weather", {}) as Dictionary
	var stored_weather_variant: Variant = settings_store.get_value("weather", {})
	var stored_weather: Dictionary = {}
	if typeof(stored_weather_variant) == TYPE_DICTIONARY:
		stored_weather = stored_weather_variant as Dictionary
	weather_manager.configure(weather_cfg, stored_weather)

	random_actions_paused = bool(settings_store.get_value(
		"random_actions_paused",
		false
	))
	reminder_manager.set_chatter_paused(random_actions_paused)
	var roaming_cfg := config.get("roaming", {}) as Dictionary
	var stored_roaming_enabled := bool(settings_store.get_value(
		"roaming_enabled",
		true
	))
	roaming_controller.configure(
		roaming_cfg,
		movement_catalog,
		stored_roaming_enabled
	)

	reminder_manager.reminder_due.connect(_on_reminder_due)
	file_drop_manager.queue_changed.connect(_on_file_queue_changed)
	weather_manager.weather_updated.connect(_on_weather_updated)
	weather_manager.reminder_due.connect(_on_weather_reminder_due)
	weather_manager.request_failed.connect(_on_weather_request_failed)
	bubble.action_selected.connect(_on_bubble_action_selected)
	bubble.interactive_changed.connect(_on_bubble_interactive_changed)
	bubble.bounds_changed.connect(_on_bubble_bounds_changed)
	command_bubble.interactive_changed.connect(_on_overlay_interactive_changed)
	weather_bubble.interactive_changed.connect(_on_overlay_interactive_changed)
	context_menu.interactive_changed.connect(_on_overlay_interactive_changed)

	if not get_window().files_dropped.is_connected(_on_files_dropped):
		get_window().files_dropped.connect(_on_files_dropped)

	command_send.pressed.connect(_on_command_send_pressed)
	command_cancel.pressed.connect(_on_command_cancel_pressed)
	command_input.text_submitted.connect(_on_command_text_submitted)
	command_input.text_changed.connect(_on_command_input_changed)
	command_input.text_change_rejected.connect(_on_command_input_rejected)

	weather_save.pressed.connect(_on_weather_save_pressed)
	weather_cancel.pressed.connect(_on_weather_cancel_pressed)


func _persist_window_position() -> void:
	PetWindowLayout.persist_position(settings_store)


func _setup_control_menu() -> void:
	context_menu.item_selected.connect(_on_control_menu_id_pressed)


func _open_control_menu(local_position: Vector2) -> void:
	command_bubble.call("hide_card", false)
	weather_bubble.call("hide_card", false)
	_hide_nickname_card(false)
	context_menu_anchor = local_position
	PetContextMenu.open_root(
		context_menu,
		config,
		local_position,
		bool(reminder_manager.enabled),
		random_actions_paused,
		roaming_controller.is_enabled(),
		manual_action_map,
		manual_category_map
	)


func _open_settings_menu() -> void:
	PetContextMenu.open_settings(
		context_menu,
		context_menu_anchor,
		manual_action_map,
		manual_category_map
	)


func _open_batch_file_window() -> void:
	command_bubble.call("hide_card", false)
	weather_bubble.call("hide_card", false)
	_hide_nickname_card(false)
	context_menu.call("hide_menu", false)
	if not is_instance_valid(batch_file_window):
		batch_file_window = BatchFileWindow.new()
		add_child(batch_file_window)
		batch_file_window.feedback_requested.connect(_on_file_feedback_requested)
		batch_file_window.call("setup", file_drop_manager)
	batch_file_window.call("open_workbench")


func _open_action_picker() -> void:
	PetContextMenu.open_action_picker(
		context_menu,
		config,
		context_menu_anchor,
		manual_action_map,
		manual_category_map
	)


func _open_action_category(category_id: String, page_index: int = 0) -> void:
	PetContextMenu.open_action_category(
		context_menu,
		config,
		context_menu_anchor,
		category_id,
		manual_action_map,
		manual_category_map,
		page_index
	)


func _on_control_menu_id_pressed(id: int) -> void:
	_register_user_activity()
	if id >= ACTION_MENU_BASE:
		if sleep_phase != "none":
			bubble.say(dream_talk_manager.chat_reply(settings_store.get_nickname()), 3.6)
			return
		var spec := manual_action_map.get(id, {}) as Dictionary
		if not spec.is_empty():
			_play_manual_action(spec)
		return
	if id >= ACTION_CATEGORY_MENU_BASE:
		var category_id := str(manual_category_map.get(id, ""))
		if not category_id.is_empty():
			call_deferred("_open_action_category", category_id)
		return

	match id:
		MENU_TALK:
			_open_command_window()
		MENU_PLAY_ACTION:
			call_deferred("_open_action_picker")
		MENU_ACTION_CATEGORY_BACK:
			call_deferred("_open_action_picker")
		MENU_ACTION_PAGE_UP, MENU_ACTION_PAGE_DOWN:
			var navigation := manual_category_map.get(id, {}) as Dictionary
			var category_id := str(navigation.get("category_id", ""))
			var page_index := int(navigation.get("page_index", 0))
			if not category_id.is_empty():
				call_deferred(
					"_open_action_category",
					category_id,
					page_index
				)
		MENU_ACTION_BACK:
			call_deferred("_open_control_menu", context_menu_anchor)
		MENU_TOGGLE_REMINDERS:
			var value: bool = not bool(reminder_manager.enabled)
			reminder_manager.set_enabled(value)
			settings_store.set_value("reminders_enabled", value)
			bubble.say(
				"日常提醒已%s。" % ("开启" if value else "关闭"),
				2.4
			)
		MENU_WEATHER_NOW:
			_request_weather_now()
		MENU_WEATHER_SETTINGS:
			_open_weather_window()
		MENU_SETTINGS:
			call_deferred("_open_settings_menu")
		MENU_NICKNAME:
			_open_nickname_window()
		MENU_FILE_WORKBENCH:
			_open_batch_file_window()
		MENU_TOGGLE_RANDOM:
			_set_autonomous_paused(not random_actions_paused)
		MENU_TOGGLE_ROAMING:
			_set_roaming_enabled(not roaming_controller.is_enabled())
		MENU_CLEAR_FILES:
			file_drop_manager.clear_queue()
			bubble.say("好啦，拖进来的文件队列清空了～", 2.6)
		MENU_RESET_POSITION:
			var was_sleeping := sleep_phase != "none"
			if was_sleeping:
				_interrupt_sleep_by_user()
			else:
				_cancel_active_action()
			throw_velocity = Vector2.ZERO
			pointer_pressed = false
			dragging = false
			_reset_window_position()
			_persist_window_position()
			if not was_sleeping:
				_return_to_idle(false)
		MENU_EXIT:
			_quit_pet()


func _play_manual_action(spec: Dictionary) -> void:
	var action_id := str(spec.get("id", ""))
	var kind := str(spec.get("kind", "clip"))

	match kind:
		"idle":
			_cancel_active_action()
			_return_to_idle(false)
		"sleep":
			_start_sleep_entry("manual", ACTION_PRIORITY_MANUAL)
		"clip":
			_request_coordinated_clip(
				action_id,
				"manual",
				ACTION_PRIORITY_MANUAL,
				true,
				PetState.REACTION
			)
		_:
			_cancel_active_action()
			_return_to_idle(false)


func _open_command_window() -> void:
	weather_bubble.call("hide_card", false)
	_hide_nickname_card(false)
	context_menu.call("hide_menu", false)
	command_input.clear()
	_on_command_input_changed("")
	command_bubble.call("popup_card")
	# popup_card() makes the control visible synchronously, so focus can be
	# assigned immediately instead of waiting another frame.
	command_input.grab_focus()


func _on_command_send_pressed() -> void:
	_on_command_text_submitted(command_input.text)


func _on_command_cancel_pressed() -> void:
	command_bubble.call("hide_card")
	command_input.clear()


func _on_command_text_submitted(text: String) -> void:
	var checked := InputGuard.check(text, InputGuard.MESSAGE_LIMIT)
	if not checked.ok:
		if checked.error == "too_long":
			_on_command_input_rejected("")
		return
	_register_user_activity()
	command_bubble.call("hide_card")
	command_input.clear()
	_handle_command_text(text)


func _handle_command_text(text: String) -> void:
	if _is_sleep_dream_state():
		bubble.say(
			dream_talk_manager.chat_reply(settings_store.get_nickname()),
			4.0
		)
		return

	var result := dialogue_manager.submit_message(
		text,
		settings_store.get_nickname()
	)
	_apply_dialogue_result(result, "dialogue")


func _apply_dialogue_result(
	result: Dictionary,
	source: String
) -> void:
	if result.is_empty():
		return

	var mood_event := str(result.get("mood_event", ""))
	if not mood_event.is_empty():
		mood_manager.apply_event(mood_event)

	var reply := str(result.get("text", ""))
	if str(result.get("intent", "")) == "mood_query":
		# Use the current MoodManager snapshot; static templates can lie.
		reply = dialogue_manager.mood_reply(
			str(mood_manager.get_snapshot().get("mood", "normal"))
		)
	if not reply.is_empty():
		bubble.say(reply, 4.0)

	var action_request := str(result.get("action_request", ""))
	if action_request == "sleep_down":
		_start_sleep_entry(source, ACTION_PRIORITY_DIALOGUE)
	elif not action_request.is_empty():
		_request_coordinated_clip(
			action_request,
			source,
			ACTION_PRIORITY_DIALOGUE,
			true,
			PetState.REACTION
		)


func _on_file_feedback_requested(kind: String) -> void:
	var text := dialogue_manager.event_reply(kind)
	if text.is_empty():
		return
	if is_instance_valid(batch_file_window):
		batch_file_window.call("set_character_feedback", text)
	# The independent file workbench can cover the pet. Show the feedback in
	# its own status area too, without stealing keyboard focus.
	bubble.say(text, 4.0)


func _say_event_feedback(kind: String, duration: float = 3.2) -> void:
	var text := dialogue_manager.event_reply(kind)
	if not text.is_empty():
		bubble.say(text, duration)


func _try_auto_birthday_easter_egg() -> void:
	var date := Time.get_date_dict_from_system()
	var year := int(date.get("year", -1))
	var last_year := int(settings_store.get_value(
		"last_birthday_auto_trigger_year",
		-1
	))
	var result := dialogue_manager.birthday_auto_event(
		date,
		last_year
	) as Dictionary
	if result.is_empty():
		return

	settings_store.set_value(
		"last_birthday_auto_trigger_year",
		year
	)
	_apply_dialogue_result(result, "birthday_auto")


func _on_command_input_changed(text: String) -> void:
	command_send.disabled = not bool(InputGuard.check(text, InputGuard.MESSAGE_LIMIT).ok)
	$CommandBubble/Card/Margin/Content/Title.text = "你想对她说：%d / 50" % text.length()


func _on_command_input_rejected(_rejected: String) -> void:
	$CommandBubble/Card/Margin/Content/Title.text = "最多 50 个字符，已保留能放下的内容。"


func _open_nickname_window() -> void:
	command_bubble.call("hide_card", false)
	weather_bubble.call("hide_card", false)
	context_menu.call("hide_menu", false)
	if not is_instance_valid(nickname_card):
		nickname_card = load("res://scenes/nickname_card.tscn").instantiate()
		add_child(nickname_card)
		nickname_card.interactive_changed.connect(_on_overlay_interactive_changed)
		nickname_card.nickname_submitted.connect(_on_nickname_submitted)
	nickname_card.call("open_for", settings_store.get_nickname())


func _hide_nickname_card(animated: bool = true) -> void:
	if is_instance_valid(nickname_card):
		nickname_card.call("hide_card", animated)


func _on_nickname_submitted(text: String) -> void:
	var checked := InputGuard.check(text, InputGuard.NICKNAME_LIMIT, true)
	if not checked.ok:
		nickname_card.call("show_error", "昵称最多 12 个字符，请缩短后再保存。")
		return
	if not settings_store.set_nickname(text):
		nickname_card.call("show_error", "暂时没能保存，请稍后重试。")
		return
	_hide_nickname_card()
	bubble.say("昵称已清除，照常陪你聊天。" if checked.text.is_empty() else "记住啦，以后就这样称呼你。", 3.0)


func _open_weather_window() -> void:
	command_bubble.call("hide_card", false)
	_hide_nickname_card(false)
	context_menu.call("hide_menu", false)
	weather_city.text = str(weather_manager.location_query)
	weather_enabled.button_pressed = bool(weather_manager.enabled)
	weather_bubble.call("popup_card")
	weather_city.call_deferred("grab_focus")


func _on_weather_cancel_pressed() -> void:
	weather_bubble.call("hide_card")


func _on_weather_save_pressed() -> void:
	var city := weather_city.text.strip_edges()
	var enabled := weather_enabled.button_pressed

	if enabled and city.is_empty():
		bubble.say("先告诉我你在哪个城市呀，不然我不知道该往哪儿看天气～", 4.0)
		return

	weather_manager.set_location(city, enabled)
	settings_store.set_value(
		"weather",
		weather_manager.export_settings()
	)
	weather_bubble.call("hide_card")

	if enabled and not city.is_empty():
		bubble.say("好～我去看看那边现在是什么天气。", 2.8)
		weather_manager.refresh()
	else:
		bubble.say("好，天气提醒先关掉啦。", 2.8)


func _request_weather_now() -> void:
	if str(weather_manager.location_name).is_empty():
		bubble.ask(
			"还没设置天气城市，要现在设置吗？",
			[
				{"id": "weather_setup", "label": "去设置"},
				{"id": "dismiss", "label": "稍后"}
			]
		)
		return

	bubble.say("我去瞄一眼天气～", 2.2)
	weather_manager.refresh()


func _on_weather_updated(summary: Dictionary) -> void:
	settings_store.set_value(
		"weather",
		weather_manager.export_settings()
	)

	var weather_text := _build_weather_reply(summary)
	bubble.say(
		dream_talk_manager.format_notice("weather", weather_text)
		if _is_sleep_dream_state()
		else weather_text,
		7.0
	)


func _build_weather_reply(summary: Dictionary) -> String:
	return WeatherReplyFormatter.build(summary)


func _on_weather_reminder_due(text: String) -> void:
	bubble.say(
		dream_talk_manager.format_notice("weather", text)
		if _is_sleep_dream_state()
		else text,
		6.0
	)


func _on_weather_request_failed(message: String) -> void:
	bubble.say(
		dream_talk_manager.format_notice("weather", message)
		if _is_sleep_dream_state()
		else message,
		4.5
	)


func _on_reminder_due(text: String) -> void:
	bubble.say(
		dream_talk_manager.format_notice("reminder", text)
		if _is_sleep_dream_state()
		else text,
		5.0
	)


func _on_bubble_action_selected(action_id: String) -> void:
	match action_id:
		"convert_png", "convert_jpg", "convert_webp":
			# Stage 5A safety guard: stale bubble actions may only open preview.
			_open_batch_file_window()
		"weather_setup":
			_open_weather_window()
		"dismiss":
			pass


func _on_bubble_interactive_changed(enabled: bool) -> void:
	bubble_interactive = enabled
	call_deferred("_configure_mouse_passthrough")


func _on_bubble_bounds_changed() -> void:
	_configure_mouse_passthrough()


func _on_overlay_interactive_changed(_enabled: bool) -> void:
	overlay_interactive = (
		command_bubble.visible
		or weather_bubble.visible
		or context_menu.visible
		or (is_instance_valid(nickname_card) and nickname_card.visible)
	)
	call_deferred("_configure_mouse_passthrough")


func _on_mood_indicator_visibility_changed() -> void:
	call_deferred("_configure_mouse_passthrough")


func _on_files_dropped(files: PackedStringArray) -> void:
	_register_user_activity()
	if sleep_phase != "none":
		_interrupt_sleep_by_user()
	var summary := file_drop_manager.enqueue(files) as Dictionary
	var images := int(summary.get("images", 0))
	var audio := int(summary.get("audio", 0))
	var video := int(summary.get("video", 0))
	var other := int(summary.get("other", 0))

	var parts: PackedStringArray = []
	if images > 0:
		parts.append("%d 张图片" % images)
	if audio > 0:
		parts.append("%d 个音频" % audio)
	if video > 0:
		parts.append("%d 个视频" % video)
	if other > 0:
		parts.append("%d 个其他文件" % other)

	var description := "、".join(parts)
	if description.is_empty():
		description = "文件"

	var note := "收到%s，已经加入文件处理队列。" % description
	if audio + video > 0:
		note += "\n音频和视频只参与批量重命名，不提供格式转换。"
	bubble.say(note, 3.2)
	call_deferred("_open_batch_file_window")


func _on_file_queue_changed(_summary: Dictionary) -> void:
	pass


func _convert_queued_images(_target: String) -> void:
	_open_batch_file_window()


func _quit_pet() -> void:
	_persist_window_position()
	settings_store.save_settings()
	get_tree().quit()


func _exit_tree() -> void:
	if is_instance_valid(settings_store):
		settings_store.set_window_position(
			DisplayServer.window_get_position(),
			false
		)
		settings_store.save_settings()


func _reset_window_position() -> void:
	var window_cfg := config.get("window", {}) as Dictionary
	var usable := DisplayServer.screen_get_usable_rect()
	var window_size := DisplayServer.window_get_size()
	var pos := Vector2i(
		usable.position.x + usable.size.x - window_size.x - int(window_cfg.get("margin_right", 28)),
		usable.position.y + usable.size.y - window_size.y - int(window_cfg.get("margin_bottom", 28))
	)
	DisplayServer.window_set_position(pos)


func _load_dynamic_hit_shapes() -> void:
	var interaction := config.get("interaction", {}) as Dictionary
	var dynamic_cfg := interaction.get("dynamic_hit_shape", {}) as Dictionary
	if not bool(dynamic_cfg.get("enabled", true)):
		dynamic_hit_shapes_ready = false
		return

	var catalog_path := str(
		dynamic_cfg.get("catalog", "res://config/video_hit_shapes.json")
	)
	dynamic_hit_shapes_ready = dynamic_hit_shape_manager.load_catalog(catalog_path)
	if not dynamic_hit_shapes_ready:
		push_warning("Dynamic hit-shape catalog unavailable; using fallback pet hitbox.")


func _set_active_hit_frame(action_id: String, frame_index: int) -> void:
	var next_action := action_id if not action_id.is_empty() else "idle"
	var next_frame := maxi(0, frame_index)
	if active_hit_action_id == next_action and active_hit_frame == next_frame:
		return
	active_hit_action_id = next_action
	active_hit_frame = next_frame
	_configure_mouse_passthrough()


func _fallback_character_polygon() -> PackedVector2Array:
	var interaction := config.get("interaction", {}) as Dictionary
	var hitbox := interaction.get("pet_hitbox", {}) as Dictionary
	var dynamic_cfg := interaction.get("dynamic_hit_shape", {}) as Dictionary
	var pad := float(dynamic_cfg.get("fallback_padding_px", 12.0))
	var left := base_position.x + float(hitbox.get("left", -125.0)) * base_scale - pad
	var top := base_position.y + float(hitbox.get("top", -155.0)) * base_scale - pad
	var right := base_position.x + float(hitbox.get("right", 125.0)) * base_scale + pad
	var bottom := base_position.y + float(hitbox.get("bottom", 161.0)) * base_scale + pad
	return PackedVector2Array([
		Vector2(left, top),
		Vector2(right, top),
		Vector2(right, bottom),
		Vector2(left, bottom)
	])


func _current_character_passthrough_polygon() -> PackedVector2Array:
	if not dynamic_hit_shapes_ready:
		return _fallback_character_polygon()

	var raw := dynamic_hit_shape_manager.polygon_for(
		active_hit_action_id,
		active_hit_frame
	)
	if raw.size() < 3:
		return _fallback_character_polygon()

	var canvas_center := dynamic_hit_shape_manager.canvas_size * 0.5
	var transformed := PackedVector2Array()
	for point in raw:
		transformed.append(pet_sprite.to_global(point - canvas_center))
	return transformed


func _append_rect_corners(points: PackedVector2Array, rect: Rect2) -> void:
	var grown := rect.grow(2.0)
	points.append(grown.position)
	points.append(Vector2(grown.end.x, grown.position.y))
	points.append(grown.end)
	points.append(Vector2(grown.position.x, grown.end.y))


func _visible_ui_passthrough_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if bubble.visible:
		rects.append(bubble.call("get_window_bounds") as Rect2)
	if context_menu.visible:
		rects.append(context_menu.get_global_rect())
	if command_bubble.visible:
		rects.append(command_bubble.get_global_rect())
	if weather_bubble.visible:
		rects.append(weather_bubble.get_global_rect())
	if is_instance_valid(nickname_card) and nickname_card.visible:
		rects.append(nickname_card.get_global_rect())
	if mood_indicator.visible:
		rects.append(mood_indicator.get_global_rect())
	return rects


func _configure_mouse_passthrough() -> void:
	# Normal mode follows the alpha-derived polygon for the *current animation
	# frame*. This keeps standing, crouching and lying poses clickable without
	# leaving a large invisible rectangle over desktop icons.
	var character_polygon := _current_character_passthrough_polygon()
	debug_character_passthrough_polygon = character_polygon
	mood_indicator.call("set_hover_polygon", character_polygon)

	var ui_rects := _visible_ui_passthrough_rects()
	if ui_rects.is_empty():
		debug_last_passthrough_polygon = character_polygon
	else:
		# DisplayServer accepts one polygon. When UI is visible, use the convex
		# hull of the current character plus only the actually visible cards.
		# This is intentionally much smaller than the old full 760x420 capture.
		var combined := PackedVector2Array(character_polygon)
		for rect in ui_rects:
			_append_rect_corners(combined, rect)
		debug_last_passthrough_polygon = Geometry2D.convex_hull(combined)

	DisplayServer.window_set_mouse_passthrough(debug_last_passthrough_polygon)


func _load_clips() -> void:
	clips.clear()
	var runtime_cfg := config.get("video_runtime", {}) as Dictionary
	video_runtime_enabled = bool(runtime_cfg.get("enabled", false))
	PetClipCatalogLoader.populate(clips, config, video_runtime_enabled)


func _load_idle_video() -> void:
	idle_video_textures.clear()
	idle_runtime_stream = null

	var spec := config.get("idle_video", {}) as Dictionary
	if not bool(spec.get("enabled", false)):
		return

	var frames_dir := str(spec.get("frames_dir", ""))
	var frame_count := int(spec.get("frame_count", 0))
	if frames_dir.is_empty() or frame_count <= 0:
		push_warning("idle_video is enabled but not configured")
		return

	var runtime_video_path := "%s/runtime_alpha.ogv" % frames_dir.get_base_dir()
	if video_runtime_enabled and ResourceLoader.exists(runtime_video_path):
		idle_runtime_stream = load(runtime_video_path) as VideoStream
		if idle_runtime_stream == null:
			push_warning("Failed to load idle runtime video; PNG fallback remains active.")

	for index in range(frame_count):
		var path := "%s/%03d.png" % [frames_dir, index]
		var texture := load(path) as Texture2D
		if texture == null:
			push_warning("Failed to load idle-video frame: %s" % path)
			idle_video_textures.clear()
			return
		idle_video_textures.append(texture)

	_reset_idle_video()


func _idle_video_is_ready() -> bool:
	return not idle_video_textures.is_empty()


func _idle_runtime_is_ready() -> bool:
	return video_runtime_enabled and idle_runtime_stream != null


func _runtime_video_is_active() -> bool:
	return (
		is_instance_valid(pet_video)
		and pet_video.visible
		and pet_video.stream != null
	)


func _show_runtime_video(
	stream: VideoStream,
	action_id: String,
	fps: float,
	frame_count: int,
	loop_playback: bool
) -> bool:
	if not video_runtime_enabled or stream == null or not is_instance_valid(pet_video):
		return false

	pet_video.stop()
	pet_video.stream = stream
	pet_video.loop = loop_playback
	pet_video.paused = false
	pet_video.visible = true
	pet_sprite.visible = false
	pet_sprite_next.visible = false

	active_video_action_id = action_id if not action_id.is_empty() else "idle"
	active_video_fps = maxf(1.0, fps)
	active_video_frame_count = maxi(1, frame_count)
	_set_active_hit_frame(active_video_action_id, 0)
	pet_video.play()
	return true


func _hide_runtime_video(clear_stream: bool = false) -> void:
	if is_instance_valid(pet_video):
		pet_video.stop()
		pet_video.paused = false
		pet_video.visible = false
		if clear_stream:
			pet_video.stream = null

	pet_sprite.visible = true
	pet_sprite_next.visible = true
	active_video_action_id = ""
	active_video_frame_count = 0


func _pause_runtime_video_preserve_frame() -> void:
	if _runtime_video_is_active():
		pet_video.paused = true


func _start_idle_runtime_video() -> bool:
	if not _idle_runtime_is_ready():
		return false
	var spec := config.get("idle_video", {}) as Dictionary
	return _show_runtime_video(
		idle_runtime_stream,
		"idle",
		float(spec.get("fps", 12.0)),
		int(spec.get("frame_count", 121)),
		true
	)


func _update_runtime_video_hit_frame() -> void:
	if not _runtime_video_is_active() or active_video_frame_count <= 0:
		return

	var frame_index := int(floor(pet_video.stream_position * active_video_fps))
	frame_index = clampi(frame_index, 0, active_video_frame_count - 1)
	_set_active_hit_frame(active_video_action_id, frame_index)


func _reset_idle_video() -> void:
	idle_video_accum_sec = 0.0
	if idle_video_textures.is_empty():
		idle_video_frame = 0
		return

	var spec := config.get("idle_video", {}) as Dictionary
	var start_frame := clampi(
		int(spec.get("start_frame", 0)),
		0,
		idle_video_textures.size() - 1
	)
	idle_video_frame = start_frame
	pet_sprite.texture = idle_video_textures[idle_video_frame]
	_set_active_hit_frame("idle", idle_video_frame)


func _update_idle_video(delta: float) -> void:
	if idle_video_textures.is_empty():
		return

	var spec := config.get("idle_video", {}) as Dictionary
	var fps := maxf(1.0, float(spec.get("fps", 24.0)))
	var start_frame := clampi(
		int(spec.get("start_frame", 0)),
		0,
		idle_video_textures.size() - 1
	)
	var end_frame := clampi(
		int(spec.get("end_frame", idle_video_textures.size() - 1)),
		start_frame,
		idle_video_textures.size() - 1
	)
	var frame_duration := 1.0 / fps

	idle_video_accum_sec += delta
	while idle_video_accum_sec >= frame_duration:
		idle_video_accum_sec -= frame_duration
		idle_video_frame += 1
		if idle_video_frame > end_frame:
			idle_video_frame = start_frame

	pet_sprite.texture = idle_video_textures[idle_video_frame]
	_set_active_hit_frame("idle", idle_video_frame)


func _load_movement_catalog() -> void:
	movement_catalog = PetMovementCatalogLoader.load_catalog(config)


func _update_roaming(delta: float) -> void:
	if random_actions_paused:
		return
	if roaming_controller.is_active():
		if state != PetState.ROAMING or not sequence_running:
			roaming_controller.cancel()
			_persist_window_position()
			return

		var current_position := DisplayServer.window_get_position()
		var usable_rect := PetWindowLayout.usable_rect_for_pet(
			current_position,
			base_position
		)
		var animation_time_sec := -1.0
		if (
			_runtime_video_is_active()
			and active_video_action_id == active_clip_id
		):
			animation_time_sec = maxf(0.0, pet_video.stream_position)

		var motion := roaming_controller.step_active(
			delta,
			current_position,
			base_position,
			usable_rect,
			animation_time_sec
		)
		var target_position: Variant = motion.get("position", current_position)
		if target_position is Vector2i and target_position != current_position:
			DisplayServer.window_set_position(target_position as Vector2i)
		if bool(motion.get("finished", false)):
			_persist_window_position()
		return

	var can_start := (
		state == PetState.IDLE
		and not sequence_running
		and sleep_phase == "none"
		and not pointer_pressed
		and not overlay_interactive
		and not bubble_interactive
	)
	var current_position := DisplayServer.window_get_position()
	var usable_rect := PetWindowLayout.usable_rect_for_pet(
		current_position,
		base_position
	)
	var action_id := roaming_controller.request_if_due(
		delta,
		can_start,
		current_position,
		base_position,
		usable_rect
	)
	if action_id.is_empty():
		return

	if _request_coordinated_clip(
		action_id,
		"roaming",
		ACTION_PRIORITY_ROAMING,
		true,
		PetState.ROAMING
	):
		if not roaming_controller.mark_started(action_id):
			_cancel_active_action()
			_return_to_idle(false)
	else:
		roaming_controller.cancel()


func _set_roaming_enabled(value: bool) -> void:
	if value and not roaming_controller.is_available():
		settings_store.set_value("roaming_enabled", false)
		bubble.say("桌面漫游素材还没准备好。", 2.4)
		return

	if not value:
		_interrupt_roaming()
	roaming_controller.set_enabled(value)
	settings_store.set_value("roaming_enabled", value)
	bubble.say("桌面漫游已%s。" % ("开启" if value else "关闭"), 2.4)


func _set_autonomous_paused(value: bool) -> void:
	if random_actions_paused == value:
		return
	random_actions_paused = value
	settings_store.set_value("random_actions_paused", value)
	# Keep water, meal and weather reminders operating independently.
	reminder_manager.set_chatter_paused(value)
	if value:
		_interrupt_roaming()
	else:
		_schedule_next_idle_action()
		roaming_controller.cancel()


func _interrupt_roaming() -> void:
	if state != PetState.ROAMING and not roaming_controller.is_active():
		return

	roaming_controller.cancel()
	if state == PetState.ROAMING and sequence_running:
		_cancel_active_action()
	if state == PetState.ROAMING:
		_return_to_idle(false)
	_persist_window_position()


func _process(delta: float) -> void:
	# dsh-pet advances Q-bounce on its shared ~60 fps interaction tick rather
	# than as a one-shot animation. Updating it before early returns keeps the
	# bounce fluid even while another click/drag input is being processed.
	_update_click_squash(delta)
	_update_inactivity_rest()
	_update_runtime_video_hit_frame()

	if pointer_pressed:
		_update_drag(delta)
		return

	if state == PetState.THROWING:
		_update_throw(delta)
		return

	_update_roaming(delta)
	if state == PetState.ROAMING:
		return

	if state == PetState.IDLE and not sequence_running:
		if _idle_runtime_is_ready():
			if not _runtime_video_is_active() or active_video_action_id != "idle":
				_start_idle_runtime_video()
		elif _idle_video_is_ready():
			_update_idle_video(delta)

		var idle_cfg := config.get("idle_actions", {}) as Dictionary
		if (
			bool(idle_cfg.get("enabled", true))
			and not random_actions_paused
			and not overlay_interactive
			and not bubble_interactive
		):
			idle_action_countdown_sec -= delta
			if idle_action_countdown_sec <= 0.0:
				_schedule_next_idle_action()
				_start_random_idle_action()
				return


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if overlay_interactive:
			command_bubble.call("hide_card")
			weather_bubble.call("hide_card")
			_hide_nickname_card()
			context_menu.call("hide_menu")
		else:
			_quit_pet()
		return

	if overlay_interactive and event is InputEventMouseButton:
		if (
			context_menu.visible
			and event.pressed
			and not bool(context_menu.call("contains_point", event.position))
		):
			context_menu.call("hide_menu")
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_register_user_activity()
		# Restore the original desktop-pet interaction: the context menu opens
		# at one stable position beside the character, independent of cursor.
		_open_control_menu(CONTEXT_MENU_FIXED_ANCHOR)
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag()
		else:
			_end_drag()


func _begin_drag() -> void:
	if pointer_pressed:
		return
	_register_user_activity()
	if sleep_phase != "none":
		_interrupt_sleep_by_user()
		return

	pointer_pressed = true
	dragging = false
	drag_moved = false
	drag_mouse_start = DisplayServer.mouse_get_position()

	var window_pos := DisplayServer.window_get_position()
	drag_window_start = Vector2(window_pos.x, window_pos.y)
	drag_current_position = drag_window_start
	drag_target_position = drag_window_start
	drag_velocity = Vector2.ZERO

	if state == PetState.THROWING:
		state = PetState.IDLE
		throw_velocity = Vector2.ZERO

	if sequence_running:
		_cancel_active_action()
		state = PetState.IDLE

func _update_drag(delta: float) -> void:
	var mouse_now := DisplayServer.mouse_get_position()
	var offset_i := mouse_now - drag_mouse_start
	var offset := Vector2(offset_i.x, offset_i.y)

	if not dragging:
		if offset.length() < float(drag_threshold_px):
			return

		dragging = true
		drag_moved = true
		_say_event_feedback("drag_start")
		_cancel_active_action()
		state = PetState.DRAGGING

		var current_pos := DisplayServer.window_get_position()
		drag_current_position = Vector2(current_pos.x, current_pos.y)
		drag_velocity = Vector2.ZERO

		var interaction := config.get("interaction", {}) as Dictionary
		var drag_action := str(interaction.get("drag_action", ""))
		if not drag_action.is_empty():
			_request_coordinated_clip(
				drag_action,
				"drag",
				ACTION_PRIORITY_DRAG,
				false,
				PetState.DRAGGING
			)

	drag_target_position = drag_window_start + offset

	var motion := PetDragThrowMotion.step_drag(
		drag_current_position,
		drag_target_position,
		drag_velocity,
		delta,
		config
	)
	drag_velocity = motion.get("velocity", drag_velocity)
	drag_current_position = motion.get("position", drag_current_position)

	DisplayServer.window_set_position(Vector2i(
		roundi(drag_current_position.x),
		roundi(drag_current_position.y)
	))


func _end_drag() -> void:
	if not pointer_pressed:
		return

	pointer_pressed = false

	if dragging:
		dragging = false
		if sequence_running:
			_cancel_active_action()
		_start_throw_or_idle()
		if state != PetState.THROWING:
			_persist_window_position()
			_say_event_feedback("drag_end")
	else:
		# Trigger only after a completed click. This prevents drag starts and a
		# fast double-click from restarting the reaction on mouse-down.
		_trigger_click_reaction()


func _cancel_active_action(
	clear_coordinator: bool = true,
	preserve_visual_transform: bool = false,
	preserve_visual_content: bool = false
) -> void:
	sequence_token += 1
	sequence_running = false
	active_clip_id = ""
	active_clip_uses_visual_fade = false
	_cancel_action_visual_fade(not preserve_visual_content)
	if clear_coordinator:
		action_coordinator.cancel("cancelled")

	if not preserve_visual_transform:
		_reset_visual_transform()
	if preserve_visual_content:
		return

	if _runtime_video_is_active():
		_hide_runtime_video()
	_reset_idle_video()
	if not _start_idle_runtime_video():
		pet_sprite.texture = (
			idle_video_textures[idle_video_frame]
			if _idle_video_is_ready()
			else master_texture
		)
		pet_sprite.modulate = Color.WHITE
		pet_sprite_next.modulate.a = 0.0
		pet_sprite_next.texture = null


func _start_throw_or_idle() -> void:
	var launch := PetDragThrowMotion.prepare_throw(drag_velocity, config)
	if bool(launch.get("assign_velocity", false)):
		throw_velocity = launch.get("velocity", throw_velocity)
	if not bool(launch.get("should_throw", false)):
		_return_to_idle()
		return

	var current_pos := DisplayServer.window_get_position()
	drag_current_position = Vector2(current_pos.x, current_pos.y)
	state = PetState.THROWING
	sequence_running = false
	_reset_visual_transform()


func _update_throw(delta: float) -> void:
	var motion := PetDragThrowMotion.step_throw(
		drag_current_position,
		throw_velocity,
		delta,
		config,
		DisplayServer.screen_get_usable_rect(),
		base_position
	)
	if not bool(motion.get("enabled", false)):
		_return_to_idle()
		return

	drag_current_position = motion.get("position", drag_current_position)
	throw_velocity = motion.get("velocity", throw_velocity)
	DisplayServer.window_set_position(Vector2i(
		roundi(drag_current_position.x),
		roundi(drag_current_position.y)
	))

	if bool(motion.get("settled", false)):
		_return_to_idle()
		_persist_window_position()
		_say_event_feedback("drag_end")
		return


func _reset_visual_transform() -> void:
	click_squash_active = false
	click_squash_phase = 0
	click_squash_elapsed_sec = 0.0
	click_squash_from_y = 1.0

	pet_visual.position = base_position
	pet_visual.scale = Vector2.ONE * base_scale
	pet_visual.rotation = 0.0
	body_pivot.position = base_body_pivot_position
	body_pivot.scale = Vector2.ONE
	body_pivot.rotation = 0.0
	_configure_mouse_passthrough()


func _ease_out_back(t: float) -> float:
	# Standard easeOutBack (same family used by dsh-pet): slight overshoot
	# above 1.0, then settle without a second hard snap.
	var c1 := 1.70158
	var c3 := c1 + 1.0
	var x := t - 1.0
	return 1.0 + c3 * x * x * x + c1 * x * x


func _update_click_squash(delta: float) -> void:
	if not click_squash_active:
		return

	var dt := minf(maxf(delta, 0.0), 1.0 / 30.0)
	click_squash_elapsed_sec += dt

	if click_squash_phase == 0:
		var t := clampf(
			click_squash_elapsed_sec / CLICK_SQUASH_COMPRESS_SEC,
			0.0,
			1.0
		)
		# Smoothly continue from the *current* scale. This is the important
		# continuous-click behaviour: retriggering never teleports from a rebound
		# frame straight to 55%, it compresses from wherever the previous bounce
		# currently is.
		var eased := 1.0 - pow(1.0 - t, 2.0)
		var y := lerpf(click_squash_from_y, CLICK_SQUASH_SCALE_Y, eased)
		body_pivot.scale = Vector2(1.0, y)

		if t >= 1.0:
			click_squash_phase = 1
			click_squash_elapsed_sec = 0.0
			body_pivot.scale = Vector2(1.0, CLICK_SQUASH_SCALE_Y)
		_configure_mouse_passthrough()
		return

	var rebound_t := clampf(
		click_squash_elapsed_sec / CLICK_SQUASH_REBOUND_SEC,
		0.0,
		1.0
	)
	var rebound_y := lerpf(
		CLICK_SQUASH_SCALE_Y,
		1.0,
		_ease_out_back(rebound_t)
	)
	body_pivot.scale = Vector2(1.0, rebound_y)

	if rebound_t >= 1.0:
		click_squash_active = false
		click_squash_phase = 0
		click_squash_elapsed_sec = 0.0
		click_squash_from_y = 1.0
		body_pivot.scale = Vector2.ONE
	_configure_mouse_passthrough()


func _start_click_squash() -> void:
	# dsh-pet's Q-bounce is repeatable on continuous clicks. Restart the curve
	# from the current Y scale rather than snapping to a fixed start frame.
	if bool(config.get("reduce_motion", false)):
		return

	body_pivot.position = base_body_pivot_position
	body_pivot.rotation = 0.0
	click_squash_from_y = clampf(body_pivot.scale.y, CLICK_SQUASH_SCALE_Y, 1.12)
	click_squash_phase = 0
	click_squash_elapsed_sec = 0.0
	click_squash_active = true


func _schedule_next_idle_action() -> void:
	var idle_cfg := config.get("idle_actions", {}) as Dictionary
	var interval := idle_cfg.get("interval_sec", [7.0, 13.0]) as Array
	var min_sec := 7.0
	var max_sec := 13.0

	if interval.size() >= 2:
		min_sec = float(interval[0])
		max_sec = float(interval[1])

	idle_action_countdown_sec = rng.randf_range(min_sec, max_sec)


func _start_random_idle_action() -> void:
	if random_actions_paused or bool(config.get("reduce_motion", false)):
		return

	var idle_cfg := config.get("idle_actions", {}) as Dictionary
	var actions := idle_cfg.get("actions", []) as Array
	if actions.is_empty():
		return

	var candidates: Array[Dictionary] = []

	for item in actions:
		var action := item as Dictionary
		var action_id := str(action.get("id", ""))
		# Drowsiness belongs to the independent inactivity/sleep subsystem.
		if action_id == "sleepy_video" or not action_registry.is_action_ready(action_id):
			continue
		var resolved_id: String = action_registry.resolve_action_id(action_id)
		if resolved_id.is_empty() or not clips.has(resolved_id):
			continue
		var weight := maxf(0.0, float(action.get("weight", 1.0)))
		if weight <= 0.0:
			continue
		candidates.append({
			"id": action_id,
			"weight": weight,
			"category": str(action.get("category", ""))
		})

	# After two consecutive actions of one category the next successful draw
	# must come from another category, even if individual actions differ.
	var blocked_category := last_idle_action_category if idle_category_streak >= 2 else ""
	var chosen_id := PetIdleActionPicker.choose(
		candidates, rng.randf(), last_idle_action_id, blocked_category
	)
	if chosen_id.is_empty():
		return
	if not _request_coordinated_clip(
		chosen_id,
		"idle",
		ACTION_PRIORITY_IDLE,
		true,
		PetState.REACTION
	):
		return

	# Never count a request rejected by the action coordinator as played.
	var chosen_category := ""
	for candidate in candidates:
		if str(candidate["id"]) == chosen_id:
			chosen_category = str(candidate["category"])
			break
	last_idle_action_id = chosen_id
	if chosen_category == last_idle_action_category:
		idle_category_streak += 1
	else:
		last_idle_action_category = chosen_category
		idle_category_streak = 1


func _is_sequence_token_current(token: int) -> bool:
	return token == sequence_token


func _cancel_action_visual_fade(restore_alpha: bool = true) -> void:
	animation_playback.cancel_visual_fade(restore_alpha)


func _fade_action_visual_alpha(
	target_alpha: float,
	duration_sec: float,
	token: int
) -> bool:
	return await animation_playback.fade_visual_alpha(
		target_alpha,
		duration_sec,
		token,
		bool(config.get("reduce_motion", false))
	)


func _is_sleep_transition_clip_id(clip_id: String) -> bool:
	for action_id in ["sleep_down", "sleep_loop", "wake_up"]:
		var runtime_id := str(action_registry.resolve_action_id(action_id))
		if clip_id == action_id or (not runtime_id.is_empty() and clip_id == runtime_id):
			return true
	return false


func _should_use_action_visual_fade(
	clip_id: String,
	source: String,
	target_state: PetState
) -> bool:
	if bool(config.get("reduce_motion", false)):
		return false
	if source in ["click", "drag", "roaming", "sleep_chain", "sleep_complete", "sleep_interrupt"]:
		return false
	if target_state in [PetState.SLEEPING, PetState.WAKING]:
		return false
	return not _is_sleep_transition_clip_id(clip_id)


func _return_to_idle_after_action(token: int, use_visual_fade: bool) -> void:
	if token != sequence_token:
		return
	if not use_visual_fade:
		_return_to_idle(false)
		return

	if not await _fade_action_visual_alpha(
		ACTION_VISUAL_FADE_MIN_ALPHA,
		ACTION_VISUAL_FADE_OUT_SEC,
		token
	):
		return
	if token != sequence_token:
		return

	# Swap to idle at the dimmed transition midpoint. The idle hit shape changes
	# at the same moment, so visible pixels and mouse passthrough stay aligned.
	_return_to_idle(false, true)
	if token != sequence_token:
		return
	await _fade_action_visual_alpha(
		1.0,
		ACTION_VISUAL_FADE_IN_SEC,
		token
	)


func _transition_to_video_texture(texture: Texture2D, token: int) -> void:
	await animation_playback.transition_to_texture(texture, token)


func _start_clip_sequence(
	clip_id: String,
	target_state: PetState,
	return_to_idle_after: bool,
	preserve_visual_transform: bool = false,
	use_visual_fade: bool = false
) -> void:
	var clip := clips.get(clip_id, {}) as Dictionary
	if str(clip.get("source_type", "")) != "green_screen_video":
		return
	if str(clip.get("render_mode", "")) != "direct":
		return

	var frames_dir := str(clip.get("frames_dir", ""))
	if not frames_dir.begins_with("res://assets_display/wuzi_chibi/video_"):
		return

	var frame_paths := clip.get("frame_paths", []) as Array
	if frame_paths.is_empty():
		return

	sequence_token += 1
	var token: int = sequence_token
	sequence_running = true
	active_clip_id = clip_id
	active_clip_uses_visual_fade = use_visual_fade
	state = target_state
	if not preserve_visual_transform:
		_reset_visual_transform()
	var loop_limit := 0
	var sleep_loop_id: String = action_registry.resolve_action_id("sleep_loop")
	if sleep_phase == "looping" and clip_id == sleep_loop_id:
		loop_limit = inactivity_manager.sleep_loop_cycles
	_run_clip_sequence(
		clip,
		token,
		return_to_idle_after,
		clip_id,
		bool(clip.get("loop", false)),
		loop_limit,
		use_visual_fade
	)


func _run_clip_sequence(
	clip: Dictionary,
	token: int,
	return_to_idle_after: bool,
	clip_id: String,
	loop_playback: bool,
	loop_limit: int = 0,
	use_visual_fade: bool = false
) -> void:
	var result := await animation_playback.play_clip(
		clip,
		token,
		clip_id,
		loop_playback,
		loop_limit,
		use_visual_fade,
		video_runtime_enabled,
		bool(config.get("reduce_motion", false)),
		ACTION_VISUAL_FADE_MIN_ALPHA,
		ACTION_VISUAL_FADE_OUT_SEC,
		ACTION_VISUAL_FADE_IN_SEC
	) as Dictionary
	if token != sequence_token or str(result.get("status", "")) != "finished":
		return

	action_coordinator.mark_finished(clip_id)
	active_clip_id = ""

	if not return_to_idle_after:
		sequence_running = false
		_on_nonreturning_clip_finished(clip_id, token)
		return

	if use_visual_fade:
		await _return_to_idle_after_action(token, true)
		return

	if str(result.get("backend", "")) == "direct":
		_reset_idle_video()
		var idle_texture: Texture2D = master_texture
		if _idle_video_is_ready():
			idle_texture = idle_video_textures[idle_video_frame]
		await _transition_to_video_texture(idle_texture, token)
		if token == sequence_token:
			_return_to_idle(false)
		return

	_return_to_idle(false)


func _trigger_click_reaction() -> void:
	var now_ms := Time.get_ticks_msec()
	var click: Dictionary = mood_manager.register_click(now_ms) as Dictionary
	var tier := str(click.get("tier", "normal"))
	var click_cfg := config.get("click_reactions", {}) as Dictionary

	var action_id := str(click.get("action_id", "click_happy_video"))
	match tier:
		"shy":
			action_id = str(click_cfg.get("shy_action", action_id))
		"angry":
			action_id = str(click_cfg.get("angry_action", action_id))
		_:
			action_id = str(click_cfg.get("normal_action", action_id))

	var tier_changed := tier != last_reaction_tier
	var cooldown_sec := float(click_cfg.get("cooldown_sec", 0.5))

	# Every click counts toward the mood tier and retriggers Q-bounce even while
	# the longer video is cooling down. Escalating to shy/angry can play at once.
	if now_ms >= reaction_cooldown_until_ms or tier_changed:
		if _request_coordinated_clip(
			action_id,
			"click",
			ACTION_PRIORITY_CLICK,
			true,
			PetState.REACTION,
			true
		):
			last_reaction_id = action_id
			last_reaction_tier = tier
			reaction_cooldown_until_ms = now_ms + int(cooldown_sec * 1000.0)

	_start_click_squash()
	if int(click.get("click_count", 0)) >= 6 and (
		int(click.get("click_count", 0)) == 6
		or now_ms - last_rapid_click_line_ms >= RAPID_CLICK_LINE_COOLDOWN_MS
	):
		_say_event_feedback("click_spam", 3.0)
		last_rapid_click_line_ms = now_ms


func _return_to_idle(
	cancel_sequence: bool = true,
	preserve_visual_alpha: bool = false
) -> void:
	var ended_sleep_session := sleep_phase != "none"
	if cancel_sequence:
		sequence_token += 1
	if not preserve_visual_alpha:
		_cancel_action_visual_fade(true)
	# A fresh interval begins after any action finishes (including roaming and
	# direct user interactions), never halfway through the previous animation.
	_schedule_next_idle_action()

	sequence_running = false
	active_clip_id = ""
	active_clip_uses_visual_fade = false
	sleep_phase = "none"
	state = PetState.IDLE
	if ended_sleep_session:
		inactivity_manager.finish_sleep(Time.get_ticks_msec())
	_reset_visual_transform()
	_reset_idle_video()

	if not _start_idle_runtime_video():
		_hide_runtime_video()
		# Return directly to the first idle-video frame. Going through master_texture
		# for one frame caused the visible white/pose flash between action and idle.
		pet_sprite.texture = (
			idle_video_textures[idle_video_frame]
			if _idle_video_is_ready()
			else master_texture
		)
		pet_sprite.modulate = Color.WHITE
		pet_sprite_next.modulate.a = 0.0
		pet_sprite_next.texture = null


func _on_mood_changed(mood: String, score: float) -> void:
	mood_indicator.call("set_mood", mood, score)


func _request_coordinated_clip(
	action_id: String,
	source: String,
	priority: int,
	return_to_idle_after: bool,
	target_state: PetState,
	preserve_visual_transform: bool = false
) -> bool:
	var request := action_coordinator.request_action(
		action_id,
		source,
		priority
	) as Dictionary
	if not bool(request.get("accepted", false)):
		return false

	var runtime_id := str(request.get("action_id", ""))
	if runtime_id.is_empty() or not clips.has(runtime_id):
		action_coordinator.mark_finished(runtime_id)
		return false

	var use_visual_fade := _should_use_action_visual_fade(
		runtime_id,
		source,
		target_state
	)
	if sequence_running:
		var preserve_visual_content := (
			use_visual_fade
			and active_clip_uses_visual_fade
		)
		_cancel_active_action(
			false,
			preserve_visual_transform,
			preserve_visual_content
		)

	_start_clip_sequence(
		runtime_id,
		target_state,
		return_to_idle_after,
		preserve_visual_transform,
		use_visual_fade
	)
	if not sequence_running:
		action_coordinator.mark_finished(runtime_id)
		return false
	return true


func _start_sleep_entry(source: String, priority: int) -> bool:
	if sleep_phase != "none":
		return false
	sleep_phase = "entering"
	inactivity_manager.set_sleep_frozen(true)
	if not _request_coordinated_clip(
		"sleep_down",
		source,
		priority,
		false,
		PetState.SLEEPING
	):
		sleep_phase = "none"
		inactivity_manager.set_sleep_frozen(false)
		return false
	return true


func _sleep_loop_ready() -> bool:
	if not action_registry.is_action_ready("sleep_loop"):
		return false
	if not action_registry.is_action_ready("wake_up"):
		return false
	var loop_id: String = action_registry.resolve_action_id("sleep_loop")
	var wake_id: String = action_registry.resolve_action_id("wake_up")
	return (
		not loop_id.is_empty()
		and not wake_id.is_empty()
		and clips.has(loop_id)
		and clips.has(wake_id)
	)


func _on_nonreturning_clip_finished(clip_id: String, _token: int) -> void:
	var sleep_down_id: String = action_registry.resolve_action_id("sleep_down")
	var sleep_loop_id: String = action_registry.resolve_action_id("sleep_loop")
	if clip_id == sleep_down_id and sleep_phase == "entering":
		if _sleep_loop_ready():
			sleep_phase = "looping"
			if not _request_coordinated_clip(
				"sleep_loop",
				"sleep_chain",
				ACTION_PRIORITY_SLEEP,
				false,
				PetState.SLEEPING
			):
				sleep_phase = "waiting_loop"
				state = PetState.SLEEPING
		else:
			# Missing sleep-loop/wake assets: keep the final sleeping frame.
			# The next user interaction returns directly to idle instead of
			# pretending a wake animation exists.
			sleep_phase = "waiting_loop"
			state = PetState.SLEEPING
	elif clip_id == sleep_loop_id and sleep_phase == "looping":
		_stop_sequence_preserve_frame()
		sleep_phase = "waking"
		if not _request_coordinated_clip(
			"wake_up",
			"sleep_complete",
			ACTION_PRIORITY_WAKE,
			true,
			PetState.WAKING
		):
			_return_to_idle(false)


func _stop_sequence_preserve_frame() -> void:
	sequence_token += 1
	sequence_running = false
	active_clip_id = ""
	action_coordinator.cancel("sleep_interrupt")
	_pause_runtime_video_preserve_frame()
	_reset_visual_transform()
	pet_sprite_next.modulate.a = 0.0
	pet_sprite_next.texture = null


func _interrupt_sleep_by_user() -> void:
	match sleep_phase:
		"entering", "waiting_loop":
			# User rule: interrupting the enter-sleep animation goes straight
			# back to the default idle state.
			_cancel_active_action()
			_return_to_idle(false)
		"looping":
			# User rule: interrupting the actual sleep loop must wake through
			# the dedicated wake-up animation, never snap directly to idle.
			_stop_sequence_preserve_frame()
			sleep_phase = "waking"
			if not _request_coordinated_clip(
				"wake_up",
				"sleep_interrupt",
				ACTION_PRIORITY_WAKE,
				true,
				PetState.WAKING
			):
				_return_to_idle(false)
		"waking":
			pass
		_:
			sleep_phase = "none"


func _register_user_activity(now_ms: int = -1) -> void:
	inactivity_manager.note_user_activity(now_ms)
	_schedule_next_idle_action()
	_interrupt_roaming()


func _is_sleep_dream_state() -> bool:
	return sleep_phase in ["entering", "waiting_loop", "looping", "waking"]


func _update_inactivity_rest() -> void:
	if random_actions_paused:
		return
	if sleep_phase != "none" or state != PetState.IDLE or sequence_running:
		return

	var now_ms := Time.get_ticks_msec()
	if not inactivity_manager.should_check_rest(now_ms):
		return

	inactivity_manager.schedule_next_rest_check(rng, now_ms)
	var decision := inactivity_manager.choose_long_idle_action(rng.randf(), rng.randf())
	if decision == "sleep":
		_start_sleep_entry("inactivity", ACTION_PRIORITY_SLEEP)
	elif decision == "sleepy":
		_request_coordinated_clip(
			"sleepy_video",
			"inactivity",
			ACTION_PRIORITY_IDLE,
			true,
			PetState.REACTION
		)
