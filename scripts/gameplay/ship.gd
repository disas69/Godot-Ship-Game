class_name Ship extends FloatablePlayer3D

const AIM_OVERLAY_SHADER := preload("res://shaders/aim_overlay.gdshader")

signal destroyed(ship: Ship)

enum Team {
	GoodGuys,
	BadGuys
}

@export_category("Settings")
@export var team: Team = Team.GoodGuys
@export var hit_ponts: int = 3
@export var aim_help_check_radius: float = 5.0

@export_category("View")
@export var view: Node3D
@export var good_view: Node3D
@export var bad_view: Node3D
@export var forward_incline: Vector2
@export var side_incline: Vector3
@export_category("Outline")
@export var enable_outline: bool = true
@export var outline_color: Color = Color.BLACK
@export var outline_thickness: float = 0.075
@export_category("Hit FX")
@export var hit_punch_scale: float = 1.12
@export var hit_flash_strength: float = 0.8
@export var hit_flash_material_template: ShaderMaterial
@export var hit_flash_targets: Array[GeometryInstance3D] = []
@export_category("Destroyed FX")
@export var destroyed_sink_distance: float = 3.0
@export var destroyed_sink_duration: float = 2.5
@export var destroyed_shake_strength: float = 0.2
@export_range(0.01, 1.0, 0.01) var destroyed_shake_step_duration: float = 0.1
@export var destroyed_destroy_delay: float = 1.0
@export var destroyed_push_radius: float = 25.0
@export var destroyed_push_strength: float = 25.0

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
@export var gamepad_aim_move_speed: float = 28.0
@export_range(0.0, 1.0, 0.01) var gamepad_aim_deadzone: float = 0.12
@export var show_aim_helpers: bool = true
@export var aim_line_dot_count: int = 12
@export var aim_line_dot_radius: float = 0.08
@export_range(0, 64, 1) var cannon_ball_preload_count: int = 8
@export_range(0, 128, 1) var max_cannon_ball_pool_size: int = 24

var last_move_dir := Vector3.ZERO
var auto_aim_target := Vector3.ZERO
var auto_aim_target_ship: Ship
var default_gravity: float
var cannon_start_position: Vector3
var cannon_start_scale: Vector3
var cannon_tween: Tween
var aim_line: MultiMeshInstance3D
var view_base_scale: Vector3
var hit_scale_tween: Tween
var hit_flash_tween: Tween
var hit_flash_material_instance: ShaderMaterial
var outline_material_instance: ShaderMaterial
var is_destroyed: bool
var gameplay_enabled: bool = true
var manual_aim_offset := Vector3.ZERO
var cannon_ball_pool: ObjectPool
var cannon_ball_pool_root: Node3D


func _ready() -> void:
	add_to_group("Ship")
	update_team_view()
	default_gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
	cannon_start_position = cannon_view.position
	cannon_start_scale = cannon_view.scale
	view_base_scale = view.scale
	setup_hit_flash_material_instance()
	set_hit_flash_strength(0.0)
	setup_outline_material_instance()
	setup_aim_line()
	initialize_aim_offset()
	setup_cannon_ball_pool()
	super._ready()


func update_team_view() -> void:
	if good_view != null:
		good_view.visible = team == Team.GoodGuys
	if bad_view != null:
		bad_view.visible = team == Team.BadGuys


func _physics_process(delta: float) -> void:
	if is_destroyed or not gameplay_enabled:
		return

	var camera: Camera3D = get_view_camera()
	if camera == null:
		return

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
	if is_destroyed or not gameplay_enabled:
		return

	if !last_move_dir.is_zero_approx():
		incline_view_x(delta)
		incline_view_z(delta)
	else:
		view.rotation_degrees = lerp(view.rotation_degrees, Vector3.ZERO, 5.0 * delta)

	var time: float = Time.get_ticks_msec() / 1000.0
	view.position.y -= sin(time * 4) * idle_wave * delta
	
	var target_position: Variant = get_aim_target_position(delta)
	if target_position != null:
		target_position = clamp_aim_position(target_position)
	else:
		var aim_input: Vector2 = get_aim_input()
	
		if not should_use_mouse_aim(aim_input):
			target_position = get_gamepad_aim_position(aim_input, delta)
		else:
			var camera: Camera3D = get_view_camera()
			var mouse_pos: Vector2 = get_viewport().get_mouse_position()
			target_position = get_mouse_water_position(camera, mouse_pos)
	
	if target_position != null:
		var target: Vector3 = target_position
		rotate_cannon_towards(target)
	else:
		if is_auto_aim_target_active():
			var locked_target: Vector3 = auto_aim_target_ship.global_position
			locked_target.y = global_position.y
			rotate_cannon_towards(locked_target)
		target_position = get_cannon_forward_aim_position()
	
	var aim_target: Vector3 = try_get_auto_aim_target(target_position)
	if show_aim_helpers:
		update_aim_line(aim_target)
	elif aim_line:
		aim_line.visible = false
		aim_indicator.visible = false

	if can_shoot():
		var shoot_direction: Vector3 = aim_target - get_aim_origin()
		shoot_direction.y = aim_target.y
		shoot(aim_target + (shoot_direction.normalized() * 1.5))


func get_move_input() -> Vector2:
	return Vector2.ZERO


func get_aim_input() -> Vector2:
	return Vector2.ZERO


func get_aim_target_position(_delta: float) -> Variant:
	return null


func should_use_mouse_aim(_aim_input: Vector2) -> bool:
	return false


func should_keep_gamepad_aim_without_input() -> bool:
	return false


func can_shoot() -> bool:
	return false


func set_gameplay_enabled(enabled: bool) -> void:
	gameplay_enabled = enabled
	set_process(enabled)
	set_physics_process(enabled)
	set_process_input(enabled)

	if enabled:
		return

	velocity = Vector3.ZERO
	last_move_dir = Vector3.ZERO
	auto_aim_target_ship = null
	auto_aim_target = Vector3.ZERO

	if aim_line != null:
		aim_line.visible = false
	if aim_indicator != null:
		aim_indicator.visible = false


func is_auto_aim_target_active() -> bool:
	return auto_aim_target_ship != null and is_instance_valid(auto_aim_target_ship) and can_target_ship(auto_aim_target_ship)


func can_target_ship(other: Ship) -> bool:
	if other == null or other == self or other.is_destroyed:
		return false

	return other.team != team
	

func try_get_auto_aim_target(pos: Vector3) -> Vector3:
	if is_auto_aim_target_active():
		var locked_target: Vector3 = auto_aim_target_ship.global_position
		locked_target.y = pos.y
		if locked_target.distance_to(pos) <= get_aim_radius_limits().y / 2:
			auto_aim_target = locked_target
			return locked_target

	auto_aim_target_ship = null
	auto_aim_target = Vector3.ZERO

	var closest_target_ship: Ship
	var closest_distance: float = aim_help_check_radius
	for node in get_tree().get_nodes_in_group("Ship"):
		var ship: Ship = node as Ship
		if not can_target_ship(ship):
			continue

		var target_position: Vector3 = ship.global_position
		target_position.y = pos.y
		var distance: float = target_position.distance_to(pos)
		if distance <= closest_distance:
			closest_distance = distance
			closest_target_ship = ship

	if closest_target_ship != null:
		auto_aim_target_ship = closest_target_ship
		auto_aim_target = closest_target_ship.global_position
		auto_aim_target.y = pos.y
		return auto_aim_target

	return pos
	

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


func get_gamepad_aim_position(aim: Vector2, delta: float) -> Variant:
	var aim_origin: Vector3 = get_aim_origin()
	var aim_strength: float = aim.length()
	if aim_strength <= gamepad_aim_deadzone:
		if should_keep_gamepad_aim_without_input():
			return aim_origin + manual_aim_offset
		return null

	var camera: Camera3D = get_view_camera()
	if camera == null:
		return null

	var forward: Vector3 = -camera.global_transform.basis.z
	var right: Vector3 = camera.global_transform.basis.x

	forward.y = 0.0
	right.y = 0.0

	var target_dir: Vector3 = (right.normalized() * aim.x + forward.normalized() * -aim.y).normalized()
	var limits: Vector2 = get_aim_radius_limits()
	var desired_radius: float = lerp(limits.x, limits.y, clamp(aim_strength, 0.0, 1.0))
	var desired_offset: Vector3 = target_dir * desired_radius
	var next_offset: Vector3 = manual_aim_offset.move_toward(desired_offset, gamepad_aim_move_speed * delta)
	set_aim_offset(next_offset)
	return aim_origin + manual_aim_offset


func get_mouse_water_position(camera: Camera3D, mouse_pos: Vector2) -> Variant:
	if camera == null:
		return null

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
	set_aim_offset(target_position - aim_origin)
	return aim_origin + manual_aim_offset


func get_view_camera() -> Camera3D:
	var active_camera: Camera3D = get_viewport().get_camera_3d()
	var main_camera := get_tree().get_first_node_in_group("MainCamera")
	if main_camera != null and main_camera.has_method("get_camera_for_target"):
		var target_camera: Variant = main_camera.get_camera_for_target(self)
		if target_camera is Camera3D:
			active_camera = target_camera

	return active_camera


func get_cannon_forward_aim_position() -> Vector3:
	var cannon_forward: Vector3 = cannon_anchor.global_transform.basis.z
	cannon_forward.y = 0.0

	if cannon_forward.is_zero_approx():
		cannon_forward = Vector3.FORWARD

	var limits: Vector2 = get_aim_radius_limits()
	return clamp_aim_position(get_aim_origin() + cannon_forward.normalized() * limits.y)


func get_aim_origin() -> Vector3:
	return Vector3(cannon_root.global_position.x, global_position.y, cannon_root.global_position.z)


func initialize_aim_offset() -> void:
	var limits: Vector2 = get_aim_radius_limits()
	set_aim_offset(resolve_fallback_aim_direction() * clamp(cannon_aim_radius, limits.x, limits.y))


func resolve_fallback_aim_direction() -> Vector3:
	var fallback_dir: Vector3 = manual_aim_offset
	fallback_dir.y = 0.0
	if fallback_dir.is_zero_approx():
		fallback_dir = cannon_root.global_transform.basis.z
		fallback_dir.y = 0.0
	if fallback_dir.is_zero_approx():
		fallback_dir = Vector3.FORWARD
	return fallback_dir.normalized()


func get_aim_radius_limits() -> Vector2:
	return Vector2(minf(cannon_aim_radius_max.x, cannon_aim_radius_max.y), maxf(cannon_aim_radius_max.x, cannon_aim_radius_max.y))


func set_aim_offset(offset: Vector3) -> void:
	manual_aim_offset = clamp_aim_offset(offset)
	cannon_aim_radius = manual_aim_offset.length()
	update_cannon_view_rotation_from_aim_radius()


func clamp_aim_offset(offset: Vector3) -> Vector3:
	var flat_offset := Vector3(offset.x, 0.0, offset.z)
	if flat_offset.is_zero_approx():
		flat_offset = resolve_fallback_aim_direction()
	var limits: Vector2 = get_aim_radius_limits()
	var clamped_radius: float = clamp(flat_offset.length(), limits.x, limits.y)
	return flat_offset.normalized() * clamped_radius


func update_cannon_view_rotation_from_aim_radius() -> void:
	var limits: Vector2 = get_aim_radius_limits()
	var t: float = inverse_lerp(limits.x, limits.y, cannon_aim_radius)
	var cannon_view_target_rotation: float = lerp(cannon_view_rotation_max.x, cannon_view_rotation_max.y, t)
	cannon_view.rotation_degrees.x = cannon_view_target_rotation


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
	dot_material.render_priority = 10
	dot_material.shader = AIM_OVERLAY_SHADER
	dot_material.set_shader_parameter("use_texture", false)
	dot_material.set_shader_parameter("tint_color", Color(1.0, 1.0, 1.0, 0.6))
	dot_material.set_shader_parameter("intensity", 1.0)
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
	
	if is_auto_aim_target_active():
		aim_indicator.scale = Vector3.ONE * 1.8
	else:
		aim_indicator.scale = Vector3.ONE


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
	if cannon_ball_inst == null:
		return

	var start_pos: Vector3 = cannon_anchor.global_transform.origin
	var launch_velocity: Vector3 = calculate_ballistic_velocity(start_pos, target_position, cannon_ball_inst.gravity_scale)
	
	if not is_auto_aim_target_active():
		launch_velocity += velocity
	
	cannon_ball_inst.linear_velocity = launch_velocity
	cannon_ball_inst.set_shooter(self)

	play_cannon_recoil()
	play_cannon_smoke_particles()
	on_shot_fired()
	AudioManager.play_sfx("cannon_shoot", start_pos)


func spawn_cannon_ball() -> CannonBall:
	if cannon_ball_pool == null:
		setup_cannon_ball_pool()

	var cannon_ball_inst: CannonBall = cannon_ball_pool.acquire() as CannonBall
	if cannon_ball_inst == null:
		return null

	move_cannon_ball_to_parent(cannon_ball_inst, get_cannon_ball_spawn_parent())
	cannon_ball_inst.global_transform = cannon_anchor.global_transform
	cannon_ball_inst.reset_for_spawn()
	return cannon_ball_inst


func setup_cannon_ball_pool() -> void:
	if cannon_ball_pool != null:
		return

	ensure_cannon_ball_pool_root()
	cannon_ball_pool = ObjectPool.new(
		create_cannon_ball,
		reset_cannon_ball_for_pool,
		discard_cannon_ball,
		max_cannon_ball_pool_size
	)
	cannon_ball_pool.prewarm(cannon_ball_preload_count)


func ensure_cannon_ball_pool_root() -> void:
	if cannon_ball_pool_root != null and is_instance_valid(cannon_ball_pool_root):
		return

	cannon_ball_pool_root = Node3D.new()
	cannon_ball_pool_root.name = "CannonBallPool"
	cannon_ball_pool_root.visible = false
	cannon_ball_pool_root.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(cannon_ball_pool_root)


func create_cannon_ball() -> CannonBall:
	if cannon_ball == null:
		push_warning("Cannot create cannon ball because no scene is assigned.")
		return null

	var cannon_ball_inst: CannonBall = cannon_ball.instantiate() as CannonBall
	if cannon_ball_inst == null:
		push_warning("Cannon ball scene root must be a CannonBall.")
		return null

	cannon_ball_inst.set_release_callback(release_cannon_ball)
	return cannon_ball_inst


func reset_cannon_ball_for_pool(cannon_ball_inst: CannonBall) -> void:
	cannon_ball_inst.reset_for_pool()
	if cannon_ball_inst.get_parent() != cannon_ball_pool_root:
		move_cannon_ball_to_parent(cannon_ball_inst, cannon_ball_pool_root)


func release_cannon_ball(cannon_ball_inst: CannonBall) -> void:
	if cannon_ball_pool == null:
		cannon_ball_inst.queue_free()
		return

	cannon_ball_pool.release(cannon_ball_inst)


func discard_cannon_ball(cannon_ball_inst: CannonBall) -> void:
	if is_instance_valid(cannon_ball_inst):
		cannon_ball_inst.queue_free()


func move_cannon_ball_to_parent(cannon_ball_inst: CannonBall, parent: Node) -> void:
	if cannon_ball_inst.get_parent() == parent:
		return
	if cannon_ball_inst.get_parent() != null:
		cannon_ball_inst.get_parent().remove_child(cannon_ball_inst)
	parent.add_child(cannon_ball_inst)


func get_cannon_ball_spawn_parent() -> Node:
	if get_tree().current_scene != null:
		return get_tree().current_scene
	return get_tree().root


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
	VfxManager.spawn_at_transform("cannon_smoke", cannon_anchor.global_transform)


func take_hit(hit_velocity: Vector3, attacker: Ship = null) -> void:
	if is_destroyed:
		return

	on_attacked_by(attacker)
	hit_ponts -= 1
	hit_velocity.y = 0
	velocity += hit_velocity
	
	var text_spawn_pos := global_position + Vector3.UP * 2.5

	if hit_ponts > 0:
		VfxManager.spawn_damage_text(text_spawn_pos, false)
		play_hit_feedback(Color.WHITE)
		on_hit_taken(false)
	else:
		is_destroyed = true
		destroyed.emit(self)
		VfxManager.spawn_damage_text(text_spawn_pos, true)
		play_hit_feedback(Color.RED)
		on_hit_taken(true)
		play_destroyed_feedback()
		

func on_attacked_by(_attacker: Ship) -> void:
	pass


func on_shot_fired() -> void:
	pass


func on_hit_taken(_destroyed: bool) -> void:
	pass


func play_destroyed_feedback() -> void:
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	
	VfxManager.spawn_at_transform("fire", Transform3D(Basis(), cannon_root.global_position + Vector3.UP), self)

	var sink_tween: Tween = create_tween()
	sink_tween.tween_property(self, "position", position + Vector3.DOWN * destroyed_sink_distance, destroyed_sink_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	var shake_tween: Tween = create_tween()
	var base_view_position: Vector3 = view.position
	var shake_step_duration: float = maxf(destroyed_shake_step_duration, 0.01)
	var shake_steps: int = maxi(1, int(round(destroyed_sink_duration / shake_step_duration)))
	for step in shake_steps:
		var shake_progress: float = float(step + 1) / float(shake_steps)
		var shake_amplitude: float = lerp(destroyed_shake_strength, 0.02, shake_progress)
		var shake_offset := Vector3(randf_range(-shake_amplitude, shake_amplitude), 0.0, randf_range(-shake_amplitude, shake_amplitude))

		shake_tween.tween_property(view, "position", base_view_position + shake_offset, shake_step_duration * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		shake_tween.tween_property(view, "position", base_view_position, shake_step_duration * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	await get_tree().create_timer(destroyed_sink_duration - 0.5).timeout
	view.position = base_view_position
	
	var explosion_position: Vector3 = global_position + Vector3.UP * destroyed_sink_distance
	VfxManager.spawn("ship_explosion", explosion_position)
	
	await get_tree().create_timer(0.25).timeout
	push_ships_from_explosion(explosion_position)
	AudioManager.play_sfx("ship_explosion", global_position)
	
	await get_tree().create_timer(destroyed_destroy_delay).timeout
	queue_free()


func push_ships_from_explosion(explosion_position: Vector3) -> void:
	if destroyed_push_radius <= 0.0 or destroyed_push_strength <= 0.0:
		return

	for node in get_tree().get_nodes_in_group("Ship"):
		var ship := node as Ship
		if ship == null or ship == self or ship.is_destroyed:
			continue

		var push_offset: Vector3 = ship.global_position - explosion_position
		push_offset.y = 0.0
		var distance: float = push_offset.length()
		if distance <= 0.0 or distance > destroyed_push_radius:
			continue

		var push_falloff: float = 1.0 - (distance / destroyed_push_radius)
		ship.velocity += push_offset.normalized() * destroyed_push_strength * push_falloff


func play_hit_feedback(color: Color) -> void:
	if hit_scale_tween and hit_scale_tween.is_valid():
		hit_scale_tween.kill()
	if hit_flash_tween and hit_flash_tween.is_valid():
		hit_flash_tween.kill()

	view.scale = view_base_scale
	set_hit_flash_color(color)
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


func set_hit_flash_color(color: Color) -> void:
	if hit_flash_material_instance:
		hit_flash_material_instance.set_shader_parameter(&"flash_color", color)


func set_hit_flash_strength(value: float) -> void:
	if hit_flash_material_instance:
		hit_flash_material_instance.set_shader_parameter(&"flash_strength", value)


func setup_outline_material_instance() -> void:
	if not enable_outline:
		return
	outline_material_instance = OutlineHelper.create_outline_material(outline_color, outline_thickness)
	OutlineHelper.apply_outline_to_nodes([self], outline_material_instance)


func set_outline_color(color: Color) -> void:
	outline_color = color
	OutlineHelper.update_outline_color(outline_material_instance, color)


func set_outline_thickness(thickness: float) -> void:
	outline_thickness = thickness
	OutlineHelper.update_outline_thickness(outline_material_instance, thickness)
