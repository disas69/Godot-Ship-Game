class_name PlayerShip extends Ship

const MAX_LOCAL_PLAYERS: int = 2
const ACTION_NAMES: PackedStringArray = [
	"move_left",
	"move_right",
	"move_up",
	"move_down",
	"aim_left",
	"aim_right",
	"aim_up",
	"aim_down",
	"shoot",
	"increase_radius",
	"decrease_radius",
]

@export_range(0, MAX_LOCAL_PLAYERS - 1, 1) var local_player_index: int = 0
@export var allow_mouse_aim: bool = true

var is_using_gamepad: bool
var actions: Dictionary = {}


func _ready() -> void:
	local_player_index = clamp(local_player_index, 0, MAX_LOCAL_PLAYERS - 1)
	_cache_actions()
	super._ready()


func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouse: 
		is_using_gamepad = false
	elif event is InputEventJoypadMotion or event is InputEventJoypadButton:
		is_using_gamepad = true


func get_move_input() -> Vector2:
	return _get_input_vector("move_left", "move_right", "move_up", "move_down")


func get_aim_input() -> Vector2:
	return _get_input_vector("aim_left", "aim_right", "aim_up", "aim_down")


func get_radius_input() -> float:
	return _get_action_strength("increase_radius") - _get_action_strength("decrease_radius")


func should_use_mouse_aim(aim_input: Vector2) -> bool:
	return allow_mouse_aim and local_player_index == 0 and aim_input.is_zero_approx() and not is_using_gamepad


func wants_to_shoot() -> bool:
	var action: StringName = _get_action("shoot")
	return action != StringName("") and Input.is_action_just_pressed(action)


func _cache_actions() -> void:
	var player_prefix: String = "p%d_" % (local_player_index + 1)
	actions.clear()

	for action_name in ACTION_NAMES:
		var player_action: StringName = StringName(player_prefix + action_name)
		if InputMap.has_action(player_action):
			actions[action_name] = player_action
			continue

		if local_player_index == 0 and InputMap.has_action(action_name):
			actions[action_name] = StringName(action_name)
			continue

		actions[action_name] = StringName("")
		push_warning("Missing input action '%s'" % player_action)


func _get_action(action_name: String) -> StringName:
	var action: StringName = actions.get(action_name, StringName(""))
	return action


func _get_action_strength(action_name: String) -> float:
	var action: StringName = _get_action(action_name)
	if action == StringName(""):
		return 0.0
	return Input.get_action_strength(action)


func _get_input_vector(left_name: String, right_name: String, up_name: String, down_name: String) -> Vector2:
	var x: float = _get_action_strength(right_name) - _get_action_strength(left_name)
	var y: float = _get_action_strength(down_name) - _get_action_strength(up_name)
	return Vector2(x, y).limit_length(1.0)
