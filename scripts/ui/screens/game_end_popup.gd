class_name GameEndPopup extends UiView

@export var title_label: RichTextLabel
@export var message_label: Label
@export var stats_label: Label
@export var replay_button: Button
@export var menu_button: Button
@export var confetti_scene: PackedScene = preload("res://scenes/vfx/confetti_particles.tscn")

var confetti_instance: CPUParticles2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if replay_button != null:
		replay_button.pressed.connect(on_replay_button_pressed)
	if menu_button != null:
		menu_button.pressed.connect(on_menu_button_pressed)


func open() -> void:
	super.open()
	sync_from_game()


func sync_from_game() -> void:
	var game: Game = GameManager.instance.active_game
	if game == null:
		return

	if title_label != null:
		if game.winner_team == int(Ship.Team.GoodGuys):
			set_title_text("White Fleet Wins!")
			spawn_confetti()
		elif game.winner_team == int(Ship.Team.BadGuys):
			set_title_text("Black Fleet Wins")
		else:
			set_title_text("Draw")

	if message_label != null:
		if game.finish_reason == Game.FinishReason.AllFlagsCaptured:
			message_label.text = "All flags captured"
		else:
			message_label.text = "Time is up"

	if stats_label != null:
		stats_label.text = "White kills: %d\nBlack kills: %d" % [game.good_team_kills, game.bad_team_kills]


func spawn_confetti() -> void:
	if confetti_scene == null:
		return

	if confetti_instance != null and is_instance_valid(confetti_instance):
		confetti_instance.queue_free()

	confetti_instance = confetti_scene.instantiate() as CPUParticles2D
	if confetti_instance != null:
		add_child(confetti_instance)
		var viewport_size := get_viewport().get_visible_rect().size
		confetti_instance.position = Vector2(viewport_size.x / 2.0, -20)
		confetti_instance.restart()
		confetti_instance.emitting = true



func set_title_text(title: String) -> void:
	title_label.text = "[wave amp=15 freq=6][center][outline_color=#2d1b0e][outline_size=8]%s[/outline_size][/outline_color][/center][/wave]" % title


func on_replay_button_pressed() -> void:
	if replay_button != null:
		replay_button.disabled = true
	GameManager.instance.replay_game_scene()


func on_menu_button_pressed() -> void:
	if menu_button != null:
		menu_button.disabled = true
	GameManager.instance.return_to_menu()


func on_back_requested() -> bool:
	on_menu_button_pressed()
	return true
