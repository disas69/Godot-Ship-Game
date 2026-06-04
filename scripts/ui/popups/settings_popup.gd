class_name SettingsPopup extends UiView

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

@export var fullscreen_button: Button
@export var windowed_button: Button
@export var resolution_option: OptionButton
@export var save_button: Button

var fullscreen := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	fullscreen = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	setup_resolution_options()

	if fullscreen_button != null:
		fullscreen_button.pressed.connect(set_fullscreen.bind(true))
	if windowed_button != null:
		windowed_button.pressed.connect(set_fullscreen.bind(false))
	if save_button != null:
		save_button.pressed.connect(on_save_pressed)


func setup_resolution_options() -> void:
	if resolution_option == null:
		return

	resolution_option.clear()
	var current_size := DisplayServer.window_get_size()
	var selected_index := 0
	for i in RESOLUTIONS.size():
		var resolution := RESOLUTIONS[i]
		resolution_option.add_item("%d x %d" % [resolution.x, resolution.y])
		resolution_option.set_item_metadata(i, resolution)
		if resolution == current_size:
			selected_index = i

	resolution_option.select(selected_index)


func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled


func on_save_pressed() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	if not fullscreen and resolution_option != null:
		var selected_resolution: Vector2i = resolution_option.get_selected_metadata()
		DisplayServer.window_set_size(selected_resolution)
	UIManager.close_popup(view_id)
