class_name GameMode extends Resource

@export_category("Players")
@export var good_team_players: Array[Player] = []
@export var bad_team_players: Array[Player] = []

@export_category("Rules")
@export var game_duration_sec: int = 60 * 3
@export var respawn_delay_sec: float = 3.0


func get_players(_max_local_players: int = -1) -> Array[Player]:
	var players: Array[Player] = []
	_append_players(players, good_team_players)
	_append_players(players, bad_team_players)
	return players


func _append_players(
	players: Array[Player],
	team_players: Array[Player]
) -> void:
	for player in team_players:
		if player == null:
			continue
		players.append(player)
