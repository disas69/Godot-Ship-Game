class_name PausePopup extends UiView

@export var continue_button: Button
@export var quit_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if continue_button != null:
		continue_button.pressed.connect(on_continue_pressed)
	if quit_button != null:
		quit_button.pressed.connect(on_quit_pressed)


func open() -> void:
	super.open()
	get_tree().paused = true


func close() -> void:
	get_tree().paused = false
	super.close()


func on_continue_pressed() -> void:
	UIManager.close_popup(view_id)


func on_quit_pressed() -> void:
	get_tree().paused = false
	GameManager.instance.return_to_menu()
