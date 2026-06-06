class_name FlagIndicators extends Control

@export var indicator_scene: PackedScene
@export var good_team_marker_texture: Texture2D
@export var bad_team_marker_texture: Texture2D
@export var marker_edge_margin: float = 28.0
@export var close_distance: float = 20.0
@export var far_distance: float = 120.0
@export_range(0.0, 1.0, 0.01) var close_alpha: float = 1.0
@export_range(0.0, 1.0, 0.01) var far_alpha: float = 0.3
@export var close_marker_scale: float = 1.2
@export var far_marker_scale: float = 0.75
@export var rotate_markers: bool = true

var active_game: Game
var indicators: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	update_indicators()


func set_game(game: Game) -> void:
	active_game = game
	connect_flag_state_signals()
	update_indicators()


func connect_flag_state_signals() -> void:
	if active_game == null or not is_instance_valid(active_game):
		return

	for flag in active_game.valid_flags:
		if flag == null or not is_instance_valid(flag):
			continue
		if not flag.state_changed.is_connected(on_flag_state_changed):
			flag.state_changed.connect(on_flag_state_changed)


func on_flag_state_changed(_flag: Flag, _state: int, _team: int) -> void:
	update_indicators()


func update_indicators() -> void:
	var game := active_game
	if game == null or not is_instance_valid(game):
		hide_all_indicators()
		return

	var active_keys: Dictionary = {}
	for player in get_indicator_players(game):
		for flag in game.valid_flags:
			if not is_indicator_target_for_player(flag, player):
				continue

			var key := get_indicator_key(player, flag)
			active_keys[key] = true
			update_indicator(game, player, flag, key)

	for key in indicators.keys():
		if not active_keys.has(key):
			hide_indicator(key)


func update_indicator(game: Game, player: PlayerShip, flag: Flag, key: String) -> void:
	var camera := get_player_camera(game, player)
	if camera == null:
		hide_indicator(key)
		return

	var camera_view_size := get_camera_view_size(camera)
	var ui_view_size := get_viewport().get_visible_rect().size
	if camera_view_size.x <= 0.0 or camera_view_size.y <= 0.0 or ui_view_size.x <= 0.0 or ui_view_size.y <= 0.0:
		hide_indicator(key)
		return

	var flag_camera_screen := camera.unproject_position(flag.global_position)
	var player_camera_screen := camera.unproject_position(player.global_position)
	if is_flag_visible_for_player(game, player, flag, camera, flag_camera_screen, camera_view_size):
		hide_indicator(key)
		return

	var marker_camera_position := get_marker_camera_position(game, player, flag_camera_screen, player_camera_screen, camera_view_size)
	var marker_ui_position := camera_to_ui_screen_position(marker_camera_position, camera_view_size, ui_view_size)
	var marker := get_or_create_indicator(key, player.team)
	if marker == null:
		return
	marker.set_marker_transform(marker_ui_position, get_marker_rotation(flag_camera_screen, player_camera_screen))
	marker.show_indicator(get_distance_alpha(player, flag), get_distance_marker_scale(player, flag))


func get_or_create_indicator(key: String, player_team: Ship.Team) -> FlagIndicator:
	var indicator := indicators.get(key) as FlagIndicator
	if indicator != null and is_instance_valid(indicator):
		indicator.set_flag_texture(get_marker_texture_for_player_team(player_team))
		return indicator

	if indicator_scene == null:
		push_warning("FlagIndicators: indicator_scene is not assigned.")
		return null

	indicator = indicator_scene.instantiate() as FlagIndicator
	if indicator == null:
		push_warning("FlagIndicators: indicator_scene root must use FlagIndicator script.")
		return null

	indicator.name = "FlagIndicator_%s" % key
	indicator.set_flag_texture(get_marker_texture_for_player_team(player_team))
	add_child(indicator)
	indicators[key] = indicator
	return indicator


func hide_indicator(key: String) -> void:
	var indicator := indicators.get(key) as FlagIndicator
	if indicator == null or not is_instance_valid(indicator):
		return
	indicator.hide_indicator()


func hide_all_indicators() -> void:
	for key in indicators.keys():
		hide_indicator(key)


func get_indicator_players(game: Game) -> Array[PlayerShip]:
	var valid_players: Array[PlayerShip] = []
	for player in game.local_players:
		if is_valid_local_player(player):
			valid_players.append(player)

	if valid_players.size() <= 1:
		return valid_players
	if is_dynamic_split_active(game):
		return valid_players
	if not are_all_players_on_same_team(valid_players):
		return valid_players

	var representative_players: Array[PlayerShip] = []
	representative_players.append(valid_players[0])
	return representative_players


func are_all_players_on_same_team(players: Array[PlayerShip]) -> bool:
	if players.is_empty():
		return true

	var team := players[0].team
	for player in players:
		if player.team != team:
			return false
	return true


func is_dynamic_split_active(game: Game) -> bool:
	if game.camera == null or not is_instance_valid(game.camera):
		return false
	if game.camera.has_method("is_dynamic_split_active"):
		return bool(game.camera.is_dynamic_split_active())
	return false


func is_valid_local_player(player: PlayerShip) -> bool:
	return player != null and is_instance_valid(player) and not player.is_destroyed


func is_indicator_target_for_player(flag: Flag, player: PlayerShip) -> bool:
	if flag == null or not is_instance_valid(flag):
		return false
	if player == null or not is_instance_valid(player):
		return false
	return not flag.is_captured_by(player.team)


func is_flag_visible_for_player(game: Game, player: PlayerShip, flag: Flag, camera: Camera3D, flag_screen: Vector2, camera_view_size: Vector2) -> bool:
	if camera.is_position_behind(flag.global_position):
		return false
	if not Rect2(Vector2.ZERO, camera_view_size).has_point(flag_screen):
		return false
	if game.camera != null and game.camera.has_method("is_screen_point_in_target_region"):
		return bool(game.camera.is_screen_point_in_target_region(player, flag_screen, camera_view_size))
	return true


func get_marker_camera_position(game: Game, player: PlayerShip, flag_screen: Vector2, player_screen: Vector2, camera_view_size: Vector2) -> Vector2:
	var origin := clamp_screen_position(player_screen, camera_view_size, marker_edge_margin)
	var direction := flag_screen - origin
	if direction.is_zero_approx():
		direction = Vector2.UP

	var far_point := origin + direction.normalized() * camera_view_size.length() * 2.0
	var low := 0.0
	var high := 1.0
	for i in range(24):
		var mid := (low + high) * 0.5
		var test_point := origin.lerp(far_point, mid)
		if is_marker_point_allowed(game, player, test_point, camera_view_size):
			low = mid
		else:
			high = mid

	var edge_point := origin.lerp(far_point, low)
	return edge_point.move_toward(origin, marker_edge_margin)


func is_marker_point_allowed(game: Game, player: PlayerShip, point: Vector2, camera_view_size: Vector2) -> bool:
	if not Rect2(Vector2.ZERO, camera_view_size).has_point(point):
		return false
	if game.camera != null and game.camera.has_method("is_screen_point_in_target_region"):
		return bool(game.camera.is_screen_point_in_target_region(player, point, camera_view_size))
	return true


func clamp_screen_position(screen_position: Vector2, screen_size: Vector2, margin: float) -> Vector2:
	return Vector2(
		clampf(screen_position.x, margin, maxf(margin, screen_size.x - margin)),
		clampf(screen_position.y, margin, maxf(margin, screen_size.y - margin))
	)


func camera_to_ui_screen_position(camera_position: Vector2, camera_view_size: Vector2, ui_view_size: Vector2) -> Vector2:
	return Vector2(
		camera_position.x / camera_view_size.x * ui_view_size.x,
		camera_position.y / camera_view_size.y * ui_view_size.y
	)


func get_player_camera(game: Game, player: PlayerShip) -> Camera3D:
	if game.camera != null and game.camera.has_method("get_camera_for_target"):
		var target_camera: Variant = game.camera.get_camera_for_target(player)
		if target_camera is Camera3D:
			return target_camera
	return get_viewport().get_camera_3d()


func get_camera_view_size(camera: Camera3D) -> Vector2:
	if camera.get_viewport() == null:
		return Vector2.ZERO
	return camera.get_viewport().get_visible_rect().size


func get_marker_texture_for_player_team(player_team: Ship.Team) -> Texture2D:
	if player_team == Ship.Team.GoodGuys:
		return bad_team_marker_texture
	return good_team_marker_texture


func get_distance_alpha(player: PlayerShip, flag: Flag) -> float:
	var weight := get_distance_weight(player, flag)
	return lerpf(close_alpha, far_alpha, weight)


func get_distance_marker_scale(player: PlayerShip, flag: Flag) -> float:
	var weight := get_distance_weight(player, flag)
	return lerpf(close_marker_scale, far_marker_scale, weight)


func get_distance_weight(player: PlayerShip, flag: Flag) -> float:
	var distance := get_horizontal_distance(player.global_position, flag.global_position)
	var distance_range := maxf(far_distance - close_distance, 0.001)
	return clampf((distance - close_distance) / distance_range, 0.0, 1.0)


func get_horizontal_distance(from: Vector3, to: Vector3) -> float:
	return Vector2(from.x - to.x, from.z - to.z).length()


func get_marker_rotation(flag_screen: Vector2, player_screen: Vector2) -> float:
	if not rotate_markers:
		return 0.0
	return (flag_screen - player_screen).angle() + PI * 0.5


func get_indicator_key(player: PlayerShip, flag: Flag) -> String:
	return "%d_%d" % [player.get_instance_id(), flag.get_instance_id()]
