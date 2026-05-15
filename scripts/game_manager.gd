class_name GameManager extends Node

@export_category("Game Settings")
@export var players_count: int = 6
@export var local_players_count: int = 1
@export var game_duration_sec: int = 60 * 3
@export var spawn_ponts_good_team: Array[Node3D] = []
@export var spawn_ponts_bad_team: Array[Node3D] = []
@export var camera: MainCamera

@export_category("References")
@export var local_player_scene: PackedScene
@export var bot_player_scene: PackedScene

var local_players: Array[PlayerShip] = []
var bot_players: Array[BotShip] = []
var spawn_point_good_index := 0
var spawn_point_bad_index := 0


func _ready() -> void:
	local_players = try_find_local_players()
	
	if local_players.size() < local_players_count:
		local_players.append_array(spawn_local_players())
		
	if local_players.size() > 0:
		var camera_targets: Array[Node3D] = []
		for player in local_players:
			camera_targets.append(player)
		camera.set_targets(camera_targets)
		
	bot_players.append_array(spawn_good_bot_players())
	bot_players.append_array(spawn_bad_bot_players())


func _process(delta: float) -> void:
	pass


func try_find_local_players() -> Array[PlayerShip]:
	var players: Array[PlayerShip] = []
	var player_nodes: Array[Node] = get_tree().get_nodes_in_group("Ship")
	
	for player in player_nodes:
		if player is PlayerShip:
			var player_ship: PlayerShip = player as PlayerShip
			players.append(player_ship)
			
	return players
	
	
func spawn_local_players() -> Array[PlayerShip]:
	var players: Array[PlayerShip] = []
	var count: int = local_players_count - players.size()
	for i in range(count):
		var spawn_point: Node3D = spawn_ponts_good_team[spawn_point_good_index]
		spawn_point_good_index = (spawn_point_good_index + 1) % spawn_ponts_good_team.size()
		
		var player_instance: PlayerShip = local_player_scene.instantiate() as PlayerShip
		player_instance.local_player_index = i
		spawn_point.add_child(player_instance)
		player_instance.global_position = spawn_point.global_position
		players.append(player_instance)
		
	return players
	

func spawn_good_bot_players() -> Array[BotShip]:
	var players: Array[BotShip] = []
	var count: int = players_count / 2 - local_players.size()
	for i in range(count):
		var spawn_point: Node3D = spawn_ponts_good_team[spawn_point_good_index]
		spawn_point_good_index = (spawn_point_good_index + 1) % spawn_ponts_good_team.size()
		
		var player_instance: BotShip = bot_player_scene.instantiate() as BotShip
		player_instance.team = Ship.Team.GoodGuys
		spawn_point.add_child(player_instance)
		player_instance.global_position = spawn_point.global_position
		players.append(player_instance)
		
	return players
	
	
func spawn_bad_bot_players() -> Array[BotShip]:
	var players: Array[BotShip] = []
	var count: int = players_count / 2
	for i in range(count):
		var spawn_point: Node3D = spawn_ponts_bad_team[spawn_point_bad_index]
		spawn_point_bad_index = (spawn_point_bad_index + 1) % spawn_ponts_bad_team.size()
		
		var player_instance: BotShip = bot_player_scene.instantiate() as BotShip
		player_instance.team = Ship.Team.BadGuys
		spawn_point.add_child(player_instance)
		player_instance.global_position = spawn_point.global_position
		players.append(player_instance)
		
	return players