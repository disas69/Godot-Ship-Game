class_name PlayPopup extends UiView

const TEAM_OPTIONS: Array[Ship.Team] = [
	Ship.Team.GoodGuys,
	Ship.Team.BadGuys,
]

const PLAYER_COUNT_OPTIONS: Array[int] = [1, 2]

@export var player_count_previous_button: Button
@export var player_count_next_button: Button
@export var player_count_value_label: Label
@export var player_1_options: Control
@export var player_1_controls_previous_button: Button
@export var player_1_controls_next_button: Button
@export var player_1_controls_value_label: Label
@export var player_1_team_previous_button: Button
@export var player_1_team_next_button: Button
@export var player_1_team_value_label: Label
@export var player_2_options: Control
@export var player_2_controls_previous_button: Button
@export var player_2_controls_next_button: Button
@export var player_2_controls_value_label: Label
@export var player_2_team_previous_button: Button
@export var player_2_team_next_button: Button
@export var player_2_team_value_label: Label
@export var play_button: Button
@export var back_button: Button
@export var summary_label: Label

var selected_player_count := 1
var selected_controls: Array[String] = [
	PlayerInput.CONTROL_KEYBOARD,
	PlayerInput.CONTROL_GAMEPAD_1,
]
var selected_teams: Array[Ship.Team] = [
	Ship.Team.GoodGuys,
	Ship.Team.BadGuys,
]
var control_options: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	setup_signals()
	refresh_control_options()
	sanitize_selections()
	refresh_view()


func setup_signals() -> void:
	player_count_previous_button.pressed.connect(change_player_count.bind(-1))
	player_count_next_button.pressed.connect(change_player_count.bind(1))
	player_1_controls_previous_button.pressed.connect(change_controls.bind(0, -1))
	player_1_controls_next_button.pressed.connect(change_controls.bind(0, 1))
	player_1_team_previous_button.pressed.connect(change_team.bind(0, -1))
	player_1_team_next_button.pressed.connect(change_team.bind(0, 1))
	player_2_controls_previous_button.pressed.connect(change_controls.bind(1, -1))
	player_2_controls_next_button.pressed.connect(change_controls.bind(1, 1))
	player_2_team_previous_button.pressed.connect(change_team.bind(1, -1))
	player_2_team_next_button.pressed.connect(change_team.bind(1, 1))
	play_button.pressed.connect(on_play_pressed)
	back_button.pressed.connect(on_back_pressed)


func refresh_control_options() -> void:
	control_options = [PlayerInput.CONTROL_KEYBOARD]

	var joypads := Input.get_connected_joypads()
	if joypads.has(0):
		control_options.append(PlayerInput.CONTROL_GAMEPAD_1)
	if joypads.has(1):
		control_options.append(PlayerInput.CONTROL_GAMEPAD_2)


func sanitize_selections() -> void:
	if not control_options.has(selected_controls[0]):
		selected_controls[0] = control_options[0]

	if not control_options.has(selected_controls[1]):
		selected_controls[1] = get_first_unused_control(selected_controls[0])

	if selected_player_count == 2 and selected_controls[0] == selected_controls[1]:
		selected_controls[1] = get_first_unused_control(selected_controls[0])


func get_first_unused_control(used_control: String) -> String:
	for control in control_options:
		if control != used_control:
			return control

	return used_control


func change_player_count(direction: int) -> void:
	refresh_control_options()
	var index := PLAYER_COUNT_OPTIONS.find(selected_player_count)
	index = wrapi(index + direction, 0, PLAYER_COUNT_OPTIONS.size())
	selected_player_count = PLAYER_COUNT_OPTIONS[index]
	sanitize_selections()
	refresh_view()


func change_controls(player_index: int, direction: int) -> void:
	refresh_control_options()
	sanitize_selections()
	if control_options.is_empty():
		return

	var index := control_options.find(selected_controls[player_index])
	if index < 0:
		index = 0

	for i in range(control_options.size()):
		index = wrapi(index + direction, 0, control_options.size())
		var next_control := control_options[index]
		if selected_player_count == 1 or (player_index == 0 and next_control != selected_controls[1]) or (player_index == 1 and next_control != selected_controls[0]):
			selected_controls[player_index] = next_control
			break

	refresh_view()


func change_team(player_index: int, direction: int) -> void:
	var index := TEAM_OPTIONS.find(selected_teams[player_index])
	index = wrapi(index + direction, 0, TEAM_OPTIONS.size())
	selected_teams[player_index] = TEAM_OPTIONS[index]
	refresh_view()


func refresh_view() -> void:
	player_count_value_label.text = "%d Player%s" % [selected_player_count, "" if selected_player_count == 1 else "s"]
	player_2_options.visible = selected_player_count == 2

	player_1_controls_value_label.text = get_control_label(selected_controls[0])
	player_1_team_value_label.text = get_team_label(selected_teams[0])
	player_2_controls_value_label.text = get_control_label(selected_controls[1])
	player_2_team_value_label.text = get_team_label(selected_teams[1])

	var can_play := selected_player_count == 1 or control_options.size() >= 2
	play_button.disabled = not can_play

	if summary_label == null:
		return

	if not can_play:
		summary_label.text = "Connect a gamepad for 2 players"
		return

	if selected_player_count == 1:
		summary_label.text = "Player 1: %s / %s" % [
			get_control_label(selected_controls[0]),
			get_team_label(selected_teams[0]),
		]
	else:
		summary_label.text = "P1: %s / %s   P2: %s / %s" % [
			get_control_label(selected_controls[0]),
			get_team_label(selected_teams[0]),
			get_control_label(selected_controls[1]),
			get_team_label(selected_teams[1]),
		]


func get_control_label(control_scheme: String) -> String:
	if control_scheme == PlayerInput.CONTROL_GAMEPAD_1:
		return "Gamepad 1"
	if control_scheme == PlayerInput.CONTROL_GAMEPAD_2:
		return "Gamepad 2"
	return "Keyboard"


func get_team_label(team: Ship.Team) -> String:
	return "White" if team == Ship.Team.GoodGuys else "Black"


func on_play_pressed() -> void:
	if play_button.disabled:
		return

	play_button.disabled = true
	GameManager.instance.configure_local_game_players(get_local_player_configs())
	GameManager.instance.start_new_game_scene()


func get_local_player_configs() -> Array[Dictionary]:
	var configs: Array[Dictionary] = []
	for i in range(selected_player_count):
		configs.append({
			"control_scheme": selected_controls[i],
			"team": selected_teams[i],
		})

	return configs


func on_back_pressed() -> void:
	UIManager.close_popup(view_id)
