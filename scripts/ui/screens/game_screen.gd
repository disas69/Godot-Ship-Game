class_name GameScreen extends UiView

@export var timer_label: Label
@export var flags_1_label: Label
@export var flags_2_label: Label
@export var kills_1_label: Label
@export var kills_2_label: Label
@export var flag_indicators: FlagIndicators
@export var touch_controls: TouchControls
@export var pause_button: Button

@export_group("HUD Animation Controls")
@export var hud_panel: Control
@export var timer_container: Control
@export var flags_1_container: Control
@export var flags_2_container: Control
@export var kills_1_container: Control
@export var kills_2_container: Control

var _last_flags_1: int = -1
var _last_flags_2: int = -1
var _last_kills_1: int = -1
var _last_kills_2: int = -1
var _last_time_sec: int = -1
var _active_tweens: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if pause_button != null:
		pause_button.pressed.connect(on_pause_button_pressed)


func open() -> void:
	super.open()

	_reset_anim_tracking()
	_animate_hud_entrance()

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


func _reset_anim_tracking() -> void:
	_last_flags_1 = -1
	_last_flags_2 = -1
	_last_kills_1 = -1
	_last_kills_2 = -1
	_last_time_sec = -1


func _animate_hud_entrance() -> void:
	if hud_panel == null or not is_instance_valid(hud_panel):
		return

	var target_scale: Vector2 = hud_panel.scale
	hud_panel.pivot_offset = Vector2(hud_panel.size.x / 2.0, hud_panel.size.y)
	hud_panel.scale = target_scale * 0.7
	hud_panel.modulate.a = 0.0

	var tween := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(hud_panel, "scale", target_scale, 0.35)
	tween.tween_property(hud_panel, "modulate:a", 1.0, 0.25)


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
	var total_sec := int(maxf(0.0, remaining_time_sec))
	var minutes := floori(float(total_sec) / 60.0)
	var seconds := total_sec % 60
	var formatted_text := "%d:%02d" % [minutes, seconds]

	if timer_label != null:
		timer_label.text = formatted_text
		if total_sec <= 15 and total_sec > 0 and total_sec != _last_time_sec:
			timer_label.modulate = Color(0.9, 0.15, 0.15, 1.0)
			_punch_control(timer_container if timer_container != null else timer_label, 1.25, 0.25)
		elif total_sec > 15:
			timer_label.modulate = Color(1.0, 1.0, 1.0, 1.0)

	_last_time_sec = total_sec


func on_team_kills_changed(good_team_kills: int, bad_team_kills: int) -> void:
	if kills_1_label != null:
		kills_1_label.text = str(good_team_kills)
	if kills_2_label != null:
		kills_2_label.text = str(bad_team_kills)

	if _last_kills_1 >= 0 and good_team_kills != _last_kills_1:
		_punch_control(kills_1_container if kills_1_container != null else kills_1_label, 1.35, 0.3)
	if _last_kills_2 >= 0 and bad_team_kills != _last_kills_2:
		_punch_control(kills_2_container if kills_2_container != null else kills_2_label, 1.35, 0.3)

	_last_kills_1 = good_team_kills
	_last_kills_2 = bad_team_kills


func on_flags_status_changed(good_captured: int, bad_captured: int, _neutral: int) -> void:
	if flags_1_label != null:
		flags_1_label.text = str(good_captured)
	if flags_2_label != null:
		flags_2_label.text = str(bad_captured)

	if _last_flags_1 >= 0 and good_captured != _last_flags_1:
		_punch_control(flags_1_container if flags_1_container != null else flags_1_label, 1.4, 0.35)
	if _last_flags_2 >= 0 and bad_captured != _last_flags_2:
		_punch_control(flags_2_container if flags_2_container != null else flags_2_label, 1.4, 0.35)

	_last_flags_1 = good_captured
	_last_flags_2 = bad_captured


func _punch_control(target_node: Control, punch_scale: float = 1.3, duration: float = 0.3) -> void:
	if target_node == null or not is_instance_valid(target_node):
		return

	var orig_scale: Vector2 = target_node.scale
	target_node.pivot_offset = target_node.size / 2.0

	var tween_key := target_node.get_instance_id()
	if _active_tweens.has(tween_key) and _active_tweens[tween_key] != null and _active_tweens[tween_key].is_running():
		_active_tweens[tween_key].kill()

	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_active_tweens[tween_key] = tween

	tween.tween_property(target_node, "scale", orig_scale * punch_scale, duration * 0.45)
	tween.tween_property(target_node, "scale", orig_scale, duration * 0.55)


func on_pause_button_pressed() -> void:
	if can_open_pause():
		UIManager.open_popup("pause")


func can_open_pause() -> bool:
	if GameManager.instance == null or GameManager.instance.active_game == null:
		return false
	return GameManager.instance.active_game.game_state == Game.GameState.Playing


func _unhandled_input(event: InputEvent) -> void:
	if should_open_pause(event):
		get_viewport().set_input_as_handled()
		UIManager.open_popup("pause")


func should_open_pause(event: InputEvent) -> bool:
	if not can_open_pause():
		return false
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE
	if event is InputEventJoypadButton:
		var joy_event := event as InputEventJoypadButton
		return joy_event.pressed and joy_event.button_index == JOY_BUTTON_START
	return false
