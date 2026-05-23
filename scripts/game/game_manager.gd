extends Node

const GAME_SETTINGS := preload("res://resources/game_settings.tres")

var game_settings: GameSettings = GAME_SETTINGS
var active_game: Game
var active_scene: Node


func _ready() -> void:
	call_deferred("load_initial_scene")


func load_initial_scene() -> void:
	resolve_active_game()
	if active_game != null:
		activate_game(active_game)
		return

	var initial_scene: PackedScene = game_settings.get_initial_scene()
	if initial_scene == null:
		push_warning("GameManager: no initial scene is assigned.")
		return

	var initial_scene_instance := instantiate_scene(initial_scene)
	if initial_scene_instance == null:
		return

	if initial_scene_instance is Game:
		active_game = initial_scene_instance as Game
		activate_game(active_game)


func resolve_active_game() -> void:
	if active_game != null and is_instance_valid(active_game):
		return

	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	active_game = find_game_in_tree(current_scene)
	if active_game != null:
		active_scene = active_game


func find_game_in_tree(root: Node) -> Game:
	if root is Game:
		return root as Game

	for child in root.get_children():
		var game := find_game_in_tree(child)
		if game != null:
			return game

	return null


func load_game_scene() -> void:
	if active_game != null and is_instance_valid(active_game):
		activate_game(active_game)
		return

	var game_scene: PackedScene = game_settings.get_game_scene()
	if game_scene == null:
		push_warning("GameManager: no game scene is assigned.")
		return

	unload_active_scene()

	var game_scene_instance := instantiate_scene(game_scene)
	if game_scene_instance == null:
		return

	active_game = game_scene_instance as Game
	if active_game == null:
		push_warning("GameManager: configured game scene is not a Game scene.")
		return

	activate_game(active_game)


func instantiate_scene(scene: PackedScene) -> Node:
	var scene_instance := scene.instantiate()
	if scene_instance == null:
		push_warning("GameManager: failed to instantiate scene.")
		return null

	active_scene = scene_instance

	var current_scene := get_tree().current_scene
	if current_scene != null:
		current_scene.add_child(active_scene)
	else:
		add_child(active_scene)

	return active_scene


func unload_active_scene() -> void:
	if active_scene == null or not is_instance_valid(active_scene):
		return

	active_scene.queue_free()
	active_scene = null


func activate_game(game: Game) -> void:
	active_game = game
	active_scene = game
	setup_game(active_game)
	active_game.start_game()


func setup_game(game: Game) -> void:
	if game_settings.game_mode != null:
		game.game_mode = game_settings.game_mode
