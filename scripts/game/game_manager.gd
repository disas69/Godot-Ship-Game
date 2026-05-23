class_name GameManager extends Node3D

signal game_state_changed(state: GameState)
signal game_time_changed(time_left_sec: float)
signal team_kills_changed(good_team_kills: int, bad_team_kills: int)
signal flags_status_changed(good_captured: int, bad_captured: int, neutral: int)
signal game_finished(winner_team: int, reason: FinishReason, good_team_kills: int, bad_team_kills: int)

enum GameState {
	Idle,
	Playing,
	Finished
}

enum FinishReason {
	TimeUp,
	AllFlagsCaptured
}

@export_category("Game Settings")
@export var game_mode: GameMode
@export var spawn_ponts_good_team: Array[Node3D] = []
@export var spawn_ponts_bad_team: Array[Node3D] = []
@export var flags: Array[Flag] = []
@export var camera: MainCamera

@export_category("References")
@export var local_player_scene: PackedScene
@export var bot_player_scene: PackedScene

var local_players: Array[PlayerShip] = []
var bot_players: Array[BotShip] = []
var spawn_point_good_index := 0
var spawn_point_bad_index := 0
var tracked_ship_spawn_data: Dictionary = {}
var respawning_ship_ids: Dictionary = {}
var game_state: GameState = GameState.Idle
var game_time_left_sec: float = 0.0
var good_team_kills: int = 0
var bad_team_kills: int = 0
var winner_team: int = -1
var finish_reason: FinishReason = FinishReason.TimeUp
var valid_flags: Array[Flag] = []


func _ready() -> void:
	register_flags()
	register_existing_ships()
	
	spawn_ponts_good_team.shuffle()
	spawn_ponts_bad_team.shuffle()
	
	spawn_players_from_game_mode()
	refresh_camera_targets(true)
	refresh_bot_reach_targets()
	
	play_music()
	start_game()


func _process(delta: float) -> void:
	if game_state != GameState.Playing:
		return

	game_time_left_sec = maxf(0.0, game_time_left_sec - delta)
	game_time_changed.emit(game_time_left_sec)

	if game_time_left_sec <= 0.0:
		finish_game(FinishReason.TimeUp)


func play_music() -> void:
	AudioManager.play_music("cannon_battle_main")
	AudioManager.play_music("ambient_sea")


func register_flags() -> void:
	valid_flags.clear()

	for flag in flags:
		if flag == null or not is_instance_valid(flag):
			continue
		if valid_flags.has(flag):
			continue

		valid_flags.append(flag)
		if not flag.captured.is_connected(on_flag_captured):
			flag.captured.connect(on_flag_captured)

	update_flags_status()


func register_existing_ships() -> void:
	local_players.clear()
	bot_players.clear()
	tracked_ship_spawn_data.clear()
	respawning_ship_ids.clear()

	var ship_nodes: Array[Node] = get_tree().get_nodes_in_group("Ship")
	for node in ship_nodes:
		var ship := node as Ship
		if ship == null:
			continue

		var is_local: bool = ship is PlayerShip
		var local_index: int = -1
		if is_local:
			local_index = (ship as PlayerShip).local_player_index

		register_tracked_ship(ship, is_local, local_index)


func spawn_players_from_game_mode() -> void:
	pass


func get_selected_game_mode() -> GameMode:
	if game_mode != null and is_instance_valid(game_mode):
		return game_mode
	return null


func spawn_local_player(team: Ship.Team, local_player_index: int) -> PlayerShip:
	if local_player_scene == null:
		push_warning("GameManager: local_player_scene is not assigned.")
		return null

	var player_instance: PlayerShip = local_player_scene.instantiate() as PlayerShip
	if player_instance == null:
		push_warning("GameManager: local_player_scene is not a PlayerShip scene.")
		return null

	player_instance.team = team
	player_instance.local_player_index = local_player_index
	spawn_ship(player_instance, team)
	register_tracked_ship(player_instance, true, local_player_index)
	return player_instance


func spawn_bot_player(team: Ship.Team) -> BotShip:
	if bot_player_scene == null:
		push_warning("GameManager: bot_player_scene is not assigned.")
		return null

	var player_instance: BotShip = bot_player_scene.instantiate() as BotShip
	if player_instance == null:
		push_warning("GameManager: bot_player_scene is not a BotShip scene.")
		return null

	player_instance.team = team
	spawn_ship(player_instance, team)
	register_tracked_ship(player_instance, false, -1)
	return player_instance


func spawn_ship(ship: Ship, team: Ship.Team) -> void:
	add_child(ship)
	var spawn_point: Node3D = get_next_spawn_point(team)
	if spawn_point == null:
		ship.global_position = global_position
		return

	ship.global_transform = spawn_point.global_transform


func get_next_spawn_point(team: Ship.Team) -> Node3D:
	var spawn_points: Array[Node3D] = get_valid_spawn_points(team)
	if spawn_points.is_empty():
		push_warning("GameManager: missing spawn points for team %s." % [team])
		return null

	if team == Ship.Team.GoodGuys:
		spawn_point_good_index %= spawn_points.size()
		var point: Node3D = spawn_points[spawn_point_good_index]
		spawn_point_good_index = (spawn_point_good_index + 1) % spawn_points.size()
		return point

	spawn_point_bad_index %= spawn_points.size()
	var bad_point: Node3D = spawn_points[spawn_point_bad_index]
	spawn_point_bad_index = (spawn_point_bad_index + 1) % spawn_points.size()
	return bad_point


func get_valid_spawn_points(team: Ship.Team) -> Array[Node3D]:
	var source_points: Array[Node3D] = spawn_ponts_good_team if team == Ship.Team.GoodGuys else spawn_ponts_bad_team
	var valid_points: Array[Node3D] = []
	for point in source_points:
		if point != null and is_instance_valid(point):
			valid_points.append(point)

	return valid_points


func register_tracked_ship(ship: Ship, is_local: bool, local_player_index: int) -> void:
	var ship_id: int = ship.get_instance_id()
	if tracked_ship_spawn_data.has(ship_id):
		return

	var spawn_kind: String = "none"
	if is_local and ship is PlayerShip:
		spawn_kind = "local"
	elif ship is BotShip:
		spawn_kind = "bot"

	var spawn_data := {
		"team": ship.team,
		"is_local": is_local,
		"local_player_index": local_player_index,
		"spawn_kind": spawn_kind,
	}
	tracked_ship_spawn_data[ship_id] = spawn_data

	if is_local and ship is PlayerShip:
		local_players.append(ship as PlayerShip)
	elif ship is BotShip:
		bot_players.append(ship as BotShip)
		refresh_bot_reach_targets()

	ship.destroyed.connect(on_ship_destroyed)
	ship.tree_exited.connect(on_tracked_ship_tree_exited.bind(ship_id), CONNECT_ONE_SHOT)


func on_ship_destroyed(ship: Ship) -> void:
	if ship == null:
		return

	if game_state != GameState.Playing:
		return

	var ship_id: int = ship.get_instance_id()
	if respawning_ship_ids.has(ship_id):
		return

	register_team_kill_from_destroyed_ship(ship)

	var spawn_data: Dictionary = tracked_ship_spawn_data.get(ship_id, {})
	if spawn_data.is_empty():
		return

	spawn_data = spawn_data.duplicate(true)
	spawn_data["team"] = ship.team
	respawning_ship_ids[ship_id] = true
	
	call_deferred("respawn_ship_after_delay", spawn_data, ship_id)


func respawn_ship_after_delay(spawn_data: Dictionary, destroyed_ship_id: int) -> void:
	var selected_game_mode = get_selected_game_mode()

	if selected_game_mode.respawn_delay_sec > 0.0:
		await get_tree().create_timer(selected_game_mode.respawn_delay_sec).timeout

	if not is_inside_tree():
		return

	if game_state != GameState.Playing:
		respawning_ship_ids.erase(destroyed_ship_id)
		return

	respawning_ship_ids.erase(destroyed_ship_id)
	var team: Ship.Team = int(spawn_data.get("team", Ship.Team.GoodGuys)) as Ship.Team
	var is_local: bool = bool(spawn_data.get("is_local", false))
	var local_index: int = int(spawn_data.get("local_player_index", 0))
	var spawn_kind: String = String(spawn_data.get("spawn_kind", "none"))

	if spawn_kind == "local" and is_local:
		spawn_local_player(team, local_index)
	elif spawn_kind == "bot":
		spawn_bot_player(team)

	refresh_camera_targets(false)


func on_tracked_ship_tree_exited(ship_id: int) -> void:
	tracked_ship_spawn_data.erase(ship_id)
	prune_player_arrays()
	refresh_bot_reach_targets()
	refresh_camera_targets(false)


func prune_player_arrays() -> void:
	for i in range(local_players.size() - 1, -1, -1):
		if local_players[i] == null or not is_instance_valid(local_players[i]):
			local_players.remove_at(i)

	for i in range(bot_players.size() - 1, -1, -1):
		if bot_players[i] == null or not is_instance_valid(bot_players[i]):
			bot_players.remove_at(i)


func refresh_camera_targets(update_position: bool) -> void:
	if camera == null:
		return

	prune_player_arrays()
	var camera_targets: Array[Node3D] = []
	for player in local_players:
		if player != null and is_instance_valid(player) and not player.is_destroyed:
			camera_targets.append(player)

	camera.set_targets(camera_targets, update_position)


func start_game() -> void:
	var selected_game_mode = get_selected_game_mode()
	good_team_kills = 0
	bad_team_kills = 0
	game_time_left_sec = maxf(float(selected_game_mode.game_duration_sec), 0.0)
	winner_team = -1
	finish_reason = FinishReason.TimeUp
	respawning_ship_ids.clear()
	refresh_bot_reach_targets()
	update_flags_status()

	set_game_state(GameState.Playing)
	team_kills_changed.emit(good_team_kills, bad_team_kills)
	game_time_changed.emit(game_time_left_sec)


func finish_game(reason: FinishReason, forced_winner_team: int = -1) -> void:
	if game_state == GameState.Finished:
		return

	finish_reason = reason
	winner_team = resolve_winner_team(forced_winner_team)
	set_game_state(GameState.Finished)
	respawning_ship_ids.clear()
	game_finished.emit(winner_team, finish_reason, good_team_kills, bad_team_kills)


func set_game_state(new_state: GameState) -> void:
	if game_state == new_state:
		return

	game_state = new_state
	game_state_changed.emit(game_state)


func register_team_kill_from_destroyed_ship(destroyed_ship: Ship) -> void:
	if destroyed_ship.team == Ship.Team.GoodGuys:
		bad_team_kills += 1
	else:
		good_team_kills += 1

	team_kills_changed.emit(good_team_kills, bad_team_kills)


func on_flag_captured(_flag: Flag, captured_team: Ship.Team) -> void:
	if game_state != GameState.Playing:
		return

	update_flags_status()
	refresh_bot_reach_targets()

	if has_team_captured_all_flags(captured_team):
		finish_game(FinishReason.AllFlagsCaptured, int(captured_team))


func refresh_bot_reach_targets() -> void:
	var uncaptured_targets: Array[Node3D] = get_uncaptured_flag_targets()
	for bot in bot_players:
		if bot == null or not is_instance_valid(bot) or bot.is_destroyed:
			continue
		bot.set_reach_targets(uncaptured_targets)


func get_uncaptured_flag_targets() -> Array[Node3D]:
	var targets: Array[Node3D] = []
	for flag in valid_flags:
		if flag == null or not is_instance_valid(flag):
			continue
		if not flag.is_captured():
			targets.append(flag)
	return targets


func has_team_captured_all_flags(team: Ship.Team) -> bool:
	var active_flags: int = 0
	for flag in valid_flags:
		if flag == null or not is_instance_valid(flag):
			continue
		active_flags += 1
		if not flag.is_captured_by(team):
			return false

	return active_flags > 0


func resolve_winner_team(forced_winner_team: int = -1) -> int:
	if forced_winner_team != -1:
		return forced_winner_team

	if has_team_captured_all_flags(Ship.Team.GoodGuys):
		return int(Ship.Team.GoodGuys)
	if has_team_captured_all_flags(Ship.Team.BadGuys):
		return int(Ship.Team.BadGuys)

	if good_team_kills > bad_team_kills:
		return int(Ship.Team.GoodGuys)
	if bad_team_kills > good_team_kills:
		return int(Ship.Team.BadGuys)

	return -1


func update_flags_status() -> void:
	var good_captured: int = 0
	var bad_captured: int = 0
	var neutral: int = 0

	for flag in valid_flags:
		if flag == null or not is_instance_valid(flag):
			continue
		if flag.is_captured_by(Ship.Team.GoodGuys):
			good_captured += 1
		elif flag.is_captured_by(Ship.Team.BadGuys):
			bad_captured += 1
		else:
			neutral += 1

	flags_status_changed.emit(good_captured, bad_captured, neutral)
