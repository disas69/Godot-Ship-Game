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
		if String(scene_entry.get("id")) == id:
			return scene_entry.get("scene") as PackedScene

	return null


func load_initial_scene() -> Node:
	var initial_scene: PackedScene = get_initial_scene()
	if initial_scene == null:
		push_warning("SceneManager: no initial scene is assigned.")
		return null

	return load_packed_scene(initial_scene)


func load_scene(id: String) -> Node:
	var scene: PackedScene = get_scene(id)
	if scene == null:
		push_warning("SceneManager: no scene found for id '%s'." % id)
		return null

	return load_packed_scene(scene)


func load_packed_scene(scene: PackedScene, unload_current := true) -> Node:
	if scene == null:
		push_warning("SceneManager: scene is not assigned.")
		return null

	if unload_current:
		unload_active_scene()

	var scene_instance := scene.instantiate()
	if scene_instance == null:
		push_warning("SceneManager: failed to instantiate scene.")
		return null

	set_active_scene(scene_instance)
	root.add_child(active_scene)
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
