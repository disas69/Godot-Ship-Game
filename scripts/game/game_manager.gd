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
	if OS.has_feature("web"):
		setup_web_rendering()
	call_deferred("load_initial_scene")


func setup_web_rendering() -> void:
	var env := load("res://scenes/main-environment.tres") as Environment
	if env != null:
		env.ambient_light_energy = 0.95
		env.adjustment_enabled = false
		env.glow_intensity = 1.2


func adjust_scene_lights_for_web(scene_instance: Node) -> void:
	if not OS.has_feature("web") or scene_instance == null:
		return
	for light in scene_instance.find_children("*", "DirectionalLight3D", true, false):
		if light is DirectionalLight3D:
			light.light_energy = 0.95






func load_initial_scene() -> void:
	resolve_active_game()
	if active_game != null:
		activate_game(active_game)
		return
		
	await scene_manager.load_initial_scene(Callable(self, "on_initial_scene_loaded"))


func on_initial_scene_loaded(initial_scene_instance: Node) -> void:
	adjust_scene_lights_for_web(initial_scene_instance)
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


func start_new_game_scene() -> void:
	if is_loading_game_scene:
		return

	is_loading_game_scene = true
	active_game = null
	UIManager.close_all_popups()
	await scene_manager.load_scene("game", Callable(self, "on_game_scene_loaded"))
	is_loading_game_scene = false


func replay_game_scene() -> void:
	await start_new_game_scene()


func configure_local_game(player_count: int, player_device: String) -> void:
	var configs: Array[Dictionary] = [{
		"team": Ship.Team.GoodGuys,
		"control_scheme": player_device,
	}]
	if player_count >= 2:
		configs.append({
			"team": Ship.Team.BadGuys,
			"control_scheme": PlayerInput.CONTROL_GAMEPAD_1 if player_device != PlayerInput.CONTROL_GAMEPAD_1 else PlayerInput.CONTROL_GAMEPAD_2,
		})

	configure_local_game_players(configs)


func configure_local_game_players(local_player_configs: Array[Dictionary]) -> void:
	if game_settings == null:
		return
	if local_player_configs.is_empty():
		return

	game_settings.player_count = clampi(local_player_configs.size(), 1, 2)
	game_settings.player_device = String(local_player_configs[0].get("control_scheme", PlayerInput.CONTROL_KEYBOARD))

	if game_settings.game_mode == null:
		game_settings.game_mode = create_local_game_mode(game_settings.player_count)

	replace_local_players_in_mode(game_settings.game_mode, local_player_configs)


func replace_local_players_in_mode(mode: GameMode, local_player_configs: Array[Dictionary]) -> void:
	var good_team_max_count := mode.good_team_players.size()
	var bad_team_max_count := mode.bad_team_players.size()

	demote_local_players(mode.good_team_players)
	demote_local_players(mode.bad_team_players)

	var good_local_insert_index := 0
	var bad_local_insert_index := 0
	for i in range(local_player_configs.size()):
		var config := local_player_configs[i]
		var team: Ship.Team = int(config.get("team", Ship.Team.GoodGuys)) as Ship.Team
		var control_scheme := String(config.get("control_scheme", PlayerInput.CONTROL_KEYBOARD))
		var player := Player.new("Player %d" % [i + 1], team, true, control_scheme, i)
		var team_players := mode.good_team_players if team == Ship.Team.GoodGuys else mode.bad_team_players
		var insert_index := good_local_insert_index if team == Ship.Team.GoodGuys else bad_local_insert_index
		if insert_index < team_players.size():
			team_players[insert_index] = player
		else:
			team_players.append(player)
		if team == Ship.Team.GoodGuys:
			good_local_insert_index += 1
		else:
			bad_local_insert_index += 1

	trim_team_players(mode.good_team_players, maxi(good_team_max_count, good_local_insert_index))
	trim_team_players(mode.bad_team_players, maxi(bad_team_max_count, bad_local_insert_index))


func demote_local_players(players: Array[Player]) -> void:
	for player in players:
		if player == null or not player.is_local:
			continue

		player.is_local = false
		player.control_scheme = PlayerInput.CONTROL_KEYBOARD
		player.local_player_index = -1


func trim_team_players(players: Array[Player], max_count: int) -> void:
	while players.size() > max_count:
		players.remove_at(players.size() - 1)


func create_local_game_mode(player_count: int) -> GameMode:
	var mode := GameMode.new()
	mode.game_duration_sec = 60 * 3
	mode.respawn_delay_sec = 3.0

	mode.good_team_players.append(Player.new("Player 1", Ship.Team.GoodGuys, true))
	if player_count >= 2:
		mode.bad_team_players.append(Player.new("Player 2", Ship.Team.BadGuys, true))
	else:
		mode.bad_team_players.append(Player.new("Black Bot 1", Ship.Team.BadGuys, false))

	mode.good_team_players.append(Player.new("White Bot 1", Ship.Team.GoodGuys, false))
	mode.bad_team_players.append(Player.new("Black Bot 2", Ship.Team.BadGuys, false))
	return mode


func on_game_scene_loaded(game_scene_instance: Node) -> void:
	active_game = game_scene_instance as Game
	if active_game == null:
		push_warning("GameManager: configured game scene is not a Game scene.")
		return

	activate_game(active_game)


func activate_game(game: Game) -> void:
	active_game = game
	adjust_scene_lights_for_web(active_game)
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


func on_game_finished(_winner_team: int, _reason: Game.FinishReason, _good_team_kills: int, _bad_team_kills: int) -> void:
	UIManager.open_popup("game_end")


func return_to_menu() -> void:
	if is_loading_menu_scene:
		return

	is_loading_menu_scene = true
	get_tree().paused = false
	active_game = null
	UIManager.close_all_popups()
	await scene_manager.load_scene("menu", Callable(self, "on_menu_scene_loaded"))
	is_loading_menu_scene = false


func on_menu_scene_loaded(menu_scene_instance: Node) -> void:
	active_game = null
	adjust_scene_lights_for_web(menu_scene_instance)
	UIManager.open_screen("menu")
	play_music()



func play_music() -> void:
	AudioManager.play_music("cannon_battle_main")
	AudioManager.play_music("ambient_sea")
