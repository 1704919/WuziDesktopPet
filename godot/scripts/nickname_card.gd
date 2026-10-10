 1 | extends "res://scripts/popup_card_controller.gd"
 2 | 
 3 | signal nickname_submitted(text: String)
 4 | 
 5 | const InputGuard = preload("res://scripts/input_guard.gd")
 6 | 
 7 | @onready var nickname_input: LineEdit = $Card/Margin/Content/NicknameInput
 8 | @onready var hint: Label = $Card/Margin/Content/Hint
 9 | 

func _ready() -> void:
	super._ready()
	nickname_input.max_length = InputGuard.NICKNAME_LIMIT
	$Card/Margin/Content/Actions/Save.pressed.connect(_submit)
	$Card/Margin/Content/Actions/Clear.pressed.connect(func(): nickname_submitted.emit(""))
	$Card/Margin/Content/Actions/Cancel.pressed.connect(func(): hide_card())
	nickname_input.text_submitted.connect(func(_text: String): _submit())


func open_for(nickname: String) -> void:
	nickname_input.text = nickname
	hint.text = "最多 12 个字符；留空保存或点清除可取消昵称。"
	popup_card()
	nickname_input.grab_focus()
	nickname_input.caret_column = nickname_input.text.length()


func _submit() -> void:
	nickname_submitted.emit(nickname_input.text)


func show_error(text: String) -> void:
	hint.text = text
	nickname_input.grab_focus()
