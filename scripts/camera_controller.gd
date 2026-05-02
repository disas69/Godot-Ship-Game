class_name CameraController extends Node3D

@export var target: Node3D
@export var smooth_speed := 10.0

@export var min_bounds: Vector3 = Vector3(-10, -10, -10)
@export var max_bounds: Vector3 = Vector3(10, 10, 10)

var offset: Vector3 = Vector3.ZERO

func _ready() -> void:
	if target:
		offset = global_position - target.global_position

func _process(delta: float) -> void:
	if not target:
		return

	var desired_position = target.global_position + offset

	# Clamp
	desired_position.x = clamp(desired_position.x, min_bounds.x, max_bounds.x)
	desired_position.y = clamp(desired_position.y, min_bounds.y, max_bounds.y)
	desired_position.z = clamp(desired_position.z, min_bounds.z, max_bounds.z)

	# Smooth follow
	global_position = global_position.lerp(desired_position, smooth_speed * delta)
