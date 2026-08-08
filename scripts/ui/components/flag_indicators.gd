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


func on_flag_state_changed(_flag: Flag, _state: Flag.State, _team: int) -> void:
	update_indicators()


func update_indicators() -> void:
	var game := active_game
	if game == null or not is_instance_valid(game):
		hide_all_indicators()
		return

	var players := get_indicator_players(game)
	if players.is_empty() or game.valid_flags.is_empty():
		hide_all_indicators()
		return

	var ui_view_size := get_viewport().get_visible_rect().size
	if ui_view_size.x <= 0.0 or ui_view_size.y <= 0.0:
		hide_all_indicators()
		return

	var main_cam := game.camera
	var active_keys: Dictionary = {}

	for player in players:
		if player == null or not is_instance_valid(player) or player.is_destroyed:
			continue

		var camera := get_player_camera(game, player)
		if camera == null:
			continue

		var camera_view_size := get_camera_view_size(camera)
		if camera_view_size.x <= 0.0 or camera_view_size.y <= 0.0:
			continue

		var player_team := player.team
		var player_pos := player.global_position
		var player_camera_screen := camera.unproject_position(player_pos)

		for flag in game.valid_flags:
			if flag == null or not is_instance_valid(flag):
				continue
			if flag.is_captured_by(player_team):
				continue

			var key := get_indicator_key(player, flag)
			active_keys[key] = true
			update_indicator(game, main_cam, player, flag, key, camera, camera_view_size, ui_view_size, player_camera_screen)

	for key in indicators.keys():
		if not active_keys.has(key):
			hide_indicator(key)


func update_indicator(
	_game: Game,
	main_cam: MainCamera,
	player: PlayerShip,
	flag: Flag,
	key: int,
	camera: Camera3D,
	camera_view_size: Vector2,
	ui_view_size: Vector2,
	player_camera_screen: Vector2
) -> void:
	var flag_pos := flag.global_position
	var is_behind := camera.is_position_behind(flag_pos)
	var flag_camera_screen := camera.unproject_position(flag_pos)

	if is_behind:
		flag_camera_screen = camera_view_size - flag_camera_screen

	if not is_behind and is_flag_visible_for_player(main_cam, player, flag_camera_screen, camera_view_size):
		hide_indicator(key)
		return

	var marker_camera_position := get_marker_camera_position(main_cam, player, flag_camera_screen, player_camera_screen, camera_view_size)
	var marker_ui_position := camera_to_ui_screen_position(marker_camera_position, camera_view_size, ui_view_size)
	var marker := get_or_create_indicator(key, player.team)
	if marker == null:
		return

	marker.set_marker_transform(marker_ui_position, get_marker_rotation(flag_camera_screen, player_camera_screen))
	marker.show_indicator(get_distance_alpha(player, flag), get_distance_marker_scale(player, flag))


func get_or_create_indicator(key: int, player_team: Ship.Team) -> FlagIndicator:
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

	indicator.name = "FlagIndicator_%d" % key
	indicator.set_flag_texture(get_marker_texture_for_player_team(player_team))
	add_child(indicator)
	indicators[key] = indicator
	return indicator


func hide_indicator(key: int) -> void:
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
	if game.camera != null and is_instance_valid(game.camera):
		return game.camera.is_dynamic_split_active()
	return false


func is_valid_local_player(player: Variant) -> bool:
	return player != null and is_instance_valid(player) and (player is PlayerShip) and not (player as PlayerShip).is_destroyed


func is_indicator_target_for_player(flag: Variant, player: Variant) -> bool:
	if flag == null or not is_instance_valid(flag) or not (flag is Flag):
		return false
	if player == null or not is_instance_valid(player) or not (player is PlayerShip):
		return false
	return not (flag as Flag).is_captured_by((player as PlayerShip).team)


func is_flag_visible_for_player(main_cam: MainCamera, player: PlayerShip, flag_screen: Vector2, camera_view_size: Vector2) -> bool:
	if not Rect2(Vector2.ZERO, camera_view_size).has_point(flag_screen):
		return false
	if main_cam != null and main_cam.is_dynamic_split_active():
		return main_cam.is_screen_point_in_target_region(player, flag_screen, camera_view_size)
	return true


func get_marker_camera_position(main_cam: MainCamera, player: PlayerShip, flag_screen: Vector2, player_screen: Vector2, camera_view_size: Vector2) -> Vector2:
	var margin := marker_edge_margin
	var origin := clamp_screen_position(player_screen, camera_view_size, margin)
	var direction := flag_screen - origin
	if direction.is_zero_approx():
		direction = Vector2.UP

	var rect_min := Vector2(margin, margin)
	var rect_max := camera_view_size - Vector2(margin, margin)

	var edge_point := get_rect_edge_intersection(origin, direction, rect_min, rect_max)

	var split_active := main_cam != null and main_cam.is_dynamic_split_active()
	if split_active and not main_cam.is_screen_point_in_target_region(player, edge_point, camera_view_size):
		var low := origin
		var high := edge_point
		for i in range(5):
			var mid := (low + high) * 0.5
			if main_cam.is_screen_point_in_target_region(player, mid, camera_view_size):
				low = mid
			else:
				high = mid
		edge_point = low

	return edge_point


func get_rect_edge_intersection(origin: Vector2, direction: Vector2, rect_min: Vector2, rect_max: Vector2) -> Vector2:
	var t_far := INF

	if direction.x > 0.0:
		t_far = minf(t_far, (rect_max.x - origin.x) / direction.x)
	elif direction.x < 0.0:
		t_far = minf(t_far, (rect_min.x - origin.x) / direction.x)

	if direction.y > 0.0:
		t_far = minf(t_far, (rect_max.y - origin.y) / direction.y)
	elif direction.y < 0.0:
		t_far = minf(t_far, (rect_min.y - origin.y) / direction.y)

	if is_inf(t_far) or t_far <= 0.0:
		return origin

	return origin + direction * t_far


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
	if game.camera != null and is_instance_valid(game.camera):
		return game.camera.get_camera_for_target(player)
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


func get_indicator_key(player: Object, flag: Object) -> int:
	if player == null or flag == null:
		return 0
	return (player.get_instance_id() & 0xFFFFFFFF) | ((flag.get_instance_id() & 0xFFFFFFFF) << 32)
