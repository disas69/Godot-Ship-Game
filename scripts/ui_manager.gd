class_name UiManager extends Node

@export var game_manager: GameManager
@export var timer_label: Label
@export var flags_1_label: Label
@export var flags_2_label: Label
@export var kills_1_label: Label
@export var kills_2_label: Label


func _ready() -> void:
	resolve_references()
	if game_manager == null:
		push_warning("UiManager: game_manager is not assigned.")
		return

	if not game_manager.game_time_changed.is_connected(on_timer_changed):
		game_manager.game_time_changed.connect(on_timer_changed)
	if not game_manager.team_kills_changed.is_connected(on_team_kills_changed):
		game_manager.team_kills_changed.connect(on_team_kills_changed)
	if not game_manager.flags_status_changed.is_connected(on_flags_status_changed):
		game_manager.flags_status_changed.connect(on_flags_status_changed)

	sync_from_game_manager()


func resolve_references() -> void:
	if game_manager == null:
		game_manager = get_parent() as GameManager
	if game_manager == null:
		game_manager = get_tree().current_scene as GameManager

	if flags_1_label == null:
		flags_1_label = get_node_or_null("Control/Control/Flags1") as Label
	if flags_2_label == null:
		flags_2_label = get_node_or_null("Control/Control/Flags2") as Label
	if kills_1_label == null:
		kills_1_label = get_node_or_null("Control/Control/Kills1") as Label
	if kills_2_label == null:
		kills_2_label = get_node_or_null("Control/Control/Kills2") as Label


func sync_from_game_manager() -> void:
	on_team_kills_changed(game_manager.good_team_kills, game_manager.bad_team_kills)

	var good_captured: int = 0
	var bad_captured: int = 0
	var neutral: int = 0
	for flag in game_manager.valid_flags:
		if flag == null or not is_instance_valid(flag):
			continue
		if flag.is_captured_by(Ship.Team.GoodGuys):
			good_captured += 1
		elif flag.is_captured_by(Ship.Team.BadGuys):
			bad_captured += 1
		else:
			neutral += 1

	on_flags_status_changed(good_captured, bad_captured, neutral)


func on_timer_changed(remaining_time_sec: float) -> void:
	if timer_label != null:
		timer_label.text = str(int(remaining_time_sec))


func on_team_kills_changed(good_team_kills: int, bad_team_kills: int) -> void:
	if kills_1_label != null:
		kills_1_label.text = str(good_team_kills)
	if kills_2_label != null:
		kills_2_label.text = str(bad_team_kills)


func on_flags_status_changed(good_captured: int, bad_captured: int, _neutral: int) -> void:
	if flags_1_label != null:
		flags_1_label.text = str(good_captured)
	if flags_2_label != null:
		flags_2_label.text = str(bad_captured)
