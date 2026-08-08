class_name BirdFlockSpawner
extends Node3D

@export_group("Custom Assets")
@export var custom_bird_scene: PackedScene = null
@export var custom_bird_mesh: Mesh = null
@export var custom_bird_texture: Texture2D = null

@export_group("Spawn Settings")
@export var auto_spawn: bool = true
@export var spawn_interval_min: float = 12.0
@export var spawn_interval_max: float = 24.0
@export var spawn_altitude: float = 22.0
@export var flight_speed: float = 14.0
@export var bird_count_min: int = 5
@export var bird_count_max: int = 11
## Distance from camera where birds spawn and despawn (outside camera view bounds).
@export var spawn_radius_from_camera: float = 130.0

var spawn_timer: float = 0.0

func _ready() -> void:
	if auto_spawn:
		reset_timer()

func _process(delta: float) -> void:
	if not auto_spawn:
		return

	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_flock()
		reset_timer()

func reset_timer() -> void:
	spawn_timer = randf_range(spawn_interval_min, spawn_interval_max)

func spawn_flock() -> BirdFlock:
	var flock = BirdFlock.new()
	flock.custom_bird_scene = custom_bird_scene
	flock.custom_bird_mesh = custom_bird_mesh
	flock.custom_bird_texture = custom_bird_texture
	flock.bird_count = randi_range(bird_count_min, bird_count_max)
	flock.name = "BirdFlock_Instance"

	# Center flight path relative to current active 3D camera if present
	var center_origin = global_position
	var camera = get_viewport().get_camera_3d()
	if camera != null:
		var cam_parent = camera.get_parent()
		center_origin = cam_parent.global_position if cam_parent is Node3D else camera.global_transform.origin

	# Choose random flight angle
	var angle = randf() * TAU
	var start_dir = Vector3(cos(angle), 0.0, sin(angle))
	
	# Start well outside camera view frustum
	var start_pos = center_origin + start_dir * spawn_radius_from_camera
	start_pos.y = spawn_altitude
	
	# End well outside camera view frustum on opposite side
	var target_pos = center_origin - start_dir * spawn_radius_from_camera
	target_pos.y = spawn_altitude + randf_range(-2.0, 2.0)

	get_parent().add_child(flock)
	flock.start_flight(start_pos, target_pos, flight_speed)
	return flock
