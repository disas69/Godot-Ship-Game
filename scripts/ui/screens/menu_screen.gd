class_name MenuScreen extends UiView

@export var play_button: Button


func _ready() -> void:
	if play_button == null:
		push_warning("MenuScreen: play_button is not assigned.")
		return

	play_button.pressed.connect(on_play_button_pressed)


func on_play_button_pressed() -> void:
	GameManager.instance.load_game_scene()
