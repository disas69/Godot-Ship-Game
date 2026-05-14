class_name BotShip extends Ship

@export_category("Navigation")
@export var navigation_agent: NavigationAgent3D
@export var target: Node3D
@export var use_auto_target_when_empty: bool = false
@export var target_update_interval: float = 1.0
@export var stop_distance: float = 2.5
@export var path_desired_distance: float = 2.0
@export var target_desired_distance: float = 3.0

@export_category("Behavior")
@export var shoot_radius: float = 15.0
@export var shoot_interval_range: Vector2

var time: float
var target_update_timer: float = 0.0
var next_shoot_time: float = 0.0

func _ready() -> void:
	show_aim_helpers = false

	if navigation_agent:
		navigation_agent.path_desired_distance = path_desired_distance
		navigation_agent.target_desired_distance = target_desired_distance
		update_navigation_target()

	super._ready()
	

func _process(delta: float) -> void:
	time += delta
	super._process(delta)


func _physics_process(delta: float) -> void:
	target_update_timer -= delta

	if target_update_timer <= 0.0:
		target_update_timer = target_update_interval
		update_navigation_target()

	super._physics_process(delta)


func get_move_input() -> Vector2:
	if navigation_agent == null:
		return Vector2.ZERO

	var nav_target: Node3D = get_navigation_target()
	if nav_target == null:
		return Vector2.ZERO

	var next_position: Vector3 = navigation_agent.get_next_path_position()

	var direction: Vector3 = next_position - global_position
	direction.y = 0.0

	var target_position: Vector3 = navigation_agent.target_position
	target_position.y = global_position.y
	var distance_to_target: float = global_position.distance_to(target_position)
	if distance_to_target <= stop_distance or direction.is_zero_approx():
		return Vector2.ZERO

	direction = direction.normalized()

	var camera: Camera3D = get_viewport().get_camera_3d()
	var camera_right: Vector3 = camera.global_transform.basis.x
	var camera_forward: Vector3 = -camera.global_transform.basis.z
	camera_right.y = 0.0
	camera_forward.y = 0.0
	camera_right = camera_right.normalized()
	camera_forward = camera_forward.normalized()

	return Vector2(direction.dot(camera_right), -direction.dot(camera_forward))


func update_navigation_target() -> void:
	var nav_target: Node3D = get_navigation_target()
	if nav_target == null:
		return

	navigation_agent.set_target_position(nav_target.global_position)


func get_navigation_target() -> Node3D:
	if target != null and is_instance_valid(target) and target != self:
		return target

	if use_auto_target_when_empty:
		return find_default_target()

	return null


func find_default_target() -> Ship:
	var closest_ship: Ship = null
	var closest_distance: float = INF

	for node in get_tree().get_nodes_in_group("Ship"):
		var ship := node as Ship

		if ship == null or ship.is_destroyed or ship == self:
			continue

		var distance := global_position.distance_to(ship.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_ship = ship

	return closest_ship


func can_shoot() -> bool:
	if target != null and is_instance_valid(target) and target != self:
		var distance_to_target: float = global_position.distance_to(target.global_position)
		if distance_to_target <= shoot_radius and time >= next_shoot_time:
			next_shoot_time = time + randf_range(shoot_interval_range.x, shoot_interval_range.y)
			return true
	return false
