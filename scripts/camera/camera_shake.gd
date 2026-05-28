class_name CameraShake extends Node

@export var target: Node
@export var max_offset: Vector2 = Vector2(1.2, 1.2)
@export_range(0.0, 15.0, 0.1) var max_roll_degrees: float = 0.0
@export var shake_speed: float = 30.0
@export var shake_decay_rate: float = 5.0
@export var noise_frequency: float = 0.5
@export var trauma_power: float = 2.0
@export var randomize_seed: bool = true
@export var noise_seed: int = 0

var trauma: float = 0.0
var noise_i: float = 0.0
var noise := FastNoiseLite.new()
var previous_offset := Vector2.ZERO
var previous_roll := 0.0


func _ready() -> void:
	add_to_group("CameraShake")
	if target == null:
		target = get_parent()

	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = noise_frequency
	if randomize_seed:
		noise.seed = randi()
	else:
		noise.seed = noise_seed


func _process(delta: float) -> void:
	clear_previous_shake()

	trauma = move_toward(trauma, 0.0, shake_decay_rate * delta)
	if is_zero_approx(trauma):
		previous_offset = Vector2.ZERO
		previous_roll = 0.0
		return

	noise_i += delta * shake_speed
	var strength: float = pow(trauma, trauma_power)
	var noise_offset := get_noise_offset()
	previous_offset = Vector2(
		noise_offset.x * max_offset.x,
		noise_offset.y * max_offset.y
	) * strength
	previous_roll = deg_to_rad(max_roll_degrees) * noise.get_noise_2d(300.0, noise_i) * strength
	apply_shake(previous_offset, previous_roll)


func shake(amount: float = 1.0) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


func set_shake(amount: float) -> void:
	trauma = clampf(amount, 0.0, 1.0)


func stop() -> void:
	clear_previous_shake()
	trauma = 0.0
	previous_offset = Vector2.ZERO
	previous_roll = 0.0


func get_noise_offset() -> Vector2:
	return Vector2(
		noise.get_noise_2d(1.0, noise_i),
		noise.get_noise_2d(100.0, noise_i)
	)


func apply_shake(offset: Vector2, roll: float) -> void:
	var camera_2d := target as Camera2D
	if camera_2d != null:
		camera_2d.offset += offset
		camera_2d.rotation += roll
		return

	var camera_3d := target as Camera3D
	if camera_3d != null:
		camera_3d.h_offset += offset.x
		camera_3d.v_offset += offset.y
		camera_3d.rotation.z += roll


func clear_previous_shake() -> void:
	if previous_offset.is_zero_approx() and is_zero_approx(previous_roll):
		return

	apply_shake(-previous_offset, -previous_roll)
