class_name MainCamera extends Node3D

@export var camera: Camera3D
@export var targets: Array[Node3D]
@export var smooth_speed: float = 10.0
@export var camera_size: float = 55.0
@export var camera_size_range: Vector2 = Vector2(50, 60)
@export var offset: Vector3 = Vector3.ZERO
@export var min_bounds: Vector3 = Vector3(-10, -10, -10)
@export var max_bounds: Vector3 = Vector3(10, 10, 10)


func _ready() -> void:
	for i in range(targets.size() - 1, -1, -1):
		var target: Node3D = targets[i]
		if target == null or not target.visible:
			targets.erase(target)
		
	camera.size = camera_size


func _process(delta: float) -> void:
	if targets.size() == 0:
		return
		
	for i in range(targets.size() - 1, -1, -1):
		if targets[i] == null or not is_instance_valid(targets[i]):
			targets.remove_at(i)

	var desired_position: Vector3
	
	if targets.size() == 1:
		desired_position = targets[0].global_position + offset
		camera.size = camera_size
		
	if targets.size() >= 2:
		var center: Vector3 = Vector3.ZERO	
		for target in targets:
			center += target.global_position
		center /= targets.size()
		desired_position = center + offset
		
		var max_distance: float = 0.0
		for target in targets:
			var distance: float = center.distance_to(target.global_position)
			max_distance = max(max_distance, distance)
		
		var target_size: float = clamp(max_distance * 2.0, camera_size_range.x, camera_size_range.y)
		camera.size = lerp(camera.size, target_size, smooth_speed * delta)
		
	desired_position.x = clamp(desired_position.x, min_bounds.x, max_bounds.x)
	desired_position.y = clamp(desired_position.y, min_bounds.y, max_bounds.y)
	desired_position.z = clamp(desired_position.z, min_bounds.z, max_bounds.z)
	
	global_position = global_position.lerp(desired_position, smooth_speed * delta)


func set_targets(new_targets: Array[Node3D]) -> void:
	targets = new_targets
	if targets.size() >= 1:
		global_position = targets[0].global_position + offset
