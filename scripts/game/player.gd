class_name Player extends Resource

@export var player_name: String = ""
@export var team: Ship.Team = Ship.Team.GoodGuys
@export var is_local: bool = false


func _init(new_player_name: String = "", new_team: Ship.Team = Ship.Team.GoodGuys, new_is_local: bool = false) -> void:
	player_name = new_player_name
	team = new_team
	is_local = new_is_local
