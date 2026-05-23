class_name GameScreen extends UiView

@export var timer_label: Label
@export var flags_1_label: Label
@export var flags_2_label: Label
@export var kills_1_label: Label
@export var kills_2_label: Label


func open() -> void:
	super.open()

	var game: Game = GameManager.instance.active_game
	while game == null:
		await get_tree().process_frame
		game = GameManager.instance.active_game

	game.game_time_changed.connect(on_timer_changed)
	game.team_kills_changed.connect(on_team_kills_changed)
	game.flags_status_changed.connect(on_flags_status_changed)

	sync_from_game(game)


func sync_from_game(game: Game) -> void:
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
