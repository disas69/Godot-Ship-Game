class_name FloatablePlayer3D extends CharacterBody3D

@export var mass := 1.0
@export var fluid_damp := 4.0
@export var move_speed := 10.0
@export var rotate_speed := 10.0
@export var angular_damp: float = 3.0
@export var idle_wave: float = 0.5

@onready var fluid_interactor := FluidInteractor3D.new()

var last_move_dir := Vector3.ZERO
var pitch_vel := 0.0
var roll_vel := 0.0


func _ready():
	for owner_id in get_shape_owners():
		var collision: Object = shape_owner_get_owner(owner_id)
		if collision is CollisionShape3D:
			fluid_interactor.add_collision_shape(collision)


func _physics_process(delta: float) -> void:
	fluid_interactor.process(global_transform, mass)
	
	if not fluid_interactor.float_force.is_zero_approx():
		# Bouyancy
		velocity += fluid_interactor.float_force * delta
		# Damping
		velocity += -velocity * fluid_damp * delta

	# Gravity
	velocity += Vector3(0.0, -9.8 * 2, 0.0) * delta
	
	var camera: Camera3D = get_viewport().get_camera_3d()
	var forward: Vector3 = -camera.global_transform.basis.z
	var right: Vector3 = camera.global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	
#	var move_direction := Vector3.ZERO
#	if Input.is_action_pressed("move_left"):
#		move_direction -= camera.basis.x
#	if Input.is_action_pressed("move_right"):
#		move_direction += camera.basis.x
#	if Input.is_action_pressed("move_up"):
#		move_direction -= camera.basis.z
#	if Input.is_action_pressed("move_down"):
#		move_direction += camera.basis.z
	
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var move_direction: Vector3 = (right.normalized() * input_dir.x + forward.normalized() * -input_dir.y).normalized()
	last_move_dir = move_direction
	
	if !move_direction.is_zero_approx():
		move_direction.y = 0.0
		move_direction = move_direction.normalized()
		velocity += move_direction * move_speed * delta
		quaternion = quaternion.slerp(Quaternion(Vector3.BACK, move_direction), rotate_speed * delta)

	var time: float = Time.get_ticks_msec() / 1000.0
	roll_vel += sin(time * 1.5) * idle_wave * delta
	pitch_vel += cos(time * 1.2) * idle_wave * 0.5 * delta
	
	pitch_vel = lerp(pitch_vel, 0.0, angular_damp * delta)
	roll_vel = lerp(roll_vel, 0.0, angular_damp * delta)
	
	rotation.x += (pitch_vel * delta)
	rotation.z += roll_vel * delta
	
	move_and_slide()
	
	
func fluid_area_enter(area: FluidArea3D) -> void:
	fluid_interactor.fluid_area_enter(area)


func fluid_area_exit(area: FluidArea3D) -> void:
	fluid_interactor.fluid_area_exit(area)
