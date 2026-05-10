class_name FloatablePlayer3D extends CharacterBody3D

@export var mass := 1.0
@export var fluid_damp := 4.0
@export var move_speed := 10.0
@export var rotate_speed := 10.0
@export var angular_damp: float = 3.0
@export var idle_wave: float = 0.5

@onready var fluid_interactor := FluidInteractor3D.new()

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
		velocity += fluid_interactor.float_force * delta
		velocity += -velocity * fluid_damp * delta

	velocity += Vector3(0.0, -9.8 * 2, 0.0) * delta

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
