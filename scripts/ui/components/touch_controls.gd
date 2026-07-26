class_name TouchControls extends Control

@export var left_joystick: TouchJoystick
@export var right_joystick: TouchJoystick
@export var shoot_button: TouchButton


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return

	update_input_actions()


func update_input_actions() -> void:
	if left_joystick == null or right_joystick == null or shoot_button == null:
		return

	var move_vec := left_joystick.output_vector
	var aim_vec := right_joystick.output_vector

	# Move actions
	update_action("runtime_p1_move_left", maxf(0.0, -move_vec.x))
	update_action("runtime_p1_move_right", maxf(0.0, move_vec.x))
	update_action("runtime_p1_move_up", maxf(0.0, -move_vec.y))
	update_action("runtime_p1_move_down", maxf(0.0, move_vec.y))

	# Aim actions
	update_action("runtime_p1_aim_left", maxf(0.0, -aim_vec.x))
	update_action("runtime_p1_aim_right", maxf(0.0, aim_vec.x))
	update_action("runtime_p1_aim_up", maxf(0.0, -aim_vec.y))
	update_action("runtime_p1_aim_down", maxf(0.0, aim_vec.y))

	# Shoot action
	var shoot_action := StringName("runtime_p1_shoot")
	if InputMap.has_action(shoot_action):
		if shoot_button.consume_just_pressed():
			Input.action_press(shoot_action, 1.0)
		elif not shoot_button.is_pressed:
			Input.action_release(shoot_action)


func update_action(action_name: StringName, strength: float) -> void:
	if not InputMap.has_action(action_name):
		return
	if strength > 0.001:
		Input.action_press(action_name, strength)
	else:
		Input.action_release(action_name)
