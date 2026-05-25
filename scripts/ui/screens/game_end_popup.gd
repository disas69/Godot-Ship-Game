class_name GameEndPopup extends UiView

@export var title_label: Label
@export var message_label: Label
@export var menu_button: Button


func _ready() -> void:
	if menu_button == null:
		push_warning("GameEndPopup: menu_button is not assigned.")
		return

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
			title_label.text = "White Fleet Wins"
		elif game.winner_team == int(Ship.Team.BadGuys):
			title_label.text = "Black Fleet Wins"
		else:
			title_label.text = "Draw"

	if message_label != null:
		if game.finish_reason == Game.FinishReason.AllFlagsCaptured:
			message_label.text = "All flags captured"
		else:
			message_label.text = "Time is up"


func on_menu_button_pressed() -> void:
	if menu_button != null:
		menu_button.disabled = true
	GameManager.instance.return_to_menu()
