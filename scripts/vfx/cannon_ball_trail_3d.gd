class_name CannonBallTrail3D
extends GPUParticles3D

const TRAIL_PARTICLES_SHADER := preload("res://shaders/ship_trail_particles.gdshader")
const TRAIL_DRAW_SHADER := preload("res://shaders/ship_trail_draw.gdshader")

@export var trail_half_width: float = 0.35
@export_range(8, 64, 1) var trail_steps: int = 16
@export_range(8, 60, 1) var trail_fps: int = 60

var _target: Node3D
var _previous_position := Vector3.ZERO
var _last_forward := Vector3.FORWARD
var _skip_frame: bool = false


func _ready() -> void:
	_target = get_parent() as Node3D
	_previous_position = _target.global_position if _target != null else global_position

	top_level = true
	amount = trail_steps
	lifetime = float(trail_steps)
	explosiveness = 1.0
	fixed_fps = trail_fps
	visibility_aabb = AABB(Vector3(-40.0, -40.0, -40.0), Vector3(80.0, 80.0, 80.0))

	process_material = ShaderMaterial.new()
	(process_material as ShaderMaterial).shader = TRAIL_PARTICLES_SHADER

	var quad := QuadMesh.new()
	var material := ShaderMaterial.new()
	material.shader = TRAIL_DRAW_SHADER
	material.resource_local_to_scene = true
	material.render_priority = 4
	quad.material = material
	draw_pass_1 = quad

	material.set_shader_parameter("color_ramp", _create_color_ramp())
	material.set_shader_parameter("width_curve", _create_width_curve())
	material.set_shader_parameter("opacity", 0.6)
	reset_trail()


func reset_trail() -> void:
	if _target != null and is_instance_valid(_target):
		_previous_position = _target.global_position
		var target_vel: Variant = _target.get("linear_velocity")
		if target_vel is Vector3 and not (target_vel as Vector3).is_zero_approx():
			_last_forward = (target_vel as Vector3).normalized()
		else:
			_last_forward = -_target.global_transform.basis.z
			if _last_forward.is_zero_approx():
				_last_forward = Vector3.FORWARD
	else:
		_previous_position = global_position

	var right := _last_forward.cross(Vector3.UP).normalized()
	if right.is_zero_approx():
		right = Vector3.RIGHT

	global_transform = Transform3D(
		Basis(right * trail_half_width, Vector3.UP, _last_forward),
		_previous_position
	)

	emitting = false
	restart()
	emitting = true
	_skip_frame = true


func _process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return

	if _skip_frame:
		_skip_frame = false
		_previous_position = _target.global_position
		return

	var current_position := _target.global_position
	var movement := current_position - _previous_position
	if delta > 0.0:
		movement /= delta

	var speed := movement.length()
	if speed > 0.1:
		_last_forward = movement / speed

	var right := _last_forward.cross(Vector3.UP).normalized()
	if right.is_zero_approx():
		right = Vector3.RIGHT

	global_transform = Transform3D(
		Basis(right * trail_half_width, Vector3.UP, _last_forward),
		current_position
	)

	_previous_position = current_position



static var _cached_color_ramp: GradientTexture1D = null
static var _cached_width_curve: CurveTexture = null


func _create_color_ramp() -> GradientTexture1D:
	if _cached_color_ramp != null:
		return _cached_color_ramp

	var gradient := Gradient.new()
	gradient.set_offset(0, 0.0)
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 0.7))
	gradient.set_offset(1, 1.0)
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	gradient.add_point(0.2, Color(1.0, 1.0, 1.0, 0.6))

	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	texture.width = 128
	_cached_color_ramp = texture
	return _cached_color_ramp


func _create_width_curve() -> CurveTexture:
	if _cached_width_curve != null:
		return _cached_width_curve

	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0), 0.0, 0.0)
	curve.add_point(Vector2(0.5, 0.6), 0.0, 0.0)
	curve.add_point(Vector2(1.0, 0.0), 0.0, 0.0)

	var texture := CurveTexture.new()
	texture.curve = curve
	texture.width = 128
	_cached_width_curve = texture
	return _cached_width_curve
