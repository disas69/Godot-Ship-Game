class_name PlayerInput extends RefCounted

const CONTROL_KEYBOARD := "keyboard"
const CONTROL_GAMEPAD_1 := "gamepad_0"
const CONTROL_GAMEPAD_2 := "gamepad_1"

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
var control_scheme := CONTROL_KEYBOARD


func init_actions(local_player_index: int, new_control_scheme: String = CONTROL_KEYBOARD) -> void:
	control_scheme = sanitize_control_scheme(new_control_scheme)
	actions.clear()

	for action_name in ACTION_NAMES:
		actions[action_name] = setup_runtime_action(local_player_index, action_name)


func sanitize_control_scheme(new_control_scheme: String) -> String:
	if new_control_scheme == CONTROL_GAMEPAD_1 or new_control_scheme == CONTROL_GAMEPAD_2:
		return new_control_scheme
	return CONTROL_KEYBOARD


static func get_target_joypad_device_id(scheme: String) -> int:
	var joypads := Input.get_connected_joypads()
	if scheme == CONTROL_GAMEPAD_1:
		return joypads[0] if joypads.size() > 0 else 0
	elif scheme == CONTROL_GAMEPAD_2:
		if joypads.size() >= 2:
			return joypads[1]
		elif joypads.size() == 1:
			return 0 if joypads[0] != 0 else 1
		return 1
	return 0


func setup_runtime_action(local_player_index: int, action_name: String) -> StringName:
	var source_action := get_source_action_name(action_name)
	if not InputMap.has_action(source_action):
		push_warning("Missing input action '%s'" % source_action)
		return StringName("")

	var runtime_action := StringName("runtime_p%d_%s" % [local_player_index + 1, action_name])
	if InputMap.has_action(runtime_action):
		InputMap.erase_action(runtime_action)
	InputMap.add_action(runtime_action)

	var target_device := get_target_joypad_device_id(control_scheme)

	for event in InputMap.action_get_events(source_action):
		if should_use_event(event):
			var event_copy := event.duplicate() as InputEvent
			if event_copy is InputEventJoypadButton or event_copy is InputEventJoypadMotion:
				event_copy.device = target_device
			InputMap.action_add_event(runtime_action, event_copy)

	if InputMap.action_get_events(runtime_action).is_empty() and not is_mouse_aim_action(action_name):
		push_warning("No input events for control '%s' action '%s'" % [control_scheme, action_name])

	return runtime_action


func get_source_action_name(action_name: String) -> StringName:
	if control_scheme == CONTROL_GAMEPAD_2:
		return StringName("p2_" + action_name)
	return StringName("p1_" + action_name)


func should_use_event(event: InputEvent) -> bool:
	if control_scheme == CONTROL_KEYBOARD:
		return event is InputEventKey or event is InputEventMouse

	return event is InputEventJoypadButton or event is InputEventJoypadMotion


func is_mouse_aim_action(action_name: String) -> bool:
	return control_scheme == CONTROL_KEYBOARD and action_name.begins_with("aim_")


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
