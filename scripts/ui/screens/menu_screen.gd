class_name MenuScreen extends UiView

@export var play_button: Button
@export var settings_button: Button
@export var quit_button: Button


func _ready() -> void:
	if play_button != null:
		play_button.pressed.connect(on_play_button_pressed)
	if settings_button != null:
		settings_button.pressed.connect(on_settings_button_pressed)
	if quit_button != null:
		quit_button.pressed.connect(on_quit_button_pressed)


func on_play_button_pressed() -> void:
	UIManager.open_popup("play")


func on_settings_button_pressed() -> void:
	UIManager.open_popup("settings")


func on_quit_button_pressed() -> void:
	get_tree().quit()
