   1 | extends Node2D
   2 | 
   3 | enum PetState { IDLE, REACTION, DRAGGING, THROWING, ROAMING, SLEEPING, WAKING }
   4 | 
   5 | const InputGuard = preload("res://scripts/input_guard.gd")
   6 | const DialogueManager = preload("res://scripts/dialogue_manager.gd")
   7 | const InactivityManager = preload("res://scripts/inactivity_manager.gd")
   8 | const DreamTalkManager = preload("res://scripts/dream_talk_manager.gd")
   9 | const DynamicHitShapeManager = preload("res://scripts/dynamic_hit_shape_manager.gd")
  10 | const BatchFileWindow = preload("res://scripts/batch_file_window.gd")
  11 | const PetWindowLayout = preload("res://scripts/pet_window_layout.gd")
  12 | const PetContextMenu = preload("res://scripts/pet_context_menu.gd")
  13 | const PetDragThrowMotion = preload("res://scripts/pet_drag_throw_motion.gd")
  14 | const WeatherReplyFormatter = preload("res://scripts/weather_reply_formatter.gd")
  15 | const PetClipCatalogLoader = preload("res://scripts/pet_clip_catalog_loader.gd")
  16 | const PetMovementCatalogLoader = preload("res://scripts/pet_movement_catalog_loader.gd")
  17 | const PetRoamingController = preload("res://scripts/pet_roaming_controller.gd")
  18 | const PetAnimationPlayback = preload("res://scripts/pet_animation_playback.gd")
  19 | const PetIdleActionPicker = preload("res://scripts/pet_idle_action_picker.gd")
  20 | 
  21 | var dialogue_manager := DialogueManager.new()
  22 | var inactivity_manager := InactivityManager.new()
  23 | var dream_talk_manager := DreamTalkManager.new()
  24 | var dynamic_hit_shape_manager := DynamicHitShapeManager.new()
  25 | var roaming_controller := PetRoamingController.new()
  26 | var animation_playback := PetAnimationPlayback.new()
  27 | var nickname_card: Control
  28 | var batch_file_window: Window
  29 | 
  30 | @onready var pet_visual: Node2D = $PetVisual
  31 | @onready var body_pivot: Node2D = $PetVisual/BodyPivot
  32 | @onready var pet_sprite: Sprite2D = $PetVisual/BodyPivot/PetSprite
  33 | @onready var pet_sprite_next: Sprite2D = $PetVisual/BodyPivot/PetSpriteNext
  34 | @onready var pet_video: VideoStreamPlayer = $PetVisual/BodyPivot/PetVideo
  35 | @onready var bubble = $Bubble
  36 | @onready var context_menu: Control = $ContextBubble
  37 | @onready var command_bubble: Control = $CommandBubble
  38 | @onready var command_input: LineEdit = $CommandBubble/Card/Margin/Content/CommandInput
  39 | @onready var command_cancel: Button = $CommandBubble/Card/Margin/Content/Actions/Cancel
  40 | @onready var command_send: Button = $CommandBubble/Card/Margin/Content/Actions/Send
  41 | @onready var weather_bubble: Control = $WeatherBubble
  42 | @onready var weather_city: LineEdit = $WeatherBubble/Card/Margin/Content/City
  43 | @onready var weather_enabled: CheckButton = $WeatherBubble/Card/Margin/Content/Enabled
  44 | @onready var weather_cancel: Button = $WeatherBubble/Card/Margin/Content/Actions/Cancel
  45 | @onready var weather_save: Button = $WeatherBubble/Card/Margin/Content/Actions/Save
  46 | @onready var settings_store = $SettingsStore
  47 | @onready var reminder_manager = $ReminderManager
  48 | @onready var file_drop_manager = $FileDropManager
  49 | @onready var action_registry = $ActionRegistry
  50 | @onready var mood_manager = $MoodManager
  51 | @onready var action_coordinator = $ActionCoordinator
  52 | @onready var mood_indicator: Control = $MoodIndicator
  53 | @onready var weather_manager = $WeatherManager
  54 | 
  55 | var config: Dictionary = {}
  56 | var feature_config: Dictionary = {}
  57 | var clips: Dictionary = {}
  58 | var movement_catalog: Dictionary = {}
  59 | var idle_video_textures: Array[Texture2D] = []
  60 | var idle_video_frame := 0
  61 | var idle_video_accum_sec := 0.0
  62 | var idle_runtime_stream: VideoStream
  63 | var video_runtime_enabled := false
  64 | var active_video_action_id := ""
  65 | var active_video_fps := 12.0
  66 | var active_video_frame_count := 0
  67 | var rng := RandomNumberGenerator.new()
  68 | 
  69 | var state: PetState = PetState.IDLE
  70 | var master_texture: Texture2D
  71 | var base_scale := 1.0
  72 | var base_position := Vector2(550, 210)
  73 | var base_body_pivot_position := Vector2(0, 161)
  74 | 
  75 | var idle_action_countdown_sec := 9.0
  76 | var last_idle_action_id := ""
  77 | var last_idle_action_category := ""
  78 | var idle_category_streak := 0
  79 | # Existing persisted preference; now pauses all autonomous behavior.
  80 | var random_actions_paused := false
  81 | 
  82 | const MENU_TOGGLE_RANDOM := PetContextMenu.MENU_TOGGLE_RANDOM
  83 | const MENU_RESET_POSITION := PetContextMenu.MENU_RESET_POSITION
  84 | const MENU_EXIT := PetContextMenu.MENU_EXIT
  85 | const MENU_TALK := PetContextMenu.MENU_TALK
  86 | const MENU_TOGGLE_REMINDERS := PetContextMenu.MENU_TOGGLE_REMINDERS
  87 | const MENU_PLAY_ACTION := PetContextMenu.MENU_PLAY_ACTION
  88 | const MENU_ACTION_BACK := PetContextMenu.MENU_ACTION_BACK
  89 | const MENU_FILE_WORKBENCH := PetContextMenu.MENU_FILE_WORKBENCH
  90 | const MENU_CLEAR_FILES := PetContextMenu.MENU_CLEAR_FILES
  91 | const MENU_WEATHER_SETTINGS := PetContextMenu.MENU_WEATHER_SETTINGS
  92 | const MENU_WEATHER_NOW := PetContextMenu.MENU_WEATHER_NOW
  93 | const MENU_SETTINGS := PetContextMenu.MENU_SETTINGS
  94 | const MENU_NICKNAME := PetContextMenu.MENU_NICKNAME
  95 | const MENU_ACTION_CATEGORY_BACK := PetContextMenu.MENU_ACTION_CATEGORY_BACK
  96 | const MENU_TOGGLE_ROAMING := PetContextMenu.MENU_TOGGLE_ROAMING
  97 | const MENU_ACTION_PAGE_UP := PetContextMenu.MENU_ACTION_PAGE_UP
  98 | const MENU_ACTION_PAGE_DOWN := PetContextMenu.MENU_ACTION_PAGE_DOWN
  99 | const ACTION_CATEGORY_MENU_BASE := PetContextMenu.ACTION_CATEGORY_MENU_BASE
 100 | const ACTION_MENU_BASE := PetContextMenu.ACTION_MENU_BASE
 101 | const CONTEXT_MENU_FIXED_ANCHOR := PetContextMenu.CONTEXT_MENU_FIXED_ANCHOR
 102 | 
 103 | const ACTION_PRIORITY_IDLE := 10
 104 | const ACTION_PRIORITY_ROAMING := 20
 105 | const ACTION_PRIORITY_DIALOGUE := 50
 106 | const ACTION_PRIORITY_CLICK := 60
 107 | const ACTION_PRIORITY_SLEEP := 80
 108 | const ACTION_PRIORITY_MANUAL := 90
 109 | const ACTION_PRIORITY_DRAG := 100
 110 | const ACTION_PRIORITY_WAKE := 110
 111 | 
 112 | var sequence_token := 0
 113 | var sequence_running := false
 114 | var active_clip_uses_visual_fade := false
 115 | const ACTION_VISUAL_FADE_MIN_ALPHA := 0.55
 116 | const ACTION_VISUAL_FADE_OUT_SEC := 0.045
 117 | const ACTION_VISUAL_FADE_IN_SEC := 0.060
 118 | 
 119 | var last_reaction_id := ""
 120 | var last_reaction_tier := ""
 121 | var reaction_cooldown_until_ms := 0
 122 | var last_rapid_click_line_ms := -100000
 123 | const RAPID_CLICK_LINE_COOLDOWN_MS := 1500
 124 | var active_clip_id := ""
 125 | var sleep_phase := "none"
 126 | 
 127 | # dsh-pet style Q-bounce state. Keep this independent from the click-reaction
 128 | # video cooldown so every completed click can retrigger the tactile feedback.
 129 | var click_squash_active := false
 130 | var click_squash_phase := 0
 131 | var click_squash_elapsed_sec := 0.0
 132 | var click_squash_from_y := 1.0
 133 | const CLICK_SQUASH_SCALE_Y := 0.55
 134 | const CLICK_SQUASH_COMPRESS_SEC := 0.055
 135 | const CLICK_SQUASH_REBOUND_SEC := 0.285
 136 | 
 137 | var pointer_pressed := false
 138 | var dragging := false
 139 | var drag_moved := false
 140 | var drag_mouse_start := Vector2i.ZERO
 141 | var drag_window_start := Vector2.ZERO
 142 | var drag_current_position := Vector2.ZERO
 143 | var drag_target_position := Vector2.ZERO
 144 | var drag_velocity := Vector2.ZERO
 145 | var throw_velocity := Vector2.ZERO
 146 | var drag_threshold_px := 12
 147 | 
 148 | var bubble_interactive := false
 149 | var overlay_interactive := false
 150 | var debug_last_passthrough_polygon := PackedVector2Array()
 151 | var debug_character_passthrough_polygon := PackedVector2Array()
 152 | var active_hit_action_id := "idle"
 153 | var active_hit_frame := 0
 154 | var dynamic_hit_shapes_ready := false
 155 | var context_menu_anchor := Vector2.ZERO
 156 | var manual_action_map: Dictionary = {}
 157 | var manual_category_map: Dictionary = {}
 158 | 
 159 | 
 160 | func _ready() -> void:
 161 | 	rng.randomize()
 162 | 	animation_playback.name = "PetAnimationPlayback"
 163 | 	add_child(animation_playback)
 164 | 	animation_playback.configure(
 165 | 		pet_sprite,
 166 | 		pet_sprite_next,
 167 | 		pet_video,
 168 | 		body_pivot,
 169 | 		Callable(self, "_is_sequence_token_current"),
 170 | 		Callable(self, "_show_runtime_video"),
 171 | 		Callable(self, "_hide_runtime_video"),
 172 | 		Callable(self, "_set_active_hit_frame")
 173 | 	)
 174 | 	settings_store.load_settings()
 175 | 	_load_config()
 176 | 	_load_feature_config()
 177 | 	base_position = pet_visual.position
 178 | 	PetWindowLayout.configure(get_viewport(), config, settings_store, base_position)
 179 | 	_load_clips()
 180 | 	_load_dynamic_hit_shapes()
 181 | 	_load_idle_video()
 182 | 	_load_movement_catalog()
 183 | 	action_registry.load_catalog()
 184 | 	_configure_feature_modules()
 185 | 
 186 | 	base_scale = float(config.get("sprite_scale", 1.0))
 187 | 	base_position = pet_visual.position
 188 | 	base_body_pivot_position = body_pivot.position
 189 | 	pet_visual.scale = Vector2.ONE * base_scale
 190 | 	var interaction := config.get("interaction", {}) as Dictionary
 191 | 	drag_threshold_px = int(interaction.get("drag_threshold_px", 12))
 192 | 
 193 | 	master_texture = load(str(config.get("master_texture", ""))) as Texture2D
 194 | 	if master_texture == null:
 195 | 		push_error("Failed to load master texture")
 196 | 		get_tree().quit(2)
 197 | 		return
 198 | 
 199 | 	pet_sprite.texture = master_texture
 200 | 	pet_sprite_next.texture = null
 201 | 	pet_sprite.modulate = Color.WHITE
 202 | 	pet_sprite_next.modulate.a = 0.0
 203 | 
 204 | 	_configure_mouse_passthrough()
 205 | 	_setup_control_menu()
 206 | 	_schedule_next_idle_action()
 207 | 	_return_to_idle(false)
 208 | 	call_deferred("_try_auto_birthday_easter_egg")
 209 | 
 210 | 
 211 | func _load_config() -> void:
 212 | 	var file := FileAccess.open("res://config/pet_behavior.json", FileAccess.READ)
 213 | 	if file == null:
 214 | 		push_error("Unable to open pet_behavior.json")
 215 | 		get_tree().quit(2)
 216 | 		return
 217 | 
 218 | 	var parsed: Variant = JSON.parse_string(file.get_as_text())
 219 | 	if typeof(parsed) != TYPE_DICTIONARY:
 220 | 		push_error("pet_behavior.json is not a JSON object")
 221 | 		get_tree().quit(2)
 222 | 		return
 223 | 
 224 | 	config = parsed as Dictionary
 225 | 
 226 | 
 227 | func _load_feature_config() -> void:
 228 | 	var file := FileAccess.open("res://config/feature_config.json", FileAccess.READ)
 229 | 	if file == null:
 230 | 		feature_config = {}
 231 | 		push_warning("feature_config.json not found")
 232 | 		return
 233 | 
 234 | 	var parsed: Variant = JSON.parse_string(file.get_as_text())
 235 | 	if typeof(parsed) != TYPE_DICTIONARY:
 236 | 		feature_config = {}
 237 | 		push_warning("feature_config.json is not a JSON object")
 238 | 		return
 239 | 
 240 | 	feature_config = parsed as Dictionary
 241 | 
 242 | 
 243 | func _configure_feature_modules() -> void:
 244 | 	dialogue_manager.load_config()
 245 | 	dream_talk_manager.load_config()
 246 | 	inactivity_manager.configure(
 247 | 		feature_config.get("inactivity", {}) as Dictionary,
 248 | 		Time.get_ticks_msec()
 249 | 	)
 250 | 	var mood_cfg := feature_config.get("mood", {}) as Dictionary
 251 | 	mood_manager.configure(mood_cfg)
 252 | 	mood_indicator.call("configure", mood_cfg)
 253 | 	if not mood_indicator.visibility_changed.is_connected(_on_mood_indicator_visibility_changed):
 254 | 		mood_indicator.visibility_changed.connect(_on_mood_indicator_visibility_changed)
 255 | 	action_coordinator.configure(
 256 | 		action_registry,
 257 | 		feature_config.get("action_coordinator", {}) as Dictionary
 258 | 	)
 259 | 	if not mood_manager.mood_changed.is_connected(_on_mood_changed):
 260 | 		mood_manager.mood_changed.connect(_on_mood_changed)
 261 | 	_on_mood_changed(mood_manager.current_mood, mood_manager.mood_score)
 262 | 	command_input.max_length = InputGuard.MESSAGE_LIMIT
 263 | 	var reminder_cfg := feature_config.get("reminders", {}) as Dictionary
 264 | 	reminder_manager.configure(reminder_cfg)
 265 | 	var stored_reminders := bool(settings_store.get_value(
 266 | 		"reminders_enabled",
 267 | 		bool(reminder_cfg.get("enabled", true))
 268 | 	))
 269 | 	reminder_manager.set_enabled(stored_reminders)
 270 | 
 271 | 	var file_cfg := feature_config.get("file_conversion", {}) as Dictionary
 272 | 	file_drop_manager.configure(file_cfg)
 273 | 
 274 | 	var weather_cfg := feature_config.get("weather", {}) as Dictionary
 275 | 	var stored_weather_variant: Variant = settings_store.get_value("weather", {})
 276 | 	var stored_weather: Dictionary = {}
 277 | 	if typeof(stored_weather_variant) == TYPE_DICTIONARY:
 278 | 		stored_weather = stored_weather_variant as Dictionary
 279 | 	weather_manager.configure(weather_cfg, stored_weather)
 280 | 
 281 | 	random_actions_paused = bool(settings_store.get_value(
 282 | 		"random_actions_paused",
 283 | 		false
 284 | 	))
 285 | 	reminder_manager.set_chatter_paused(random_actions_paused)
 286 | 	var roaming_cfg := config.get("roaming", {}) as Dictionary
 287 | 	var stored_roaming_enabled := bool(settings_store.get_value(
 288 | 		"roaming_enabled",
 289 | 		true
 290 | 	))
 291 | 	roaming_controller.configure(
 292 | 		roaming_cfg,
 293 | 		movement_catalog,
 294 | 		stored_roaming_enabled
 295 | 	)
 296 | 
 297 | 	reminder_manager.reminder_due.connect(_on_reminder_due)
 298 | 	file_drop_manager.queue_changed.connect(_on_file_queue_changed)
 299 | 	weather_manager.weather_updated.connect(_on_weather_updated)
 300 | 	weather_manager.reminder_due.connect(_on_weather_reminder_due)
 301 | 	weather_manager.request_failed.connect(_on_weather_request_failed)
 302 | 	bubble.action_selected.connect(_on_bubble_action_selected)
 303 | 	bubble.interactive_changed.connect(_on_bubble_interactive_changed)
 304 | 	bubble.bounds_changed.connect(_on_bubble_bounds_changed)
 305 | 	command_bubble.interactive_changed.connect(_on_overlay_interactive_changed)
 306 | 	weather_bubble.interactive_changed.connect(_on_overlay_interactive_changed)
 307 | 	context_menu.interactive_changed.connect(_on_overlay_interactive_changed)
 308 | 
 309 | 	if not get_window().files_dropped.is_connected(_on_files_dropped):
 310 | 		get_window().files_dropped.connect(_on_files_dropped)
 311 | 
 312 | 	command_send.pressed.connect(_on_command_send_pressed)
 313 | 	command_cancel.pressed.connect(_on_command_cancel_pressed)
 314 | 	command_input.text_submitted.connect(_on_command_text_submitted)
 315 | 	command_input.text_changed.connect(_on_command_input_changed)
 316 | 	command_input.text_change_rejected.connect(_on_command_input_rejected)
 317 | 
 318 | 	weather_save.pressed.connect(_on_weather_save_pressed)
 319 | 	weather_cancel.pressed.connect(_on_weather_cancel_pressed)
 320 | 
 321 | 
 322 | func _persist_window_position() -> void:
 323 | 	PetWindowLayout.persist_position(settings_store)
 324 | 
 325 | 
 326 | func _setup_control_menu() -> void:
 327 | 	context_menu.item_selected.connect(_on_control_menu_id_pressed)
 328 | 
 329 | 
 330 | func _open_control_menu(local_position: Vector2) -> void:
 331 | 	command_bubble.call("hide_card", false)
 332 | 	weather_bubble.call("hide_card", false)
 333 | 	_hide_nickname_card(false)
 334 | 	context_menu_anchor = local_position
 335 | 	PetContextMenu.open_root(
 336 | 		context_menu,
 337 | 		config,
 338 | 		local_position,
 339 | 		bool(reminder_manager.enabled),
 340 | 		random_actions_paused,
 341 | 		roaming_controller.is_enabled(),
 342 | 		manual_action_map,
 343 | 		manual_category_map
 344 | 	)
 345 | 
 346 | 
 347 | func _open_settings_menu() -> void:
 348 | 	PetContextMenu.open_settings(
 349 | 		context_menu,
 350 | 		context_menu_anchor,
 351 | 		manual_action_map,
 352 | 		manual_category_map
 353 | 	)
 354 | 
 355 | 
 356 | func _open_batch_file_window() -> void:
 357 | 	command_bubble.call("hide_card", false)
 358 | 	weather_bubble.call("hide_card", false)
 359 | 	_hide_nickname_card(false)
 360 | 	context_menu.call("hide_menu", false)
 361 | 	if not is_instance_valid(batch_file_window):
 362 | 		batch_file_window = BatchFileWindow.new()
 363 | 		add_child(batch_file_window)
 364 | 		batch_file_window.feedback_requested.connect(_on_file_feedback_requested)
 365 | 		batch_file_window.call("setup", file_drop_manager)
 366 | 	batch_file_window.call("open_workbench")
 367 | 
 368 | 
 369 | func _open_action_picker() -> void:
 370 | 	PetContextMenu.open_action_picker(
 371 | 		context_menu,
 372 | 		config,
 373 | 		context_menu_anchor,
 374 | 		manual_action_map,
 375 | 		manual_category_map
 376 | 	)
 377 | 
 378 | 
 379 | func _open_action_category(category_id: String, page_index: int = 0) -> void:
 380 | 	PetContextMenu.open_action_category(
 381 | 		context_menu,
 382 | 		config,
 383 | 		context_menu_anchor,
 384 | 		category_id,
 385 | 		manual_action_map,
 386 | 		manual_category_map,
 387 | 		page_index
 388 | 	)
 389 | 
 390 | 
 391 | func _on_control_menu_id_pressed(id: int) -> void:
 392 | 	_register_user_activity()
 393 | 	if id >= ACTION_MENU_BASE:
 394 | 		if sleep_phase != "none":
 395 | 			bubble.say(dream_talk_manager.chat_reply(settings_store.get_nickname()), 3.6)
 396 | 			return
 397 | 		var spec := manual_action_map.get(id, {}) as Dictionary
 398 | 		if not spec.is_empty():
 399 | 			_play_manual_action(spec)
 400 | 		return
 401 | 	if id >= ACTION_CATEGORY_MENU_BASE:
 402 | 		var category_id := str(manual_category_map.get(id, ""))
 403 | 		if not category_id.is_empty():
 404 | 			call_deferred("_open_action_category", category_id)
 405 | 		return
 406 | 
 407 | 	match id:
 408 | 		MENU_TALK:
 409 | 			_open_command_window()
 410 | 		MENU_PLAY_ACTION:
 411 | 			call_deferred("_open_action_picker")
 412 | 		MENU_ACTION_CATEGORY_BACK:
 413 | 			call_deferred("_open_action_picker")
 414 | 		MENU_ACTION_PAGE_UP, MENU_ACTION_PAGE_DOWN:
 415 | 			var navigation := manual_category_map.get(id, {}) as Dictionary
 416 | 			var category_id := str(navigation.get("category_id", ""))
 417 | 			var page_index := int(navigation.get("page_index", 0))
 418 | 			if not category_id.is_empty():
 419 | 				call_deferred(
 420 | 					"_open_action_category",
 421 | 					category_id,
 422 | 					page_index
 423 | 				)
 424 | 		MENU_ACTION_BACK:
 425 | 			call_deferred("_open_control_menu", context_menu_anchor)
 426 | 		MENU_TOGGLE_REMINDERS:
 427 | 			var value: bool = not bool(reminder_manager.enabled)
 428 | 			reminder_manager.set_enabled(value)
 429 | 			settings_store.set_value("reminders_enabled", value)
 430 | 			bubble.say(
 431 | 				"日常提醒已%s。" % ("开启" if value else "关闭"),
 432 | 				2.4
 433 | 			)
 434 | 		MENU_WEATHER_NOW:
 435 | 			_request_weather_now()
 436 | 		MENU_WEATHER_SETTINGS:
 437 | 			_open_weather_window()
 438 | 		MENU_SETTINGS:
 439 | 			call_deferred("_open_settings_menu")
 440 | 		MENU_NICKNAME:
 441 | 			_open_nickname_window()
 442 | 		MENU_FILE_WORKBENCH:
 443 | 			_open_batch_file_window()
 444 | 		MENU_TOGGLE_RANDOM:
 445 | 			_set_autonomous_paused(not random_actions_paused)
 446 | 		MENU_TOGGLE_ROAMING:
 447 | 			_set_roaming_enabled(not roaming_controller.is_enabled())
 448 | 		MENU_CLEAR_FILES:
 449 | 			file_drop_manager.clear_queue()
 450 | 			bubble.say("好啦，拖进来的文件队列清空了～", 2.6)
 451 | 		MENU_RESET_POSITION:
 452 | 			var was_sleeping := sleep_phase != "none"
 453 | 			if was_sleeping:
 454 | 				_interrupt_sleep_by_user()
 455 | 			else:
 456 | 				_cancel_active_action()
 457 | 			throw_velocity = Vector2.ZERO
 458 | 			pointer_pressed = false
 459 | 			dragging = false
 460 | 			_reset_window_position()
 461 | 			_persist_window_position()
 462 | 			if not was_sleeping:
 463 | 				_return_to_idle(false)
 464 | 		MENU_EXIT:
 465 | 			_quit_pet()
 466 | 
 467 | 
 468 | func _play_manual_action(spec: Dictionary) -> void:
 469 | 	var action_id := str(spec.get("id", ""))
 470 | 	var kind := str(spec.get("kind", "clip"))
 471 | 
 472 | 	match kind:
 473 | 		"idle":
 474 | 			_cancel_active_action()
 475 | 			_return_to_idle(false)
 476 | 		"sleep":
 477 | 			_start_sleep_entry("manual", ACTION_PRIORITY_MANUAL)
 478 | 		"clip":
 479 | 			_request_coordinated_clip(
 480 | 				action_id,
 481 | 				"manual",
 482 | 				ACTION_PRIORITY_MANUAL,
 483 | 				true,
 484 | 				PetState.REACTION
 485 | 			)
 486 | 		_:
 487 | 			_cancel_active_action()
 488 | 			_return_to_idle(false)
 489 | 
 490 | 
 491 | func _open_command_window() -> void:
 492 | 	weather_bubble.call("hide_card", false)
 493 | 	_hide_nickname_card(false)
 494 | 	context_menu.call("hide_menu", false)
 495 | 	command_input.clear()
 496 | 	_on_command_input_changed("")
 497 | 	command_bubble.call("popup_card")
 498 | 	# popup_card() makes the control visible synchronously, so focus can be
 499 | 	# assigned immediately instead of waiting another frame.
 500 | 	command_input.grab_focus()
 501 | 
 502 | 
 503 | func _on_command_send_pressed() -> void:
 504 | 	_on_command_text_submitted(command_input.text)
 505 | 
 506 | 
 507 | func _on_command_cancel_pressed() -> void:
 508 | 	command_bubble.call("hide_card")
 509 | 	command_input.clear()
 510 | 
 511 | 
 512 | func _on_command_text_submitted(text: String) -> void:
 513 | 	var checked := InputGuard.check(text, InputGuard.MESSAGE_LIMIT)
 514 | 	if not checked.ok:
 515 | 		if checked.error == "too_long":
 516 | 			_on_command_input_rejected("")
 517 | 		return
 518 | 	_register_user_activity()
 519 | 	command_bubble.call("hide_card")
 520 | 	command_input.clear()
 521 | 	_handle_command_text(text)
 522 | 
 523 | 
 524 | func _handle_command_text(text: String) -> void:
 525 | 	if _is_sleep_dream_state():
 526 | 		bubble.say(
 527 | 			dream_talk_manager.chat_reply(settings_store.get_nickname()),
 528 | 			4.0
 529 | 		)
 530 | 		return
 531 | 
 532 | 	var result := dialogue_manager.submit_message(
 533 | 		text,
 534 | 		settings_store.get_nickname()
 535 | 	)
 536 | 	_apply_dialogue_result(result, "dialogue")
 537 | 
 538 | 
 539 | func _apply_dialogue_result(
 540 | 	result: Dictionary,
 541 | 	source: String
 542 | ) -> void:
 543 | 	if result.is_empty():
 544 | 		return
 545 | 
 546 | 	var mood_event := str(result.get("mood_event", ""))
 547 | 	if not mood_event.is_empty():
 548 | 		mood_manager.apply_event(mood_event)
 549 | 
 550 | 	var reply := str(result.get("text", ""))
 551 | 	if str(result.get("intent", "")) == "mood_query":
 552 | 		# Use the current MoodManager snapshot; static templates can lie.
 553 | 		reply = dialogue_manager.mood_reply(
 554 | 			str(mood_manager.get_snapshot().get("mood", "normal"))
 555 | 		)
 556 | 	if not reply.is_empty():
 557 | 		bubble.say(reply, 4.0)
 558 | 
 559 | 	var action_request := str(result.get("action_request", ""))
 560 | 	if action_request == "sleep_down":
 561 | 		_start_sleep_entry(source, ACTION_PRIORITY_DIALOGUE)
 562 | 	elif not action_request.is_empty():
 563 | 		_request_coordinated_clip(
 564 | 			action_request,
 565 | 			source,
 566 | 			ACTION_PRIORITY_DIALOGUE,
 567 | 			true,
 568 | 			PetState.REACTION
 569 | 		)
 570 | 
 571 | 
 572 | func _on_file_feedback_requested(kind: String) -> void:
 573 | 	var text := dialogue_manager.event_reply(kind)
 574 | 	if text.is_empty():
 575 | 		return
 576 | 	if is_instance_valid(batch_file_window):
 577 | 		batch_file_window.call("set_character_feedback", text)
 578 | 	# The independent file workbench can cover the pet. Show the feedback in
 579 | 	# its own status area too, without stealing keyboard focus.
 580 | 	bubble.say(text, 4.0)
 581 | 
 582 | 
 583 | func _say_event_feedback(kind: String, duration: float = 3.2) -> void:
 584 | 	var text := dialogue_manager.event_reply(kind)
 585 | 	if not text.is_empty():
 586 | 		bubble.say(text, duration)
 587 | 
 588 | 
 589 | func _try_auto_birthday_easter_egg() -> void:
 590 | 	var date := Time.get_date_dict_from_system()
 591 | 	var year := int(date.get("year", -1))
 592 | 	var last_year := int(settings_store.get_value(
 593 | 		"last_birthday_auto_trigger_year",
 594 | 		-1
 595 | 	))
 596 | 	var result := dialogue_manager.birthday_auto_event(
 597 | 		date,
 598 | 		last_year
 599 | 	) as Dictionary
 600 | 	if result.is_empty():
 601 | 		return
 602 | 
 603 | 	settings_store.set_value(
 604 | 		"last_birthday_auto_trigger_year",
 605 | 		year
 606 | 	)
 607 | 	_apply_dialogue_result(result, "birthday_auto")
 608 | 
 609 | 
 610 | func _on_command_input_changed(text: String) -> void:
 611 | 	command_send.disabled = not bool(InputGuard.check(text, InputGuard.MESSAGE_LIMIT).ok)
 612 | 	$CommandBubble/Card/Margin/Content/Title.text = "你想对她说：%d / 50" % text.length()
 613 | 
 614 | 
 615 | func _on_command_input_rejected(_rejected: String) -> void:
 616 | 	$CommandBubble/Card/Margin/Content/Title.text = "最多 50 个字符，已保留能放下的内容。"
 617 | 
 618 | 
 619 | func _open_nickname_window() -> void:
 620 | 	command_bubble.call("hide_card", false)
 621 | 	weather_bubble.call("hide_card", false)
 622 | 	context_menu.call("hide_menu", false)
 623 | 	if not is_instance_valid(nickname_card):
 624 | 		nickname_card = load("res://scenes/nickname_card.tscn").instantiate()
 625 | 		add_child(nickname_card)
 626 | 		nickname_card.interactive_changed.connect(_on_overlay_interactive_changed)
 627 | 		nickname_card.nickname_submitted.connect(_on_nickname_submitted)
 628 | 	nickname_card.call("open_for", settings_store.get_nickname())
 629 | 
 630 | 
 631 | func _hide_nickname_card(animated: bool = true) -> void:
 632 | 	if is_instance_valid(nickname_card):
 633 | 		nickname_card.call("hide_card", animated)
 634 | 
 635 | 
 636 | func _on_nickname_submitted(text: String) -> void:
 637 | 	var checked := InputGuard.check(text, InputGuard.NICKNAME_LIMIT, true)
 638 | 	if not checked.ok:
 639 | 		nickname_card.call("show_error", "昵称最多 12 个字符，请缩短后再保存。")
 640 | 		return
 641 | 	if not settings_store.set_nickname(text):
 642 | 		nickname_card.call("show_error", "暂时没能保存，请稍后重试。")
 643 | 		return
 644 | 	_hide_nickname_card()
 645 | 	bubble.say("昵称已清除，照常陪你聊天。" if checked.text.is_empty() else "记住啦，以后就这样称呼你。", 3.0)
 646 | 
 647 | 
 648 | func _open_weather_window() -> void:
 649 | 	command_bubble.call("hide_card", false)
 650 | 	_hide_nickname_card(false)
 651 | 	context_menu.call("hide_menu", false)
 652 | 	weather_city.text = str(weather_manager.location_query)
 653 | 	weather_enabled.button_pressed = bool(weather_manager.enabled)
 654 | 	weather_bubble.call("popup_card")
 655 | 	weather_city.call_deferred("grab_focus")
 656 | 
 657 | 
 658 | func _on_weather_cancel_pressed() -> void:
 659 | 	weather_bubble.call("hide_card")
 660 | 
 661 | 
 662 | func _on_weather_save_pressed() -> void:
 663 | 	var city := weather_city.text.strip_edges()
 664 | 	var enabled := weather_enabled.button_pressed
 665 | 
 666 | 	if enabled and city.is_empty():
 667 | 		bubble.say("先告诉我你在哪个城市呀，不然我不知道该往哪儿看天气～", 4.0)
 668 | 		return
 669 | 
 670 | 	weather_manager.set_location(city, enabled)
 671 | 	settings_store.set_value(
 672 | 		"weather",
 673 | 		weather_manager.export_settings()
 674 | 	)
 675 | 	weather_bubble.call("hide_card")
 676 | 
 677 | 	if enabled and not city.is_empty():
 678 | 		bubble.say("好～我去看看那边现在是什么天气。", 2.8)
 679 | 		weather_manager.refresh()
 680 | 	else:
 681 | 		bubble.say("好，天气提醒先关掉啦。", 2.8)
 682 | 
 683 | 
 684 | func _request_weather_now() -> void:
 685 | 	if str(weather_manager.location_name).is_empty():
 686 | 		bubble.ask(
 687 | 			"还没设置天气城市，要现在设置吗？",
 688 | 			[
 689 | 				{"id": "weather_setup", "label": "去设置"},
 690 | 				{"id": "dismiss", "label": "稍后"}
 691 | 			]
 692 | 		)
 693 | 		return
 694 | 
 695 | 	bubble.say("我去瞄一眼天气～", 2.2)
 696 | 	weather_manager.refresh()
 697 | 
 698 | 
 699 | func _on_weather_updated(summary: Dictionary) -> void:
 700 | 	settings_store.set_value(
 701 | 		"weather",
 702 | 		weather_manager.export_settings()
 703 | 	)
 704 | 
 705 | 	var weather_text := _build_weather_reply(summary)
 706 | 	bubble.say(
 707 | 		dream_talk_manager.format_notice("weather", weather_text)
 708 | 		if _is_sleep_dream_state()
 709 | 		else weather_text,
 710 | 		7.0
 711 | 	)
 712 | 
 713 | 
 714 | func _build_weather_reply(summary: Dictionary) -> String:
 715 | 	return WeatherReplyFormatter.build(summary)
 716 | 
 717 | 
 718 | func _on_weather_reminder_due(text: String) -> void:
 719 | 	bubble.say(
 720 | 		dream_talk_manager.format_notice("weather", text)
 721 | 		if _is_sleep_dream_state()
 722 | 		else text,
 723 | 		6.0
 724 | 	)
 725 | 
 726 | 
 727 | func _on_weather_request_failed(message: String) -> void:
 728 | 	bubble.say(
 729 | 		dream_talk_manager.format_notice("weather", message)
 730 | 		if _is_sleep_dream_state()
 731 | 		else message,
 732 | 		4.5
 733 | 	)
 734 | 
 735 | 
 736 | func _on_reminder_due(text: String) -> void:
 737 | 	bubble.say(
 738 | 		dream_talk_manager.format_notice("reminder", text)
 739 | 		if _is_sleep_dream_state()
 740 | 		else text,
 741 | 		5.0
 742 | 	)
 743 | 
 744 | 
 745 | func _on_bubble_action_selected(action_id: String) -> void:
 746 | 	match action_id:
 747 | 		"convert_png", "convert_jpg", "convert_webp":
 748 | 			# Stage 5A safety guard: stale bubble actions may only open preview.
 749 | 			_open_batch_file_window()
 750 | 		"weather_setup":
 751 | 			_open_weather_window()
 752 | 		"dismiss":
 753 | 			pass
 754 | 
 755 | 
 756 | func _on_bubble_interactive_changed(enabled: bool) -> void:
 757 | 	bubble_interactive = enabled
 758 | 	call_deferred("_configure_mouse_passthrough")
 759 | 
 760 | 
 761 | func _on_bubble_bounds_changed() -> void:
 762 | 	_configure_mouse_passthrough()
 763 | 
 764 | 
 765 | func _on_overlay_interactive_changed(_enabled: bool) -> void:
 766 | 	overlay_interactive = (
 767 | 		command_bubble.visible
 768 | 		or weather_bubble.visible
 769 | 		or context_menu.visible
 770 | 		or (is_instance_valid(nickname_card) and nickname_card.visible)
 771 | 	)
 772 | 	call_deferred("_configure_mouse_passthrough")
 773 | 
 774 | 
 775 | func _on_mood_indicator_visibility_changed() -> void:
 776 | 	call_deferred("_configure_mouse_passthrough")
 777 | 
 778 | 
 779 | func _on_files_dropped(files: PackedStringArray) -> void:
 780 | 	_register_user_activity()
 781 | 	if sleep_phase != "none":
 782 | 		_interrupt_sleep_by_user()
 783 | 	var summary := file_drop_manager.enqueue(files) as Dictionary
 784 | 	var images := int(summary.get("images", 0))
 785 | 	var audio := int(summary.get("audio", 0))
 786 | 	var video := int(summary.get("video", 0))
 787 | 	var other := int(summary.get("other", 0))
 788 | 
 789 | 	var parts: PackedStringArray = []
 790 | 	if images > 0:
 791 | 		parts.append("%d 张图片" % images)
 792 | 	if audio > 0:
 793 | 		parts.append("%d 个音频" % audio)
 794 | 	if video > 0:
 795 | 		parts.append("%d 个视频" % video)
 796 | 	if other > 0:
 797 | 		parts.append("%d 个其他文件" % other)
 798 | 
 799 | 	var description := "、".join(parts)
 800 | 	if description.is_empty():
 801 | 		description = "文件"
 802 | 
 803 | 	var note := "收到%s，已经加入文件处理队列。" % description
 804 | 	if audio + video > 0:
 805 | 		note += "\n音频和视频只参与批量重命名，不提供格式转换。"
 806 | 	bubble.say(note, 3.2)
 807 | 	call_deferred("_open_batch_file_window")
 808 | 
 809 | 
 810 | func _on_file_queue_changed(_summary: Dictionary) -> void:
 811 | 	pass
 812 | 
 813 | 
 814 | func _convert_queued_images(_target: String) -> void:
 815 | 	_open_batch_file_window()
 816 | 
 817 | 
 818 | func _quit_pet() -> void:
 819 | 	_persist_window_position()
 820 | 	settings_store.save_settings()
 821 | 	get_tree().quit()
 822 | 
 823 | 
 824 | func _exit_tree() -> void:
 825 | 	if is_instance_valid(settings_store):
 826 | 		settings_store.set_window_position(
 827 | 			DisplayServer.window_get_position(),
 828 | 			false
 829 | 		)
 830 | 		settings_store.save_settings()
 831 | 
 832 | 
 833 | func _reset_window_position() -> void:
 834 | 	var window_cfg := config.get("window", {}) as Dictionary
 835 | 	var usable := DisplayServer.screen_get_usable_rect()
 836 | 	var window_size := DisplayServer.window_get_size()
 837 | 	var pos := Vector2i(
 838 | 		usable.position.x + usable.size.x - window_size.x - int(window_cfg.get("margin_right", 28)),
 839 | 		usable.position.y + usable.size.y - window_size.y - int(window_cfg.get("margin_bottom", 28))
 840 | 	)
 841 | 	DisplayServer.window_set_position(pos)
 842 | 
 843 | 
 844 | func _load_dynamic_hit_shapes() -> void:
 845 | 	var interaction := config.get("interaction", {}) as Dictionary
 846 | 	var dynamic_cfg := interaction.get("dynamic_hit_shape", {}) as Dictionary
 847 | 	if not bool(dynamic_cfg.get("enabled", true)):
 848 | 		dynamic_hit_shapes_ready = false
 849 | 		return
 850 | 
 851 | 	var catalog_path := str(
 852 | 		dynamic_cfg.get("catalog", "res://config/video_hit_shapes.json")
 853 | 	)
 854 | 	dynamic_hit_shapes_ready = dynamic_hit_shape_manager.load_catalog(catalog_path)
 855 | 	if not dynamic_hit_shapes_ready:
 856 | 		push_warning("Dynamic hit-shape catalog unavailable; using fallback pet hitbox.")
 857 | 
 858 | 
 859 | func _set_active_hit_frame(action_id: String, frame_index: int) -> void:
 860 | 	var next_action := action_id if not action_id.is_empty() else "idle"
 861 | 	var next_frame := maxi(0, frame_index)
 862 | 	if active_hit_action_id == next_action and active_hit_frame == next_frame:
 863 | 		return
 864 | 	active_hit_action_id = next_action
 865 | 	active_hit_frame = next_frame
 866 | 	_configure_mouse_passthrough()
 867 | 
 868 | 
 869 | func _fallback_character_polygon() -> PackedVector2Array:
 870 | 	var interaction := config.get("interaction", {}) as Dictionary
 871 | 	var hitbox := interaction.get("pet_hitbox", {}) as Dictionary
 872 | 	var dynamic_cfg := interaction.get("dynamic_hit_shape", {}) as Dictionary
 873 | 	var pad := float(dynamic_cfg.get("fallback_padding_px", 12.0))
 874 | 	var left := base_position.x + float(hitbox.get("left", -125.0)) * base_scale - pad
 875 | 	var top := base_position.y + float(hitbox.get("top", -155.0)) * base_scale - pad
 876 | 	var right := base_position.x + float(hitbox.get("right", 125.0)) * base_scale + pad
 877 | 	var bottom := base_position.y + float(hitbox.get("bottom", 161.0)) * base_scale + pad
 878 | 	return PackedVector2Array([
 879 | 		Vector2(left, top),
 880 | 		Vector2(right, top),
 881 | 		Vector2(right, bottom),
 882 | 		Vector2(left, bottom)
 883 | 	])
 884 | 
 885 | 
 886 | func _current_character_passthrough_polygon() -> PackedVector2Array:
 887 | 	if not dynamic_hit_shapes_ready:
 888 | 		return _fallback_character_polygon()
 889 | 
 890 | 	var raw := dynamic_hit_shape_manager.polygon_for(
 891 | 		active_hit_action_id,
 892 | 		active_hit_frame
 893 | 	)
 894 | 	if raw.size() < 3:
 895 | 		return _fallback_character_polygon()
 896 | 
 897 | 	var canvas_center := dynamic_hit_shape_manager.canvas_size * 0.5
 898 | 	var transformed := PackedVector2Array()
 899 | 	for point in raw:
 900 | 		transformed.append(pet_sprite.to_global(point - canvas_center))
 901 | 	return transformed
 902 | 
 903 | 
 904 | func _append_rect_corners(points: PackedVector2Array, rect: Rect2) -> void:
 905 | 	var grown := rect.grow(2.0)
 906 | 	points.append(grown.position)
 907 | 	points.append(Vector2(grown.end.x, grown.position.y))
 908 | 	points.append(grown.end)
 909 | 	points.append(Vector2(grown.position.x, grown.end.y))
 910 | 
 911 | 
 912 | func _visible_ui_passthrough_rects() -> Array[Rect2]:
 913 | 	var rects: Array[Rect2] = []
 914 | 	if bubble.visible:
 915 | 		rects.append(bubble.call("get_window_bounds") as Rect2)
 916 | 	if context_menu.visible:
 917 | 		rects.append(context_menu.get_global_rect())
 918 | 	if command_bubble.visible:
 919 | 		rects.append(command_bubble.get_global_rect())
 920 | 	if weather_bubble.visible:
 921 | 		rects.append(weather_bubble.get_global_rect())
 922 | 	if is_instance_valid(nickname_card) and nickname_card.visible:
 923 | 		rects.append(nickname_card.get_global_rect())
 924 | 	if mood_indicator.visible:
 925 | 		rects.append(mood_indicator.get_global_rect())
 926 | 	return rects
 927 | 
 928 | 
 929 | func _configure_mouse_passthrough() -> void:
 930 | 	# Normal mode follows the alpha-derived polygon for the *current animation
 931 | 	# frame*. This keeps standing, crouching and lying poses clickable without
 932 | 	# leaving a large invisible rectangle over desktop icons.
 933 | 	var character_polygon := _current_character_passthrough_polygon()
 934 | 	debug_character_passthrough_polygon = character_polygon
 935 | 	mood_indicator.call("set_hover_polygon", character_polygon)
 936 | 
 937 | 	var ui_rects := _visible_ui_passthrough_rects()
 938 | 	if ui_rects.is_empty():
 939 | 		debug_last_passthrough_polygon = character_polygon
 940 | 	else:
 941 | 		# DisplayServer accepts one polygon. When UI is visible, use the convex
 942 | 		# hull of the current character plus only the actually visible cards.
 943 | 		# This is intentionally much smaller than the old full 760x420 capture.
 944 | 		var combined := PackedVector2Array(character_polygon)
 945 | 		for rect in ui_rects:
 946 | 			_append_rect_corners(combined, rect)
 947 | 		debug_last_passthrough_polygon = Geometry2D.convex_hull(combined)
 948 | 
 949 | 	DisplayServer.window_set_mouse_passthrough(debug_last_passthrough_polygon)
 950 | 
 951 | 
 952 | func _load_clips() -> void:
 953 | 	clips.clear()
 954 | 	var runtime_cfg := config.get("video_runtime", {}) as Dictionary
 955 | 	video_runtime_enabled = bool(runtime_cfg.get("enabled", false))
 956 | 	PetClipCatalogLoader.populate(clips, config, video_runtime_enabled)
 957 | 
 958 | 
 959 | func _load_idle_video() -> void:
 960 | 	idle_video_textures.clear()
 961 | 	idle_runtime_stream = null
 962 | 
 963 | 	var spec := config.get("idle_video", {}) as Dictionary
 964 | 	if not bool(spec.get("enabled", false)):
 965 | 		return
 966 | 
 967 | 	var frames_dir := str(spec.get("frames_dir", ""))
 968 | 	var frame_count := int(spec.get("frame_count", 0))
 969 | 	if frames_dir.is_empty() or frame_count <= 0:
 970 | 		push_warning("idle_video is enabled but not configured")
 971 | 		return
 972 | 
 973 | 	var runtime_video_path := "%s/runtime_alpha.ogv" % frames_dir.get_base_dir()
 974 | 	if video_runtime_enabled and ResourceLoader.exists(runtime_video_path):
 975 | 		idle_runtime_stream = load(runtime_video_path) as VideoStream
 976 | 		if idle_runtime_stream == null:
 977 | 			push_warning("Failed to load idle runtime video; PNG fallback remains active.")
 978 | 
 979 | 	for index in range(frame_count):
 980 | 		var path := "%s/%03d.png" % [frames_dir, index]
 981 | 		var texture := load(path) as Texture2D
 982 | 		if texture == null:
 983 | 			push_warning("Failed to load idle-video frame: %s" % path)
 984 | 			idle_video_textures.clear()
 985 | 			return
 986 | 		idle_video_textures.append(texture)
 987 | 
 988 | 	_reset_idle_video()
 989 | 
 990 | 
 991 | func _idle_video_is_ready() -> bool:
 992 | 	return not idle_video_textures.is_empty()
 993 | 
 994 | 
 995 | func _idle_runtime_is_ready() -> bool:
 996 | 	return video_runtime_enabled and idle_runtime_stream != null
 997 | 
 998 | 
 999 | func _runtime_video_is_active() -> bool:
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
