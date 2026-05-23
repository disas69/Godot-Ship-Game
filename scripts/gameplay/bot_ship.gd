class_name BotShip extends Ship

@export_category("Navigation")
@export var navigation_agent: NavigationAgent3D
@export var target: Node3D
@export var reach_targets: Array[Node3D] = []
@export var use_auto_target_when_empty: bool = false
@export var target_update_interval: float = 1.0
@export var stop_distance: float = 2.5
@export var path_desired_distance: float = 2.0
@export var target_desired_distance: float = 3.0
@export var patrol_bounds_min: Vector3 = Vector3(-150.0, 0.0, -150.0)
@export var patrol_bounds_max: Vector3 = Vector3(150.0, 0.0, 150.0)
@export var patrol_point_count_range: Vector2i = Vector2i(3, 5)
@export var patrol_reach_distance: float = 6.0

@export_category("Behavior")
@export var shoot_radius: float = 15.0
@export var shoot_interval_range: Vector2
@export var target_search_radius: float = 60.0
@export var target_lose_radius: float = 85.0
@export var idle_wait_time_range: Vector2 = Vector2(0.5, 2.0)
@export var attack_min_distance: float = 8.0
@export var attack_preferred_distance: float = 16.0
@export var attack_position_tolerance: float = 2.0
@export var closest_reach_target_attempts: Vector2i = Vector2i(0, 2)

var time: float
var target_update_timer: float = 0.0
var next_shoot_time: float = 0.0
var idle_wait_timer: float = 0.0
var current_target_position: Vector3 = Vector3.ZERO
var patrol_points: Array[Vector3] = []
var patrol_index: int = 0
var current_reach_target: Node3D
var reach_target_attempt_count: int = 0
var closest_reach_target_attempt_limit: int = 0

enum BotState {
	IDLE_WAIT,
	IDLE_PATROL,
	REACH_TARGET,
	ATTACK
}

var state: BotState = BotState.IDLE_WAIT

func _ready() -> void:
	show_aim_helpers = false

	generate_patrol_points()
	randomize_closest_reach_target_attempt_limit()
	enter_idle_wait()

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

	if state == BotState.IDLE_WAIT:
		update_idle_wait(delta)

	if state == BotState.IDLE_PATROL:
		update_patrol_progress()

	if state != BotState.IDLE_WAIT and target_update_timer <= 0.0:
		target_update_timer = target_update_interval
		refresh_target_state()
		update_navigation_target()

	super._physics_process(delta)


func get_move_input() -> Vector2:
	if navigation_agent == null or state == BotState.IDLE_WAIT:
		return Vector2.ZERO

	var next_position: Vector3 = navigation_agent.get_next_path_position()

	var direction: Vector3 = next_position - global_position
	direction.y = 0.0

	var target_position: Vector3 = current_target_position
	target_position.y = global_position.y
	var distance_to_target: float = global_position.distance_to(target_position)
	if distance_to_target <= get_stop_distance() or direction.is_zero_approx():
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


func get_aim_target_position(_delta: float) -> Variant:
	if state == BotState.ATTACK and is_target_valid(target):
		var target_position: Vector3 = target.global_position
		target_position.y = global_position.y
		return target_position

	return null


func update_navigation_target() -> void:
	if navigation_agent == null or not is_inside_tree():
		return

	if state == BotState.IDLE_WAIT:
		current_target_position = global_position
		navigation_agent.set_target_position(current_target_position)
		return

	if state == BotState.ATTACK and is_target_valid(target):
		current_target_position = get_attack_position()
		navigation_agent.set_target_position(current_target_position)
		return

	if state == BotState.REACH_TARGET and is_reach_target_valid(current_reach_target):
		current_target_position = current_reach_target.global_position
		navigation_agent.set_target_position(current_target_position)
		return

	if patrol_points.is_empty():
		generate_patrol_points()
		if patrol_points.is_empty():
			return

	current_target_position = patrol_points[patrol_index]
	navigation_agent.set_target_position(current_target_position)


func refresh_target_state() -> void:
	var previous_state: BotState = state
	var previous_reach_target: Node3D = current_reach_target

	if is_target_lost(target):
		target = null
		if previous_state == BotState.ATTACK:
			enter_idle_wait()
			return

	if target == null:
		target = find_target_in_radius()
		if target == null and use_auto_target_when_empty:
			target = find_any_target()

	if is_target_valid(target):
		state = BotState.ATTACK
		current_reach_target = null
		patrol_points.clear()
		return

	current_reach_target = sanitize_reach_target(current_reach_target)
	if previous_state == BotState.REACH_TARGET and previous_reach_target != null and current_reach_target == null:
		enter_idle_wait()
		return

	if current_reach_target == null:
		current_reach_target = pick_reach_target()
	if current_reach_target != null:
		state = BotState.REACH_TARGET
		if previous_state != BotState.REACH_TARGET:
			patrol_points.clear()
		return

	state = BotState.IDLE_PATROL


func find_target_in_radius() -> Ship:
	var closest_ship: Ship = null
	var closest_distance: float = target_search_radius
	
	if get_tree() == null:
		return null

	for node in get_tree().get_nodes_in_group("Ship"):
		var ship := node as Ship

		if not can_target_ship(ship):
			continue

		var distance := global_position.distance_to(ship.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_ship = ship

	return closest_ship


func find_any_target() -> Ship:
	var closest_ship: Ship = null
	var closest_distance: float = INF

	for node in get_tree().get_nodes_in_group("Ship"):
		var ship := node as Ship

		if not can_target_ship(ship):
			continue

		var distance := global_position.distance_to(ship.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_ship = ship

	return closest_ship


func set_reach_targets(targets: Array[Node3D]) -> void:
	var previous_reach_target: Node3D = current_reach_target
	reach_targets = targets
	current_reach_target = sanitize_reach_target(current_reach_target)
	if not is_inside_tree():
		return
	if state == BotState.REACH_TARGET and previous_reach_target != null and current_reach_target == null:
		enter_idle_wait()
		update_navigation_target()
		return
	if state == BotState.IDLE_WAIT:
		update_navigation_target()
		return
	refresh_target_state()
	update_navigation_target()


func sanitize_reach_target(candidate: Node3D) -> Node3D:
	if not is_reach_target_valid(candidate) or not reach_targets.has(candidate):
		return null
	return candidate


func pick_reach_target() -> Node3D:
	var valid_targets := get_valid_reach_targets()
	if valid_targets.is_empty():
		return null

	reach_target_attempt_count += 1
	if reach_target_attempt_count <= closest_reach_target_attempt_limit:
		return pick_closest_reach_target(valid_targets)

	return pick_random_reach_target(valid_targets)


func pick_closest_reach_target(valid_targets: Array[Node3D]) -> Node3D:
	var closest_target: Node3D
	var closest_distance: float = INF
	for node in valid_targets:
		var distance: float = global_position.distance_to(node.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_target = node

	return closest_target


func pick_random_reach_target(valid_targets: Array[Node3D]) -> Node3D:
	var random_index: int = randi() % valid_targets.size()
	return valid_targets[random_index]


func randomize_closest_reach_target_attempt_limit() -> void:
	var min_attempts: int = max(0, min(closest_reach_target_attempts.x, closest_reach_target_attempts.y))
	var max_attempts: int = max(min_attempts, max(closest_reach_target_attempts.x, closest_reach_target_attempts.y))
	closest_reach_target_attempt_limit = randi_range(min_attempts, max_attempts)


func get_valid_reach_targets() -> Array[Node3D]:
	var valid_targets: Array[Node3D] = []
	for node in reach_targets:
		if is_reach_target_valid(node):
			valid_targets.append(node)
	return valid_targets


func is_reach_target_valid(candidate: Node3D) -> bool:
	if candidate == null:
		return false
	return is_instance_valid(candidate)


func is_target_valid(candidate: Node3D) -> bool:
	if candidate == null or not is_instance_valid(candidate):
		return false

	var ship: Ship = candidate as Ship
	return can_target_ship(ship)


func is_target_lost(candidate: Node3D) -> bool:
	if not is_target_valid(candidate):
		return true

	return global_position.distance_to(candidate.global_position) > target_lose_radius


func generate_patrol_points() -> void:
	patrol_points.clear()
	patrol_index = 0

	var min_count: int = max(1, min(patrol_point_count_range.x, patrol_point_count_range.y))
	var max_count: int = max(min_count, patrol_point_count_range.y)
	var point_count: int = randi_range(min_count, max_count)

	for i in point_count:
		var point := Vector3(
			randf_range(min(patrol_bounds_min.x, patrol_bounds_max.x), max(patrol_bounds_min.x, patrol_bounds_max.x)),
			randf_range(min(patrol_bounds_min.y, patrol_bounds_max.y), max(patrol_bounds_min.y, patrol_bounds_max.y)),
			randf_range(min(patrol_bounds_min.z, patrol_bounds_max.z), max(patrol_bounds_min.z, patrol_bounds_max.z))
		)

		if is_zero_approx(patrol_bounds_max.y - patrol_bounds_min.y):
			point.y = global_position.y

		patrol_points.append(point)


func update_patrol_progress() -> void:
	if patrol_points.is_empty():
		return

	var patrol_target: Vector3 = patrol_points[patrol_index]
	var distance_to_point: float = global_position.distance_to(patrol_target)
	var reach_distance: float = max(patrol_reach_distance, stop_distance)
	if distance_to_point > reach_distance:
		return

	patrol_index = (patrol_index + 1) % patrol_points.size()
	update_navigation_target()


func update_idle_wait(delta: float) -> void:
	idle_wait_timer -= delta
	if idle_wait_timer > 0.0:
		return

	target_update_timer = target_update_interval
	refresh_target_state()
	update_navigation_target()


func enter_idle_wait() -> void:
	state = BotState.IDLE_WAIT
	idle_wait_timer = randf_range(minf(idle_wait_time_range.x, idle_wait_time_range.y), maxf(idle_wait_time_range.x, idle_wait_time_range.y))
	current_target_position = global_position


func get_stop_distance() -> float:
	if state == BotState.ATTACK:
		return attack_position_tolerance
	return stop_distance


func get_attack_position() -> Vector3:
	var target_position: Vector3 = target.global_position
	target_position.y = global_position.y

	var away_from_target: Vector3 = global_position - target_position
	away_from_target.y = 0.0
	if away_from_target.is_zero_approx():
		away_from_target = -target.global_transform.basis.z
		away_from_target.y = 0.0
	if away_from_target.is_zero_approx():
		away_from_target = Vector3.FORWARD

	var distance_to_target: float = global_position.distance_to(target_position)
	var attack_max_distance: float = get_attack_max_distance()
	var preferred_distance: float = clamp(attack_preferred_distance, attack_min_distance, attack_max_distance)
	if distance_to_target < attack_min_distance or distance_to_target > attack_max_distance:
		return target_position + away_from_target.normalized() * preferred_distance

	return global_position


func get_attack_max_distance() -> float:
	return get_aim_radius_limits().y


func on_attacked_by(attacker: Ship) -> void:
	if not can_target_ship(attacker):
		return

	target = attacker
	current_reach_target = null
	patrol_points.clear()
	state = BotState.ATTACK
	target_update_timer = 0.0
	update_navigation_target()


func can_shoot() -> bool:
	if state == BotState.ATTACK and is_target_valid(target):
		var distance_to_target: float = global_position.distance_to(target.global_position)
		if distance_to_target >= attack_min_distance and distance_to_target <= get_attack_max_distance() and time >= next_shoot_time:
			next_shoot_time = time + randf_range(shoot_interval_range.x, shoot_interval_range.y)
			enter_idle_wait()
			return true
	return false
