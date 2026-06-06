class_name Player extends Resource

@export var player_name: String = ""
@export var team: Ship.Team = Ship.Team.GoodGuys
@export var is_local: bool = false
@export var control_scheme: String = PlayerInput.CONTROL_KEYBOARD
@export var local_player_index: int = -1


func _init(
	new_player_name: String = "",
	new_team: Ship.Team = Ship.Team.GoodGuys,
	new_is_local: bool = false,
	new_control_scheme: String = PlayerInput.CONTROL_KEYBOARD,
	new_local_player_index: int = -1
) -> void:
	player_name = new_player_name
	team = new_team
	is_local = new_is_local
	control_scheme = new_control_scheme
	local_player_index = new_local_player_index
