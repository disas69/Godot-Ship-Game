class_name Flag extends Node3D

signal capture_progress_changed(flag: Flag, team: Ship.Team, progress_sec: float, duration_sec: float)
signal captured(flag: Flag, team: Ship.Team)
signal state_changed(flag: Flag, state: State, team: int)

enum State {
	Neutral,
	Captured
}

@export_category("Capture")
@export var capture_radius: float = 10.0
@export var capture_duration_sec: float = 10.0
@export var capture_area: Area3D
@export var collision_shape: CollisionShape3D
@export var neutral_view: Node3D
@export var captured_good_view: Node3D
@export var captured_bad_view: Node3D

var state: State = State.Neutral
var captured_team: int = -1

var capture_team: int = -1
var capture_progress_sec: float = 0.0
var ships_in_radius: Dictionary = {}


func _ready() -> void:
	collision_shape.shape.radius = capture_radius
	reset_flag()


func _process(delta: float) -> void:
	cleanup_invalid_ships()
	update_capture_progress(delta)


func reset_flag() -> void:
	state = State.Neutral
	captured_team = -1
	capture_team = -1
	capture_progress_sec = 0.0
	ships_in_radius.clear()
	update_view()
	state_changed.emit(self, state, captured_team)


func is_captured() -> bool:
	return state == State.Captured


func is_captured_by(team: Ship.Team) -> bool:
	return state == State.Captured and captured_team == int(team)


func on_capture_area_body_entered(body: Node) -> void:
	var ship := body as Ship
	if ship == null:
		return

	ships_in_radius[ship.get_instance_id()] = ship
	var on_exit_callable: Callable = on_tracked_ship_tree_exited.bind(ship.get_instance_id())
	if not ship.tree_exited.is_connected(on_exit_callable):
		ship.tree_exited.connect(on_exit_callable, CONNECT_ONE_SHOT)


func on_capture_area_body_exited(body: Node) -> void:
	var ship := body as Ship
	if ship == null:
		return

	ships_in_radius.erase(ship.get_instance_id())


func on_tracked_ship_tree_exited(ship_id: int) -> void:
	ships_in_radius.erase(ship_id)


func cleanup_invalid_ships() -> void:
	var invalid_ids: Array[int] = []
	for ship_id in ships_in_radius.keys():
		var ship := ships_in_radius[ship_id] as Ship
		if ship == null or not is_instance_valid(ship) or ship.is_destroyed:
			invalid_ids.append(ship_id)

	for ship_id in invalid_ids:
		ships_in_radius.erase(ship_id)


func update_capture_progress(delta: float) -> void:
	var good_count: int = 0
	var bad_count: int = 0

	for ship in ships_in_radius.values():
		var typed_ship := ship as Ship
		if typed_ship == null or typed_ship.is_destroyed:
			continue

		if typed_ship.team == Ship.Team.GoodGuys:
			good_count += 1
		else:
			bad_count += 1

	var candidate_team: int = -1
	if good_count > 0 and bad_count == 0:
		candidate_team = int(Ship.Team.GoodGuys)
	elif bad_count > 0 and good_count == 0:
		candidate_team = int(Ship.Team.BadGuys)

	var capturing_team: int = -1
	if candidate_team != -1:
		if state == State.Neutral:
			capturing_team = candidate_team
		elif captured_team != candidate_team:
			capturing_team = candidate_team

	if capturing_team == -1:
		reset_capture_progress()
		return

	if capture_team != capturing_team:
		capture_team = capturing_team
		capture_progress_sec = 0.0

	capture_progress_sec += delta
	capture_progress_sec = minf(capture_progress_sec, capture_duration_sec)
	var progress_team: Ship.Team = int(capture_team) as Ship.Team
	capture_progress_changed.emit(self, progress_team, capture_progress_sec, capture_duration_sec)

	if capture_progress_sec >= capture_duration_sec:
		state = State.Captured
		captured_team = capture_team
		capture_team = -1
		capture_progress_sec = 0.0
		update_view()
		state_changed.emit(self, state, captured_team)
		var winner_team: Ship.Team = int(captured_team) as Ship.Team
		captured.emit(self, winner_team)


func reset_capture_progress() -> void:
	capture_team = -1
	capture_progress_sec = 0.0


func update_view() -> void:
	neutral_view.visible = state == State.Neutral
	captured_good_view.visible = state == State.Captured and captured_team == int(Ship.Team.GoodGuys)
	captured_bad_view.visible = state == State.Captured and captured_team == int(Ship.Team.BadGuys)
