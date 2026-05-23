extends Node

const GAME_SETTINGS := preload("res://resources/game_settings.tres")

var game_settings: GameSettings = GAME_SETTINGS
var active_game: Game


func _ready() -> void:
	call_deferred("load_initial_game")


func load_initial_game() -> void:
	resolve_active_game()
	if active_game == null:
		instantiate_initial_scene()

	if active_game == null:
		push_warning("GameManager: active_game is not assigned.")
		return

	setup_game(active_game)
	active_game.start_game()


func resolve_active_game() -> void:
	if active_game != null and is_instance_valid(active_game):
		return

	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	active_game = find_game_in_tree(current_scene)


func find_game_in_tree(root: Node) -> Game:
	if root is Game:
		return root as Game

	for child in root.get_children():
		var game := find_game_in_tree(child)
		if game != null:
			return game

	return null


func instantiate_initial_scene() -> void:
	var game_scene: PackedScene = game_settings.get_initial_scene()
	if game_scene == null:
		push_warning("GameManager: no initial game scene is assigned.")
		return

	var game_instance := game_scene.instantiate() as Game
	if game_instance == null:
		push_warning("GameManager: initial game scene is not a Game scene.")
		return

	active_game = game_instance

	var current_scene := get_tree().current_scene
	if current_scene != null:
		current_scene.add_child(active_game)
	else:
		add_child(active_game)


func setup_game(game: Game) -> void:
	if game_settings.game_mode != null:
		game.game_mode = game_settings.game_mode
