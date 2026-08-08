class_name ShipTrail3D
extends GPUParticles3D

const TRAIL_PARTICLES_SHADER := preload("res://shaders/ship_trail_particles.gdshader")
const TRAIL_DRAW_SHADER := preload("res://shaders/ship_trail_draw.gdshader")
const FOAM_NOISE := preload("res://addons/toon_water/Textures/PerlinNoise.png")
const FOAM_DISTORTION := preload("res://addons/toon_water/Textures/WaterDistortion.png")

@export var water_height: float = 5.0
@export var stern_distance: float = 3.0
@export var trail_half_width: float = 1.75
@export var min_speed: float = 0.8
@export var fade_speed: float = 6.0
@export_range(8, 64, 1) var trail_steps: int = 24
@export_range(8, 60, 1) var trail_fps: int = 30

var _target: Node3D
var _previous_position := Vector3.ZERO
var _last_forward := Vector3.BACK
var _opacity := 0.0


func _ready() -> void:
	_target = get_parent() as Node3D
	_previous_position = _target.global_position if _target != null else global_position

	top_level = true
	amount = trail_steps
	lifetime = float(trail_steps)
	explosiveness = 1.0
	fixed_fps = trail_fps
	visibility_aabb = AABB(Vector3(-80.0, -8.0, -80.0), Vector3(160.0, 16.0, 160.0))

	process_material = ShaderMaterial.new()
	process_material.shader = TRAIL_PARTICLES_SHADER

	var quad := QuadMesh.new()
	var material := ShaderMaterial.new()
	material.shader = TRAIL_DRAW_SHADER
	material.resource_local_to_scene = true
	material.render_priority = 3
	quad.material = material
	draw_pass_1 = quad

	material.set_shader_parameter("foam_noise", FOAM_NOISE)
	material.set_shader_parameter("distort_noise", FOAM_DISTORTION)
	material.set_shader_parameter("color_ramp", _create_color_ramp())
	material.set_shader_parameter("width_curve", _create_width_curve())
	material.set_shader_parameter("opacity", 0.0)
	restart()


func _process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return

	var current_position := _target.global_position
	var movement := _get_horizontal_velocity(current_position, delta)
	var speed := movement.length()
	if speed > min_speed:
		_last_forward = movement / speed

	var right := _last_forward.cross(Vector3.UP).normalized()
	if right.is_zero_approx():
		right = Vector3.RIGHT

	var origin := current_position - _last_forward * stern_distance
	origin.y = water_height

	global_transform = Transform3D(
		Basis(right * trail_half_width, Vector3.UP, _last_forward),
		origin
	)

	var target_opacity: float = clampf((speed - min_speed) / maxf(min_speed, 0.001), 0.0, 1.0)
	_opacity = move_toward(_opacity, target_opacity, fade_speed * delta)
	var material := draw_pass_1.material as ShaderMaterial
	material.set_shader_parameter("opacity", _opacity)

	_previous_position = current_position


func _get_horizontal_velocity(current_position: Vector3, delta: float) -> Vector3:
	var velocity := Vector3.ZERO
	var target_velocity: Variant = _target.get("velocity")
	if target_velocity is Vector3:
		velocity = target_velocity
	elif delta > 0.0:
		velocity = (current_position - _previous_position) / delta

	velocity.y = 0.0
	return velocity


static var _cached_color_ramp: GradientTexture1D = null
static var _cached_width_curve: CurveTexture = null


func _create_color_ramp() -> GradientTexture1D:
	if _cached_color_ramp != null:
		return _cached_color_ramp
	var gradient := Gradient.new()
	gradient.set_offset(0, 0.0)
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_offset(1, 1.0)
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	gradient.add_point(0.35, Color(1.0, 1.0, 1.0, 1.0))

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
	curve.add_point(Vector2(0.65, 0.72), 0.0, 0.0)
	curve.add_point(Vector2(1.0, 0.0), 0.0, 0.0)

	var texture := CurveTexture.new()
	texture.curve = curve
	texture.width = 128
	_cached_width_curve = texture
	return _cached_width_curve
