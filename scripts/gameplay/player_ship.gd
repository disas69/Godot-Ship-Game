class_name PlayerShip extends Ship

@export var local_player_index: int = 0
@export var allow_mouse_aim: bool = true
@export_range(0.0, 0.2, 0.01) var gamepad_aim_release_snap_guard_duration: float = 0.08
@export_range(0.0, 0.5, 0.01) var gamepad_aim_release_snap_window: float = 0.12
@export_range(0.0, 1.0, 0.01) var gamepad_aim_release_snap_min_previous_strength: float = 0.85
@export_range(0.0, 1.0, 0.01) var gamepad_aim_release_snap_max_strength: float = 0.65
@export_range(-1.0, 1.0, 0.01) var gamepad_aim_release_snap_max_dot: float = -0.35

var player_input: PlayerInput = PlayerInput.new()
var is_using_gamepad: bool
var last_gamepad_aim_input := Vector2.ZERO
var gamepad_aim_no_input_time := INF
var gamepad_aim_release_snap_time_left := 0.0


func _ready() -> void:
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


func get_gamepad_aim_position(aim: Vector2, delta: float) -> Variant:
	return super.get_gamepad_aim_position(filter_gamepad_aim_release_snap(aim, delta), delta)


func filter_gamepad_aim_release_snap(aim: Vector2, delta: float) -> Vector2:
	var aim_strength: float = aim.length()
	if aim_strength <= gamepad_aim_deadzone:
		gamepad_aim_no_input_time += delta
		gamepad_aim_release_snap_time_left = 0.0
		return aim

	var last_strength: float = last_gamepad_aim_input.length()
	if is_gamepad_aim_release_snap(aim, aim_strength, last_strength):
		if gamepad_aim_release_snap_time_left <= 0.0:
			gamepad_aim_release_snap_time_left = gamepad_aim_release_snap_guard_duration

		gamepad_aim_release_snap_time_left -= delta
		if gamepad_aim_release_snap_time_left > 0.0:
			return Vector2.ZERO

	gamepad_aim_release_snap_time_left = 0.0
	gamepad_aim_no_input_time = 0.0
	last_gamepad_aim_input = aim
	return aim


func is_gamepad_aim_release_snap(aim: Vector2, aim_strength: float, last_strength: float) -> bool:
	if gamepad_aim_no_input_time > gamepad_aim_release_snap_window:
		return false

	if last_strength < gamepad_aim_release_snap_min_previous_strength:
		return false

	if aim_strength > gamepad_aim_release_snap_max_strength:
		return false

	var aim_dot: float = aim.normalized().dot(last_gamepad_aim_input.normalized())
	return aim_dot <= gamepad_aim_release_snap_max_dot


func should_use_mouse_aim(aim_input: Vector2) -> bool:
	return allow_mouse_aim and local_player_index == 0 and aim_input.is_zero_approx() and not is_using_gamepad


func should_keep_gamepad_aim_without_input() -> bool:
	return is_using_gamepad


func can_shoot() -> bool:
	var action: StringName = player_input.get_action("shoot")
	return action != StringName("") and Input.is_action_just_pressed(action)


func on_shot_fired() -> void:
	play_camera_shake(0.1)


func on_hit_taken(_destroyed: bool) -> void:
	if _destroyed:
		play_camera_shake(0.6)
	else:
		play_camera_shake(0.25)


func play_camera_shake(amount: float) -> void:
	var camera_shake := get_tree().get_first_node_in_group("CameraShake")
	if camera_shake == null or not camera_shake.has_method("shake"):
		return

	camera_shake.shake(amount)
