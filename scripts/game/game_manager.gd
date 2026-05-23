class_name GameManager extends Node3D

@export var game_settings: GameSettings
@export var scene_manager: SceneManager

var active_game: Game

func _ready() -> void:
	call_deferred("load_initial_scene")


func load_initial_scene() -> void:
	resolve_scene_manager()
	if scene_manager == null:
		push_warning("GameManager: scene_manager is not assigned.")
		return

	resolve_active_game()
	if active_game != null:
		activate_game(active_game)
		return

	var initial_scene: PackedScene = game_settings.get_initial_scene()
	if initial_scene == null:
		push_warning("GameManager: no initial scene is assigned.")
		return

	var initial_scene_instance := scene_manager.load_scene(initial_scene)
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
		resolve_scene_manager()
		if scene_manager != null:
			scene_manager.set_active_scene(active_game)


func resolve_scene_manager() -> void:
	if scene_manager != null and is_instance_valid(scene_manager):
		return

	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	scene_manager = find_scene_manager_in_tree(current_scene)


func find_scene_manager_in_tree(root: Node) -> SceneManager:
	if root is SceneManager:
		return root as SceneManager

	for child in root.get_children():
		var found_scene_manager := find_scene_manager_in_tree(child)
		if found_scene_manager != null:
			return found_scene_manager

	return null


func find_game_in_tree(root: Node) -> Game:
	if root is Game:
		return root as Game

	for child in root.get_children():
		var game := find_game_in_tree(child)
		if game != null:
			return game

	return null


func load_game_scene() -> void:
	resolve_scene_manager()
	if scene_manager == null:
		push_warning("GameManager: scene_manager is not assigned.")
		return

	if active_game != null and is_instance_valid(active_game):
		activate_game(active_game)
		return

	var game_scene: PackedScene = game_settings.get_game_scene()
	if game_scene == null:
		push_warning("GameManager: no game scene is assigned.")
		return

	var game_scene_instance := scene_manager.load_scene(game_scene)
	if game_scene_instance == null:
		return

	active_game = game_scene_instance as Game
	if active_game == null:
		push_warning("GameManager: configured game scene is not a Game scene.")
		return

	activate_game(active_game)


func activate_game(game: Game) -> void:
	active_game = game
	if scene_manager != null:
		scene_manager.set_active_scene(game)
	setup_game(active_game)
	active_game.start_game()


func setup_game(game: Game) -> void:
	if game_settings.game_mode != null:
		game.game_mode = game_settings.game_mode
