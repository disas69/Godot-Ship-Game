class_name GameManager extends Node3D

static var instance: GameManager

@export var game_settings: GameSettings
@export var scene_manager: SceneManager

var active_game: Game
var is_loading_game_scene := false
var is_loading_menu_scene := false


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	instance = null


func _ready() -> void:
	call_deferred("load_initial_scene")


func load_initial_scene() -> void:
	resolve_active_game()
	if active_game != null:
		activate_game(active_game)
		return
		
	await scene_manager.load_initial_scene(Callable(self, "on_initial_scene_loaded"))


func on_initial_scene_loaded(initial_scene_instance: Node) -> void:
	if initial_scene_instance is Game:
		active_game = initial_scene_instance as Game
		activate_game(active_game)
	else:
		UIManager.open_screen("menu")
		play_music()


func resolve_active_game() -> void:
	if active_game != null and is_instance_valid(active_game):
		return

	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	active_game = find_game_in_tree(current_scene)
	if active_game != null:
		scene_manager.set_active_scene(active_game)


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

	if is_loading_game_scene:
		return

	is_loading_game_scene = true
	await scene_manager.load_scene("game", Callable(self, "on_game_scene_loaded"))
	is_loading_game_scene = false


func on_game_scene_loaded(game_scene_instance: Node) -> void:
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
	connect_game_signals(active_game)
	active_game.start_game()
	UIManager.open_screen("game")


func setup_game(game: Game) -> void:
	if game_settings.game_mode != null:
		game.game_mode = game_settings.game_mode


func connect_game_signals(game: Game) -> void:
	if game == null:
		return
	if not game.game_finished.is_connected(on_game_finished):
		game.game_finished.connect(on_game_finished)


func on_game_finished(_winner_team: int, _reason: int, _good_team_kills: int, _bad_team_kills: int) -> void:
	UIManager.open_popup("game_end")


func return_to_menu() -> void:
	if is_loading_menu_scene:
		return

	is_loading_menu_scene = true
	active_game = null
	UIManager.close_all_popups()
	await scene_manager.load_scene("menu", Callable(self, "on_menu_scene_loaded"))
	is_loading_menu_scene = false


func on_menu_scene_loaded(_menu_scene_instance: Node) -> void:
	active_game = null
	UIManager.open_screen("menu")
	play_music()


func play_music() -> void:
	AudioManager.play_music("cannon_battle_main")
	AudioManager.play_music("ambient_sea")
