class_name Ship extends FloatablePlayer3D

const AIM_OVERLAY_SHADER := preload("res://shaders/aim_overlay.gdshader")

@export_category("View")
@export var view: Node3D
@export var forward_incline: Vector2
@export var side_incline: Vector3
@export_category("Hit FX")
@export var hit_punch_scale: float = 1.12
@export var hit_flash_strength: float = 0.8
@export var hit_flash_material_template: ShaderMaterial
@export var hit_flash_targets: Array[GeometryInstance3D] = []

@export_category("Cannon")
@export var cannon_ball: PackedScene
@export var cannon_view: Node3D
@export var cannon_root: Node3D
@export var cannon_anchor: Node3D
@export var aim_indicator: Node3D
@export_range(5.0, 85.0, 1.0) var cannon_launch_angle_degrees: float = 45.0
@export var cannon_aim_radius: float = 10.0
@export var cannon_aim_radius_max: Vector2
@export var cannon_view_rotation_max: Vector2
@export var cannon_aim_radius_change_speed: float = 1.0
@export var show_aim_helpers: bool = true
@export var aim_line_dot_count: int = 12
@export var aim_line_dot_radius: float = 0.08
@export var cannon_smoke_particles: PackedScene

var last_move_dir := Vector3.ZERO
var default_gravity: float
var cannon_start_position: Vector3
var cannon_start_scale: Vector3
var cannon_tween: Tween
var aim_line: MultiMeshInstance3D
var view_base_scale: Vector3
var hit_scale_tween: Tween
var hit_flash_tween: Tween
var hit_flash_material_instance: ShaderMaterial


func _ready() -> void:
	default_gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
	cannon_start_position = cannon_view.position
	cannon_start_scale = cannon_view.scale
	view_base_scale = view.scale
	setup_hit_flash_material_instance()
	set_hit_flash_strength(0.0)
	setup_aim_line()
	super._ready()


func _physics_process(delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	var forward: Vector3 = -camera.global_transform.basis.z
	var right: Vector3 = camera.global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	
	var input_dir: Vector2 = get_move_input()
	var move_direction: Vector3 = (right.normalized() * input_dir.x + forward.normalized() * -input_dir.y).normalized()
	last_move_dir = move_direction
	
	if !move_direction.is_zero_approx():
		move_direction.y = 0.0
		move_direction = move_direction.normalized()
		velocity += move_direction * move_speed * delta
		quaternion = quaternion.slerp(Quaternion(Vector3.BACK, move_direction), rotate_speed * delta)
		
	super._physics_process(delta)


func _process(delta: float) -> void:
	if !last_move_dir.is_zero_approx():
		incline_view_x(delta)
		incline_view_z(delta)
	else:
		view.rotation_degrees = lerp(view.rotation_degrees, Vector3.ZERO, 5.0 * delta)

	var time: float = Time.get_ticks_msec() / 1000.0
	view.position.y -= sin(time * 4) * idle_wave * delta
	
	update_aim_radius(delta, get_radius_input())
	
	var target_position: Variant
	var aim_input: Vector2 = get_aim_input()
	
	if not should_use_mouse_aim(aim_input):
		target_position = get_gamepad_aim_position(aim_input)
	else:
		var camera: Camera3D = get_viewport().get_camera_3d()
		var mouse_pos: Vector2 = get_viewport().get_mouse_position()
		target_position = get_mouse_water_position(camera, mouse_pos)
	
	if target_position != null:
		var target: Vector3 = target_position
		rotate_cannon_towards(target)
	else:		
		target_position = get_cannon_forward_aim_position()

	var aim_target: Vector3 = target_position
	if show_aim_helpers:
		update_aim_line(aim_target)
	elif aim_line:
		aim_line.visible = false
		aim_indicator.visible = false

	if can_shoot():
		shoot(aim_target)


func get_move_input() -> Vector2:
	return Vector2.ZERO


func get_aim_input() -> Vector2:
	return Vector2.ZERO


func get_radius_input() -> float:
	return 0.0


func should_use_mouse_aim(_aim_input: Vector2) -> bool:
	return false


func can_shoot() -> bool:
	return false


func update_aim_radius(delta: float, radius_input: float) -> void:
	var target_radius: float = cannon_aim_radius
	target_radius += radius_input * cannon_aim_radius_change_speed * delta
	cannon_aim_radius = clamp(target_radius, cannon_aim_radius_max.x, cannon_aim_radius_max.y)
	
	var t: float = inverse_lerp(cannon_aim_radius_max.x, cannon_aim_radius_max.y, cannon_aim_radius)
	var cannon_view_target_rotation: float = lerp(cannon_view_rotation_max.x, cannon_view_rotation_max.y, t)
	cannon_view.rotation_degrees.x = cannon_view_target_rotation


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


func get_gamepad_aim_position(aim: Vector2) -> Variant:
	if aim.is_zero_approx():
		return null

	var camera: Camera3D = get_viewport().get_camera_3d()
	var forward: Vector3 = -camera.global_transform.basis.z
	var right: Vector3 = camera.global_transform.basis.x

	forward.y = 0.0
	right.y = 0.0

	var target_dir: Vector3 = (right.normalized() * aim.x + forward.normalized() * -aim.y).normalized()
	var aim_origin: Vector3 = get_aim_origin()
	return clamp_aim_position(aim_origin + target_dir * cannon_aim_radius)


func get_mouse_water_position(camera: Camera3D, mouse_pos: Vector2) -> Variant:
	var ray_origin: Vector3 = camera.project_ray_origin(mouse_pos)
	var ray_direction: Vector3 = camera.project_ray_normal(mouse_pos)

	if is_zero_approx(ray_direction.y):
		return null

	var distance_to_plane: float = (global_position.y - ray_origin.y) / ray_direction.y
	if distance_to_plane < 0.0:
		return null

	return clamp_aim_position(ray_origin + ray_direction * distance_to_plane)


func clamp_aim_position(target_position: Vector3) -> Vector3:
	var aim_origin: Vector3 = get_aim_origin()
	var aim_offset: Vector3 = target_position - aim_origin
	aim_offset.y = 0.0

	if aim_offset.is_zero_approx():
		aim_offset = cannon_root.global_transform.basis.z
		aim_offset.y = 0.0
		if aim_offset.is_zero_approx():
			aim_offset = Vector3.FORWARD

	return aim_origin + aim_offset.normalized() * cannon_aim_radius


func get_cannon_forward_aim_position() -> Vector3:
	var cannon_forward: Vector3 = cannon_anchor.global_transform.basis.z
	cannon_forward.y = 0.0

	if cannon_forward.is_zero_approx():
		cannon_forward = Vector3.FORWARD

	return clamp_aim_position(get_aim_origin() + cannon_forward.normalized() * cannon_aim_radius)


func get_aim_origin() -> Vector3:
	return Vector3(cannon_root.global_position.x, global_position.y, cannon_root.global_position.z)


func setup_aim_line() -> void:
	aim_line = MultiMeshInstance3D.new()
	aim_line.visible = false
	add_child(aim_line)
	aim_line.set_as_top_level(true)
	aim_line.global_transform = Transform3D.IDENTITY

	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = aim_line_dot_radius
	dot_mesh.height = aim_line_dot_radius * 2.0
	dot_mesh.radial_segments = 8
	dot_mesh.rings = 4

	var dot_material := ShaderMaterial.new()
	dot_material.shader = AIM_OVERLAY_SHADER
	dot_material.set_shader_parameter("use_texture", false)
	dot_material.set_shader_parameter("tint_color", Color(1.0, 1.0, 1.0, 0.6))
	dot_mesh.material = dot_material

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = dot_mesh
	multimesh.instance_count = aim_line_dot_count

	aim_line.multimesh = multimesh
	aim_indicator.visible = show_aim_helpers


func update_aim_line(target_position: Vector3) -> void:
	var start_position: Vector3 = get_aim_origin()
	var line_offset: Vector3 = target_position - start_position
	line_offset.y = 0.0

	if line_offset.is_zero_approx():
		aim_line.visible = false
		return

	aim_line.visible = true
	var line_direction: Vector3 = line_offset.normalized()
	var line_length: float = line_offset.length() - 1.5

	for i in aim_line_dot_count:
		var t: float = float(i + 1) / float(aim_line_dot_count + 1)
		var dot_position: Vector3 = start_position + line_direction * line_length * t
		aim_line.multimesh.set_instance_transform(i, Transform3D(Basis(), dot_position))
		
	aim_indicator.global_transform.origin = target_position


func rotate_cannon_towards(target_position: Vector3) -> void:
	var target_dir: Vector3 = target_position - cannon_view.global_position
	target_dir.y = 0.0

	if target_dir.is_zero_approx():
		return

	var local_target_dir: Vector3 = global_transform.basis.inverse() * target_dir.normalized()
	var target_y: float = atan2(local_target_dir.x, local_target_dir.z)
	cannon_view.rotation.y = lerp_angle(cannon_view.rotation.y, target_y, 15.0 * get_process_delta_time())
	

func shoot(target_position: Vector3) -> void:
	var cannon_ball_inst: CannonBall = spawn_cannon_ball()
	var start_pos: Vector3 = cannon_anchor.global_transform.origin
	var launch_velocity: Vector3 = calculate_ballistic_velocity(start_pos, target_position, cannon_ball_inst.gravity_scale)
	cannon_ball_inst.linear_velocity = launch_velocity + velocity
	cannon_ball_inst.set_shooter(self)

	play_cannon_recoil()
	play_cannon_smoke_particles()


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
	cannon_view.scale = cannon_start_scale * 1.25

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


func play_cannon_smoke_particles() -> void:
	var smoke: Node3D = cannon_smoke_particles.instantiate() as Node3D
	smoke.global_transform = cannon_anchor.global_transform
	get_tree().current_scene.add_child(smoke)
	smoke.get_node("GPUParticles3D").emitting = true
	await smoke.get_node("GPUParticles3D").finished
	smoke.queue_free()


func take_hit(hit_velocity: Vector3) -> void:
	hit_velocity.y = 0
	velocity += hit_velocity
	play_hit_feedback()


func play_hit_feedback() -> void:
	if hit_scale_tween and hit_scale_tween.is_valid():
		hit_scale_tween.kill()
	if hit_flash_tween and hit_flash_tween.is_valid():
		hit_flash_tween.kill()

	view.scale = view_base_scale
	set_hit_flash_strength(0.0)

	hit_scale_tween = create_tween()
	hit_scale_tween.tween_property(view, "scale", view_base_scale * hit_punch_scale, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hit_scale_tween.tween_property(view, "scale", view_base_scale, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if hit_flash_material_instance:
		hit_flash_tween = create_tween()
		var flash_setter := Callable(self, "set_hit_flash_strength")
		hit_flash_tween.tween_method(flash_setter, 0.0, hit_flash_strength, 0.03)
		hit_flash_tween.tween_method(flash_setter, hit_flash_strength, 0.0, 0.08)


func setup_hit_flash_material_instance() -> void:
	hit_flash_material_instance = hit_flash_material_template.duplicate(true) as ShaderMaterial
	for mesh in hit_flash_targets:
		mesh.material_overlay = hit_flash_material_instance


func set_hit_flash_strength(value: float) -> void:
	if hit_flash_material_instance:
		hit_flash_material_instance.set_shader_parameter(&"flash_strength", value)
