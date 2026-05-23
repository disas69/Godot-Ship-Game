class_name Flag extends Node3D

signal capture_progress_changed(flag: Flag, team: Ship.Team, progress_sec: float, duration_sec: float)
signal captured(flag: Flag, team: Ship.Team)
signal state_changed(flag: Flag, state: State, team: int)

enum State {
	Neutral,
	Captured
}

@export_category("State")
@export var state: State = State.Neutral
@export var captured_team: int = -1

@export_category("Capture")
@export var capture_radius: float = 10.0
@export var capture_duration_sec: float = 10.0
@export var capture_area: Area3D
@export var collision_shape: CollisionShape3D
@export var neutral_view: Node3D
@export var captured_good_view: Node3D
@export var captured_bad_view: Node3D
@export var capture_progress_view: Sprite3D

@export_category("Capture FX")
@export var capture_push_scale: float = 0.82
@export var capture_pop_scale: float = 1.18
@export var capture_flash_strength: float = 0.8
@export var capture_flash_material_template: ShaderMaterial = preload("res://materials/hit_flash.tres")
@export var capture_flash_targets: Array[GeometryInstance3D] = []

var capture_team: int = -1
var capture_progress_sec: float = 0.0
var ships_in_radius: Dictionary = {}
var view_base_scales: Dictionary = {}
var capture_state_tween: Tween
var capture_flash_tween: Tween
var capture_flash_material_instance: ShaderMaterial
var capture_progress_material_instance: ShaderMaterial


func _ready() -> void:
	collision_shape.shape.radius = capture_radius
	setup_view_base_scales()
	setup_capture_flash_material_instance()
	setup_capture_progress_view()
	set_capture_flash_strength(0.0)
	ensure_capture_hooks()
	update_view()
	state_changed.emit(self, state, captured_team)


func _process(delta: float) -> void:
	cleanup_invalid_ships()
	update_capture_progress(delta)


func reset_flag() -> void:
	state = State.Neutral
	captured_team = -1
	capture_team = -1
	capture_progress_sec = 0.0
	ships_in_radius.clear()
	stop_capture_state_feedback()
	update_capture_progress_view()
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
	update_capture_progress_view()
	capture_progress_changed.emit(self, progress_team, capture_progress_sec, capture_duration_sec)

	if capture_progress_sec >= capture_duration_sec:
		state = State.Captured
		captured_team = capture_team
		capture_team = -1
		capture_progress_sec = 0.0
		update_capture_progress_view()
		play_capture_state_changed_feedback()
		state_changed.emit(self, state, captured_team)
		var winner_team: Ship.Team = int(captured_team) as Ship.Team
		captured.emit(self, winner_team)


func reset_capture_progress() -> void:
	capture_team = -1
	capture_progress_sec = 0.0
	update_capture_progress_view()


func ensure_capture_hooks() -> void:
	if capture_area == null:
		push_warning("Flag: capture_area is not assigned.")
		return

	if not capture_area.body_entered.is_connected(on_capture_area_body_entered):
		capture_area.body_entered.connect(on_capture_area_body_entered)
	if not capture_area.body_exited.is_connected(on_capture_area_body_exited):
		capture_area.body_exited.connect(on_capture_area_body_exited)


func update_view() -> void:
	neutral_view.visible = state == State.Neutral
	captured_good_view.visible = state == State.Captured and captured_team == int(Ship.Team.GoodGuys)
	captured_bad_view.visible = state == State.Captured and captured_team == int(Ship.Team.BadGuys)


func play_capture_state_changed_feedback() -> void:
	stop_capture_state_feedback()

	var previous_view := get_visible_view()
	var next_view := get_current_view()
	set_capture_flash_color(Color.WHITE)
	set_capture_flash_strength(0.0)

	if previous_view == null or next_view == null:
		update_view()
		return

	capture_state_tween = create_tween()
	capture_state_tween.tween_property(previous_view, "scale", get_view_base_scale(previous_view) * capture_push_scale, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	capture_state_tween.tween_callback(switch_to_current_view_for_capture_feedback)
	capture_state_tween.tween_property(next_view, "scale", get_view_base_scale(next_view), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if capture_flash_material_instance:
		capture_flash_tween = create_tween()
		capture_flash_tween.tween_interval(0.05)
		var flash_setter := Callable(self, "set_capture_flash_strength")
		capture_flash_tween.tween_method(flash_setter, 0.0, capture_flash_strength, 0.1)
		capture_flash_tween.tween_method(flash_setter, capture_flash_strength, 0.0, 0.25)


func stop_capture_state_feedback() -> void:
	if capture_state_tween and capture_state_tween.is_valid():
		capture_state_tween.kill()
	if capture_flash_tween and capture_flash_tween.is_valid():
		capture_flash_tween.kill()

	reset_view_scales()
	set_capture_flash_strength(0.0)


func switch_to_current_view_for_capture_feedback() -> void:
	update_view()
	var current_view := get_current_view()
	if current_view:
		current_view.scale = get_view_base_scale(current_view) * capture_pop_scale
	AudioManager.play_sfx("flag_capture", current_view.global_transform.origin)


func setup_view_base_scales() -> void:
	view_base_scales[neutral_view] = neutral_view.scale
	view_base_scales[captured_good_view] = captured_good_view.scale
	view_base_scales[captured_bad_view] = captured_bad_view.scale


func reset_view_scales() -> void:
	for view in view_base_scales:
		var node := view as Node3D
		node.scale = get_view_base_scale(node)


func get_view_base_scale(view: Node3D) -> Vector3:
	return view_base_scales.get(view, view.scale)


func get_current_view() -> Node3D:
	if state == State.Neutral:
		return neutral_view
	if captured_team == int(Ship.Team.GoodGuys):
		return captured_good_view
	return captured_bad_view


func get_visible_view() -> Node3D:
	for view in [neutral_view, captured_good_view, captured_bad_view]:
		if view.visible:
			return view
	return null


func setup_capture_flash_material_instance() -> void:
	if capture_flash_material_template == null:
		return

	capture_flash_material_instance = capture_flash_material_template.duplicate(true) as ShaderMaterial
	if capture_flash_targets.is_empty():
		for view in [neutral_view, captured_good_view, captured_bad_view]:
			add_capture_flash_targets_from(view)

	for mesh in capture_flash_targets:
		mesh.material_overlay = capture_flash_material_instance


func add_capture_flash_targets_from(node: Node) -> void:
	var mesh := node as GeometryInstance3D
	if mesh:
		capture_flash_targets.append(mesh)

	for child in node.get_children():
		add_capture_flash_targets_from(child)


func set_capture_flash_color(color: Color) -> void:
	if capture_flash_material_instance:
		capture_flash_material_instance.set_shader_parameter(&"flash_color", color)


func set_capture_flash_strength(value: float) -> void:
	if capture_flash_material_instance:
		capture_flash_material_instance.set_shader_parameter(&"flash_strength", value)


func setup_capture_progress_view() -> void:
	if capture_progress_view == null:
		return

	var progress_material := capture_progress_view.material_override as ShaderMaterial
	if progress_material:
		capture_progress_material_instance = progress_material.duplicate(true) as ShaderMaterial
		capture_progress_view.material_override = capture_progress_material_instance

	update_capture_progress_view()


func update_capture_progress_view() -> void:
	if capture_progress_view == null:
		return

	var is_capture_in_progress := capture_team != -1 and capture_progress_sec > 0.0
	capture_progress_view.visible = is_capture_in_progress

	var progress := 0.0
	if is_capture_in_progress:
		progress = clampf(capture_progress_sec / maxf(capture_duration_sec, 0.001), 0.0, 1.0)

	if capture_progress_material_instance:
		capture_progress_material_instance.set_shader_parameter(&"progress", progress)
