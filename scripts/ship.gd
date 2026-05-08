class_name Ship extends FloatablePlayer3D

@export_category("View")
@export var view: Node3D
@export var forward_incline: Vector2
@export var side_incline: Vector3

@export_category("Cannon")
@export var cannon_ball: PackedScene
@export var cannon_view: Node3D
@export var cannon_anchor: Node3D
@export_range(5.0, 85.0, 1.0) var cannon_launch_angle_degrees: float = 45.0
@export var use_constant_force: bool
@export var cannon_constant_force: float = 15.0

var is_using_gamepad: bool
var default_gravity: float
var cannon_start_position: Vector3
var cannon_start_scale: Vector3
var cannon_tween: Tween


func _ready() -> void:
	default_gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
	cannon_start_position = cannon_view.position
	cannon_start_scale = cannon_view.scale
	super._ready()
	
	
func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouse: 
		is_using_gamepad = false
	elif event is InputEventJoypadMotion or event is InputEventJoypadButton:
		is_using_gamepad = true


func _process(delta: float) -> void:
	if !last_move_dir.is_zero_approx():
		incline_view_x(delta)
		incline_view_z(delta)
	else:
		view.rotation_degrees = lerp(view.rotation_degrees, Vector3.ZERO, 5.0 * delta)

	var time: float = Time.get_ticks_msec() / 1000.0
	view.position.y -= sin(time * 4) * idle_wave * delta
	
	var target_position: Variant
	
	if is_using_gamepad:
		target_position = get_gamepad_aim_position()
	else:
		var camera: Camera3D = get_viewport().get_camera_3d()
		var mouse_pos: Vector2 = get_viewport().get_mouse_position()
		target_position = get_mouse_water_position(camera, mouse_pos)
	
	if target_position != null:
		var target: Vector3 = target_position
		rotate_cannon_towards(target)

	if Input.is_action_just_pressed("shoot"):
		if use_constant_force:
			shoot_constant_force()
		elif target_position != null:
			var target: Vector3 = target_position
			shoot(target)


func incline_view_x(delta: float) -> void:
	view.rotation_degrees.x = lerp(view.rotation_degrees.x, forward_incline.x, forward_incline.y * delta)
	
	
func incline_view_z(delta: float) -> void:
	var target_z := 0.0
	var incline_speed := 0.0
	var forward: Vector3 = global_transform.basis.z
	var dot: float = forward.dot(last_move_dir)
	
	if dot > 0.98:
		target_z = 0.0
		incline_speed = 1.0
	else:
		var cross: Vector3 = forward.cross(last_move_dir)

		if cross.y > 0.0:
			target_z = side_incline.x
		else:
			target_z = side_incline.y
		incline_speed = side_incline.z

	view.rotation_degrees.z = lerp(view.rotation_degrees.z, target_z, incline_speed * delta)


func get_gamepad_aim_position() -> Variant:
	var aim: Vector2 = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if aim.is_zero_approx():
		return null

	var camera: Camera3D = get_viewport().get_camera_3d()
	var forward: Vector3 = -camera.global_transform.basis.z
	var right: Vector3 = camera.global_transform.basis.x

	forward.y = 0.0
	right.y = 0.0

	var target_dir: Vector3 = (right.normalized() * aim.x + forward.normalized() * -aim.y).normalized()
	return global_position + target_dir * 10.0


func get_mouse_water_position(camera: Camera3D, mouse_pos: Vector2) -> Variant:
	var ray_origin: Vector3 = camera.project_ray_origin(mouse_pos)
	var ray_direction: Vector3 = camera.project_ray_normal(mouse_pos)

	if is_zero_approx(ray_direction.y):
		return null

	var distance_to_plane: float = (global_position.y - ray_origin.y) / ray_direction.y
	if distance_to_plane < 0.0:
		return null

	return ray_origin + ray_direction * distance_to_plane


func rotate_cannon_towards(target_position: Vector3) -> void:
	var target_dir: Vector3 = target_position - cannon_view.global_position
	target_dir.y = 0.0

	if target_dir.is_zero_approx():
		return

	var local_target_dir: Vector3 = global_transform.basis.inverse() * target_dir.normalized()
	cannon_view.rotation.y = atan2(local_target_dir.x, local_target_dir.z)


func shoot(target_position: Vector3) -> void:
	var cannon_ball_inst: CannonBall = spawn_cannon_ball()
	var start_pos: Vector3 = cannon_anchor.global_transform.origin
	var launch_velocity: Vector3 = calculate_ballistic_velocity(start_pos, target_position, cannon_ball_inst.gravity_scale)
	cannon_ball_inst.linear_velocity = launch_velocity + velocity

	play_cannon_recoil()


func shoot_constant_force() -> void:
	var cannon_ball_inst: CannonBall = spawn_cannon_ball()
	var forward: Vector3 = cannon_anchor.global_transform.basis.z.normalized()
	cannon_ball_inst.linear_velocity = forward * cannon_constant_force + velocity

	play_cannon_recoil()


func spawn_cannon_ball() -> CannonBall:
	var cannon_ball_inst: CannonBall = cannon_ball.instantiate() as CannonBall
	get_tree().current_scene.add_child(cannon_ball_inst)
	cannon_ball_inst.global_transform = cannon_anchor.global_transform
	return cannon_ball_inst


func play_cannon_recoil() -> void:
	if cannon_tween and cannon_tween.is_valid():
		cannon_tween.kill()

	var cannon_forward: Vector3 = cannon_view.transform.basis.z.normalized()
	cannon_view.position = cannon_start_position - cannon_forward * 0.75
	cannon_view.scale = cannon_start_scale * 1.15

	cannon_tween = create_tween()
	cannon_tween.set_parallel(true)
	cannon_tween.tween_property(cannon_view, "position", cannon_start_position, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	cannon_tween.tween_property(cannon_view, "scale", cannon_start_scale, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func calculate_ballistic_velocity(start_position: Vector3, target_position: Vector3, gravity_scale: float) -> Vector3:
	var displacement: Vector3 = target_position - start_position
	var horizontal_displacement: Vector3 = Vector3(displacement.x, 0.0, displacement.z)
	var horizontal_distance: float = horizontal_displacement.length()

	if is_zero_approx(horizontal_distance):
		return Vector3.ZERO

	var gravity: float = default_gravity * gravity_scale
	var launch_angle: float = deg_to_rad(cannon_launch_angle_degrees)
	var cos_angle: float = cos(launch_angle)
	var tan_angle: float = tan(launch_angle)
	var denominator: float = 2.0 * cos_angle * cos_angle * (horizontal_distance * tan_angle - displacement.y)

	if denominator <= 0.0:
		return Vector3.ZERO

	var launch_speed: float = sqrt((gravity * horizontal_distance * horizontal_distance) / denominator)
	var horizontal_velocity: Vector3 = horizontal_displacement.normalized() * launch_speed * cos_angle
	var vertical_velocity: Vector3 = Vector3.UP * launch_speed * sin(launch_angle)
	return horizontal_velocity + vertical_velocity


func take_hit() -> void:
	print("Ship hit!")
