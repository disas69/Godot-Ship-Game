class_name SceneManager extends Node

@export var root: Node
@export var scenes: Array[SceneEntry] = []
@export var initial_scene_index := 0

var active_scene: Node


func _ready() -> void:
	if root == null:
		root = self


func get_initial_scene() -> PackedScene:
	if scenes.is_empty():
		return null

	var clamped_index: int = clampi(initial_scene_index, 0, scenes.size() - 1)
	var scene_entry := scenes[clamped_index]
	if scene_entry == null:
		return null
	return scene_entry.scene


func get_scene(id: String) -> PackedScene:
	if id.is_empty():
		return null

	for scene_entry in scenes:
		if scene_entry == null:
			continue
		if scene_entry.id == id:
			return scene_entry.scene

	return null


func load_initial_scene(before_fade_out := Callable()) -> Node:
	var initial_scene: PackedScene = get_initial_scene()
	if initial_scene == null:
		push_warning("SceneManager: no initial scene is assigned.")
		return null

	return await load_packed_scene(initial_scene, true, false, before_fade_out)


func load_scene(id: String, before_fade_out := Callable()) -> Node:
	var scene: PackedScene = get_scene(id)
	if scene == null:
		push_warning("SceneManager: no scene found for id '%s'." % id)
		return null

	return await load_packed_scene(scene, true, true, before_fade_out)


func load_packed_scene(scene: PackedScene, unload_current := true, use_transition := true, before_fade_out := Callable()) -> Node:
	if scene == null:
		push_warning("SceneManager: scene is not assigned.")
		return null

	if use_transition:
		await UIManager.transition_in()

	if unload_current:
		unload_active_scene()

	var scene_instance := scene.instantiate()
	if scene_instance == null:
		push_warning("SceneManager: failed to instantiate scene.")
		await UIManager.transition_out()
		return null

	set_active_scene(scene_instance)
	root.add_child(active_scene)
	await get_tree().process_frame

	if before_fade_out.is_valid():
		before_fade_out.call(active_scene)

	if use_transition:
		await UIManager.transition_out()
	return active_scene


func unload_active_scene() -> void:
	if active_scene == null or not is_instance_valid(active_scene):
		active_scene = null
		return

	active_scene.queue_free()
	active_scene = null


func set_active_scene(scene: Node) -> void:
	active_scene = scene


func get_active_scene() -> Node:
	if active_scene != null and is_instance_valid(active_scene):
		return active_scene

	active_scene = null
	return null
