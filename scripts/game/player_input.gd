class_name PlayerInput extends RefCounted

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
]

var actions: Dictionary

func init_actions(local_player_index: int) -> void:
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


func get_action(action_name: String) -> StringName:
	var action: StringName = actions.get(action_name, StringName(""))
	return action


func get_action_strength(action_name: String) -> float:
	var action: StringName = get_action(action_name)
	if action == StringName(""):
		return 0.0
	return Input.get_action_strength(action)


func get_input_vector(left_name: String, right_name: String, up_name: String, down_name: String) -> Vector2:
	var x: float = get_action_strength(right_name) - get_action_strength(left_name)
	var y: float = get_action_strength(down_name) - get_action_strength(up_name)
	return Vector2(x, y).limit_length(1.0)
