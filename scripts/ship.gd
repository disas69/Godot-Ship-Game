class_name Ship extends FloatablePlayer3D

@export_category("View")
@export var view: Node3D
@export var forward_incline: Vector2
@export var side_incline: Vector3

@export_category("Cannon")
@export var cannon_ball: PackedScene
@export var cannon_view: Node3D
@export var cannon_anchor: Node3D
@export var cannon_force: float = 20.0

func _process(delta: float) -> void:
	if !last_move_dir.is_zero_approx():
		incline_view_x(delta)
		incline_view_z(delta)
	else:
		view.rotation_degrees = lerp(view.rotation_degrees, Vector3.ZERO, 5.0 * delta)

	var time: float = Time.get_ticks_msec() / 1000.0
	view.position.y -= sin(time * 4) * idle_wave * delta
	
	# rotate cannon view towards the mouse position
	var camera: Camera3D = get_viewport().get_camera_3d()
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var from: Vector3 = cannon_view.global_transform.origin
	var to: Vector3 = camera.project_position(mouse_pos, from.distance_to(camera.global_transform.origin))
	to.y = from.y # keep the cannon level
	var target_dir: Vector3 = (to - from).normalized()
	
	# Transform target direction to ship's local space
	var ship_basis: Basis = global_transform.basis
	var local_target_dir: Vector3 = ship_basis.inverse() * target_dir
	cannon_view.rotation.y = atan2(local_target_dir.x, local_target_dir.z)
	
	if Input.is_action_just_pressed("shoot"):
		shoot(Vector3(to.x, to.y, to.z))


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

	
func shoot(target_position: Vector3) -> void:
	var cannon_ball_inst: CannonBall = cannon_ball.instantiate() as CannonBall
	cannon_ball_inst.transform.origin = cannon_anchor.global_transform.origin
	cannon_ball_inst.transform.basis = cannon_anchor.global_transform.basis
	get_tree().current_scene.add_child(cannon_ball_inst)
	
	var start_pos: Vector3 = cannon_anchor.global_transform.origin
	var displacement: Vector3 = target_position - start_pos
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	
	# Calculate required velocity for ballistic trajectory
	var horizontal_dist: float = Vector2(displacement.x, displacement.z).length()
	var vertical_dist: float = displacement.y
	
	# Using angle of 45 degrees for optimal range
	var angle: float = PI / 4.0
	var required_speed: float = sqrt((gravity * horizontal_dist * horizontal_dist) / (2.0 * cos(angle) * cos(angle) * (horizontal_dist * tan(angle) - vertical_dist)))
	
	var direction: Vector3 = displacement.normalized()
	var cannon_velocity: Vector3 = direction * required_speed * cannon_force
	cannon_ball_inst.linear_velocity = cannon_velocity + velocity


func take_hit() -> void:
	print("Ship hit!")
