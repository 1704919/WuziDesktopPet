extends Window

signal interactive_changed(enabled: bool)

const FramelessWindow = preload("res://scripts/frameless_window.gd")
const SHADOW_MARGIN := 14

@export var anchor_position := Vector2i(14, 48)

var _content_width := 400
var _fit_pending := false
var _first_open := true
@onready var card: PanelContainer = $Card


func _ready() -> void:
	_content_width = size.x
	FramelessWindow.configure(self)
	always_on_top = true
	unresizable = true
	close_requested.connect(hide_card)
	window_input.connect(_on_window_input)
	card.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	card.position = Vector2(SHADOW_MARGIN, SHADOW_MARGIN)
	card.minimum_size_changed.connect(_queue_fit)
	var title_label := get_node_or_null("Card/Margin/Content/Title") as Label
	if title_label != null:
		title = "舞梓 · " + title_label.text
		FramelessWindow.bind_drag_handle(title_label, self)
		title_label.tooltip_text = "拖动标题移动窗口"
	hide()
	_queue_fit()


func _queue_fit() -> void:
	if _fit_pending:
		return
	_fit_pending = true
	call_deferred("_fit_content")


func _fit_content() -> void:
	_fit_pending = false
	if not is_instance_valid(card):
		return
	var content_size := Vector2(_content_width, card.get_combined_minimum_size().y)
	if not card.size.is_equal_approx(content_size):
		card.size = content_size
	var fitted := Vector2i(ceili(card.size.x), ceili(card.size.y)) + Vector2i.ONE * SHADOW_MARGIN * 2
	if size != fitted:
		size = fitted
	if visible:
		position = FramelessWindow.clamp_position(self, position)


func popup_card() -> void:
	_fit_content()
	if _first_open:
		position = get_tree().root.position + anchor_position - Vector2i.ONE * SHADOW_MARGIN
		_first_open = false
	position = FramelessWindow.clamp_position(self, position)
	FramelessWindow.show_window(self)
	interactive_changed.emit(true)
	# Wrapped labels can report their final minimum after the first layout pass.
	_queue_fit()


func hide_card(_animated: bool = true) -> void:
	hide()
	interactive_changed.emit(false)


func _on_window_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		hide_card()
		set_input_as_handled()
