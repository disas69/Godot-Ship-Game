class_name GameScreen extends UiView

@export var timer_label: Label
@export var flags_1_label: Label
@export var flags_2_label: Label
@export var kills_1_label: Label
@export var kills_2_label: Label
@export var flag_indicators: FlagIndicators
@export var touch_controls: TouchControls


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func open() -> void:
	super.open()

	var game: Game = GameManager.instance.active_game
	while game == null:
		await get_tree().process_frame
		game = GameManager.instance.active_game

	game.game_time_changed.connect(on_timer_changed)
	game.team_kills_changed.connect(on_team_kills_changed)
	game.flags_status_changed.connect(on_flags_status_changed)
	if flag_indicators != null:
		flag_indicators.set_game(game)

	sync_from_game(game)


func sync_from_game(game: Game) -> void:
	refresh_touch_controls_visibility(game)
	on_team_kills_changed(game.good_team_kills, game.bad_team_kills)

	var good_captured: int = 0
	var bad_captured: int = 0
	var neutral: int = 0
	for flag in game.valid_flags:
		if flag == null or not is_instance_valid(flag):
			continue
		if flag.is_captured_by(Ship.Team.GoodGuys):
			good_captured += 1
		elif flag.is_captured_by(Ship.Team.BadGuys):
			bad_captured += 1
		else:
			neutral += 1

	on_flags_status_changed(good_captured, bad_captured, neutral)


func refresh_touch_controls_visibility(game: Game) -> void:
	if touch_controls == null:
		return

	var is_touch_active := false
	if game != null and game.local_players.size() == 1:
		var p1 := game.local_players[0]
		if p1 != null and is_instance_valid(p1) and p1.control_scheme == PlayerInput.CONTROL_TOUCH:
			is_touch_active = true

	touch_controls.visible = is_touch_active


func on_timer_changed(remaining_time_sec: float) -> void:
	if timer_label != null:
		timer_label.text = str(int(remaining_time_sec))


func on_team_kills_changed(good_team_kills: int, bad_team_kills: int) -> void:
	if kills_1_label != null:
		kills_1_label.text = str(good_team_kills)
	if kills_2_label != null:
		kills_2_label.text = str(bad_team_kills)


func on_flags_status_changed(good_captured: int, bad_captured: int, _neutral: int) -> void:
	if flags_1_label != null:
		flags_1_label.text = str(good_captured)
	if flags_2_label != null:
		flags_2_label.text = str(bad_captured)


func _unhandled_input(event: InputEvent) -> void:
	if should_open_pause(event):
		get_viewport().set_input_as_handled()
		UIManager.open_popup("pause")


func should_open_pause(event: InputEvent) -> bool:
	if GameManager.instance == null or GameManager.instance.active_game == null:
		return false
	if GameManager.instance.active_game.game_state != Game.GameState.Playing:
		return false
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE
	if event is InputEventJoypadButton:
		var joy_event := event as InputEventJoypadButton
		return joy_event.pressed and joy_event.button_index == JOY_BUTTON_START
	return false
