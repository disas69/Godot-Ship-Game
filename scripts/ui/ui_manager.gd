extends Node

const SCENE_TRANSITION_SCENE: PackedScene = preload("res://scenes/ui/scene_transition.tscn")

var library: Resource = preload("res://resources/libraries/ui_library.tres")

var entry_map: Dictionary[String, Resource] = {}
var active_screen: UiView
var active_popups: Dictionary[String, UiView] = {}
var active_popup_stack: Array[String] = []
var scene_transition
var gamepad_ui_active := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ensure_gamepad_ui_input_actions()
	rebuild_entry_map()
	create_scene_transition()


func _input(event: InputEvent) -> void:
	if is_gamepad_ui_event(event):
		activate_gamepad_ui()
	elif is_mouse_or_keyboard_event(event):
		deactivate_gamepad_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and handle_back_navigation():
		get_viewport().set_input_as_handled()


func should_use_gamepad_focus() -> bool:
	return gamepad_ui_active


func activate_gamepad_ui() -> void:
	if should_use_gamepad_focus():
		focus_top_view_if_needed()
		return

	gamepad_ui_active = true
	focus_top_view()


func deactivate_gamepad_ui() -> void:
	if not gamepad_ui_active:
		return

	gamepad_ui_active = false
	clear_focus()


func clear_focus() -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner != null:
		focus_owner.release_focus()


func is_gamepad_ui_event(event: InputEvent) -> bool:
	if event is InputEventJoypadButton:
		var button_event := event as InputEventJoypadButton
		return button_event.pressed
	if event is InputEventJoypadMotion:
		var motion_event := event as InputEventJoypadMotion
		return absf(motion_event.axis_value) >= 0.5

	return false


func is_mouse_or_keyboard_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return key_event.pressed and not key_event.echo

	return false


func ensure_gamepad_ui_input_actions() -> void:
	ensure_input_action("ui_accept")
	ensure_input_action("ui_cancel")
	ensure_input_action("ui_up")
	ensure_input_action("ui_down")
	ensure_input_action("ui_left")
	ensure_input_action("ui_right")

	add_joy_button_event("ui_accept", JOY_BUTTON_A)
	add_joy_button_event("ui_cancel", JOY_BUTTON_B)
	add_joy_button_event("ui_up", JOY_BUTTON_DPAD_UP)
	add_joy_button_event("ui_down", JOY_BUTTON_DPAD_DOWN)
	add_joy_button_event("ui_left", JOY_BUTTON_DPAD_LEFT)
	add_joy_button_event("ui_right", JOY_BUTTON_DPAD_RIGHT)
	add_joy_motion_event("ui_up", JOY_AXIS_LEFT_Y, -1.0)
	add_joy_motion_event("ui_down", JOY_AXIS_LEFT_Y, 1.0)
	add_joy_motion_event("ui_left", JOY_AXIS_LEFT_X, -1.0)
	add_joy_motion_event("ui_right", JOY_AXIS_LEFT_X, 1.0)


func ensure_input_action(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)


func add_joy_button_event(action: StringName, button_index: int) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	event.pressed = true
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)


func add_joy_motion_event(action: StringName, axis: int, axis_value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = axis_value
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)


func rebuild_entry_map() -> void:
	entry_map.clear()
	if library == null:
		push_warning("UI library is not assigned.")
		return

	for entry in library.get("entries"):
		var ui_entry := entry as Resource
		if ui_entry == null:
			continue

		var id := String(ui_entry.get("id"))
		if id.is_empty():
			continue

		var scene := ui_entry.get("scene") as PackedScene
		if scene == null:
			push_warning("UI entry '%s' has no scene assigned." % id)
			continue

		entry_map[id] = ui_entry


func open_screen(id: String) -> UiView:
	close_opened_screen()
	var view := create_view(id)
	if view == null:
		return null

	active_screen = view
	add_child(active_screen)
	active_screen.open()
	return active_screen


func close_opened_screen() -> void:
	if active_screen == null:
		return

	if is_instance_valid(active_screen):
		active_screen.close()
	active_screen = null


func open_popup(id: String) -> UiView:
	var existing := active_popups.get(id) as UiView
	if existing != null and is_instance_valid(existing):
		move_popup_to_top(id)
		existing.focus_first_control.call_deferred()
		return existing

	var popup := create_view(id)
	if popup == null:
		return null

	active_popups[id] = popup
	active_popup_stack.append(id)
	add_child(popup)
	popup.open()
	return popup


func close_popup(id: String) -> void:
	var popup := active_popups.get(id) as UiView
	if popup == null:
		return

	active_popups.erase(id)
	active_popup_stack.erase(id)
	if is_instance_valid(popup):
		popup.close()

	focus_top_view.call_deferred()


func close_all_popups() -> void:
	var popup_ids := active_popups.keys()
	for id in popup_ids:
		close_popup(String(id))


func move_popup_to_top(id: String) -> void:
	active_popup_stack.erase(id)
	active_popup_stack.append(id)

	var popup := active_popups.get(id) as UiView
	if popup != null and is_instance_valid(popup):
		move_child(popup, get_child_count() - 1)


func handle_back_navigation() -> bool:
	var top_view := get_top_view()
	if top_view == null:
		return false

	return top_view.on_back_requested()


func focus_top_view() -> void:
	var top_view := get_top_view()
	if top_view != null:
		top_view.focus_first_control()


func focus_top_view_if_needed() -> void:
	var top_view := get_top_view()
	if top_view == null:
		return

	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner is Control and top_view.is_ancestor_of(focus_owner) and top_view.is_focusable_control(focus_owner):
		return

	top_view.focus_first_control()


func get_top_view() -> UiView:
	while not active_popup_stack.is_empty():
		var id := active_popup_stack[active_popup_stack.size() - 1]
		var popup := active_popups.get(id) as UiView
		if popup != null and is_instance_valid(popup):
			return popup

		active_popup_stack.pop_back()

	if active_screen != null and is_instance_valid(active_screen):
		return active_screen

	return null


func create_view(id: String) -> UiView:
	var entry := get_entry_or_warn(id)
	if entry == null:
		return null

	var scene := entry.get("scene") as PackedScene
	var view := scene.instantiate() as UiView
	if view == null:
		push_warning("UI scene '%s' is not a UiView scene." % id)
		return null

	view.view_id = id
	return view


func get_entry_or_warn(id: String) -> Resource:
	var entry := entry_map.get(id) as Resource
	if entry == null:
		push_warning("Missing UI entry id: " + id)
	return entry


func create_scene_transition():
	if scene_transition != null and is_instance_valid(scene_transition):
		return scene_transition

	scene_transition = SCENE_TRANSITION_SCENE.instantiate()
	if not scene_transition.has_method("fade_in") or not scene_transition.has_method("fade_out"):
		push_warning("UIManager: scene transition scene is missing transition methods.")
		return null

	add_child(scene_transition)
	return scene_transition


func transition_in() -> void:
	var transition: Variant = create_scene_transition()
	if transition == null:
		return

	await transition.fade_in()


func transition_out() -> void:
	var transition: Variant = create_scene_transition()
	if transition == null:
		return

	await transition.fade_out()
