class_name PlayPopup extends UiView

@export var one_player_button: Button
@export var two_players_button: Button
@export var keyboard_button: Button
@export var gamepad_button: Button
@export var play_button: Button
@export var back_button: Button
@export var summary_label: Label

var selected_player_count := 1
var selected_device := "keyboard"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if one_player_button != null:
		one_player_button.pressed.connect(set_player_count.bind(1))
	if two_players_button != null:
		two_players_button.pressed.connect(set_player_count.bind(2))
	if keyboard_button != null:
		keyboard_button.pressed.connect(set_device.bind("keyboard"))
	if gamepad_button != null:
		gamepad_button.pressed.connect(set_device.bind("gamepad"))
	if play_button != null:
		play_button.pressed.connect(on_play_pressed)
	if back_button != null:
		back_button.pressed.connect(on_back_pressed)
	refresh_summary()


func set_player_count(count: int) -> void:
	selected_player_count = count
	refresh_summary()


func set_device(device: String) -> void:
	selected_device = device
	refresh_summary()


func refresh_summary() -> void:
	if summary_label == null:
		return

	var players_text := "1 player" if selected_player_count == 1 else "2 players"
	summary_label.text = "%s / %s" % [players_text, selected_device.capitalize()]


func on_play_pressed() -> void:
	if play_button != null:
		play_button.disabled = true

	GameManager.instance.configure_local_game(selected_player_count, selected_device)
	GameManager.instance.start_new_game_scene()


func on_back_pressed() -> void:
	UIManager.close_popup(view_id)
