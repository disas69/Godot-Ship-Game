extends Node

const SCENE_TRANSITION_SCENE: PackedScene = preload("res://scenes/ui/scene_transition.tscn")

var library: Resource = preload("res://resources/libraries/ui_library.tres")

var entry_map: Dictionary[String, Resource] = {}
var active_screen: UiView
var active_popups: Dictionary[String, UiView] = {}
var scene_transition


func _ready() -> void:
	rebuild_entry_map()
	create_scene_transition()


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
		return existing

	var popup := create_view(id)
	if popup == null:
		return null

	active_popups[id] = popup
	add_child(popup)
	popup.open()
	return popup


func close_popup(id: String) -> void:
	var popup := active_popups.get(id) as UiView
	if popup == null:
		return

	active_popups.erase(id)
	if is_instance_valid(popup):
		popup.close()


func close_all_popups() -> void:
	var popup_ids := active_popups.keys()
	for id in popup_ids:
		close_popup(String(id))


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
