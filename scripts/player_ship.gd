class_name PlayerShip extends Ship

@export_range(0, PlayerInput.MAX_LOCAL_PLAYERS - 1, 1) var local_player_index: int = 0
@export var allow_mouse_aim: bool = true

var player_input: PlayerInput = PlayerInput.new()
var is_using_gamepad: bool

func _ready() -> void:
	local_player_index = clamp(local_player_index, 0, PlayerInput.MAX_LOCAL_PLAYERS - 1)
	player_input.init_actions(local_player_index)
	super._ready()


func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouse: 
		is_using_gamepad = false
	elif event is InputEventJoypadMotion or event is InputEventJoypadButton:
		is_using_gamepad = true


func get_move_input() -> Vector2:
	return player_input.get_input_vector("move_left", "move_right", "move_up", "move_down")


func get_aim_input() -> Vector2:
	return player_input.get_input_vector("aim_left", "aim_right", "aim_up", "aim_down")


func get_radius_input() -> float:
	return player_input.get_action_strength("increase_radius") - player_input.get_action_strength("decrease_radius")


func should_use_mouse_aim(aim_input: Vector2) -> bool:
	return allow_mouse_aim and local_player_index == 0 and aim_input.is_zero_approx() and not is_using_gamepad


func can_shoot() -> bool:
	var action: StringName = player_input.get_action("shoot")
	return action != StringName("") and Input.is_action_just_pressed(action)
